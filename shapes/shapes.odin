package shapes

import "../shared/text"
import "core:fmt"
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
Buffers :: struct {
	pos:            Buffer,
	indices:        EaBuffer,
	model_matrices: Buffer,
}
buffers_init :: proc(buffers: ^Buffers) {
	pos_data: [4][2]f32 = {{0, 0}, {0, 1}, {1, 1}, {1, 0}}
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

	model_matrices: [3]glm.mat4 = glm.mat4(1)
	buffers.model_matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.model_matrices, model_matrices[:])
}

flat_vert_source := #load("flat.vert", string)
flat_frag_source := #load("flat.frag", string)
FlatShader :: struct {
	program:                  gl.Program,
	a_pos:                    i32,
	a_model_matrix:           i32,
	u_color:                  i32,
	u_view_projection_matrix: i32,
}
FlatUniforms :: struct {
	color:                  glm.vec4,
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
	s.a_model_matrix = gl.GetAttribLocation(program, "aModelMatrix")
	s.u_color = gl.GetUniformLocation(program, "uColor")
	s.u_view_projection_matrix = gl.GetUniformLocation(program, "uViewProjectionMatrix")
	return true
}
flat_shader_use :: proc(s: FlatShader, u: FlatUniforms, buffers: Buffers) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffers.pos)
	shader_set_instance_matrix_attribute(s.a_model_matrix, buffers.model_matrices)

	// set uniforms
	gl.Uniform4fv(s.u_color, u.color)
	gl.UniformMatrix4fv(s.u_view_projection_matrix, u.view_projection_matrix)
}
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}
buffer_update :: proc(b: Buffer, data: []$T) {
	gl.BindBuffer(b.target, b.id)
	gl.BufferSubDataSlice(b.target, 0, data[:])
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

ShapeType :: enum {
	RECTANGLE,
	CIRCLE,
	LINE,
}

Shape :: struct {
	type:  ShapeType,
	pos:   [2]i32,
	size:  [2]i32,
	color: [3]f32,
}

MAX_SHAPES :: 64

Shapes :: struct {
	shape_count: int,
	shapes:      [MAX_SHAPES]Shape,
	buffers:     Buffers,
	shader:      FlatShader,
}

shapes_init :: proc(s: ^Shapes) -> (ok: bool) {
	ok = flat_shader_init(&s.shader)
	if !ok {return false}

	buffers_init(&s.buffers)

	return ok
}

shapes_update :: proc(s: ^Shapes, w, h: i32) {
}

shapes_draw :: proc(s: ^Shapes, projection_matrix: glm.mat4) {
	// draw rects for buttons
	rect_matrices: [3]glm.mat4

	// for btn, i in ui.buttons {
	// 	// fmt.println("button:", btn.pos, btn.size)
	// 	mat: glm.mat4 = glm.mat4(1)
	// 	mat *= glm.mat4Translate({f32(btn.pos.x), f32(btn.pos.y), -1.0})
	// 	mat *= glm.mat4Scale({f32(btn.size.x), f32(btn.size.y), 1.0})
	// 	rect_matrices[i] = mat
	// }

	// buffer_update(ui.buffers.model_matrices, rect_matrices[:])
	// c := ui.buttons[0].color
	uniforms: FlatUniforms = {{1, 1, 1, 1}, projection_matrix}
	flat_shader_use(s.shader, uniforms, s.buffers)

	// fmt.println("drawing ui")
	ea_buffer_draw(s.buffers.indices, instance_count = s.shape_count)

	gl.VertexAttribDivisor(1, 0)
	gl.VertexAttribDivisor(2, 0)
	gl.VertexAttribDivisor(3, 0)
	gl.VertexAttribDivisor(4, 0)

}

