package sound

import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"


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
	gl.BufferSubDataSlice(b.target, 0, data[:])
}
ea_buffer_init :: proc(b: ^EaBuffer, data: []$T) {
	b.count = (len(data) * size_of(T)) / 2 // 2 is size of unsigned_short (u16)
	// fmt.println("b.count:", b.count)
	b.offset = nil
	b.id = gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], b.usage)
}
ea_buffer_draw :: proc(b: EaBuffer, instance_count: int = 0) {
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	if instance_count > 0 {
		// fmt.printf("drawing b.count %d, instance_count: %d\n", b.count, instance_count)
		gl.DrawElementsInstanced(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, 0, instance_count)
	} else {
		gl.DrawElements(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, b.offset)
	}
}
Buffers :: struct {
	pos:            Buffer,
	indices:        EaBuffer,
	colors:         Buffer,
	circle_blends:  Buffer,
	model_matrices: Buffer,
}
buffers_init :: proc(buffers: ^Buffers) {
	// pos_data: [4][2]f32 = {{0, 0}, {0, 1}, {1, 1}, {1, 0}}
	pos_data: [4][2]f32 = {{-0.5, -0.5}, {-0.5, 0.5}, {0.5, 0.5}, {0.5, -0.5}}
	buffers.pos = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.pos, pos_data[:])

	indices_data: [6]u16 = {0, 1, 2, 0, 2, 3}
	buffers.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&buffers.indices, indices_data[:])

	colors: [N_INSTANCE]glm.vec4 = glm.vec4({1, 1, 1, 1})
	buffers.colors = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.colors, colors[:])

	circle_blends: [N_INSTANCE]f32
	buffers.circle_blends = {
		size   = 1,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.circle_blends, circle_blends[:])

	model_matrices: [N_INSTANCE]glm.mat4 = glm.mat4(1)
	buffers.model_matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.model_matrices, model_matrices[:])
}

flat_vert_source := #load("flat.vert", string)
flat_frag_source := #load("flat.frag", string)
FlatShader :: struct {
	program:                  gl.Program,
	a_pos:                    i32,
	a_color:                  i32,
	a_model_matrix:           i32,
	a_circle_blend:           i32,
	u_view_projection_matrix: i32,
}
FlatUniforms :: struct {
	view_projection_matrix: glm.mat4,
}
flat_shader_init :: proc(s: ^FlatShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({flat_vert_source}, {flat_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program
	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_color = gl.GetAttribLocation(program, "aColor")
	s.a_model_matrix = gl.GetAttribLocation(program, "aModelMatrix")
	s.a_circle_blend = gl.GetAttribLocation(program, "aCircleBlend")
	s.u_view_projection_matrix = gl.GetUniformLocation(program, "uViewProjectionMatrix")
	return check_gl_error()
}
flat_shader_use :: proc(s: FlatShader, u: FlatUniforms, buffers: Buffers) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffers.pos)
	shader_set_instance_vec4_attribute(s.a_color, buffers.colors)
	shader_set_instance_matrix_attribute(s.a_model_matrix, buffers.model_matrices)
	shader_set_instance_f_attribute(s.a_circle_blend, buffers.circle_blends)

	// set uniforms
	gl.UniformMatrix4fv(s.u_view_projection_matrix, u.view_projection_matrix)
}
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
	gl.VertexAttribDivisor(u32(index), 0)
}
shader_set_instance_f_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.EnableVertexAttribArray(index)
	stride := size_of(f32)
	gl.VertexAttribPointer(index, b.size, b.type, false, stride, 0)
	gl.VertexAttribDivisor(u32(index), 1)
}
shader_set_instance_vec4_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.EnableVertexAttribArray(index)
	size := size_of(glm.vec4)
	gl.VertexAttribPointer(index, b.size, b.type, false, size, 0)
	gl.VertexAttribDivisor(u32(index), 1)
}
shader_set_instance_matrix_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	matrix_size := size_of(glm.mat4)
	for i in 0 ..< 4 {
		loc: i32 = i32(index) + i32(i)
		gl.EnableVertexAttribArray(loc)
		offset: uintptr = uintptr(i) * 16
		gl.VertexAttribPointer(loc, b.size, b.type, false, matrix_size, offset)
		gl.VertexAttribDivisor(u32(loc), 1)
	}
}

Rectangle :: struct {
	pos:      [2]i32,
	size:     [2]i32,
	rotation: f32,
	color:    [4]f32,
}
Circle :: struct {
	pos:    [2]i32,
	radius: i32,
	color:  [4]f32,
}
Line :: struct {
	start:     [2]i32,
	end:       [2]i32,
	thickness: i32,
	color:     [4]f32,
}

