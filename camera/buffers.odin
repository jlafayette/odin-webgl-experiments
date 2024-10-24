package camera

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:math/rand"
import gl "vendor:wasm/WebGL"

Buffers :: struct {
	position:        Buffer,
	normal:          Buffer,
	indices:         EaBuffer,
	model_matrices:  Buffer,
	normal_matrices: Buffer,
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

init_buffers :: proc(b: ^Buffers, n_cubes: int) {
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

	cube_positions: [10]glm.vec3 = {
		{0, 0, 0}, // 0
		{2, 5, -15},
		{-1.5, -2.2, -2.5},
		{-3.8, -2, -12.3}, // 3
		{2.4, -0.4, -3.5},
		{-1.7, 3, -7.5},
		{1.3, -2, -2.5}, // 6
		{1.5, 2, -2.5},
		{1.5, 0.2, -1.5},
		{-1.3, 1, -1.5}, // 9
	}

	bbox_max: glm.vec3
	bbox_min: glm.vec3
	model_matrices := make([]glm.mat4, n_cubes)
	defer delete(model_matrices)
	normal_matrices := make([]glm.mat4, n_cubes)
	defer delete(normal_matrices)
	for &pos, i in cube_positions {
		pos *= 2
		bbox_min.x = math.min(bbox_min.x, pos.x)
		bbox_min.y = math.min(bbox_min.y, pos.y)
		bbox_min.z = math.min(bbox_min.z, pos.z)
		bbox_max.x = math.max(bbox_max.x, pos.x)
		bbox_max.y = math.max(bbox_max.y, pos.y)
		bbox_max.z = math.max(bbox_max.z, pos.z)
		// rotating around zero length vectors results in a matrix
		// with Nan values and the cube disapears
		if glm.length(pos) == 0.0 {
			pos += {0.0003, 0.0007, 0.0002}
		}
		model := glm.mat4(1)

		// scale
		model *= glm.mat4Scale({0.5, 0.5, 0.5})
		// rotate
		angle: f32 = glm.radians_f32(20.0 * f32(i))
		// if i % 2 == 0 && i != 0 {
		// 	angle = state.rotation
		// }
		model *= glm.mat4Rotate(pos, angle)
		// translate
		model *= glm.mat4Translate(pos)

		model_matrices[i] = model
		normal_matrices[i] = glm.inverse_transpose_matrix4x4(model)
	}
	bbox_max += {1, 1, 1}
	bbox_min -= {-1, -1, -1}
	for i in len(cube_positions) ..< n_cubes {
		collides: bool = true
		pos: [3]f32 = {1, 2, 3}
		for {
			pos = random_pos()
			d: f32 = math.pow(rand.float32(), 0.3) * SPHERE_RADIUS
			pos = pos * d
			if ((pos.x > bbox_max.x || pos.x < bbox_min.x) ||
				   (pos.y > bbox_max.y || pos.y < bbox_min.y) ||
				   (pos.z > bbox_max.z || pos.z < bbox_min.z)) {
				break
			}
		}
		model := glm.mat4(1)
		// model *= glm.mat4Scale({0.5, 0.5, 0.5})
		model += random_scale()
		model *= random_rotation()
		// angle: f32 = glm.radians_f32(20.0 * f32(i + len(cube_positions)))
		// model *= glm.mat4Rotate(pos, angle)
		model *= glm.mat4Translate(pos)
		model_matrices[i] = model
		normal_matrices[i] = glm.inverse_transpose_matrix4x4(model)
	}
	b.model_matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&b.model_matrices, model_matrices[:])
	b.normal_matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&b.normal_matrices, normal_matrices[:])
}

random_pos :: proc() -> glm.vec3 {
	pos: glm.vec3 = {rand.float32() * 2 - 1, rand.float32() * 2 - 1, rand.float32() * 2 - 1}
	return glm.normalize(pos)
}
random_rotation :: proc() -> glm.mat4 {
	p := random_pos()
	angle := rand.float32() * math.TAU
	return glm.mat4Rotate(p, angle)
}
random_scale :: proc() -> glm.mat4 {
	min_scale: f32 = 0.1
	max_scale: f32 = 0.9
	r_scale: f32 = rand.float32() * (max_scale - min_scale) + min_scale
	return glm.mat4Scale({r_scale, r_scale, r_scale})
}

