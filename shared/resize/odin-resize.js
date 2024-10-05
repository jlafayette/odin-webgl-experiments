let remove = null;
let dpr = 1;
const updatePixelRatio = () => {
	if (remove != null) {
		remove();
	}
	const mqString = `(resolution: ${window.devicePixelRatio}dppx)`;
	const media = matchMedia(mqString);
	media.addEventListener("change", updatePixelRatio);
	remove = () => {
		media.removeEventListener("change", updatePixelRatio);
	};
	dpr = window.devicePixelRatio;
	console.log(`devicePixelRatio: ${dpr}`);
};
updatePixelRatio();

function setupImports(wasmMemoryInterface, consoleElement, memory) {
	const env = {};
	if (memory) {
		env.memory = memory;
	}
	return {
		env,
		"odin_resize": {
			updateSizeInfo: (ptr_array6_f64) => {
				const canvas = document.getElementById("canvas-1");
				// const dpr = window.devicePixelRatio || 1;
				const rect = canvas.getBoundingClientRect()
				canvas.width = rect.width * dpr
				// canvas.width = window.innerWidth;
				// canvas.height = window.innerHeight;
				canvas.height = rect.height * dpr
				let values = wasmMemoryInterface.loadF64Array(ptr_array6_f64, 7);
				values[0] = window.innerWidth;
				values[1] = window.innerHeight;
				values[2] = rect.width;
				values[3] = rect.height;
				values[4] = rect.left;
				values[5] = rect.top;
				values[6] = dpr;
			},
		},
	};
}
window.odinResize = {
	setupImports: setupImports,
}
