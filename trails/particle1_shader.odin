package trails

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

particle1_vert_source := #load("particle1.vert", string)
// aPos (vec4)
// aTexCoord (vec2)
// aColor (vec4)
// aMatrix (mat4)
// uModelMatrix (mat4)
// uViewProjectionMatrix (mat4)
particle1_frag_source := #load("particle1.frag", string)

Particle1Shader :: struct {
	program:                  gl.Program,
	a_pos:                    i32,
	a_tex_coord:              i32,
	a_color:                  i32,
	a_matrix:                 i32,
	u_model_matrix:           i32,
	u_view_projection_matrix: i32,
}
Particle1Uniforms :: struct {
	model_matrix:           glm.mat4,
	view_projection_matrix: glm.mat4,
}

particle1_shader_init :: proc(s: ^Particle1Shader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({particle1_vert_source}, {particle1_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_tex_coord = gl.GetAttribLocation(program, "aTexCoord")
	s.a_color = gl.GetAttribLocation(program, "aColor")
	s.a_matrix = gl.GetAttribLocation(program, "aMatrix")
	s.u_model_matrix = gl.GetUniformLocation(program, "uModelMatrix")
	s.u_view_projection_matrix = gl.GetUniformLocation(program, "uViewProjectionMatrix")

	return check_gl_error()
}
particle_shader_use :: proc(
	s: Particle1Shader,
	u: Particle1Uniforms,
	buffer_pos: Buffer,
	buffer_tex: Buffer,
	buffer_color: Buffer,
	buffer_matrix: Buffer,
) -> (
	ok: bool,
) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffer_pos)
	shader_set_attribute(s.a_tex_coord, buffer_tex)
	shader_set_instance_attribute(s.a_color, buffer_color)
	shader_set_instance_matrix_attribute(s.a_matrix, buffer_matrix)

	// set uniforms
	gl.UniformMatrix4fv(s.u_model_matrix, u.model_matrix)
	gl.UniformMatrix4fv(s.u_view_projection_matrix, u.view_projection_matrix)

	// return check_gl_error()
	return true
}
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}
shader_set_instance_attribute :: proc(index: i32, b: Buffer) {
	// b.size = 4, b.type = gl.FLOAT
	gl.BindBuffer(b.target, b.id)
	gl.EnableVertexAttribArray(index)
	size := size_of(glm.vec4)
	gl.VertexAttribPointer(index, b.size, b.type, false, size, 0)
	gl.VertexAttribDivisor(u32(index), 1)
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

