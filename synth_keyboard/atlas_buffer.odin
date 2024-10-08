package synth_keyboard

import "../shared/text"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

AtlasBuffers :: struct {
	pos:      Buffer,
	tex:      Buffer,
	indices:  EaBuffer,
	matrices: Buffer,
}

atlas_buffers_init :: proc(buffers: ^AtlasBuffers, header: text.Header, keys: []Key) {
	data_len := len(keys)
	pos_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	tex_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	indices_data := make([][6]u16, data_len, allocator = context.temp_allocator)

	for key, key_i in keys {
		ch := key.char
		x := key.pos.x
		x += (key.w / 2) - (ch.w / 2)
		y := key.pos.y + key.label_offset_height
		i := key_i * 4
		pos_data[i + 0] = {x, y}
		pos_data[i + 1] = {x, y + ch.h}
		pos_data[i + 2] = {x + ch.w, y + ch.h}
		pos_data[i + 3] = {x + ch.w, y}

		w_mult := 1.0 / f32(header.atlas_w)
		h_mult := 1.0 / f32(header.atlas_h)
		tx := ch.x * w_mult
		ty := ch.y * h_mult
		tx2 := tx + ch.w * w_mult
		ty2 := ty + ch.h * h_mult

		// mirror y
		tex_data[i + 1] = {tx, ty}
		tex_data[i + 0] = {tx, ty2}
		tex_data[i + 3] = {tx2, ty2}
		tex_data[i + 2] = {tx2, ty}

		o: u16 = u16(i)
		indices_data[key_i] = {0 + o, 1 + o, 2 + o, 0 + o, 2 + o, 3 + o}
	}
	buffers.pos = {
		size   = 2,
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

	check_gl_error()
}

