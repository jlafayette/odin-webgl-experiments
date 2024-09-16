let audioContext = null;
const oscList = [];
let mainGainNode = null;

// global vars for constructing waveforms
let noteFreq = null;
let customWaveform = null;
let sineTerms = null;
let cosineTerms = null;


function setup() {
	audioContext = new AudioContext();
	mainGainNode = audioContext.createGain();
	mainGainNode.connect(audioContext.destination);
	mainGainNode.gain.value = 0.5;
	sineTerms = new Float32Array([0, 0, 1, 0, 1]);
	cosineTerms = new Float32Array(sineTerms.length);
	customWaveform = audioContext.createPeriodicWave(cosineTerms, sineTerms);
}
function playTone(freq) {
	const osc = audioContext.createOscillator();
	osc.connect(mainGainNode);
	const type = "custom";
	if (type === "custom") {
		osc.setPeriodicWave(customWaveform);
	} else {
		osc.type = type;
	}
	osc.frequency.value = freq;
	osc.start();
	return osc;
}


function setupImports(wasmMemoryInterface, consoleElement, memory) {
	const env = {};
	if (memory) {
		env.memory = memory;
	}
	return {
		env,
		"odin_synth": {
			note_pressed: (index, freq) => {
				// console.log(`note_pressed(index: ${index}, freq: ${freq})`);
				if (!audioContext) {
					setup();
				}
				if (oscList[index] == undefined) {
					oscList[index] = {};
				}
				if (!oscList[index].pressed) {
					oscList[index].osc = playTone(freq);
					oscList[index].pressed = true;
				}
			},
			note_released: (index) => {
				// console.log(`note_released(index: ${index})`);
				if (!audioContext) {
					setup();
				}
				if (oscList[index] == undefined) {
					oscList[index] = {};
				}
				if (oscList[index].osc) {
					oscList[index].osc.stop();
					delete oscList[index].osc;
					oscList[index].pressed = false;
				}
			}
		},
	};
}
window.odinSynth = {
	setupImports: setupImports,
}