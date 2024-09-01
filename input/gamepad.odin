package input

import "core:fmt"

Button :: struct {
	pressed: bool,
	touched: bool,
	value: f32,
}
@export
gamepad_button_pressed_offset :: proc() -> i32 {
	return cast(i32)offset_of(Button, pressed)
}
@export
gamepad_button_touched_offset :: proc() -> i32 {
	return cast(i32)offset_of(Button, touched)
}
@export
gamepad_button_value_offset :: proc() -> i32 {
	return cast(i32)offset_of(Button, value)
}
@export
gamepad_button_size :: proc() -> i32 {
	return cast(i32)size_of(Button)
}
Gamepad :: struct {
	connected: bool,
	buttons: [17]Button,
	axes: [4]f32,
}
@export
gamepad_connected_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, connected)
}
@export
gamepad_buttons_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, buttons)
}
@export
gamepad_axes_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, axes)
}

GAMEPAD_POINTER: ^Gamepad
GAMEPAD_SIZE: i32 = 0

@export
gamepad_alloc :: proc() -> ^Gamepad {
	fmt.println("alloc_gamepad ...")
	gp := new(Gamepad, allocator=arena_allocator)
	GAMEPAD_POINTER = gp
	GAMEPAD_SIZE = size_of(Gamepad)
	fmt.println("allocated", GAMEPAD_SIZE, "bytes")
	return gp
}
