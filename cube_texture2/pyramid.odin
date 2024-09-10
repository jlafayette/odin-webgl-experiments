package cube_texture2

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

pyramid_buffers_init :: proc(buffers: ^Buffers) {
	pos_data: [16][3]f32 = {
		{-1, -1, 1},
		{1, -1, 1},
		{0, 1, 0}, // front
		{1, -1, -1},
		{-1, -1, -1},
		{0, 1, 0}, // back
		{1, -1, 1},
		{1, -1, -1},
		{0, 1, 0}, // right
		{-1, -1, -1},
		{-1, -1, 1},
		{0, 1, 0}, // left
		{-1, -1, -1},
		{1, -1, -1},
		{1, -1, 1},
		{-1, -1, 1}, // bottom
	}
	buffers.pos = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.pos, pos_data[:])

	tex_data: [16][2]f32 = {
		{0, 0},
		{1, 0},
		{0.5, 1}, // front
		{0, 0},
		{1, 0},
		{0.5, 1}, // back
		{0, 0},
		{1, 0},
		{0.5, 1}, // right
		{0, 0},
		{1, 0},
		{0.5, 1}, // left
		{0, 0},
		{1, 0},
		{1, 1},
		{0, 1}, // bottom
	}
	buffers.tex = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.tex, tex_data[:])

	normal_data: [16][3]f32 = {
		{0, 0, 1},
		{0, 0, 1},
		{0, 0, 1}, // front
		{0, 0, -1},
		{0, 0, -1},
		{0, 0, -1}, // back
		{1, 0, 0},
		{1, 0, 0},
		{1, 0, 0}, // right
		{-1, 0, 0},
		{-1, 0, 0},
		{-1, 0, 0}, // left
		{0, -1, 0},
		{0, -1, 0},
		{0, -1, 0},
		{0, -1, 0}, // bottom
	}
	buffers.normal = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.normal, normal_data[:])

	indices_data: [18]u16 = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 12, 14, 15}
	buffers.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&buffers.indices, indices_data[:])
}

