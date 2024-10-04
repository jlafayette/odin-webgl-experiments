package text

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

Buffers :: struct {
	pos:          Buffer,
	tex:          Buffer,
	indices:      EaBuffer,
	_initialized: bool,
}
Buffer :: struct {
	id:     gl.Buffer,
	size:   int, // 3
	type:   gl.Enum, // gl.FLOAT
	target: gl.Enum, // gl.ARRAY_BUFFER
	usage:  gl.Enum, // gl.STATIC_DRAW
}
EaBuffer :: struct {
	id:     gl.Buffer,
	// size:   int, // 1 (assumed)
	count:  int, // (len(data) * size_of(data[0])) / 2
	// type:   gl.Enum, // gl.UNSIGNED_SHORT (assumed)
	// target: gl.Enum, // gl.ELEMENT_ARRAY_BUFFER (assumed)
	usage:  gl.Enum, // gl.STATIC_DRAW
	offset: rawptr,
}
buffer_init :: proc(b: ^Buffer, data: []$T) {
	b.id = gl.CreateBuffer()
	gl.BindBuffer(b.target, b.id)
	gl.BufferDataSlice(b.target, data[:], b.usage)
}
ea_buffer_init :: proc(b: ^EaBuffer, data: []$T) {
	b.count = (len(data) * size_of(T)) / 2 // 2 is size of unsigned_short (u16)
	b.offset = nil
	b.id = gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], b.usage)
}
ea_buffer_draw :: proc(b: EaBuffer, instance_count: int = 0) {
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	if instance_count > 0 {
		gl.DrawElementsInstanced(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, 0, instance_count)
	} else {
		gl.DrawElements(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, b.offset)
	}
}


