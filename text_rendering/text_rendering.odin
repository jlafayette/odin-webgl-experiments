package text_rendering

import "../shared/text"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

atlas_pixel_data := #load("../atlas_pixel_data_24")
atlas_data := #load("../atlas_data_24")
vert_source := #load("text.vert", string)
frag_source := #load("text.frag", string)
vert_tri_source := #load("tri.vert", string)
frag_tri_source := #load("tri.frag", string)

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
TextBuffers :: struct {
	vertex_pos: gl.Buffer,
	vertex_tex: gl.Buffer,
	indices:    gl.Buffer,
}
TextState :: struct {
	program_info: TextProgramInfo,
	buffers:      TextBuffers,
	texture:      gl.Texture,
}

TriProgramInfo :: struct {
	program:           gl.Program,
	attrib_locations:  TriAttribLocations,
	uniform_locations: TriUniformLocations,
}
TriAttribLocations :: struct {
	pos:   i32,
	color: i32,
}
TriUniformLocations :: struct {
	projection: i32,
}
TriBuffers :: struct {
	pos:     gl.Buffer,
	color:   gl.Buffer,
	indices: gl.Buffer,
}
TriState :: struct {
	program_info: TriProgramInfo,
	buffers:      TriBuffers,
	texture:      gl.Texture,
}

State :: struct {
	started: bool,
	text:    TextState,
	tri:     TriState,
}
g_state: State = {}

W :: 640
H :: 480

temp_arena_buffer: [mem.Megabyte * 4]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

start :: proc() -> (ok: bool) {
	g_state.started = true

	if ok = gl.CreateCurrentContextById("canvas-1", {.stencil}); !ok {
		return
	}
	{
		es_major, es_minor: i32
		gl.GetESVersion(&es_major, &es_minor)
		fmt.println("es version:", es_major, es_minor)
	}

	{
		program: gl.Program
		program, ok = gl.CreateProgramFromStrings({vert_source}, {frag_source})
		if !ok {
			fmt.eprintln("Failed to create program")
			return
		}

		// buffers
		text_buffers: TextBuffers
		{
			buffer := gl.CreateBuffer()
			gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
			// just render a square for now
			x: f32 = 10
			y: f32 = 10
			w: f32 = 256
			h: f32 = 256
			pos_data: [4][2]f32
			pos_data[0] = {x, y + h}
			pos_data[1] = {x, y}
			pos_data[2] = {x + w, y}
			pos_data[3] = {x + w, y + h}
			gl.BufferDataSlice(gl.ARRAY_BUFFER, pos_data[:], gl.STATIC_DRAW)
			text_buffers.vertex_pos = buffer
		}
		{
			buffer := gl.CreateBuffer()
			gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
			tex_data: [4][2]f32 = {{0, 1}, {0, 0}, {1, 0}, {1, 1}}
			gl.BufferDataSlice(gl.ARRAY_BUFFER, tex_data[:], gl.STATIC_DRAW)
			text_buffers.vertex_tex = buffer
		}
		{
			// indices
			buffer := gl.CreateBuffer()
			gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer)
			data: [6]u16 = {0, 1, 2, 0, 2, 3}
			gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
			text_buffers.indices = buffer
		}

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

		g_state.text.program_info = {
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
		g_state.text.buffers = text_buffers
		g_state.text.texture = texture
		gl.UseProgram(program)
		ok = check_gl_error()
		if !ok {return}
	}
	// Tri shader and buffers
	{

		program: gl.Program
		program, ok = gl.CreateProgramFromStrings({vert_tri_source}, {frag_tri_source})
		if !ok {
			fmt.eprintln("Failed to create program")
			return
		}
		// buffers
		buffers: TriBuffers
		{
			// position
			buffer := gl.CreateBuffer()
			gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
			// just render a square for now
			x: f32 = 5
			y: f32 = 5
			w: f32 = W - 10
			h: f32 = H - 10
			pos_data: [4][2]f32
			pos_data[0] = {x, y + h} // 0
			pos_data[1] = {x, y}
			pos_data[2] = {x + w, y}
			pos_data[3] = {x + w, y + h}
			gl.BufferDataSlice(gl.ARRAY_BUFFER, pos_data[:], gl.STATIC_DRAW)
			buffers.pos = buffer
		}
		{
			// color
			buffer := gl.CreateBuffer()
			gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
			w: [3]f32 = {1, 1, 1}
			r: [3]f32 = {1, 0, 0}
			g: [3]f32 = {0, 1, 0}
			b: [3]f32 = {0, 0, 1}
			data: [4][3]f32 = {r, r, b, b}
			gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
			buffers.color = buffer
		}
		{
			// indices
			buffer := gl.CreateBuffer()
			gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer)
			data: [6]u16 = {0, 1, 2, 0, 2, 3}
			gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
			buffers.indices = buffer
		}
		g_state.tri.program_info = {
			program = program,
			attrib_locations = {
				pos = gl.GetAttribLocation(program, "aPos"),
				color = gl.GetAttribLocation(program, "aColor"),
			},
			uniform_locations = {projection = gl.GetUniformLocation(program, "uProjection")},
		}
		g_state.tri.buffers = buffers
	}

	ok = check_gl_error()
	return
}

