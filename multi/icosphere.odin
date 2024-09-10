package multi

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

m_hash :: proc(i1: int, i2: int) -> int {
	if i1 < i2 {
		return (i1 * 100) + i2
	} else if i2 < i1 {
		return (i2 * 100) + i1
	} else {
		fmt.eprintln("cannot hash same index")
		return -1
	}
}
PosI :: struct {
	pos: glm.vec3,
	i:   u16,
}
get_middle_point :: proc(
	next_pos2_i: int,
	m: ^map[int]PosI,
	a: PosI,
	b: PosI,
) -> (
	middle: PosI,
	new: bool,
) {
	h := m_hash(int(a.i), int(b.i))
	ok: bool
	middle, ok = m[h]
	// fmt.printf("hash %d for %d->%d in map: %v\n", h, a.i, b.i, ok)
	if ok {
		return middle, false
	}
	middle.pos = (a.pos + b.pos) / 2
	middle.i = u16(next_pos2_i)
	m[h] = middle
	return middle, true
}

icosphere_create :: proc() -> ([NVertex1]glm.vec3, [NFace1][3]u16) {
	context.allocator = temp_arena_allocator

	// create 12 vertices of a icosahedron
	t: f32 = (1 + math.sqrt(f32(5))) / 2
	pos1: [12]glm.vec3 = {
		{-1, t, 0},
		{1, t, 0},
		{-1, -t, 0},
		{1, -t, 0},
		{0, -1, t},
		{0, 1, t},
		{0, -1, -t},
		{0, 1, -t},
		{t, 0, -1},
		{t, 0, 1},
		{-t, 0, -1},
		{-t, 0, 1},
	}
	for &pos in pos1 {
		pos = glm.normalize(pos)
	}
	// 20 faces
	indices1: [20][3]u16 = {
		{0, 11, 5},
		{0, 5, 1},
		{0, 1, 7},
		{0, 7, 10},
		{0, 10, 11},
		{1, 5, 9},
		{5, 11, 4},
		{11, 10, 2},
		{10, 7, 6},
		{7, 1, 8},
		{3, 9, 4},
		{3, 4, 2},
		{3, 2, 6},
		{3, 6, 8},
		{3, 8, 9},
		{4, 9, 5},
		{2, 4, 11},
		{6, 2, 10},
		{8, 6, 7},
		{9, 8, 1},
	}
	pos2: [NVertex1]glm.vec3
	for p1, i in pos1 {
		pos2[i] = p1
	}
	next_pos2_i := 12
	indices2: [NFace1][3]u16
	next_indices_i := 0

	m := make(map[int]PosI)

	// loop over faces in indices1
	for tri, i in indices1 {
		p1: PosI = {pos1[tri.x], tri.x}
		p2: PosI = {pos1[tri.y], tri.y}
		p3: PosI = {pos1[tri.z], tri.z}

		// for each edge, find midpoints
		// for new ones, add to pos2 and store index in map for lookup
		a, b, c: PosI
		new: bool
		a, new = get_middle_point(next_pos2_i, &m, p1, p2)
		if new {
			pos2[next_pos2_i] = a.pos
			next_pos2_i += 1
		}
		b, new = get_middle_point(next_pos2_i, &m, p2, p3)
		if new {
			pos2[next_pos2_i] = b.pos
			next_pos2_i += 1
		}
		c, new = get_middle_point(next_pos2_i, &m, p3, p1)
		if new {
			pos2[next_pos2_i] = c.pos
			next_pos2_i += 1
		}

		// add 4 new faces to indices2
		indices2[next_indices_i + 0] = {p1.i, a.i, c.i}
		indices2[next_indices_i + 1] = {p2.i, b.i, a.i}
		indices2[next_indices_i + 2] = {p3.i, c.i, b.i}
		indices2[next_indices_i + 3] = {a.i, b.i, c.i}
		next_indices_i += 4

	}
	return pos2, indices2

}

NVertex0 :: 12
NFace0 :: 20

NVertex1 :: 42
NFace1 :: 80

NVertex2 :: 162
NFace2 :: 320

icosphere_refine :: proc(
	pos1: [NVertex1]glm.vec3,
	indices1: [NFace1][3]u16,
) -> (
	[NVertex2]glm.vec3,
	[NFace2][3]u16,
) {
	context.allocator = temp_arena_allocator
	for &pos in pos1 {
		pos = glm.normalize(pos)
	}
	pos2: [NVertex2]glm.vec3
	for p1, i in pos1 {
		pos2[i] = p1
	}
	next_pos2_i := NVertex1
	indices2: [NFace2][3]u16
	next_indices_i := 0

	m := make(map[int]PosI)

	// loop over faces in indices1
	for tri, i in indices1 {
		p1: PosI = {pos1[tri.x], tri.x}
		p2: PosI = {pos1[tri.y], tri.y}
		p3: PosI = {pos1[tri.z], tri.z}

		// for each edge, find midpoints
		// for new ones, add to pos2 and store index in map for lookup
		a, b, c: PosI
		new: bool
		a, new = get_middle_point(next_pos2_i, &m, p1, p2)
		if new {
			pos2[next_pos2_i] = a.pos
			next_pos2_i += 1
		}
		b, new = get_middle_point(next_pos2_i, &m, p2, p3)
		if new {
			pos2[next_pos2_i] = b.pos
			next_pos2_i += 1
		}
		c, new = get_middle_point(next_pos2_i, &m, p3, p1)
		if new {
			pos2[next_pos2_i] = c.pos
			next_pos2_i += 1
		}

		// add 4 new faces to indices2
		indices2[next_indices_i + 0] = {p1.i, a.i, c.i}
		indices2[next_indices_i + 1] = {p2.i, b.i, a.i}
		indices2[next_indices_i + 2] = {p3.i, c.i, b.i}
		indices2[next_indices_i + 3] = {a.i, b.i, c.i}
		next_indices_i += 4

	}
	return pos2, indices2
}


icosphere_buffers_init :: proc(buffers: ^Buffers) {
	pos_data1, indices_data1 := icosphere_create()
	pos_data, indices_data := icosphere_refine(pos_data1, indices_data1)
	for &pos in pos_data {
		pos = glm.normalize(pos)
	}
	buffers.pos = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.pos, pos_data[:])

	tex_data: [NVertex2][3]f32
	buffers.tex = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.tex, tex_data[:])

	normal_data: [NVertex2]glm.vec3
	for pos, i in pos_data {
		normal_data[i] = glm.normalize_vec3(pos)
	}
	buffers.normal = {
		size   = 3,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.normal, normal_data[:])

	buffers.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&buffers.indices, indices_data[:])
}

