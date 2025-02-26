package game

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

	colors := make([]glm.vec4, N_INSTANCE)
	defer delete(colors)
	buffers.colors = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.colors, colors[:])

	circle_blends := make([]f32, N_INSTANCE)
	defer delete(circle_blends)
	buffers.circle_blends = {
		size   = 1,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.circle_blends, circle_blends[:])

	model_matrices := make([]glm.mat4, N_INSTANCE)
	defer delete(model_matrices)
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
	pos:   [2]int,
	size:  [2]int,
	color: Color,
}
RectangleCn :: struct {
	pos:      [2]int,
	size:     [2]int,
	rotation: f32,
	color:    Color,
}
RectangleMat :: struct {
	m:     glm.mat4,
	color: Color,
}
Circle :: struct {
	pos:    [2]int,
	radius: int,
	color:  Color,
}
CircleMat :: struct {
	m:     glm.mat4,
	color: Color,
}
Line :: struct {
	start:     [2]int,
	end:       [2]int,
	thickness: int,
	color:     Color,
}
LineMat :: struct {
	m:     glm.mat4,
	color: Color,
}
Shape :: union {
	Rectangle,
	Circle,
	Line,
	RectangleMat,
	CircleMat,
	LineMat,
}

N_INSTANCE :: 4096 * 2

ShapesDebug :: struct {
	prev_count: int,
	max_count:  int,
}
Shapes :: struct {
	rectangle_count: int,
	circle_count:    int,
	line_count:      int,
	buffers:         Buffers,
	shader:          FlatShader,
	rect_matrices:   [dynamic]glm.mat4,
	colors:          [dynamic]glm.vec4,
	circle_blends:   [dynamic]f32,
	debug:           ShapesDebug,
}

shapes_init :: proc(s: ^Shapes) -> (ok: bool) {
	ok = flat_shader_init(&s.shader)
	if !ok {return false}
	buffers_init(&s.buffers)
	err := reserve_dynamic_array(&s.rect_matrices, N_INSTANCE)
	assert(err == nil)
	err = reserve_dynamic_array(&s.colors, N_INSTANCE)
	assert(err == nil)
	err = reserve_dynamic_array(&s.circle_blends, N_INSTANCE)
	assert(err == nil)
	return ok
}

line_angle :: proc(line: Line) -> f32 {
	line_diff_int: [2]int = line.end - line.start
	line_diff: [2]f32 = {f32(line_diff_int.x), f32(line_diff_int.y)}
	angle := math.atan2(line_diff.y, line_diff.x)
	return angle
}
line_to_matrix :: proc(line: Line, rotation: f32 = 0) -> glm.mat4 {
	line_diff_int: [2]int = line.end - line.start
	line_diff: [2]f32 = {f32(line_diff_int.x), f32(line_diff_int.y)}
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
	pos := f_(rect.pos)
	size := f_(rect.size)
	pos += size * 0.5
	m := glm.mat4Translate({pos.x, pos.y, -1.0})
	m *= glm.mat4Scale({size.x, size.y, 1.0})
	return m
}
rect_cn_to_matrix :: proc(rect: RectangleCn) -> glm.mat4 {
	pos := f_(rect.pos)
	size := f_(rect.size)
	m := glm.mat4Translate({pos.x, pos.y, -1.0})
	m *= glm.mat4Rotate({0, 0, 1}, rect.rotation)
	m *= glm.mat4Scale({size.x, size.y, 1.0})
	return m
}

i_ :: proc(pos: [2]f32) -> [2]int {
	return {int(math.round(pos.x)), int(math.round(pos.y))}
}
i_int_floor :: proc(pos: [2]f32) -> [2]int {
	return {int(math.floor(pos.x)), int(math.floor(pos.y))}
}
i_int_round :: proc(pos: [2]f32) -> [2]int {
	return {int(math.round(pos.x)), int(math.round(pos.y))}
}
f_i64 :: proc(pos: [2]i64) -> [2]f32 {
	return {f32(pos.x), f32(pos.y)}
}
f_i32 :: proc(pos: [2]i32) -> [2]f32 {
	return {f32(pos.x), f32(pos.y)}
}
f_int :: proc(pos: [2]int) -> [2]f32 {
	return {f32(pos.x), f32(pos.y)}
}
f_ :: proc {
	f_i64,
	f_i32,
	f_int,
}

