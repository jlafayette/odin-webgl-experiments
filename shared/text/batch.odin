package text

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:wasm/WebGL"

Batch :: struct {
	color:      glm.vec3,
	atlas:      ^Atlas,
	buffers:    Buffers,
	size:       AtlasSize,
	spacing:    i32,
	shader:     TextShader,
	capacity:   uint,
	projection: glm.mat4,
	_loaded:    bool,
}

_current_batch: ^Batch

@(deferred_out = batch_end)
batch_start :: proc(
	b: ^Batch,
	size: AtlasSize,
	color: glm.vec3,
	projection: glm.mat4,
	capacity: uint,
	spacing: i32 = -1,
) -> (
	^Batch,
	bool,
) {
	ok: bool
	b.size = size
	b.color = color
	b.projection = projection
	b.capacity = capacity
	b.atlas = &g_atlases[size]
	ok = init(b.atlas, size)

	if spacing == -1 {
		b.spacing = b.atlas.h / 10
	} else {
		b.spacing = spacing
	}
	if !ok {return b, ok}

	if !b._loaded {
		// load buffers
		ok = shader_init(&b.shader)
		if !ok {return b, ok}

		pos_data := make([][2]f32, b.capacity * 4, allocator = context.temp_allocator)
		tex_data := make([][2]f32, b.capacity * 4, allocator = context.temp_allocator)
		indices_data := make([][6]u16, b.capacity, allocator = context.temp_allocator)
		b.buffers.pos = {
			size   = 2,
			type   = gl.FLOAT,
			target = gl.ARRAY_BUFFER,
			usage  = gl.STATIC_DRAW,
		}
		buffer_init(&b.buffers.pos, pos_data)

		b.buffers.tex = {
			size   = 2,
			type   = gl.FLOAT,
			target = gl.ARRAY_BUFFER,
			usage  = gl.STATIC_DRAW,
		}
		buffer_init(&b.buffers.tex, tex_data)

		b.buffers.indices = {
			usage = gl.STATIC_DRAW,
		}
		ea_buffer_init(&b.buffers.indices, indices_data)
		b.buffers._initialized = true
	}
	b.buffers.offset = 0
	_current_batch = b
	return b, ok // for batch_end
}
batch_end :: proc(b: ^Batch, ok: bool) {
	// fmt.println("running batch_end")
	if !ok {return}
	// draw everything
	shader_use(
		b.shader,
		{b.color, b.projection},
		b.buffers.pos,
		b.buffers.tex,
		b.atlas.texture_info,
	)
	b.buffers.indices.count = cast(int)b.buffers.offset * 6
	// fmt.printf("offset: %d\n", b.buffers.offset)
	// ea_buffer_draw(b.buffers.indices)
	{
		buf := b.buffers.indices
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buf.id)
		gl.DrawElements(gl.TRIANGLES, buf.count, gl.UNSIGNED_SHORT, buf.offset)

	}
	_current_batch = nil
}

_get_batch_space :: #force_inline proc(atlas: ^Atlas, spacing: i32) -> i32 {
	char_w := i32(atlas.chars[30].w)
	return char_w + spacing
}
debug :: proc(pos: [2]i32, str: string) -> (width: i32, ok: bool) {
	if _current_batch == nil {
		fmt.eprintf("current batch not set, run text.batch_start first")
		return 0, false
	}
	b := _current_batch
	width = 0

	data_len: int = 0
	for r in str {
		if r < '!' || r > '~' {
			continue
		}
		data_len += 1
	}
	pos_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	tex_data := make([][2]f32, data_len * 4, allocator = context.temp_allocator)
	indices_data := make([][6]u16, data_len, allocator = context.temp_allocator)

	x: i32 = pos.x
	y: i32 = pos.y
	char_h: i32 = b.atlas.h

	data_i: int = 0
	for rune_ in str {
		if rune_ == ' ' {
			x += _get_batch_space(b.atlas, b.spacing)
			continue
		}
		if rune_ < '!' || rune_ > '~' {
			fmt.printf("out of range '%v'\n", rune_)
		}
		char_i: i32 = i32(rune_) - 33
		ch: Char = b.atlas.chars[char_i]
		char_w := i32(ch.w)

		px := f32(x)
		py := f32(y)
		i := data_i * 4
		pos_data[i + 0] = {px, py + f32(char_h)}
		pos_data[i + 1] = {px, py}
		pos_data[i + 2] = {px + f32(char_w), py}
		pos_data[i + 3] = {px + f32(char_w), py + f32(char_h)}
		x += char_w + b.spacing

		w_mult := 1.0 / f32(b.atlas.w)
		tx := f32(ch.x) * w_mult
		ty: f32 = 0
		tx2 := tx + f32(ch.w) * w_mult
		ty2: f32 = 1
		i = data_i * 4
		tex_data[i + 0] = {tx, ty2}
		tex_data[i + 1] = {tx, ty}
		tex_data[i + 2] = {tx2, ty}
		tex_data[i + 3] = {tx2, ty2}

		ii := data_i
		i_off := u16(b.buffers.offset * 4)
		indices_data[ii][0] = i_off + u16(i) + 0
		indices_data[ii][1] = i_off + u16(i) + 1
		indices_data[ii][2] = i_off + u16(i) + 2
		indices_data[ii][3] = i_off + u16(i) + 0
		indices_data[ii][4] = i_off + u16(i) + 2
		indices_data[ii][5] = i_off + u16(i) + 3

		data_i += 1
		if data_i > data_len {
			fmt.printf("error, %d is longer than data len allocated\n", data_i)
			break
		}
	}
	width = x
	if data_i != data_len {
		fmt.eprintf("%d != %d\n", data_i, data_len)
		return width, false
	}
	{
		buffer: Buffer = b.buffers.pos
		gl.BindBuffer(buffer.target, buffer.id)
		offset := b.buffers.offset * uint(buffer.size) * 4 * size_of(f32)
		gl.BufferSubDataSlice(buffer.target, cast(uintptr)offset, pos_data)
	}
	{
		buffer: Buffer = b.buffers.tex
		gl.BindBuffer(buffer.target, buffer.id)
		offset := b.buffers.offset * uint(buffer.size) * 4 * size_of(f32)
		gl.BufferSubDataSlice(buffer.target, cast(uintptr)offset, tex_data)
	}
	{
		buffer: EaBuffer = b.buffers.indices
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer.id)
		offset := b.buffers.offset * 6 * size_of(u16)
		gl.BufferSubDataSlice(gl.ELEMENT_ARRAY_BUFFER, cast(uintptr)offset, indices_data)
	}
	b.buffers.offset += uint(data_len)

	return width, check_gl_error()
}

