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

