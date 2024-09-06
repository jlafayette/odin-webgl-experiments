package text_rendering

import "../shared/text"
import "core:fmt"
import "core:math"
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
	header:            text.Header,
	chars:             [dynamic]text.Char,
}
writer_init :: proc(w: ^Writer, xpos: i32, ypos: i32, str: string) -> (ok: bool) {
	// w.str = "Hello WOdinlingssss!"
	w.str = str
	w.header, w.chars, ok = text.decode(atlas_data)
	if !ok {
		fmt.eprintln("Failed to decode atlas data")
		return ok
	}

	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vert_source}, {frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return ok
	}

	// buffers
	buffer: gl.Buffer
	pos_data := make([][2]f32, len(w.str) * 4, allocator = context.temp_allocator)
	tex_data := make([][2]f32, len(w.str) * 4, allocator = context.temp_allocator)
	indices_data := make([]u16, len(w.str) * 6, allocator = context.temp_allocator)
	{
		x: f32 = f32(xpos)
		y: f32 = f32(ypos)
		for char, ch_index in w.str {
			i := ch_index * 4
			char_i := i32(char) - w.header.starting_codepoint
			if char_i < 0 || int(char_i) > len(w.chars) {
				fmt.printf("out of range '%v'(%d)\n", char, i32(char))
				// render space...
				x += 15
				continue
			}

			// xoff/yoff are the offset it pixel space from the glyph origin to the top-left of the bitmap

			ch: text.Char = w.chars[char_i]
			px := x + ch.xoff
			py := y + f32(w.header.px) + ch.yoff
			pos_data[i + 0] = {px, py + ch.h}
			pos_data[i + 1] = {px, py}
			pos_data[i + 2] = {px + ch.w, py}
			pos_data[i + 3] = {px + ch.w, py + ch.h}
			x += ch.advance_width
			x += f32(w.header.kern)
			// x += ch.left_side_bearing
			// x = cast(f32)math.round(x)
			if char == rune(' ') {
				fmt.println("kern:", w.header.kern)
				fmt.println("space:", ch)
			}

			w_mult := 1.0 / f32(w.header.atlas_w)
			h_mult := 1.0 / f32(w.header.atlas_h)
			tx := ch.x * w_mult
			ty := ch.y * h_mult
			tx2 := tx + ch.w * w_mult
			ty2 := ty + ch.h * h_mult
			tex_data[i + 0] = {tx, ty2}
			tex_data[i + 1] = {tx, ty}
			tex_data[i + 2] = {tx2, ty}
			tex_data[i + 3] = {tx2, ty2}

			ii := ch_index * 6
			indices_data[ii + 0] = u16(i) + 0
			indices_data[ii + 1] = u16(i) + 1
			indices_data[ii + 2] = u16(i) + 2
			indices_data[ii + 3] = u16(i) + 0
			indices_data[ii + 4] = u16(i) + 2
			indices_data[ii + 5] = u16(i) + 3
		}
	}
	{
		buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
		gl.BufferDataSlice(gl.ARRAY_BUFFER, pos_data, gl.STATIC_DRAW)
	}
	w.buffer_vertex_pos = buffer
	{
		buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
		gl.BufferDataSlice(gl.ARRAY_BUFFER, tex_data, gl.STATIC_DRAW)
	}
	w.buffer_vertex_tex = buffer
	{
		// indices
		buffer = gl.CreateBuffer()
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer)
		gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, indices_data, gl.STATIC_DRAW)
	}
	w.buffer_indices = buffer

	// texture
	texture: gl.Texture
	{
		texture = gl.CreateTexture()
		gl.BindTexture(gl.TEXTURE_2D, texture)
		gl.TexImage2DSlice(
			gl.TEXTURE_2D,
			0,
			gl.ALPHA,
			w.header.atlas_w,
			w.header.atlas_h,
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
			vertex_count := len(w.str) * 6
			type := gl.UNSIGNED_SHORT
			offset: rawptr
			gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
		}
	}

}

