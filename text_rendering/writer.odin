package text_rendering

import "../shared/text"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

atlas_pixel_data := #load("../atlas_pixel_data_24")
atlas_data := #load("../atlas_data_24")
vert_source := #load("text.vert", string)
frag_source := #load("text.frag", string)

TextProgramInfo :: struct {
	program:           gl.Program,
	attrib_locations:  TextAttribLocations,
	uniform_locations: TextUniformLocations,
}
TextAttribLocations :: struct {
	pos: i32,
	tex: i32,
}
TextUniformLocations :: struct {
	projection: i32,
	sampler:    i32,
	text_color: i32,
}

Writer :: struct {
	buf:               [1024]byte,
	str:               string,
	program_info:      TextProgramInfo,
	texture:           gl.Texture,
	buffer_vertex_pos: gl.Buffer,
	buffer_vertex_tex: gl.Buffer,
	buffer_indices:    gl.Buffer,
}
writer_init :: proc(w: ^Writer) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vert_source}, {frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return ok
	}

	// buffers
	buffer: gl.Buffer
	{
		buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
		// just render a square for now
		x: f32 = 20
		y: f32 = 20
		w: f32 = 256
		h: f32 = 256
		data: [4][2]f32
		data[0] = {x, y + h}
		data[1] = {x, y}
		data[2] = {x + w, y}
		data[3] = {x + w, y + h}
		gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	}
	w.buffer_vertex_pos = buffer
	{
		buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
		data: [4][2]f32 = {{0, 1}, {0, 0}, {1, 0}, {1, 1}}
		gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	}
	w.buffer_vertex_tex = buffer
	{
		// indices
		buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer)
		data: [6]u16 = {0, 1, 2, 0, 2, 3}
		gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	}
	w.buffer_indices = buffer

	// texture
	texture: gl.Texture
	header, chars, ok2 := text.decode(atlas_data)
	{
		texture = gl.CreateTexture()
		gl.BindTexture(gl.TEXTURE_2D, texture)
		gl.TexImage2DSlice(
			gl.TEXTURE_2D,
			0,
			gl.ALPHA,
			header.atlas_w,
			header.atlas_h,
			0,
			gl.ALPHA,
			gl.UNSIGNED_BYTE,
			atlas_pixel_data,
		)
		// fmt.println("generating mipmaps")
		// gl.GenerateMipmap(gl.TEXTURE_2D)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.LINEAR)
	}
	// gl.PixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)

	w.program_info = {
		program = program,
		attrib_locations = {
			pos = gl.GetAttribLocation(program, "aPos"),
			tex = gl.GetAttribLocation(program, "aTex"),
		},
		uniform_locations = {
			projection = gl.GetUniformLocation(program, "uProjection"),
			sampler = gl.GetUniformLocation(program, "uSampler"),
			text_color = gl.GetUniformLocation(program, "uTextColor"),
		},
	}
	w.texture = texture

	ok = check_gl_error()
	return ok
}
writer_destroy :: proc(w: ^Writer) {

}
writer_draw :: proc(w: ^Writer) {

	// draw text
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	{
		attrib_locations := w.program_info.attrib_locations
		{
			gl.BindBuffer(gl.ARRAY_BUFFER, w.buffer_vertex_pos)
			gl.VertexAttribPointer(attrib_locations.pos, 2, gl.FLOAT, false, 0, 0)
			gl.EnableVertexAttribArray(attrib_locations.pos)
		}
		{
			gl.BindBuffer(gl.ARRAY_BUFFER, w.buffer_vertex_tex)
			gl.VertexAttribPointer(attrib_locations.tex, 2, gl.FLOAT, false, 0, 0)
			gl.EnableVertexAttribArray(attrib_locations.tex)
		}
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, w.buffer_indices)
		gl.UseProgram(w.program_info.program)
		// set uniforms
		uniform_locations := w.program_info.uniform_locations
		// bottom left (0, 0)
		// projection_mat := glm.mat4Ortho3d(0, W, 0, H, -1, 1)
		// top left (0, 0)
		projection_mat := glm.mat4Ortho3d(0, W, H, 0, -1, 1)
		gl.UniformMatrix4fv(uniform_locations.projection, projection_mat)
		gl.Uniform3fv(uniform_locations.text_color, {0, 1, 1})
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, w.texture)
		gl.Uniform1i(uniform_locations.sampler, 0)
		{
			vertex_count := 6
			type := gl.UNSIGNED_SHORT
			offset: rawptr
			gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
		}
	}

}