N_SHAPES :: 64
N_INSTANCE :: N_SHAPES * 3 + 3


Shapes :: struct {
	rectangle_count: int,
	circle_count:    int,
	line_count:      int,
	rectangles:      [N_SHAPES]Rectangle,
	circles:         [N_SHAPES]Circle,
	lines:           [N_SHAPES]Line,
	buffers:         Buffers,
	shader:          FlatShader,
}

shapes_init :: proc(s: ^Shapes, w, h: i32) -> (ok: bool) {
	ok = flat_shader_init(&s.shader)
	if !ok {return false}

	buffers_init(&s.buffers)

	add_rectangle(s, {{10, 10}, {20, 20}, 0, {1, 1, 1, 0.2}})
	add_rectangle(s, {{10, 10}, {20, 20}, 0, {1, 1, 1, 0.2}})
	add_rectangle(s, {{10, 10}, {20, 20}, 0, {1, 1, 1, 0.2}})
	add_rectangle(s, {{10, 10}, {20, 20}, 0, {1, 1, 1, 0.2}})
	add_rectangle(s, {{10, 10}, {20, 20}, 0, {1, 1, 1, 0.2}})
	for i in 0 ..< 5 {
		part: f32 = math.TAU / 5
		add_rectangle(s, {{200 + i32(i) * 50, 200}, {300, 50}, f32(i) * part, {1, 1, 1, 0.2}})
	}

	c: glm.vec4 = {1, 1, 1, 1}
	add_circle(s, {{20, 20}, 5, c})
	add_circle(s, {{20, 20}, 5, c})
	add_circle(s, {{20, 20}, 5, c})
	add_circle(s, {{20, 20}, 5, c})
	add_circle(s, {{20, 20}, 5, c})
	add_circle(s, {{20, 20}, 5, c})

	add_line(s, {{0, 0}, {100, 100}, 2, c})
	add_line(s, {{0, 0}, {100, 100}, 2, c})
	add_line(s, {{0, 0}, {100, 100}, 2, c})
	add_line(s, {{0, 0}, {100, 100}, 2, c})
	add_line(s, {{100, 100}, {500, 100}, 2, c})
	c.a = 0.4
	add_line(s, {{100, 100}, {500, 100}, 8, c})
	c.a = 0.2
	add_line(s, {{100, 100}, {500, 100}, 16, c})
	add_line(s, {{100, 100}, {500, 500}, 16, c})
	c.a = 0.8
	add_line(s, {{0, 0}, {500, 500}, 4, c})

	return ok
}

add_rectangle :: proc(s: ^Shapes, r: Rectangle) {
	if s.rectangle_count >= N_SHAPES {
		return
	}
	s.rectangles[s.rectangle_count] = r
	s.rectangle_count += 1
}
add_circle :: proc(s: ^Shapes, c: Circle) {
	if s.circle_count >= N_SHAPES {
		return
	}
	s.circles[s.circle_count] = c
	s.circle_count += 1
}
add_line :: proc(s: ^Shapes, l: Line) {
	if s.line_count >= N_SHAPES {
		return
	}
	s.lines[s.line_count] = l
	s.line_count += 1
}

_line_offset: f32 = 0
shapes_update :: proc(s: ^Shapes, w, h: i32, dt: f32, time_elapsed: f64) {
	s.rectangles[0].pos = {10, 10}
	s.rectangles[1].pos = {10, h - 10}
	s.rectangles[2].pos = {w - 10, 10}
	s.rectangles[3].pos = {w - 10, h - 10}

	s.rectangles[4].pos = {w - 100, h / 2}
	s.rectangles[4].size = {100, 100}
	s.rectangles[4].rotation = 0

	for &rect, i in s.rectangles {
		if i < 4 {
			rect.rotation = 0
		} else if i < s.rectangle_count {
			rect.rotation += dt
		}
	}

	s.circles[0].pos = {20, 20}
	s.circles[1].pos = {20, h - 20}
	s.circles[2].pos = {w - 20, 20}
	s.circles[3].pos = {w - 20, h - 20}

	s.circles[4].pos = {w - 100, h / 2}
	s.circles[4].radius = 50
	s.circles[5].pos = {w - 220, h / 2}
	s.circles[5].radius = 50

	_line_offset += dt

	c: glm.vec4 = {1, 1, 1, 1}
	s.lines[0] = {{0, 0}, {w, h}, 2, c}
	s.lines[1] = {{0, h}, {w, 0}, 2, c}
	c.r = 0.5
	c.g = 0.7
	c.a = 0.5
	s.lines[2] = {{0, 0}, {w, h}, 4, c}
	s.lines[3] = {{0, h}, {w, 0}, 4, c}
}

