package game


import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"


TextureInfo :: struct {
	id:   gl.Texture,
	unit: gl.Enum,
}

PatchBuffers :: struct {
	pos:     Buffer,
	indices: EaBuffer,
}

// a single square to render to
patch_buffers_init :: proc(buffers: ^PatchBuffers) {
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
}

@(private = "file")
patch_vert_source := #load("patch.vert", string)
@(private = "file")
patch_frag_source := #load("patch.frag", string)

PatchShader :: struct {
	program:             gl.Program,
	a_pos:               i32,
	// a_tex_coord:         i32,
	u_sampler:           i32,
	u_color:             i32,
	u_dim:               i32,
	u_tile_size:         i32,
	u_pos_offset:        i32,
	u_projection_matrix: i32,
}
PatchUniforms :: struct {
	projection_matrix: glm.mat4,
	dim:               glm.vec2,
	tile_size:         glm.vec2,
	pos_offset:        glm.vec2,
	color:             glm.vec3,
}

patch_shader_init :: proc(s: ^PatchShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({patch_vert_source}, {patch_frag_source})
	if !ok {
		fmt.eprintln("Failed to create patch shader program")
		return false
	}
	s.program = program
	s.a_pos = gl.GetAttribLocation(program, "aPos")

	s.u_projection_matrix = gl.GetUniformLocation(program, "uProjection")

	s.u_sampler = gl.GetUniformLocation(program, "uSampler")
	s.u_dim = gl.GetUniformLocation(program, "uDim")
	s.u_tile_size = gl.GetUniformLocation(program, "uTileSize")
	s.u_pos_offset = gl.GetUniformLocation(program, "uPosOffset")

	s.u_color = gl.GetUniformLocation(program, "uColor")

	// return check_gl_error()
	return true
}

patch_shader_use :: proc(
	s: PatchShader,
	u: PatchUniforms,
	buffers: PatchBuffers,
	texture: TextureInfo,
) {
	gl.UseProgram(s.program)
	shader_set_attribute(s.a_pos, buffers.pos)

	gl.UniformMatrix4fv(s.u_projection_matrix, u.projection_matrix)
	gl.Uniform2fv(s.u_dim, u.dim)
	gl.Uniform2fv(s.u_tile_size, u.tile_size)
	gl.Uniform2fv(s.u_pos_offset, u.pos_offset)
	gl.Uniform3fv(s.u_color, u.color)

	// set texture
	gl.ActiveTexture(texture.unit)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.Uniform1i(s.u_sampler, 0)

	// ok := check_gl_error()
	// assert(ok, "Failed to setup patch shader to use")
}

patch_init_texture :: proc(pixels: [][4]u8) -> TextureInfo {
	t: TextureInfo
	t.id = gl.CreateTexture()
	t.unit = gl.TEXTURE0
	gl.BindTexture(gl.TEXTURE_2D, t.id)
	w := cast(i32)SQUARES.x
	h := cast(i32)SQUARES.y
	for _, i in pixels {
		pixels[i] = {0, 0, 0, 0}
		if i % 2 == 0 {
			pixels[i] = {255, 255, 255, 255}
		}
	}
	gl.TexImage2DSlice(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels[:])

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, cast(i32)gl.NEAREST)

	return t
}

_patch_update_texture :: proc(patch: ^Patch) {
	w := SQUARES.x
	h := SQUARES.y
	pixels := patch.texture_data
	for v, i in patch.vertexes {
		tv: [4]u8
		if v {
			tv = {255, 255, 255, 0}
		} else {
			tv = {0, 0, 0, 0}
		}
		pixels[i] = tv
	}
	gl.BindTexture(gl.TEXTURE_2D, patch.texture_info.id)
	gl.TexSubImage2DSlice(
		gl.TEXTURE_2D,
		0,
		0,
		0,
		cast(i32)w,
		cast(i32)h,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		pixels[:],
	)
}

patch_draw :: proc(patch: ^Patch, projection_matrix: glm.mat4, w, h: int, shader: PatchShader) {
	_patch_update_texture(patch)

	uniforms: PatchUniforms

	m := projection_matrix
	uniforms.projection_matrix = m

	// size := _size({w, h})
	x := w / SQUARES.x
	y := h / SQUARES.y
	size := math.min(x, y)

	dim := f_(size * SQUARES)
	tile_size := dim / f_(SQUARES)
	uniforms.tile_size = tile_size
	uniforms.dim = dim
	uniforms.pos_offset = f_int(patch.offset)

	// fmt.println(uniforms.dim, uniforms.tile_size)

	uniforms.color = COLOR_2.rgb
	patch_shader_use(shader, uniforms, patch.buffers, patch.texture_info)
	ea_buffer_draw(patch.buffers.indices)
}

