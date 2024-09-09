package cube_texture2

import "core:bytes"
import "core:fmt"
import "core:image/png"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

cube_vert_source := #load("cube.vert", string)
// aPos (vec4)
// aTexCoord (vec2)
// uModelViewMatrix (mat4)
// uProjectionMatrix (mat4)
cube_frag_source := #load("cube.frag", string)
// uSampler (sampler2D)

CubeShader :: struct {
	program:             gl.Program,
	a_pos:               i32,
	a_tex_coord:         i32,
	u_model_view_matrix: i32,
	u_projection_matrix: i32,
	u_sampler:           i32,
}
CubeUniforms :: struct {
	model_view_matrix: glm.mat4,
	projection_matrix: glm.mat4,
}

shader_init :: proc(s: ^CubeShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({cube_vert_source}, {cube_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_tex_coord = gl.GetAttribLocation(program, "aTexCoord")
	s.u_model_view_matrix = gl.GetUniformLocation(program, "uModelViewMatrix")
	s.u_projection_matrix = gl.GetUniformLocation(program, "uProjectionMatrix")

	return check_gl_error()
}
shader_use :: proc(
	s: ^CubeShader,
	u: CubeUniforms,
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
	gl.UniformMatrix4fv(s.u_model_view_matrix, u.model_view_matrix)
	gl.UniformMatrix4fv(s.u_projection_matrix, u.projection_matrix)

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

