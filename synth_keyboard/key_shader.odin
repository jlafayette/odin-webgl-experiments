package synth_keyboard

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

key_vert_source := #load("key.vert", string)
// aPos (vec4)
// aTexCoord (vec2)
// uModelMatrix (mat4)
// uViewProjectionMatrix (mat4)
key_frag_source := #load("key.frag", string)
// uSampler (sampler2D)

KeyShader :: struct {
	program:                  gl.Program,
	a_pos:                    i32,
	a_tex_coord:              i32,
	a_matrix:                 i32,
	u_model_matrix:           i32,
	u_view_projection_matrix: i32,
	u_sampler:                i32,
}
KeyUniforms :: struct {
	model_matrix:           glm.mat4,
	view_projection_matrix: glm.mat4,
}

key_shader_init :: proc(s: ^KeyShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({key_vert_source}, {key_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_tex_coord = gl.GetAttribLocation(program, "aTexCoord")
	s.a_matrix = gl.GetAttribLocation(program, "aMatrix")
	s.u_model_matrix = gl.GetUniformLocation(program, "uModelMatrix")
	s.u_view_projection_matrix = gl.GetUniformLocation(program, "uViewProjectionMatrix")

	return check_gl_error()
}
shader_use :: proc(
	s: ^KeyShader,
	u: KeyUniforms,
	buffer_pos: Buffer,
	buffer_tex: Buffer,
	buffer_matrix: Buffer,
	texture: TextureInfo,
) -> (
	ok: bool,
) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffer_pos)
	shader_set_attribute(s.a_tex_coord, buffer_tex)
	shader_set_matrix_attribute(s.a_matrix, buffer_matrix)

	// set uniforms
	gl.UniformMatrix4fv(s.u_model_matrix, u.model_matrix)
	gl.UniformMatrix4fv(s.u_view_projection_matrix, u.view_projection_matrix)

	// set texture
	gl.ActiveTexture(texture.unit)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.Uniform1i(s.u_sampler, 0)

	return check_gl_error()
}
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}
shader_set_matrix_attribute :: proc(index: i32, b: Buffer) {
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

