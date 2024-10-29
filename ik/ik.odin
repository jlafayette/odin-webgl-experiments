package ik

import glm "core:math/linalg/glsl"

Ik :: struct {
	s1: Segment,
}

ik_init :: proc(ik: ^Ik, w: i32, h: i32) {
	ik.s1.a = {f32(w) / 2, f32(h) / 2}
	ik.s1.length = 200
}

ik_update :: proc(ik: ^Ik, input: Input, w: i32, h: i32, dt: f32) {
	ik.s1.a = {f32(w) / 2, f32(h) / 2}
	segment_calculate_b(&ik.s1)
}

Segment :: struct {
	a:      glm.vec2,
	b:      glm.vec2,
	length: f32,
	angle:  f32,
}

segment_calculate_b :: proc(seg: ^Segment) {
	// TODO: real calculation
	seg.b = seg.a + glm.vec2({seg.length, 0})
}

segment_to_shapes :: proc(seg: Segment, r1, r2: ^Rectangle, line: ^Line) {
	r1.pos = {i32(seg.a.x), i32(seg.a.y)}
	r1.size = {10, 10}
	r1.rotation = 0
	r1.color = {1, 1, 1, 1}
	r1.z = 1
	r2.pos = {i32(seg.b.x), i32(seg.b.y)}
	r2.size = {10, 10}
	r2.rotation = 0
	r2.color = {1, 1, 1, 1}
	r2.z = 1
	line.start = {i32(seg.a.x), i32(seg.a.y)}
	line.end = {i32(seg.b.x), i32(seg.b.y)}
	line.thickness = 4
	line.color = {0.5, 0.5, 0.5, 1.0}
	line.z = 0
}

