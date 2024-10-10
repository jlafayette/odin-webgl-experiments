package camera

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

vert_source := #load("cube.vert", string)
frag_source := #load("cube.frag", string)

Shader :: struct {
	program:             gl.Program,
	a_vertex_position:   i32,
	a_vertex_color:      i32,
	a_vertex_normal:     i32,
	a_model_matrix:      i32,
	a_normal_matrix:     i32,
	u_view_matrix:       i32,
	u_projection_matrix: i32,
}
Uniforms :: struct {
	view_matrix:       glm.mat4,
	projection_matrix: glm.mat4,
}

shader_init :: proc(s: ^Shader) -> (ok: bool) {
	s.program, ok = gl.CreateProgramFromStrings({vert_source}, {frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.a_vertex_position = gl.GetAttribLocation(s.program, "aVertexPosition")
	s.a_vertex_color = gl.GetAttribLocation(s.program, "aVertexColor")
	s.a_vertex_normal = gl.GetAttribLocation(s.program, "aVertexNormal")
	s.a_model_matrix = gl.GetAttribLocation(s.program, "aModelMatrix")
	s.a_normal_matrix = gl.GetAttribLocation(s.program, "aNormalMatrix")

	s.u_view_matrix = gl.GetUniformLocation(s.program, "uViewMatrix")
	s.u_projection_matrix = gl.GetUniformLocation(s.program, "uProjectionMatrix")
	// s.u_normal_matrix = gl.GetUniformLocation(s.program, "uNormalMatrix")

	return check_gl_error()
}

shader_use :: proc(s: Shader, u: Uniforms, buffers: Buffers) -> (ok: bool) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_vertex_position, buffers.position)
	shader_set_attribute(s.a_vertex_color, buffers.color)
	shader_set_attribute(s.a_vertex_normal, buffers.normal)
	shader_set_instance_matrix_attribute(s.a_model_matrix, buffers.model_matrices)
	shader_set_instance_matrix_attribute(s.a_normal_matrix, buffers.normal_matrices)

	// set uniforms
	gl.UniformMatrix4fv(s.u_view_matrix, u.view_matrix)
	gl.UniformMatrix4fv(s.u_projection_matrix, u.projection_matrix)
	// gl.UniformMatrix4fv(s.u_normal_matrix, u.normal_matrix)

	return check_gl_error()
}
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}
shader_set_instance_matrix_attribute :: proc(index: i32, b: Buffer) {
	// b.size = 4, b.type = gl.FLOAT
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

