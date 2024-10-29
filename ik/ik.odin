package ik

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"

Ik :: struct {
	anchor: glm.vec2,
	segs:   []Segment,
}

ik_init :: proc(ik: ^Ik, w: i32, h: i32) {
	ik.segs = make([]Segment, 4)

	pos: glm.vec2 = {f32(w) / 2, f32(h) / 2}
	ik.anchor = pos
	angle: f32 = 0
	length: f32 = 100
	mult: f32 = 1.0
	// angle_s: f32 = 0.05
	// angle_change: f32 = 0.005
	c: f32 = 1
	z: f32 = 1
	for &seg in ik.segs {
		seg.color = c
		seg.a = pos
		seg.length = length
		seg.angle = 0
		seg.z = z
		segment_calculate_b(&seg)
		pos = seg.b
		// angle += math.PI / 10 - angle_s
		// angle_s += angle_change
		length = length * mult
		// if length > 100 {
		// 	mult = 0.8
		// }
		c -= 1 / f32(len(ik.segs) + 10)
		z -= 0.01
		a_pos := seg.a - seg.b
		seg.angle = math.atan2_f32(a_pos.y, a_pos.x)
	}
	ik.segs[0].color = {0.8, 0.2, 0.2}
	ik.segs[1].color = {0.2, 0.7, 0.3}
	ik.segs[2].color = {0.2, 0.2, 1.0}
}

ik_update :: proc(ik: ^Ik, input: Input, w: i32, h: i32, dpr: f32, dt: f32) {
	ik.anchor = {f32(w) / 2, f32(h) / 2}

	// follow mouse
	if input.mouse_down {
		target: glm.vec2 = {f32(input.mouse_pos.x) * dpr, f32(input.mouse_pos.y) * dpr}
		#reverse for &seg in ik.segs {
			segment_follow(&seg, target)
			target = seg.a
		}
	}

	// move everything back to anchor
	diff: glm.vec2 = ik.anchor - ik.segs[0].a
	for &seg in ik.segs {
		seg.a += diff
		seg.b += diff
		a_pos := seg.a - seg.b
		seg.angle = math.atan2_f32(a_pos.y, a_pos.x)
	}
}

Segment :: struct {
	a:      glm.vec2,
	b:      glm.vec2,
	length: f32,
	angle:  f32,
	color:  glm.vec3,
	z:      f32,
}

segment_follow :: proc(seg: ^Segment, target: glm.vec2) {
	dir: glm.vec2 = target - seg.a
	dir = glm.normalize(dir) * seg.length
	dir *= -1
	seg.a = target + dir
	seg.b = target
}

segment_calculate_b :: proc(seg: ^Segment) {
	x: f32 = seg.length * math.cos(seg.angle) + seg.a.x
	y: f32 = seg.length * math.sin(seg.angle) + seg.a.y
	seg.b = {x, y}
}

segment_to_shapes :: proc(seg: Segment, r1, r2: ^Rectangle, line: ^Line) {
	r1.pos = {i32(seg.a.x), i32(seg.a.y)}
	r1.size = {20, 20}
	r1.rotation = seg.angle
	r1.color.a = 1
	r1.color.rgb = seg.color * 0.8
	r1.z = 0.005 + seg.z
	r2.pos = {i32(seg.b.x), i32(seg.b.y)}
	r2.size = {10, 10}
	r2.rotation = seg.angle
	r2.color.a = 1
	r2.color.rgb = seg.color
	r2.z = 0.005 + seg.z
	line.start = {i32(seg.a.x), i32(seg.a.y)}
	line.end = {i32(seg.b.x), i32(seg.b.y)}
	line.thickness = 4
	line.color.a = 1.0
	line.color.rgb = seg.color * 0.8
	line.z = 0 + seg.z
}

