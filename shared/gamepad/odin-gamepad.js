let gp_state = {
	logged: false,
};

function setupImports(wasmMemoryInterface, consoleElement, memory) {
	const env = {};
	if (memory) {
		env.memory = memory;
	}
	return {
		env,
		"odin_gamepad": {
			getInput: (
				connected_u8_ptr,
				axis_ptr_array4_f64,
				buttons_ptr,
				button_size,
				button_pressed_offset,
				button_touched_offset,
				button_value_offset,
			) => {
				let gamepads = navigator.getGamepads();
				let gp = null;
				wasmMemoryInterface.storeU8(connected_u8_ptr, false);
				for (let i = 0; i < gamepads.length; i++) {
					if (gamepads[i] != null) {
						gp = gamepads[i];
						wasmMemoryInterface.storeU8(connected_u8_ptr, true);
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

				let axis_values = wasmMemoryInterface.loadF64Array(axis_ptr_array4_f64, 4);
				for (let i = 0; i < gp.axes.length; i++) {
					if (i >= 4) {
						break;
					}
					let value = gp.axes[i];
					axis_values[i] = value;
				}

				for (let i = 0; i < gp.buttons.length; i++) {
					if (i >= 17) {
						break;
					}
					let btn = gp.buttons[i];
					let btn_ptr = buttons_ptr + (i * button_size);
					wasmMemoryInterface.storeU8(btn_ptr + button_pressed_offset, btn.pressed);
					wasmMemoryInterface.storeU8(btn_ptr + button_touched_offset, btn.touched);
					wasmMemoryInterface.storeF32(btn_ptr + button_value_offset, btn.value);
				}
			},
		},
	};
}
window.odinGamepad = {
	setupImports: setupImports,
}
