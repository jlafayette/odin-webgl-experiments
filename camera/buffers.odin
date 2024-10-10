package camera

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

Buffers :: struct {
	position: Buffer,
	color:    Buffer,
	normal:   Buffer,
	indices:  EaBuffer,
}
Buffer :: struct {
	id:     gl.Buffer,
	size:   int, // 3
	type:   gl.Enum, // gl.FLOAT
	target: gl.Enum, // gl.ARRAY_BUFFER
	usage:  gl.Enum, // gl.STATIC_DRAW
}
EaBuffer :: struct {
	id:     gl.Buffer,
	// size:   int, // 1 (assumed)
	count:  int, // (len(data) * size_of(data[0])) / 2
	// type:   gl.Enum, // gl.UNSIGNED_SHORT (assumed)
	// target: gl.Enum, // gl.ELEMENT_ARRAY_BUFFER (assumed)
	usage:  gl.Enum, // gl.STATIC_DRAW
	offset: rawptr,
}
buffer_init :: proc(b: ^Buffer, data: []$T) {
	b.id = gl.CreateBuffer()
	gl.BindBuffer(b.target, b.id)
	gl.BufferDataSlice(b.target, data[:], b.usage)
}
ea_buffer_init :: proc(b: ^EaBuffer, data: []$T) {
	b.count = (len(data) * size_of(T)) / 2 // 2 is size of unsigned_short (u16)
	fmt.println("b.count:", b.count)
	b.offset = nil
	b.id = gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], b.usage)
}
ea_buffer_draw :: proc(b: EaBuffer, instance_count: int = 0) {
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	if instance_count > 0 {
		gl.DrawElementsInstanced(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, 0, instance_count)
	} else {
		// fmt.printf("drawing elements: %d\n", b.count)
		gl.DrawElements(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, b.offset)
	}
}

init_buffers :: proc(b: ^Buffers) {
	position_data: [6 * 4][3]f32 = {
		{-1, -1, 1},
		{1, -1, 1},
		{1, 1, 1},
		{-1, 1, 1}, // front
		{-1, -1, -1},
		{-1, 1, -1},
		{1, 1, -1},
		{1, -1, -1}, // back
		{-1, 1, -1},
		{-1, 1, 1},
		{1, 1, 1},
		{1, 1, -1}, // top
		{-1, -1, -1},
		{1, -1, -1},
		{1, -1, 1},
		{-1, -1, 1}, // bottom
		{1, -1, -1},
		{1, 1, -1},
		{1, 1, 1},
		{1, -1, 1}, // right
		{-1, -1, -1},
		{-1, -1, 1},
		{-1, 1, 1},
		{-1, 1, -1}, // left
	}
	b.position = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&b.position, position_data[:])

	c: [4]f32 = {0.5, 0.5, 0.5, 1}
	color_data: [6 * 4][4]f32 = c
	b.color = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&b.color, color_data[:])

	normal_data: [6 * 4][3]f32 = {
		{0, 0, 1},
		{0, 0, 1},
		{0, 0, 1},
		{0, 0, 1}, // front
		{0, 0, -1},
		{0, 0, -1},
		{0, 0, -1},
		{0, 0, -1}, // back
		{0, 1, 0},
		{0, 1, 0},
		{0, 1, 0},
		{0, 1, 0}, // top
		{0, -1, 0},
		{0, -1, 0},
		{0, -1, 0},
		{0, -1, 0}, // bottom
		{1, 0, 0},
		{1, 0, 0},
		{1, 0, 0},
		{1, 0, 0}, // right
		{-1, 0, 0},
		{-1, 0, 0},
		{-1, 0, 0},
		{-1, 0, 0}, // left
	}
	b.normal = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&b.normal, normal_data[:])

	indices_data: [6][6]u16 = {
		{0, 1, 2, 0, 2, 3}, // front
		{4, 5, 6, 4, 6, 7}, // back
		{8, 9, 10, 8, 10, 11}, // top
		{12, 13, 14, 12, 14, 15}, // bottom
		{16, 17, 18, 16, 18, 19}, // right
		{20, 21, 22, 20, 22, 23}, // left
	}
	b.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&b.indices, indices_data[:])
}

