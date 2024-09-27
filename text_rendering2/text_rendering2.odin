package text_rendering

import text "../shared/text2"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

main :: proc() {}

vert_tri_source := #load("tri.vert", string)
frag_tri_source := #load("tri.frag", string)

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

WriterSet :: struct {
	w:        i32,
	h:        i32,
	writer_1: text.Writer(len(LINE1)),
	writer_2: text.Writer(len(LINE2)),
	writer_3: text.Writer(len(LINE3)),
}
init_writer_set :: proc(
	ws: ^WriterSet,
	size: i32,
	canvas_w: i32,
	pos: [2]i32,
) -> (
	y_pos: i32,
	ok: bool,
) {
	text.writer_init(&ws.writer_1, size, pos.x, pos.y, LINE1, false, canvas_w, false) or_return
	line_offset := i32(f32(ws.writer_1.header.h) * 1.2)
	text.writer_init(
		&ws.writer_2,
		size,
		pos.x,
		pos.y + line_offset,
		LINE2,
		false,
		canvas_w,
		false,
	) or_return
	text.writer_init(
		&ws.writer_3,
		size,
		pos.x,
		pos.y + line_offset * 2,
		LINE3,
		false,
		canvas_w,
		false,
	) or_return
	return pos.y + line_offset * 3, true
}
draw_writer_set :: proc(ws: ^WriterSet, w, h: i32, color: glm.vec3) {
	text.writer_draw(&ws.writer_1, w, h, color)
	text.writer_draw(&ws.writer_2, w, h, color)
	text.writer_draw(&ws.writer_3, w, h, color)
}

LINE1 :: "!\"#$%&'()*+,-./0123456789:;<=>?@"
LINE2 :: "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
LINE3 :: "abcdefghijklmnopqrstuvwxyz{|}~"
State :: struct {
	started:       bool,
	writer_20_set: WriterSet,
	writer_30_set: WriterSet,
	writer_40_set: WriterSet,
	tri:           TriState,
}
g_state: State = {}

temp_arena_buffer: [mem.Megabyte]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

arena_buffer: [mem.Megabyte * 4]byte
arena: mem.Arena = {
	data = arena_buffer[:],
}
arena_allocator := mem.arena_allocator(&arena)

start :: proc() -> (ok: bool) {
	g_state.started = true

	if ok = gl.CreateCurrentContextById("canvas-1", {.stencil}); !ok {
		return ok
	}
	{
		es_major, es_minor: i32
		gl.GetESVersion(&es_major, &es_minor)
		fmt.println("es version:", es_major, es_minor)
	}

	canvas_w: i32 = gl.DrawingBufferWidth()
	canvas_h: i32 = gl.DrawingBufferHeight()

	{
		y: i32 = 20
		y = init_writer_set(&g_state.writer_20_set, 20, canvas_w, {20, y}) or_return
		y = init_writer_set(&g_state.writer_30_set, 30, canvas_w, {20, y + 40}) or_return
		y = init_writer_set(&g_state.writer_40_set, 40, canvas_w, {20, y + 40}) or_return
	}

	// js.add_window_event_listener(.Key_Down, {}, on_key_down)

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
			w: f32 = f32(canvas_w) - 10
			h: f32 = f32(canvas_h) - 10
			pos_data: [4][2]f32
			pos_data[0] = {x, y + h}
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
			r: [3]f32 = {0.5, 0, 0}
			g: [3]f32 = {0, 1, 0}
			b: [3]f32 = {0, 0, 0.5}
			black: [3]f32 = {0.2, 0.2, 0.2}
			data: [4][3]f32 = {black, black, black, black}
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

	canvas_w: i32 = gl.DrawingBufferWidth()
	canvas_h: i32 = gl.DrawingBufferHeight()

	gl.ClearColor(0, 0, 0, 1)
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
		projection_mat := glm.mat4Ortho3d(0, f32(canvas_w), f32(canvas_h), 0, -1, 1)

		gl.UniformMatrix4fv(uniform_locations.projection, projection_mat)
		{
			vertex_count := 6
			type := gl.UNSIGNED_SHORT
			offset: rawptr
			gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
		}
	}
	color: glm.vec3 = {1, 1, 1}
	draw_writer_set(&g_state.writer_20_set, canvas_w, canvas_h, color)
	draw_writer_set(&g_state.writer_30_set, canvas_w, canvas_h, color)
	draw_writer_set(&g_state.writer_40_set, canvas_w, canvas_h, color)
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.allocator = arena_allocator
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	if !g_state.started {
		if keep_going = start(); !keep_going {return}
	}

	draw(dt)

	keep_going = check_gl_error()
	return
}

// --- input

on_key_down :: proc(e: js.Event) {
	// w := &g_state.writer3
	// if !w.dyn {
	// 	return
	// }
	// if e.key.code == "Backspace" {
	// 	fmt.println("backspace")
	// 	text.writer_backspace(w)
	// 	return
	// }
	// if len(e.key.key) != 1 {
	// 	return
	// }
	// fmt.println("code:", e.key.code, "key:", e.key.key)
	// text.writer_add_char(w, e.key.key[0])
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

