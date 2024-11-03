let audioContext = null;
const oscList = [];
let mainGainNode = null;
let compressorNode = null;

// global vars for constructing waveforms
let noteFreq = null;
let customWaveform = null;
let sineTerms = null;
let cosineTerms = null;


const attackTime = 0.03;
const decayTimeConstant = 0.01;
const releaseTimeConstant = 0.05;


function setup() {
	audioContext = new AudioContext();

	compressorNode = audioContext.createDynamicsCompressor();
	// threshold: The decibel value above which the compression will start
	//            taking effect.
	compressorNode.threshold.setValueAtTime(-50, audioContext.currentTime);
	// knee: A decibel value representing the range above the threshold where
	//       the curve smoothly transitions to the compressed portion.
	compressorNode.knee.setValueAtTime(40, audioContext.currentTime);
	// ratio: The amount of change, in dB, needed in the input for a
	//        1 dB change in the output.
	compressorNode.ratio.setValueAtTime(12, audioContext.currentTime);
	// attack: The amount of time, in seconds, required to reduce the gain by 10 dB.
	compressorNode.attack.setValueAtTime(0, audioContext.currentTime);
	// release: The amount of time, in seconds, required to increase the gain by 10 dB.
	compressorNode.release.setValueAtTime(0.25, audioContext.currentTime);

	mainGainNode = audioContext.createGain();
	mainGainNode.connect(compressorNode);
	compressorNode.connect(audioContext.destination);
	mainGainNode.gain.value = 0.5;
	sineTerms = new Float32Array([0, 0, 1, 0, 1]);
	cosineTerms = new Float32Array(sineTerms.length);
	customWaveform = audioContext.createPeriodicWave(cosineTerms, sineTerms);

	// setupQueues();
}

const qs = [];
const soundLookup = {
	pause: "./sounds/pause.mp3",
	unpause: "./sounds/unpause.mp3",
	pop: "./sounds/pop.mp3",
};
const indexToSound = {
	0: "pause",
	1: "unpause",
	2: "pop",
}

function setupQueues() {
	console.log("starting setupQueues");
	qs.push(createSoundQueue(soundLookup["pause"], 3));
	qs.push(createSoundQueue(soundLookup["unpause"], 3));
	qs.push(createSoundQueue(soundLookup["pop"], 3));
	console.log("done setupQueues");
}

function createSoundQueue(url, count) {
	let q = {};
	q.players = [];
	for (let i = 0; i < count; i++) {
		const element = new Audio(url);
		element.playbackRate = 1.0;
		element.preservesPitch = false;
		const player = {
			element,
			canPlay: false,
			isPlaying: false,
		};
		element.addEventListener("canplaythrough", (event) => {
			console.log("canplaythrough");
			player.canPlay = true;
		});
		element.addEventListener("ended", (event) => {
			// console.log("ended");
			player.isPlaying = false;
		});
		element.addEventListener("play", (event) => {
			// console.log("play");
			player.isPlaying = true;
		});
		q.players.push(player);
	}
	return q;
}

function qPlay(index, rate) {
	if (qs.length <= index) {
		console.log(`No sounds queue for index ${index}`);
		return;
	}
	const q = qs[index];
	for (let i = 0; i < q.players.length; i++) {
		const player = q.players[i];
		if (player.canPlay && !player.isPlaying) {
			console.log(`sound[${index}] playing player ${i}`);
			player.element.playbackRate = rate;
			player.element.play();
			break;
		}
	}
}

function playSound(index, rate) {
	qPlay(index, rate);
}

function playTone(index, freq) {
	let ampInitialGain = 0.0;
	let osc = null;
	let amp = null;

	if (oscList[index] == undefined) {
		oscList[index] = {};
		oscList[index].osc = audioContext.createOscillator();
		oscList[index].amp = audioContext.createGain();
		oscList[index].pressed = true;
		osc = oscList[index].osc;
		amp = oscList[index].amp;
		osc.connect(amp);
		amp.connect(mainGainNode);
		const type = "sine";
		if (type === "custom") {
			osc.setPeriodicWave(customWaveform);
		} else {
			osc.type = type;
		}
		osc.frequency.value = freq;
		osc.start();
	} else {
		ampInitialGain = oscList[index].amp.gain.value;
		osc = oscList[index].osc;
		amp = oscList[index].amp;
	}
	const time = audioContext.currentTime;
	amp.gain.cancelScheduledValues(time);
	amp.gain.setValueAtTime(ampInitialGain, time);
	amp.gain.linearRampToValueAtTime(1, time + attackTime);
	amp.gain.setTargetAtTime(0.5, time + attackTime, decayTimeConstant);
}

function release(index) {
	if (oscList[index] == undefined) {
		return;
	}
	const amp = oscList[index].amp;
	const time = audioContext.currentTime;
	const ampInitialGain = amp.gain.value;
	amp.gain.cancelScheduledValues(time);
	amp.gain.setValueAtTime(ampInitialGain, time);
	amp.gain.setTargetAtTime(0, time, releaseTimeConstant);
	oscList[index].pressed = false;
}

function setupImports(wasmMemoryInterface, consoleElement, memory) {
	const env = {};
	if (memory) {
		env.memory = memory;
	}
	return {
		env,
		"odin_sound": {
			play_sound: (index, rate) => {
				playSound(index, rate);
			},
			note_pressed: (index, freq) => {
				// console.log(`note_pressed(index: ${index}, freq: ${freq})`);
				if (!audioContext) {
					setup();
				}
				playTone(index, freq);
			},
			note_released: (index) => {
				// console.log(`note_released(index: ${index})`);
				if (!audioContext) {
					setup();
				}
				release(index);
			}
		},
	};
}
window.odinSound = {
	setupImports: setupImports,
	load: setupQueues,
}