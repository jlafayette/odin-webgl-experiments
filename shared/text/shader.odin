package text

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

@(private)
vert_source := #load("text.vert", string)
@(private)
frag_source := #load("text.frag", string)

TextShader :: struct {
	program:             gl.Program,
	a_pos:               i32,
	a_tex_coord:         i32,
	u_text_color:        i32,
	u_projection_matrix: i32,
	u_sampler:           i32,
}
@(private)
Uniforms :: struct {
	color:             glm.vec3,
	projection_matrix: glm.mat4,
}

@(private)
shader_init :: proc(s: ^TextShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vert_source}, {frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_tex_coord = gl.GetAttribLocation(program, "aTex")

	s.u_sampler = gl.GetUniformLocation(program, "uSampler")
	s.u_text_color = gl.GetUniformLocation(program, "uTextColor")
	s.u_projection_matrix = gl.GetUniformLocation(program, "uProjection")

	return check_gl_error()
}
@(private)
shader_use :: proc(
	s: TextShader,
	u: Uniforms,
	buffer_pos: Buffer,
	buffer_tex: Buffer,
	texture: TextureInfo,
) -> (
	ok: bool,
) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffer_pos)
	shader_set_attribute(s.a_tex_coord, buffer_tex)

	// set uniforms
	gl.Uniform3fv(s.u_text_color, u.color)
	gl.UniformMatrix4fv(s.u_projection_matrix, u.projection_matrix)

	// set texture
	gl.ActiveTexture(texture.unit)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.Uniform1i(s.u_sampler, 0)

	return check_gl_error()
}
@(private)
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}

