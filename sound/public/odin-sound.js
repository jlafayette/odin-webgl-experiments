let audioContext = null;
let mainGainNode = null;
let compressorNode = null;

const soundLookup = {
	pause: "./sounds/pause.mp3",
	unpause: "./sounds/unpause.mp3",
	pop: "./sounds/pop.mp3",
	thud: "./sounds/thud.mp3",
};
const indexToSound = {
	0: "pause",
	1: "unpause",
	2: "pop",
	3: "thud",
}

// TODO: try buffer -> multiple buffer sources to play
// https://developer.mozilla.org/en-US/docs/Web/API/AudioBufferSourceNode
const qs = []
function setupQueues() {
	console.log("starting setupQueues");
	qs.push(createSoundQueue(soundLookup["pause"], 3));
	qs.push(createSoundQueue(soundLookup["unpause"], 3));
	qs.push(createSoundQueue(soundLookup["pop"], 3));
	qs.push(createSoundQueue(soundLookup["thud"], 3));
	console.log("done setupQueues");
}

function addToQ(q) {
	const element = new Audio(q.url);
	const source = audioContext.createMediaElementSource(element);
	element.playbackRate = 1.0;
	element.preservesPitch = false;
	const player = {
		element,
		source,
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
	player.source.connect(mainGainNode);
	q.players.push(player);
}

function createSoundQueue(url, count) {
	let q = {
		players: [],
		url: url,
		maxCount: count,
	};
	addToQ(q);
	return q;
}

function qPlay(index, rate) {
	if (qs.length <= index) {
		console.log(`No sounds queue for index ${index}`);
		return;
	}
	let played = false;
	const q = qs[index];
	for (let i = 0; i < q.players.length; i++) {
		const player = q.players[i];
		if (player.canPlay && !player.isPlaying) {
			console.log(`sound[${index}] playing player ${i}`);
			player.element.playbackRate = rate;
			player.element.play();
			played = true;
			break;
		}
	}
	if (!played) {
		console.log(`Failed to play sound, have ${q.players.length} of max ${q.maxCount}`);
	}
	if (q.players.length < q.maxCount) {
		addToQ(q);
	}
}

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
	// g_player.source.connect(mainGainNode);
	mainGainNode.connect(compressorNode);
	compressorNode.connect(audioContext.destination);

	mainGainNode.gain.value = 0.5;

	setupQueues();
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
				if (!audioContext) {
					setup();
				}
				qPlay(index, rate);
			},
		},
	};
}
window.odinSound = {
	setupImports: setupImports,
}