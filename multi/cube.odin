package multi

import "core:fmt"
import gl "vendor:wasm/WebGL"

Buffers :: struct {
	pos:     Buffer,
	tex:     Buffer,
	normal:  Buffer,
	indices: EaBuffer,
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
buffer_update :: proc(b: Buffer, data: []$T) {
	gl.BindBuffer(b.target, b.id)
	// gl.BufferDataSlice(b.target, data[:], b.usage)
	gl.BufferSubDataSlice(b.target, 0, data[:])
}
ea_buffer_init :: proc(b: ^EaBuffer, data: []$T) {
	b.count = (len(data) * size_of(T)) / 2 // 2 is size of unsigned_short (u16)
	b.offset = nil
	b.id = gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], b.usage)
}
ea_buffer_draw :: proc(b: EaBuffer, instance_count: int = 0) {
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	if instance_count > 0 {
		// fmt.println("b.count:", b.count, "instance count:", instance_count)
		gl.DrawElementsInstanced(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, 0, instance_count)
	} else {
		gl.DrawElements(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, b.offset)
	}
}

cube_buffers_init :: proc(buffers: ^Buffers) {
	pos_data: [6][4][3]f32 = {
		{{-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1}}, // front
		{{1, -1, -1}, {-1, -1, -1}, {-1, 1, -1}, {1, 1, -1}}, // back
		{{-1, 1, 1}, {1, 1, 1}, {1, 1, -1}, {-1, 1, -1}}, // top
		{{-1, -1, -1}, {1, -1, -1}, {1, -1, 1}, {-1, -1, 1}}, // bottom
		{{1, -1, 1}, {1, -1, -1}, {1, 1, -1}, {1, 1, 1}}, // right
		{{-1, -1, -1}, {-1, -1, 1}, {-1, 1, 1}, {-1, 1, -1}}, // left
	}
	buffers.pos = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.pos, pos_data[:])

	tex_data: [6][4][2]f32 = {
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // front
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // back
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // top
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // bottom
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // right
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // left
	}
	buffers.tex = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.tex, tex_data[:])

	normal_data: [6][4][3]f32 = {
		{{0, 0, 1}, {0, 0, 1}, {0, 0, 1}, {0, 0, 1}}, // front
		{{0, 0, -1}, {0, 0, -1}, {0, 0, -1}, {0, 0, -1}}, // back
		{{0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}, // top
		{{0, -1, 0}, {0, -1, 0}, {0, -1, 0}, {0, -1, 0}}, // bottom
		{{1, 0, 0}, {1, 0, 0}, {1, 0, 0}, {1, 0, 0}}, // right
		{{-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0}}, // left
	}
	buffers.normal = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.normal, normal_data[:])

	indices_data: [6][6]u16 = {
		{0, 1, 2, 0, 2, 3}, // front
		{4, 5, 6, 4, 6, 7}, // back
		{8, 9, 10, 8, 10, 11}, // top
		{12, 13, 14, 12, 14, 15}, // bottom
		{16, 17, 18, 16, 18, 19}, // right
		{20, 21, 22, 20, 22, 23}, // left
	}
	buffers.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&buffers.indices, indices_data[:])
}

