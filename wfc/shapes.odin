package wfc

import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"


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
buffer_update :: proc(b: Buffer, data: []$T) {
	gl.BindBuffer(b.target, b.id)
	gl.BufferSubDataSlice(b.target, 0, data[:])
}
ea_buffer_init :: proc(b: ^EaBuffer, data: []$T) {
	b.count = (len(data) * size_of(T)) / 2 // 2 is size of unsigned_short (u16)
	// fmt.println("b.count:", b.count)
	b.offset = nil
	b.id = gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], b.usage)
}
ea_buffer_draw :: proc(b: EaBuffer, instance_count: int = 0) {
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
	if instance_count > 0 {
		// fmt.printf("drawing b.count %d, instance_count: %d\n", b.count, instance_count)
		gl.DrawElementsInstanced(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, 0, instance_count)
	} else {
		gl.DrawElements(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, b.offset)
	}
}
Buffers :: struct {
	pos:            Buffer,
	indices:        EaBuffer,
	colors:         Buffer,
	tile_infos:     Buffer,
	model_matrices: Buffer,
}
buffers_init :: proc(buffers: ^Buffers) {
	pos_data: [4][2]f32 = {{-0.5, -0.5}, {-0.5, 0.5}, {0.5, 0.5}, {0.5, -0.5}}
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

	colors := make([]glm.vec4, N_INSTANCE, allocator = context.temp_allocator)
	buffers.colors = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.colors, colors[:])

	tile_infos := make([]glm.vec4, N_INSTANCE, allocator = context.temp_allocator)
	buffers.tile_infos = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.tile_infos, tile_infos[:])

	model_matrices := make([]glm.mat4, N_INSTANCE, allocator = context.temp_allocator)
	buffers.model_matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.DYNAMIC_DRAW,
	}
	buffer_init(&buffers.model_matrices, model_matrices[:])
}

flat_vert_source := #load("flat.vert", string)
flat_frag_source := #load("flat.frag", string)
FlatShader :: struct {
	program:                  gl.Program,
	a_pos:                    i32,
	a_color:                  i32,
	a_tile_info:              i32,
	a_model_matrix:           i32,
	u_view_projection_matrix: i32,
	u_sampler:                i32,
}
FlatUniforms :: struct {
	view_projection_matrix: glm.mat4,
}
flat_shader_init :: proc(s: ^FlatShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({flat_vert_source}, {flat_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program
	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_color = gl.GetAttribLocation(program, "aColor")
	s.a_tile_info = gl.GetAttribLocation(program, "aTileInfo")
	s.a_model_matrix = gl.GetAttribLocation(program, "aModelMatrix")
	s.u_view_projection_matrix = gl.GetUniformLocation(program, "uViewProjectionMatrix")
	s.u_sampler = gl.GetUniformLocation(program, "uSampler")
	return check_gl_error()
}
flat_shader_use :: proc(s: FlatShader, u: FlatUniforms, buffers: Buffers, texture: TextureInfo) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffers.pos)

	shader_set_instance_vec4_attribute(s.a_color, buffers.colors)
	shader_set_instance_vec4_attribute(s.a_tile_info, buffers.tile_infos)
	shader_set_instance_matrix_attribute(s.a_model_matrix, buffers.model_matrices)

	// set uniforms
	gl.UniformMatrix4fv(s.u_view_projection_matrix, u.view_projection_matrix)

	// set texture
	gl.ActiveTexture(texture.unit)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.Uniform1i(s.u_sampler, 0)
}
shader_set_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.VertexAttribPointer(index, b.size, b.type, false, 0, 0)
	gl.EnableVertexAttribArray(index)
}
shader_set_instance_f_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.EnableVertexAttribArray(index)
	stride := size_of(f32)
	gl.VertexAttribPointer(index, b.size, b.type, false, stride, 0)
	gl.VertexAttribDivisor(u32(index), 1)
}
shader_set_instance_vec4_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	gl.EnableVertexAttribArray(index)
	size := size_of(glm.vec4)
	gl.VertexAttribPointer(index, b.size, b.type, false, size, 0)
	gl.VertexAttribDivisor(u32(index), 1)
}
shader_set_instance_matrix_attribute :: proc(index: i32, b: Buffer) {
	gl.BindBuffer(b.target, b.id)
	matrix_size := size_of(glm.mat4)
	for i in 0 ..< 4 {
		loc: i32 = i32(index) + i32(i)
		gl.EnableVertexAttribArray(loc)
		offset: uintptr = uintptr(i) * 16
		gl.VertexAttribPointer(loc, b.size, b.type, false, matrix_size, offset)
		gl.VertexAttribDivisor(u32(loc), 1)
	}
}

Rectangle :: struct {
	pos:      [2]i32,
	size:     [2]i32,
	rotation: f32,
	color:    [4]f32,
	tile:     Tile,
}
Line :: struct {
	start:     [2]i32,
	end:       [2]i32,
	thickness: i32,
	color:     [4]f32,
}

N_RECTANGES :: 8000
N_LINES :: 64
N_INSTANCE :: N_RECTANGES + N_LINES

