let mouse_pos_state = {
	ptr: null,
	x: 0,
	y: 0,
	logged: false,
};

function getMousePos(canvas, evt) {
	let rect = canvas.getBoundingClientRect();
	let pos = {
		x: (evt.clientX - rect.left) / (rect.right - rect.left) * canvas.width,
		y: (evt.clientY - rect.top) / (rect.bottom - rect.top) * canvas.height
	};
	// make 0,0 in lower left instead of upper left
	pos.y = canvas.height - pos.y;
	return pos;
}

export function setup(wasmMemoryInterface, exports) {
	if (!exports.mouse_pos_alloc) {
		console.warn("No mouse_pos_alloc function is exported by wasm");
		return;
	}
	mouse_pos_state.ptr = exports.mouse_pos_alloc();
	window.addEventListener('mousemove', function (evt) {
		let canvas = document.getElementById("canvas-1");
		let pos = getMousePos(canvas, evt);
		// console.log(pos);
		mouse_pos_state.x = pos.x;
		mouse_pos_state.y = pos.y;
	}, false);
}

export function step(wasmMemoryInterface, exports) {
	if (!exports.mouse_pos_alloc || !exports.mouse_pos_x_offset || !exports.mouse_pos_y_offset) {
		if (!mouse_pos_state.logged) {
			mouse_pos_state.logged = true;
			console.warn("Missing required wasm bindings for mouse-pos interface");
		}
		return;
	}
	// console.log(`step: ${mouse_pos_state.x},${mouse_pos_state.y}`);
	let ptr = mouse_pos_state.ptr;
	let offset_x = exports.mouse_pos_x_offset();
	let offset_y = exports.mouse_pos_y_offset();
	wasmMemoryInterface.storeF32(ptr + offset_x, mouse_pos_state.x);
	wasmMemoryInterface.storeF32(ptr + offset_y, mouse_pos_state.y);
}
