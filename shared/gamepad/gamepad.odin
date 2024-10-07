package gamepad

foreign import odin_gamepad "odin_gamepad"

import "core:fmt"

Button :: struct {
	pressed: bool,
	touched: bool,
	value:   f32,
}
Gamepad :: struct {
	connected: bool,
	buttons:   [17]Button,
	axes:      [4]f32,
}

get_input :: proc() -> Gamepad {
	@(default_calling_convention = "contextless")
	foreign odin_gamepad {
		@(link_name = "getInput")
		_getInput :: proc(connected_out: ^bool, axis_out: ^[4]f64, buttons_ptr: ^[17]Button, button_size: i32, button_pressed_offset: i32, button_touched_offset: i32, button_value_offset: i32) ---
	}
	connected_out: bool
	axis_out: [4]f64
	g: Gamepad
	_getInput(
		&connected_out,
		&axis_out,
		&g.buttons,
		cast(i32)size_of(Button),
		cast(i32)offset_of(Button, pressed),
		cast(i32)offset_of(Button, touched),
		cast(i32)offset_of(Button, value),
	)
	g.connected = connected_out
	for axis, i in axis_out {
		g.axes[i] = f32(axis)
	}
	for btn, i in g.buttons {
		if btn.pressed || btn.touched {
			fmt.printf("Button[%d] pressed: %.2f\n", i, btn.value)
		}
	}
	return g
}

