package synth_keyboard

import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

AtlasBuffers :: struct {
	pos:      Buffer,
	tex:      Buffer,
	indices:  EaBuffer,
	matrices: Buffer,
}

NKeys :: 3

atlas_buffers_init :: proc(buffers: ^AtlasBuffers) {
	x: f32 = 0
	y: f32 = 0
	w: f32 = 16
	h: f32 = 24
	pos_data: [4][2]f32 = {{x + 0, y + 0}, {x + w, y + 0}, {x + w, y + h}, {x + 0, y + h}}
	buffers.pos = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.pos, pos_data[:])

	tex_data: [NKeys * 4][2]f32
	buffers.tex = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.tex, tex_data[:])

	indices_data: [6]u16 = {0, 1, 2, 0, 2, 3}
	buffers.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&buffers.indices, indices_data[:])

	matrix_data: [NKeys]glm.mat4 = {
		glm.mat4(1),
		glm.mat4Translate({200, 0, 0}),
		glm.mat4Translate({400, 0, 0}),
	}
	buffers.matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.matrices, matrix_data[:])

	check_gl_error()
}

