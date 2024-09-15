function setupImports(wasmMemoryInterface, consoleElement, memory) {
	const env = {};
	if (memory) {
		env.memory = memory;
	}
	return {
		env,
		"odin_mouse": {
			getMousePos: (ptr_array2_f64, canvas_id_ptr, canvas_id_len, client_x, client_y, flip_y) => {
				let canvasId = wasmMemoryInterface.loadString(canvas_id_ptr, canvas_id_len);
				let canvas = document.getElementById(canvasId);
				let rect = canvas.getBoundingClientRect();
				let pos = {
					x: (Number(client_x) - rect.left) / (rect.right - rect.left) * canvas.width,
					y: (Number(client_y) - rect.top) / (rect.bottom - rect.top) * canvas.height
				};
				if (flip_y) {
					// make 0,0 in lower left instead of upper left
					pos.y = canvas.height - pos.y;
				}
				let values = wasmMemoryInterface.loadF64Array(ptr_array2_f64, 2);
				values[0] = pos.x;
				values[1] = pos.y;
			}
		},
	};
}
window.odinMouse = {
	setupImports: setupImports,
}