package input

import "core:fmt"

BUFFER_POINTER: [^]u8
BUFFER_SIZE: i32 = 0
@export
alloc_123 :: proc() {
	fmt.println("alloc_123 ...")
	a := make([]u8, 3, allocator=arena_allocator)
	a[0] = 1
	a[1] = 2
	a[2] = 3
	BUFFER_POINTER = raw_data(a[:])
	BUFFER_SIZE = cast(i32)len(a)
	fmt.println("allocated:", a)
}
@export
get_buffer_pointer :: proc() -> [^]u8 {
	return BUFFER_POINTER
}
@export
get_buffer_size :: proc() -> i32 {
	return BUFFER_SIZE
}

F32_POINTER: [^]f32
F32_SIZE: i32 = 0
@export
alloc_3_f32 :: proc() {
	fmt.println("alloc_3_f32 ...")
	a := make([]f32, 3, allocator=arena_allocator)
	a[0] = -32.1
	a[1] = 0.123
	a[2] = 321.31
	F32_POINTER = raw_data(a[:])
	F32_SIZE = cast(i32)len(a)
	fmt.println("allocated:", a)
}
@export
get_buffer_f32_pointer :: proc() -> [^]f32 {
	return F32_POINTER
}
@export
get_buffer_f32_size :: proc() -> i32 {
	return F32_SIZE
}
@export
print_f32_array :: proc() {
	pos : []f32 = F32_POINTER[0:F32_SIZE]
	fmt.println("In Odin pos=", pos)
}

Gamepad :: struct {
	connected: bool,
	btn_a_pressed: bool,
	btn_b_pressed: bool,
	btn_x_pressed: bool,
	btn_y_pressed: bool,
	trigger_left: f32,
	trigger_right: f32,
	stick_left: [2]f32,
	stick_right: [2]f32,
}

GAMEPAD_POINTER: ^Gamepad
GAMEPAD_SIZE: i32 = 0

@export
gamepad_alloc :: proc() -> ^Gamepad {
	fmt.println("alloc_gamepad ...")
	gp := new(Gamepad, allocator=arena_allocator)
	gp.stick_left.x = 0.123
	gp.stick_left.y = 0.789
	GAMEPAD_POINTER = gp
	GAMEPAD_SIZE = size_of(Gamepad)
	fmt.println("allocated:", gp)
	return gp
}
@export
gamepad_connect_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, connected)
}
@export
gamepad_btn_a_pressed_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, btn_a_pressed)
}
@export
gamepad_btn_b_pressed_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, btn_b_pressed)
}
@export
gamepad_btn_x_pressed_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, btn_x_pressed)
}
@export
gamepad_btn_y_pressed_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, btn_y_pressed)
}


@export
gamepad_trigger_left_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, trigger_left)
}
@export
gamepad_trigger_right_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, trigger_right)
}

@export
gamepad_stick_left_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, stick_left)
}
@export
gamepad_stick_right_offset :: proc() -> i32 {
	return cast(i32)offset_of(Gamepad, stick_right)
}
