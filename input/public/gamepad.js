let gp_state = {
	ptr: null,
	logged: false,
};

export function setup(wasmMemoryInterface, exports) {
	gp_state.ptr = exports.gamepad_alloc();
}

export function step(wasmMemoryInterface, exports) {
	let gamepads = navigator.getGamepads();
	let gp = null;
	let gp_ptr = gp_state.ptr;

	const offset = {
		button_pressed: exports.gamepad_button_pressed_offset(),
		button_touched: exports.gamepad_button_touched_offset(),
		button_value: exports.gamepad_button_value_offset(),
		gamepad_connected: exports.gamepad_connected_offset(),
		gamepad_buttons: exports.gamepad_buttons_offset(),
		gamepad_axes: exports.gamepad_axes_offset(),
	};
	const button_size = exports.gamepad_button_size();

	wasmMemoryInterface.storeU8(gp_ptr + offset.gamepad_connected, false);
	for (let i = 0; i < gamepads.length; i++) {
		if (gamepads[i] != null) {
			gp = gamepads[i];
			wasmMemoryInterface.storeU8(gp_ptr + offset.gamepad_connected, true);
			break;
		}
	}
	if (!gp) {
		return;
	}
	if (!gp_state.logged) {
		gp_state.logged = true;
		console.log(`Gamepad connected at index ${gp.index}: ${gp.id}. It has ${gp.buttons.length} buttons and ${gp.axes.length} axes.`);
		console.log(gp);
	}
	for (let i = 0; i < gp.buttons.length; i++) {
		let btn = gp.buttons[i];
		let btn_ptr = gp_ptr + offset.gamepad_buttons + (i * button_size);
		if (gp) {
			wasmMemoryInterface.storeU8(btn_ptr + offset.button_pressed, btn.pressed);
			wasmMemoryInterface.storeU8(btn_ptr + offset.button_touched, btn.touched);
			wasmMemoryInterface.storeF32(btn_ptr + offset.button_value, btn.value);
		}
		if (btn.pressed || btn.touched) {
			console.log(`btn[${i}]: ${btn.value}`);
		}
	}
	for (let i = 0; i < gp.axes.length; i++) {
		let value = gp.axes[i];
		let ptr = gp_ptr + offset.gamepad_axes + (i * 4);
		wasmMemoryInterface.storeF32(ptr, value);
	}
}
