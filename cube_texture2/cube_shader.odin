package cube_texture2

import "core:bytes"
import "core:fmt"
import "core:image/png"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

texture_data := #load("odin_logo.png")
vs_source := #load("cube.vert", string)
fs_source := #load("cube.frag", string)

CubeShader :: struct {
	program:             gl.Program,
	buffer_pos:          gl.Buffer,
	buffer_tex:          gl.Buffer,
	buffer_indices:      gl.Buffer,
	a_pos:               i32,
	a_tex_coord:         i32,
	u_model_view_matrix: i32,
	u_projection_matrix: i32,
	u_sampler:           i32,
	texture:             gl.Texture,
	texture_unit:        gl.Enum,
}
Uniforms :: struct {
	model_view_matrix: glm.mat4,
	projection_matrix: glm.mat4,
}
InitBuffers :: struct {
	pos:     InitBuffer([4][3]f32),
	tex:     InitBuffer([4][2]f32),
	indices: InitBuffer([6]u16),
}
Buffers2 :: struct {
	pos:     Buffer,
	tex:     Buffer,
	indices: Buffer,
}
// vert
// aPos (vec4)
// aTexCoord (vec2)
// uModelViewMatrix (mat4)
// uProjectionMatrix (mat4)
// frag
// uSampler (sampler2D)

shader_init :: proc(s: ^CubeShader, buffers: InitBuffers) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vs_source}, {fs_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program

	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_tex_coord = gl.GetAttribLocation(program, "aTexCoord")
	s.u_model_view_matrix = gl.GetUniformLocation(program, "uModelViewMatrix")
	s.u_projection_matrix = gl.GetUniformLocation(program, "uProjectionMatrix")

	s.buffer_pos = buffer_init(buffers.pos)
	s.buffer_tex = buffer_init(buffers.tex)
	s.buffer_indices = buffer_init(buffers.indices)

	s.texture_unit = gl.TEXTURE0
	s.texture = load_texture()

	return check_gl_error()
}
shader_use :: proc(s: ^CubeShader, u: Uniforms, buffers: Buffers2) -> (ok: bool) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, s.buffer_pos, buffers.pos)
	shader_set_attribute(s.a_tex_coord, s.buffer_tex, buffers.tex)

	// set uniforms
	gl.UniformMatrix4fv(s.u_model_view_matrix, u.model_view_matrix)
	gl.UniformMatrix4fv(s.u_projection_matrix, u.projection_matrix)

	// set texture
	gl.ActiveTexture(s.texture_unit)
	gl.BindTexture(gl.TEXTURE_2D, s.texture)
	gl.Uniform1i(s.u_sampler, 0)

	return true
}
shader_set_attribute :: proc(index: i32, id: gl.Buffer, b: Buffer) {
	gl.BindBuffer(b.target, id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}

// -- Buffers

InitBuffer :: struct($T: typeid) {
	data: []T, // [3]f32
	b:    Buffer,
}
Buffer :: struct {
	size:   int, // 3
	type:   gl.Enum, // gl.FLOAT
	target: gl.Enum, // gl.ARRAY_BUFFER
	usage:  gl.Enum, // gl.STATIC_DRAW
}
buffer_init :: proc(ib: InitBuffer($T)) -> gl.Buffer {
	id := gl.CreateBuffer()
	gl.BindBuffer(ib.b.target, id)
	gl.BufferDataSlice(ib.b.target, ib.data[:], ib.b.usage)
	return id
}
// seems like id and count should be built-in to Buffer...
g_first := true
buffer_draw :: proc(id: gl.Buffer, count: int, b: Buffer, offset: rawptr = nil) {
	if g_first {
		g_first = false
		fmt.println("id:", id)
		fmt.println("buffer:", b)
	}
	gl.BindBuffer(b.target, id)
	gl.DrawElements(gl.TRIANGLES, count, b.type, offset)
}

// --- Texture

load_texture :: proc() -> gl.Texture {
	texture := gl.CreateTexture()
	gl.BindTexture(gl.TEXTURE_2D, texture)
	fmt.println("texture data len:", len(texture_data))

	options: png.Options = {}
	img, err := png.load_from_bytes(
		texture_data,
		options = options,
		allocator = context.temp_allocator,
	)
	if err != nil {
		fmt.eprintln("error loading image:", err)
		return texture
	}
	fmt.println(img.width, "x", img.height, "chan:", img.channels)
	data := bytes.buffer_to_bytes(&img.pixels)
	fmt.println("data len:", len(data))
	level: i32 = 0
	border: i32 = 0
	internal_format := gl.RGBA
	format := gl.RGBA
	if img.channels == 3 {
		internal_format = gl.RGB
		format = gl.RGB
	}
	type := gl.UNSIGNED_BYTE
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.PixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
	gl.TexImage2DSlice(
		gl.TEXTURE_2D,
		level,
		internal_format,
		cast(i32)img.width,
		cast(i32)img.height,
		border,
		format,
		type,
		data,
	)
	if (is_power_of_two(img.width) && is_power_of_two(img.height)) {
		fmt.println("generating mipmaps")
		gl.GenerateMipmap(gl.TEXTURE_2D)
	} else {
		// wasn't able to test this because non-power-of-2 images fail on the
		// TexImage2D command
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.LINEAR)
	}
	return texture
}
@(private = "file")
is_power_of_two :: proc(n: int) -> bool {
	return (n & (n - 1)) == 0
}