shapes_update_debug :: proc(s: ^Shapes) {

	// actually this will from prev frame... but that doesn't 
	// really matter for this debugging
	new_count := len(s.rect_matrices)

	prev := s.debug.prev_count
	s.debug.prev_count = new_count

	old_max := s.debug.max_count
	if new_count > old_max {
		fmt.println("New max shapes:", old_max, "->", new_count)
		s.debug.max_count = new_count
	}
}

shapes_draw :: proc(s: ^Shapes, shapes: []Shape, projection_matrix: glm.mat4) {

	shapes_update_debug(s)

	// reset shapes
	clear(&s.rect_matrices)
	clear(&s.colors)
	clear(&s.circle_blends)

	retained_rectangle_count: int = s.rectangle_count
	retained_circle_count: int = s.circle_count
	retained_line_count: int = s.line_count
	defer {
		s.rectangle_count = retained_rectangle_count
		s.circle_count = retained_circle_count
		s.line_count = retained_line_count
	}

	for sh in shapes {
		switch shape in sh {
		case Rectangle:
			{
				m := rect_to_matrix(shape)
				append(&s.rect_matrices, m)
				append(&s.colors, color_enum_to_4f32(shape.color))
				append(&s.circle_blends, 0)
			}
		// case RectangleCn:
		// 	{
		// 		m := rect_cn_to_matrix(shape)
		// 		rect_matrices[mi] = m
		// 		colors[mi] = color_enum_to_4f32(shape.color)
		// 		mi += 1
		// 	}
		case Circle:
			{
				c := shape
				m := glm.mat4Translate({f32(c.pos.x), f32(c.pos.y), -1.0})
				m *= glm.mat4Scale({f32(c.radius * 2), f32(c.radius * 2), 1.0})
				append(&s.rect_matrices, m)
				append(&s.colors, color_enum_to_4f32(c.color))
				append(&s.circle_blends, 1)
			}
		case Line:
			{
				l := shape
				m := line_to_matrix(l)
				append(&s.rect_matrices, m)
				append(&s.colors, color_enum_to_4f32(l.color))
				append(&s.circle_blends, 0)
			}
		case RectangleMat:
			{
				append(&s.rect_matrices, shape.m)
				append(&s.colors, color_enum_to_4f32(shape.color))
				append(&s.circle_blends, 0)
			}
		case CircleMat:
			{
				append(&s.rect_matrices, shape.m)
				append(&s.colors, color_enum_to_4f32(shape.color))
				append(&s.circle_blends, 1)
			}
		case LineMat:
			{
				append(&s.rect_matrices, shape.m)
				append(&s.colors, color_enum_to_4f32(shape.color))
				append(&s.circle_blends, 0)
			}
		}
	}
	instance_count: int = len(s.rect_matrices)
	assert(instance_count == len(s.colors))
	assert(instance_count == len(s.circle_blends))
	if instance_count > N_INSTANCE {
		fmt.eprintln("Too many shapes to draw")
		instance_count = N_INSTANCE
	}

	buffer_update(s.buffers.colors, s.colors[:instance_count])
	buffer_update(s.buffers.model_matrices, s.rect_matrices[:instance_count])
	buffer_update(s.buffers.circle_blends, s.circle_blends[:instance_count])
	uniforms: FlatUniforms = {projection_matrix}
	flat_shader_use(s.shader, uniforms, s.buffers)

	ea_buffer_draw(s.buffers.indices, instance_count = instance_count)
}

