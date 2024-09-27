package text2

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

// Run assets/smallest_atlas/t.odin script first
atlas_20_data := #load("../../assets/smallest_atlas/data-20.jatlas")
atlas_30_data := #load("../../assets/smallest_atlas/data-30.jatlas")
atlas_40_data := #load("../../assets/smallest_atlas/data-40.jatlas")
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

Writer :: struct(N: uint) {
	buf:               [N]u8,
	next_buf_i:        int,
	str:               string,
	xpos:              i32,
	ypos:              i32,
	program_info:      TextProgramInfo,
	texture:           gl.Texture,
	buffer_vertex_pos: gl.Buffer,
	buffer_vertex_tex: gl.Buffer,
	buffer_indices:    gl.Buffer,
	header:            Header,
	chars:             [dynamic]Char,
	dyn:               bool,
	buffered:          bool,
	wrap:              bool,
}
writer_init :: proc(
	w: ^Writer($N),
	size: i32,
	xpos: i32,
	ypos: i32,
	str: string,
	dyn: bool,
	canvas_w: i32,
	wrap: bool,
) -> (
	ok: bool,
) {
	atlas_data: []byte
	switch size {
	case 20:
		atlas_data = atlas_20_data
	case 30:
		atlas_data = atlas_30_data
	case 40:
		atlas_data = atlas_40_data
	case:
		{
			fmt.eprintf("Invalid font size: %d\n", size)
			return false
		}
	}
	// w.str = "Hello WOdinlingssss!"
	w.str = str
	w.dyn = dyn
	w.wrap = wrap
	w.xpos = xpos
	w.ypos = ypos
	pixels: [dynamic][1]u8
	w.header, w.chars, pixels, ok = decode(atlas_data, 1)
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

	for i := 0; i < len(w.str); i += 1 {
		writer_add_char(w, w.str[i])
	}

	// buffers
	buffer: gl.Buffer
	pos_data := make([][2]f32, len(w.buf) * 4, allocator = context.temp_allocator)
	tex_data := make([][2]f32, len(w.buf) * 4, allocator = context.temp_allocator)
	indices_data := make([]u16, len(w.buf) * 6, allocator = context.temp_allocator)
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
	writer_update_buffer_data(w, canvas_w)

	fmt.println("size:", w.header.w * w.header.h, "pixels_size:", len(pixels[:]))

	// texture
	texture: gl.Texture
	{
		alignment: i32 = 1
		gl.PixelStorei(gl.UNPACK_ALIGNMENT, alignment)
		texture = gl.CreateTexture()
		gl.BindTexture(gl.TEXTURE_2D, texture)
		gl.TexImage2DSlice(
			gl.TEXTURE_2D,
			0,
			gl.ALPHA,
			w.header.w,
			w.header.h,
			0,
			gl.ALPHA,
			gl.UNSIGNED_BYTE,
			pixels[:],
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

	// if w.dyn {
	// 	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	// }
	return ok
}
writer_destroy :: proc(w: ^Writer($N)) {

}
writer_update_buffer_data :: proc(w: ^Writer($N), canvas_w: i32) {
	data_len := w.next_buf_i
	if data_len < 1 {
		return
	}
	pos_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	tex_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	indices_data := make([]u16, data_len * 6, allocator = context.temp_allocator)
	x: f32 = f32(w.xpos)
	y: f32 = f32(w.ypos)
	char_h := f32(w.header.h)
	line_gap := f32(w.header.h) / 2
	for ch_index := 0; ch_index < data_len; ch_index += 1 {
		i := ch_index * 4
		char := w.buf[ch_index]
		char_i := i32(char) - 33
		if char_i < 0 || int(char_i) > len(w.chars) {
			// fmt.printf("out of range '%v'(%d)\n", rune(char), i32(char))
			// render space...
			x += 8
			continue
		}
		ch: Char = w.chars[char_i]

		// wrap to new line if needed
		spacing := f32(w.header.h / 10)
		if w.wrap {
			next_w: f32 = f32(ch.w) + spacing
			line_gap: f32 = f32(w.header.h) / 2
			if x + next_w >= f32(canvas_w) {
				x = f32(w.xpos)
				y += f32(w.header.h)
			}
		}

		px := x
		py := y
		pos_data[i + 0] = {px, py + char_h}
		pos_data[i + 1] = {px, py}
		pos_data[i + 2] = {px + f32(ch.w), py}
		pos_data[i + 3] = {px + f32(ch.w), py + char_h}
		x += f32(ch.w) + spacing

		// x += ch.left_side_bearing
		// x = cast(f32)math.round(x)
		// if char == ' ' {
		// 	fmt.println("space:", ch)
		// }

		w_mult := 1.0 / f32(w.header.w)
		h_mult := 1.0 / f32(w.header.h)
		tx := f32(ch.x) * w_mult
		ty: f32 = 0
		tx2 := tx + f32(ch.w) * w_mult
		ty2: f32 = 1
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
	buffer: gl.Buffer
	{
		buffer = w.buffer_vertex_pos
		gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
		gl.BufferSubDataSlice(gl.ARRAY_BUFFER, 0, pos_data)
	}
	{
		buffer = w.buffer_vertex_tex
		gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
		gl.BufferSubDataSlice(gl.ARRAY_BUFFER, 0, tex_data)
	}
	{
		buffer = w.buffer_indices
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer)
		gl.BufferSubDataSlice(gl.ELEMENT_ARRAY_BUFFER, 0, indices_data)
	}
	w.buffered = true
}
writer_draw :: proc(w: ^Writer($N), canvas_w: i32, canvas_h: i32, color: glm.vec3) {
	if !w.buffered {
		writer_update_buffer_data(w, canvas_w)
	}
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
		projection_mat := glm.mat4Ortho3d(0, f32(canvas_w), f32(canvas_h), 0, -1, 1)
		gl.UniformMatrix4fv(uniform_locations.projection, projection_mat)
		gl.Uniform3fv(uniform_locations.text_color, color)
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, w.texture)
		gl.Uniform1i(uniform_locations.sampler, 0)
		{
			vertex_count := w.next_buf_i * 6
			type := gl.UNSIGNED_SHORT
			offset: rawptr
			gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
		}
	}
}
writer_add_char :: proc(w: ^Writer($N), char: u8) {
	if w.next_buf_i >= len(w.buf) {
		return
	}
	w.buf[w.next_buf_i] = char
	w.next_buf_i += 1
	w.buffered = false
}
writer_backspace :: proc(w: ^Writer($N)) {
	if w.next_buf_i == 0 {
		return
	}
	w.next_buf_i -= 1
	w.buffered = false
}

check_gl_error :: proc() -> (ok: bool) {
	err := gl.GetError()
	if err != gl.NO_ERROR {
		fmt.eprintln("WebGL error:", err)
		return false
	}
	return true
}

