package multi

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

lighting_vert_source := #load("lighting.vert", string)
// aVertexPosition (vec4)
// aVertexNormal (vec3)
// aTextureCoord (vec2)
// uNormalMatrix (mat4)
// uModelMatrix (mat4)
// uViewProjectionMatrix (mat4)
lighting_frag_source := #load("lighting.frag", string)
// uSampler (sampler2D)

LightingShader :: struct {
	program:                  gl.Program,
	a_vertex_position:        i32,
	a_vertex_normal:          i32,
	a_texture_coord:          i32,
	u_model_matrix:           i32,
	u_normal_matrix:          i32,
	u_view_projection_matrix: i32,
	u_sampler:                i32,
}
LightingUniforms :: struct {
	model_matrix:           glm.mat4,
	normal_matrix:          glm.mat4,
	view_projection_matrix: glm.mat4,
}

lighting_shader_init :: proc(s: ^LightingShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({lighting_vert_source}, {lighting_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_vertex_position = gl.GetAttribLocation(program, "aVertexPosition")
	s.a_vertex_normal = gl.GetAttribLocation(program, "aVertexNormal")
	s.a_texture_coord = gl.GetAttribLocation(program, "aTextureCoord")

	s.u_normal_matrix = gl.GetUniformLocation(program, "uNormalMatrix")
	s.u_model_matrix = gl.GetUniformLocation(program, "uModelMatrix")
	s.u_view_projection_matrix = gl.GetUniformLocation(program, "uViewProjectionMatrix")

	return check_gl_error()
}
lighting_shader_use :: proc(
	s: LightingShader,
	u: LightingUniforms,
	buffer_pos: Buffer,
	buffer_tex: Buffer,
	buffer_normal: Buffer,
	texture: TextureInfo,
) -> (
	ok: bool,
) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_vertex_position, buffer_pos)
	shader_set_attribute(s.a_texture_coord, buffer_tex)
	shader_set_attribute(s.a_vertex_normal, buffer_normal)

	// set uniforms
	gl.UniformMatrix4fv(s.u_normal_matrix, u.normal_matrix)
	gl.UniformMatrix4fv(s.u_model_matrix, u.model_matrix)
	gl.UniformMatrix4fv(s.u_view_projection_matrix, u.view_projection_matrix)

	// set texture
	gl.ActiveTexture(texture.unit)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.Uniform1i(s.u_sampler, 0)

	return check_gl_error()
}