line_angle :: proc(line: Line) -> f32 {
	line_diff_i32: [2]i32 = line.end - line.start
	line_diff: [2]f32 = {f32(line_diff_i32.x), f32(line_diff_i32.y)}
	angle := math.atan2(line_diff.y, line_diff.x)
	return angle
}
line_to_matrix :: proc(line: Line, rotation: f32 = 0) -> glm.mat4 {
	line_diff_i32: [2]i32 = line.end - line.start
	line_diff: [2]f32 = {f32(line_diff_i32.x), f32(line_diff_i32.y)}
	angle := math.atan2(line_diff.y, line_diff.x)
	x_scale := glm.length(line_diff)
	y_scale := f32(line.thickness)
	m := glm.mat4Translate({f32(line.start.x), f32(line.start.y), -1.0})
	m *= glm.mat4Rotate({0, 0, 1}, angle + rotation)
	m *= glm.mat4Scale({x_scale, y_scale, 1.0})
	m *= glm.mat4Translate({0.5, 0, 0})
	return m
}
rect_to_matrix :: proc(rect: Rectangle) -> glm.mat4 {
	m := glm.mat4Translate({f32(rect.pos.x), f32(rect.pos.y), -1.0})
	m *= glm.mat4Rotate({0, 0, 1}, rect.rotation)
	m *= glm.mat4Scale({f32(rect.size.x), f32(rect.size.y), 1.0})
	return m
}

i_ :: proc(pos: [2]f32) -> [2]i32 {
	return {i32(math.round(pos.x)), i32(math.round(pos.y))}
}
f_ :: proc(pos: [2]i32) -> [2]f32 {
	return {f32(pos.x), f32(pos.y)}
}
shapes_draw :: proc(s: ^Shapes, buttons: []Button, projection_matrix: glm.mat4) {
	rect_matrices := make([]glm.mat4, N_INSTANCE, allocator = context.temp_allocator)
	colors := make([]glm.vec4, N_INSTANCE, allocator = context.temp_allocator)
	circle_blends := make([]f32, N_INSTANCE, allocator = context.temp_allocator)

	retained_rectangle_count: int = s.rectangle_count
	retained_circle_count: int = s.circle_count
	retained_line_count: int = s.line_count
	defer {
		s.rectangle_count = retained_rectangle_count
		s.circle_count = retained_circle_count
		s.line_count = retained_line_count
	}
	for btn in buttons {
		btn_shape := button_get_shape(btn)
		switch shape in btn_shape {
		case Rectangle:
			{
				add_rectangle(s, shape)
			}
		case Circle:
			{
				add_circle(s, shape)
			}
		}
		bbox := button_get_bbox(btn)
		add_line(s, {bbox.pos, bbox.pos + bbox.size, 2, {1, 1, 1, 1}})
		p1: [2]i32 = {bbox.pos.x, bbox.pos.y + bbox.size.y}
		p2: [2]i32 = {bbox.pos.x + bbox.size.x, bbox.pos.y}
		add_line(s, {p1, p2, 2, {1, 1, 1, 1}})
	}

	mi: int = 0
	for rect, i in s.rectangles {
		if i < s.rectangle_count {
			m := rect_to_matrix(rect)
			rect_matrices[mi] = m
			colors[mi] = rect.color
			mi += 1
		} else {
			break
		}
	}
	for c, i in s.circles {
		if i < s.circle_count {
			m := glm.mat4Translate({f32(c.pos.x), f32(c.pos.y), -1.0})
			m *= glm.mat4Scale({f32(c.radius * 2), f32(c.radius * 2), 1.0})
			rect_matrices[mi] = m
			colors[mi] = c.color
			circle_blends[mi] = 1
			mi += 1
		} else {
			break
		}
	}
	for l, i in s.lines {
		if i < s.line_count {
			m := line_to_matrix(l)
			rect_matrices[mi] = m
			colors[mi] = l.color
			mi += 1
		} else {
			break
		}
	}

	instance_count: int = s.rectangle_count + s.circle_count + s.line_count + 3
	buffer_update(s.buffers.colors, colors[:instance_count])
	buffer_update(s.buffers.model_matrices, rect_matrices[:instance_count])
	buffer_update(s.buffers.circle_blends, circle_blends[:instance_count])
	uniforms: FlatUniforms = {projection_matrix}
	flat_shader_use(s.shader, uniforms, s.buffers)

	ea_buffer_draw(s.buffers.indices, instance_count = instance_count)
}

