package synth_keyboard

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

atlas_vert_source := #load("atlas.vert", string)
// aPos (vec2)
// aTex (vec2)
// aMatrix (mat4)
// uProjection (mat4)
atlas_frag_source := #load("atlas.frag", string)
// uTextColor (vec3)
// uSampler (sampler2D)

AtlasShader :: struct {
	program:      gl.Program,
	a_pos:        i32,
	a_tex:        i32,
	a_matrix:     i32,
	u_projection: i32,
	u_text_color: i32,
	u_sampler:    i32,
}
AtlasUniforms :: struct {
	projection: glm.mat4,
	text_color: glm.vec3,
}

atlas_shader_init :: proc(s: ^AtlasShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({atlas_vert_source}, {atlas_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_tex = gl.GetAttribLocation(program, "aTex")
	s.a_matrix = gl.GetAttribLocation(program, "aMatrix")
	s.u_text_color = gl.GetUniformLocation(program, "uTextColor")
	s.u_projection = gl.GetUniformLocation(program, "uProjection")
	fmt.println("a_pos:", s.a_pos, "a_tex:", s.a_tex, "a_matrix:", s.a_matrix)
	fmt.println("u_text_color:", s.u_text_color, "u_projection:", s.u_projection)

	return check_gl_error()
}
atlas_shader_use :: proc(
	s: ^AtlasShader,
	u: AtlasUniforms,
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
	shader_set_instanced_tex_attribute(s.a_tex, buffer_tex)
	shader_set_matrix_attribute(s.a_matrix, buffer_matrix)

	// set uniforms
	gl.UniformMatrix4fv(s.u_projection, u.projection)
	gl.Uniform3fv(s.u_text_color, u.text_color)

	// set texture
	gl.ActiveTexture(texture.unit)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.Uniform1i(s.u_sampler, 0)

	return check_gl_error()
}