draw :: proc(dt: f32) {

	gl.ClearColor(0.1, 0.2, 0.2, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	// draw tris
	{
		buffers := g_state.tri.buffers
		program_info := g_state.tri.program_info
		attrib_locations := program_info.attrib_locations
		{
			gl.BindBuffer(gl.ARRAY_BUFFER, buffers.pos)
			gl.VertexAttribPointer(attrib_locations.pos, 2, gl.FLOAT, false, 0, 0)
			gl.EnableVertexAttribArray(attrib_locations.pos)
		}
		{
			gl.BindBuffer(gl.ARRAY_BUFFER, buffers.color)
			gl.VertexAttribPointer(attrib_locations.color, 3, gl.FLOAT, false, 0, 0)
			gl.EnableVertexAttribArray(attrib_locations.color)
		}
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffers.indices)
		gl.UseProgram(program_info.program)
		// set uniforms
		uniform_locations := program_info.uniform_locations
		projection_mat := glm.mat4Ortho3d(0, W, H, 0, -1, 1)

		gl.UniformMatrix4fv(uniform_locations.projection, projection_mat)
		{
			vertex_count := 6
			type := gl.UNSIGNED_SHORT
			offset: rawptr
			gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
		}
	}

	// draw text
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	{
		buffers := g_state.text.buffers
		program_info := g_state.text.program_info
		attrib_locations := program_info.attrib_locations
		{
			gl.BindBuffer(gl.ARRAY_BUFFER, buffers.vertex_pos)
			gl.VertexAttribPointer(attrib_locations.pos, 2, gl.FLOAT, false, 0, 0)
			gl.EnableVertexAttribArray(attrib_locations.pos)
		}
		{
			gl.BindBuffer(gl.ARRAY_BUFFER, buffers.vertex_tex)
			gl.VertexAttribPointer(attrib_locations.tex, 2, gl.FLOAT, false, 0, 0)
			gl.EnableVertexAttribArray(attrib_locations.tex)
		}
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffers.indices)
		gl.UseProgram(program_info.program)
		// set uniforms
		uniform_locations := program_info.uniform_locations
		// bottom left (0, 0)
		// projection_mat := glm.mat4Ortho3d(0, W, 0, H, -1, 1)
		// top left (0, 0)
		projection_mat := glm.mat4Ortho3d(0, W, H, 0, -1, 1)
		gl.UniformMatrix4fv(uniform_locations.projection, projection_mat)
		gl.Uniform3fv(uniform_locations.text_color, {0, 1, 1})
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, g_state.text.texture)
		gl.Uniform1i(uniform_locations.sampler, 0)
		{
			vertex_count := 6
			type := gl.UNSIGNED_SHORT
			offset: rawptr
			gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
		}
	}
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	if !g_state.started {
		if keep_going = start(); !keep_going {return}
	}

	draw(dt)

	keep_going = check_gl_error()
	return
}

// --- utils

check_gl_error :: proc() -> (ok: bool) {
	err := gl.GetError()
	if err != gl.NO_ERROR {
		fmt.eprintln("WebGL error:", err)
		return false
	}
	return true
}