Shapes :: struct {
	rectangle_count: int,
	line_count:      int,
	rectangles:      [N_RECTANGES]Rectangle,
	lines:           [N_LINES]Line,
	buffers:         Buffers,
	shader:          FlatShader,
	texture_info:    TextureInfo,
}

shapes_init :: proc(s: ^Shapes, w, h: i32) -> (ok: bool) {
	ok = flat_shader_init(&s.shader)
	if !ok {return false}

	buffers_init(&s.buffers)
	ok = texture_init(&s.texture_info)
	if !ok {return false}

	return ok
}

clear_rectangles :: proc(s: ^Shapes) {
	s.rectangle_count = 0
}
add_rectangle :: proc(s: ^Shapes, r: Rectangle) {
	if s.rectangle_count >= N_RECTANGES {
		return
	}
	s.rectangles[s.rectangle_count] = r
	s.rectangle_count += 1
}
add_line :: proc(s: ^Shapes, l: Line) {
	if s.line_count >= N_LINES {
		return
	}
	s.lines[s.line_count] = l
	s.line_count += 1
}

shapes_update :: proc(s: ^Shapes, w, h: i32, dt: f32, time_elapsed: f64) {
}

line_angle :: proc(line: Line) -> f32 {
	line_diff_i32: [2]i32 = line.end - line.start
	line_diff: [2]f32 = {f32(line_diff_i32.x), f32(line_diff_i32.y)}
	angle := math.atan2(line_diff.y, line_diff.x)
	return angle
}
line_to_matrix :: proc(line: Line, rotation: f32 = 0) -> glm.mat4 {
	line_diff_i32: [2]i32 = line.end - line.start
	line_diff: [2]f32 = {f32(line_diff_i32.x), f32(line_diff_i32.y)}
	angle := math.atan2(line_diff.y, line_diff.x)
	x_scale := glm.length(line_diff)
	y_scale := f32(line.thickness)
	m := glm.mat4Translate({f32(line.start.x), f32(line.start.y), -1.0})
	m *= glm.mat4Rotate({0, 0, 1}, angle + rotation)
	m *= glm.mat4Scale({x_scale, y_scale, 1.0})
	m *= glm.mat4Translate({0.5, 0, 0})
	return m
}
rect_to_matrix :: proc(rect: Rectangle) -> glm.mat4 {
	m := glm.mat4Translate({f32(rect.pos.x), f32(rect.pos.y), -1.0})
	m *= glm.mat4Rotate({0, 0, 1}, rect.rotation)
	m *= glm.mat4Scale({f32(rect.size.x), f32(rect.size.y), 1.0})
	return m
}

shapes_draw :: proc(g: ^Game, s: ^Shapes, projection_matrix: glm.mat4) {
	rect_matrices := make([]glm.mat4, N_INSTANCE, allocator = context.temp_allocator)
	colors := make([]glm.vec4, N_INSTANCE, allocator = context.temp_allocator)
	tile_infos := make([]glm.vec4, N_INSTANCE, allocator = context.temp_allocator)

	clear_rectangles(s)
	for yi in 0 ..< g.grid.col_count {
		for xi in 0 ..< g.grid.row_count {
			square, ok := grid_get(&g.grid, xi, yi).?
			if !ok {
				fmt.printf("error, no square at %d,%d\n", xi, yi)
				continue
			}
			c: glm.vec4 = {0.5, 0.2, 0.5, 1.0}
			x: i32 = i32(xi) * TILE_SIZE + TILE_SIZE / 2
			y: i32 = i32(yi) * TILE_SIZE + TILE_SIZE / 2
			size: [2]i32 = {TILE_SIZE, TILE_SIZE}
			if square.collapsed {
				c.g = 1.0
				c.r = 0.2
			} else {
				c.r = 1 - (f32(len(square.options)) / OPTIONS_COUNT)
			}
			add_rectangle(s, Rectangle{{x, y}, size, 0, c, .CORNER})
		}
	}

	mi: int = 0
	for rect, i in s.rectangles {
		if i < s.rectangle_count {
			m := rect_to_matrix(rect)
			rect_matrices[mi] = m
			colors[mi] = rect.color
			tile_infos[mi] = {0, 0, 0.2, 1.0}
			mi += 1
		} else {
			break
		}
	}
	for l, i in s.lines {
		if i < s.line_count {
			m := line_to_matrix(l)
			rect_matrices[mi] = m
			colors[mi] = l.color
			tile_infos[mi] = {0, 0, 1, 1}
			mi += 1
		} else {
			break
		}
	}

	instance_count: int = s.rectangle_count + s.line_count
	buffer_update(s.buffers.colors, colors[:instance_count])
	buffer_update(s.buffers.tile_infos, tile_infos[:instance_count])
	buffer_update(s.buffers.model_matrices, rect_matrices[:instance_count])
	uniforms: FlatUniforms = {projection_matrix}
	flat_shader_use(s.shader, uniforms, s.buffers, s.texture_info)

	ea_buffer_draw(s.buffers.indices, instance_count = instance_count)

	gl.VertexAttribDivisor(1, 0)
	gl.VertexAttribDivisor(2, 0)
	gl.VertexAttribDivisor(3, 0)
	gl.VertexAttribDivisor(4, 0)
}

