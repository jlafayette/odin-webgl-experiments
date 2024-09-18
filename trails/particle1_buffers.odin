package trails
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

Particle1Buffers :: struct {
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

particle1_buffers_init :: proc(buffers: ^Particle1Buffers, n_particles: int) {
	pos_data: [4][2]f32
	pos_data[0] = {-0.5, -0.5}
	pos_data[1] = {-0.5, 0.5}
	pos_data[2] = {0.5, 0.5}
	pos_data[3] = {0.5, -0.5}
	tex_data: [4][2]f32
	tex_data[0] = {0, 0}
	tex_data[1] = {0, 1}
	tex_data[2] = {1, 1}
	tex_data[3] = {1, 0}
	indices_data: [6]u16 = {0, 1, 2, 0, 2, 3}

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

	matrix_data := make([]glm.mat4, n_particles)
	defer delete(matrix_data)
	buffers.matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.matrices, matrix_data[:])

	color_data := make([]glm.vec4, n_particles)
	defer delete(color_data)
	for i in 0 ..< n_particles {
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
}

// Do something like this for particle update

// key_buffer_update_matrix_data :: proc(keys: []Key, b: Buffer) {
// 	matrix_data := make([]glm.mat4, len(keys))
// 	defer delete(matrix_data)
// 	for key, i in keys {
// 		matrix_data[i] = glm.mat4Translate({key.pos.x, key.pos.y, 0})
// 	}
// 	gl.BindBuffer(b.target, b.id)
// 	gl.BufferSubDataSlice(b.target, 0, matrix_data)
// }