Writer :: struct {
	buf:            []u8,
	next_buf_i:     int,
	str:            string,
	pos:            [2]i32,
	atlas:          ^Atlas,
	dyn:            bool,
	buffered:       bool,
	wrap:           bool,
	buffers:        Buffers,
	overall_height: i32,
	size:           AtlasSize,
	spacing:        i32,
	shader:         TextShader,
}
writer_init :: proc(
	w: ^Writer,
	buf_size: uint,
	atlas_size: AtlasSize,
	pos: [2]i32,
	str: string,
	canvas_w: i32,
	spacing: i32 = -1,
	dyn: bool = false,
	wrap: bool = false,
) -> (
	ok: bool,
) {
	// w.str = "Hello WOdinlingssss!"
	w.buf = make([]u8, buf_size)
	writer_set_size(w, atlas_size)
	w.dyn = dyn
	w.wrap = wrap
	w.pos = pos
	if spacing == -1 {
		w.spacing = w.atlas.h / 10
	} else {
		w.spacing = spacing
	}
	writer_set_text(w, str)

	writer_update_buffer_data(w, canvas_w)

	shader_init(&w.shader) or_return

	return true
}
writer_destroy :: proc(w: ^Writer) {
	delete(w.buf)
}
writer_set_size :: proc(w: ^Writer, atlas_size: AtlasSize, spacing: i32 = -1) {
	w.atlas = &g_atlases[atlas_size]
	init(w.atlas, atlas_size)
	if spacing == -1 {
		w.spacing = w.atlas.h / 10
	} else {
		w.spacing = spacing
	}
	w.size = atlas_size
	w.buffered = false
}
_get_space :: #force_inline proc(w: ^Writer) -> i32 {
	char_w := i32(w.atlas.chars[30].w)
	return char_w + w.spacing
}
writer_get_size :: proc(w: ^Writer, canvas_w: i32) -> [2]i32 {
	x: i32 = 0
	y: i32 = 0
	char_h := w.atlas.h
	line_gap := char_h / 3
	for ch_index := 0; ch_index < w.next_buf_i; ch_index += 1 {
		i := ch_index * 4
		char := w.buf[ch_index]
		char_i := i32(char) - 33
		if char_i < 0 || int(char_i) > len(w.atlas.chars) {
			if rune(char) == ' ' {
				x += _get_space(w)
			} else if rune(char) == '\n' {
				x = 0
				y += char_h + line_gap
			} else {
				fmt.printf("out of range '%v'(%d)\n", rune(char), i32(char))
			}
			continue
		}
		ch: Char = w.atlas.chars[char_i]
		// wrap to new line if needed
		char_w := i32(ch.w)
		if w.wrap {
			next_w := char_w + w.spacing
			if x + next_w >= canvas_w {
				x = 0
				y += char_h + line_gap
			}
		}
		x += char_w + w.spacing
	}
	return {x, y + char_h}
}
writer_update_buffer_data :: proc(w: ^Writer, canvas_w: i32) {

	w.overall_height = 0
	data_len := len(w.buf)
	if data_len < 1 {
		return
	}

	pos_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	tex_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	indices_data := make([][6]u16, data_len, allocator = context.temp_allocator)
	x: i32 = w.pos.x
	y: i32 = w.pos.y
	char_h: i32 = w.atlas.h
	line_gap: i32 = char_h / 3
	for ch_index := 0; ch_index < w.next_buf_i; ch_index += 1 {
		i := ch_index * 4
		char := w.buf[ch_index]
		char_i := i32(char) - 33
		// fmt.printf("ch_index: %d, i: %d, char:%v, char_i:%d\n", ch_index, i, char, char_i)
		line_gap: i32 = w.atlas.h / 3
		if char_i < 0 || int(char_i) > len(w.atlas.chars) {
			if rune(char) == ' ' {
				x += _get_space(w)
			} else if rune(char) == '\n' {
				x = w.pos.x
				y += char_h + line_gap
			} else {
				fmt.printf("out of range '%v'(%d)\n", rune(char), i32(char))
			}
			continue
		}
		ch: Char = w.atlas.chars[char_i]
		// wrap to new line if needed
		char_w := i32(ch.w)
		if w.wrap {
			next_w: i32 = char_w + w.spacing
			if x + next_w >= canvas_w {
				x = w.pos.x
				y += char_h + line_gap
			}
		}

		px := f32(x)
		py := f32(y)
		pos_data[i + 0] = {px, py + f32(char_h)}
		pos_data[i + 1] = {px, py}
		pos_data[i + 2] = {px + f32(char_w), py}
		pos_data[i + 3] = {px + f32(char_w), py + f32(char_h)}
		x += char_w + w.spacing

		w_mult := 1.0 / f32(w.atlas.w)
		tx := f32(ch.x) * w_mult
		ty: f32 = 0
		tx2 := tx + f32(ch.w) * w_mult
		ty2: f32 = 1
		tex_data[i + 0] = {tx, ty2}
		tex_data[i + 1] = {tx, ty}
		tex_data[i + 2] = {tx2, ty}
		tex_data[i + 3] = {tx2, ty2}

		ii := ch_index
		indices_data[ii][0] = u16(i) + 0
		indices_data[ii][1] = u16(i) + 1
		indices_data[ii][2] = u16(i) + 2
		indices_data[ii][3] = u16(i) + 0
		indices_data[ii][4] = u16(i) + 2
		indices_data[ii][5] = u16(i) + 3
	}
	w.overall_height = i32(y + char_h - w.pos.y)
	if w.buffers._initialized {
		{
			buffer: Buffer = w.buffers.pos
			gl.BindBuffer(buffer.target, buffer.id)
			gl.BufferSubDataSlice(buffer.target, 0, pos_data)
		}
		{
			buffer: Buffer = w.buffers.tex
			gl.BindBuffer(buffer.target, buffer.id)
			gl.BufferSubDataSlice(buffer.target, 0, tex_data)
		}
		{
			buffer: EaBuffer = w.buffers.indices
			gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer.id)
			gl.BufferSubDataSlice(gl.ELEMENT_ARRAY_BUFFER, 0, indices_data)
		}
	} else {
		w.buffers.pos = {
			size   = 2,
			type   = gl.FLOAT,
			target = gl.ARRAY_BUFFER,
			usage  = gl.STATIC_DRAW,
		}
		buffer_init(&w.buffers.pos, pos_data)

		w.buffers.tex = {
			size   = 2,
			type   = gl.FLOAT,
			target = gl.ARRAY_BUFFER,
			usage  = gl.STATIC_DRAW,
		}
		buffer_init(&w.buffers.tex, tex_data)

		w.buffers.indices = {
			usage = gl.STATIC_DRAW,
		}
		ea_buffer_init(&w.buffers.indices, indices_data)
		w.buffers._initialized = true
	}
	w.buffered = true
}
writer_draw :: proc(
	w: ^Writer,
	projection: glm.mat4,
	color: glm.vec3,
	canvas_w: i32,
) -> (
	ok: bool,
) {
	if !w.buffered {
		writer_update_buffer_data(w, canvas_w)
	}
	// fmt.println(w.buffers)
	uniforms: Uniforms = {color, projection}
	shader_use(w.shader, uniforms, w.buffers.pos, w.buffers.tex, w.atlas.texture_info)
	ea_buffer_draw(w.buffers.indices)
	return check_gl_error()
}
writer_set_text :: proc(w: ^Writer, str: string) {
	w.str = str
	w.next_buf_i = 0
	for i := 0; i < len(w.str); i += 1 {
		writer_add_char(w, w.str[i])
	}
}
writer_set_pos :: proc(w: ^Writer, pos: [2]i32) {
	w.pos = pos
	w.buffered = false
}
writer_add_char :: proc(w: ^Writer, char: u8) {
	if w.next_buf_i >= len(w.buf) {
		return
	}
	w.buf[w.next_buf_i] = char
	w.next_buf_i += 1
	w.buffered = false
}
writer_backspace :: proc(w: ^Writer) {
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

