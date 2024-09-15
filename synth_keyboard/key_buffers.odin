package synth_keyboard

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

Buffers :: struct {
	pos:      Buffer,
	tex:      Buffer,
	colors:   Buffer,
	indices:  EaBuffer,
	matrices: Buffer,
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
		gl.DrawElements(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, b.offset)
	}
}

TexId :: enum {
	Corner,
	LineH,
	LineV,
	Open,
}
Transform :: enum {
	None,
	FlipH,
	FlipV,
	FlipVH,
}
tex_uvs :: proc(id: TexId, t: Transform, out: [][2]f32) {
	tex_data: [4][2]f32
	p1, p2: [2]f32
	switch id {
	case .Corner:
		{
			p1 = {0, 0}
			p2 = {0.5, 0.5}
		}
	case .LineH:
		{
			p1 = {0.5, 0}
			p2 = {1, 0.5}
		}
	case .LineV:
		{
			p1 = {0, 0.5}
			p2 = {0.5, 1}

		}
	case .Open:
		{
			p1 = {0.5, 0.5}
			p2 = {1, 1}
		}
	}
	switch t {
	case .None:
		{}
	case .FlipH:
		{
			p1.x, p2.x = p2.x, p1.x
		}
	case .FlipV:
		{
			p1.y, p2.y = p2.y, p1.y
		}
	case .FlipVH:
		{
			p1.x, p2.x = p2.x, p1.x
			p1.y, p2.y = p2.y, p1.y
		}
	}
	out[0] = p1
	out[1] = {p2.x, p1.y}
	out[2] = p2
	out[3] = {p1.x, p2.y}
}

add_verts :: proc(x, y, w, h: f32, out: [][3]f32) {
	out[0] = {x + 0, y + 0, 0}
	out[1] = {x + w, y + 0, 0}
	out[2] = {x + w, y + h, 0}
	out[3] = {x + 0, y + h, 0}
}

NFace :: 9

key_buffers_init :: proc(buffers: ^Buffers, layout: Layout) -> (key_dimensions: [2]f32) {
	w: f32 = 16
	h: f32 = 16
	pos_data: [NFace * 4][3]f32
	tex_data: [NFace * 4][2]f32
	indices_data: [NFace * 6]u16
	lo, hi: int;hi = 4
	x, y: f32
	// top
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.Corner, .None, tex_data[lo:hi])
	lo = hi;hi += 4
	x += w
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.LineH, .None, tex_data[lo:hi])
	lo = hi;hi += 4
	x += w
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.Corner, .FlipH, tex_data[lo:hi])
	// middle
	lo = hi;hi += 4
	x = 0
	y += h
	h = h * 6
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.LineV, .None, tex_data[lo:hi])
	lo = hi;hi += 4
	x += w
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.Open, .None, tex_data[lo:hi])
	lo = hi;hi += 4
	x += w
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.LineV, .FlipH, tex_data[lo:hi])
	// bottom
	lo = hi;hi += 4
	x = 0
	y += h - 3 // not sure why it doesn't line up exactly...
	h = 16
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.Corner, .FlipV, tex_data[lo:hi])
	lo = hi;hi += 4
	x += w
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.LineH, .FlipV, tex_data[lo:hi])
	lo = hi;hi += 4
	x += w
	add_verts(x, y, w, h, pos_data[lo:hi])
	tex_uvs(.Corner, .FlipVH, tex_data[lo:hi])
	key_dimensions = {x + w, y + h}
	fmt.println("w:", key_dimensions.x)
	fmt.println("h:", key_dimensions.y)

	for n in 0 ..< NFace {
		i := n * 6
		vo := u16(n * 4)
		indices_data[i + 0] = 0 + vo
		indices_data[i + 1] = 1 + vo
		indices_data[i + 2] = 2 + vo
		indices_data[i + 3] = 0 + vo
		indices_data[i + 4] = 2 + vo
		indices_data[i + 5] = 3 + vo
	}

	buffers.pos = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.pos, pos_data[:])

	buffers.tex = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.tex, tex_data[:])

	buffers.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&buffers.indices, indices_data[:])

	matrix_data := make([]glm.mat4, layout.number_of_keys)
	defer delete(matrix_data)
	// for i in 0 ..< layout.number_of_keys {
	// 	matrix_data[i] = glm.mat4Translate({f32(i) * layout.spacing, 0, 0})
	// }
	//  {
	// 	glm.mat4(1),
	// 	glm.mat4Translate({52, 0, 0}),
	// 	glm.mat4Translate({104, 0, 0}),
	// }
	// fmt.println("matrix size:", size_of(glm.mat4))
	buffers.matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.matrices, matrix_data[:])

	color_data := make([]glm.vec4, layout.number_of_keys)
	defer delete(color_data)
	for i in 0 ..< layout.number_of_keys {
		color_data[i] = {0, 1, 1, 1}
	}
	buffers.colors = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.colors, color_data)

	check_gl_error()

	return key_dimensions
}

key_buffer_update_matrix_data :: proc(keys: []Key, b: Buffer) {
	matrix_data := make([]glm.mat4, len(keys))
	defer delete(matrix_data)
	for key, i in keys {
		matrix_data[i] = glm.mat4Translate({key.pos.x, key.pos.y, 0})
	}
	gl.BindBuffer(b.target, b.id)
	gl.BufferSubDataSlice(b.target, 0, matrix_data)
}

