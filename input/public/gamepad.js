let gp_state = {
	ptr: null,
	logged: false,
};

function u8FromButton(button) {
	if (button.pressed) {
		return 255;
	}
	return 0;
}
function f32FromButton(button) {
	return button.value;
}

export function setup(wasmMemoryInterface, exports) {
	exports.alloc_123();
	let ptr = exports.get_buffer_pointer();
	let size = exports.get_buffer_size();
	console.log(ptr, size);
	let result = wasmMemoryInterface.loadBytes(ptr, size);
	console.log(result);

	exports.alloc_3_f32();
	ptr = exports.get_buffer_f32_pointer();
	size = exports.get_buffer_f32_size();
	console.log(ptr, size);
	result = wasmMemoryInterface.loadF32Array(ptr, size);
	console.log(result);

	exports.print_f32_array();
	wasmMemoryInterface.storeF32(ptr, 111.111);
	wasmMemoryInterface.storeF32(ptr + 4, 222.222);
	wasmMemoryInterface.storeF32(ptr + 8, 333.333);
	exports.print_f32_array();

	gp_state.ptr = exports.gamepad_alloc();
}

export function step(wasmMemoryInterface, exports) {
	let gamepads = navigator.getGamepads();
	let gp = null;
	let gp_ptr = gp_state.ptr;

	wasmMemoryInterface.storeU8(gp_ptr + exports.gamepad_connect_offset(), 0);
	for (let i = 0; i < gamepads.length; i++) {
		if (gamepads[i] != null) {
			gp = gamepads[i];
			wasmMemoryInterface.storeU8(gp_ptr + exports.gamepad_connect_offset(), 255);
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
		if (btn.pressed || btn.touched) {
			console.log(`btn[${i}]: ${btn.value}`);
		}
	}
	const offset = {
		btn_a: exports.gamepad_btn_a_pressed_offset(),
		btn_b: exports.gamepad_btn_b_pressed_offset(),
		btn_x: exports.gamepad_btn_x_pressed_offset(),
		btn_y: exports.gamepad_btn_y_pressed_offset(),
		trigger_left: exports.gamepad_trigger_left_offset(),
		trigger_right: exports.gamepad_trigger_right_offset(),
		stick_left: exports.gamepad_stick_left_offset(),
		stick_right: exports.gamepad_stick_right_offset(),
	};
	wasmMemoryInterface.storeU8(gp_ptr + offset.btn_a, u8FromButton(gp.buttons[0]));
	wasmMemoryInterface.storeU8(gp_ptr + offset.btn_b, u8FromButton(gp.buttons[1]));
	wasmMemoryInterface.storeU8(gp_ptr + offset.btn_x, u8FromButton(gp.buttons[2]));
	wasmMemoryInterface.storeU8(gp_ptr + offset.btn_y, u8FromButton(gp.buttons[3]));

	wasmMemoryInterface.storeF32(gp_ptr + offset.trigger_left, f32FromButton(gp.buttons[6]));
	wasmMemoryInterface.storeF32(gp_ptr + offset.trigger_right, f32FromButton(gp.buttons[7]));

	wasmMemoryInterface.storeF32(gp_ptr + offset.stick_left, gp.axes[0]);
	wasmMemoryInterface.storeF32(gp_ptr + offset.stick_left + 4, gp.axes[1]);
	wasmMemoryInterface.storeF32(gp_ptr + offset.stick_right, gp.axes[2]);
	wasmMemoryInterface.storeF32(gp_ptr + offset.stick_right + 4, gp.axes[3]);
}