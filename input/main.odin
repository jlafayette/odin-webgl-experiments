package input

import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

vert_source := #load("rect.vert", string)
frag_source := #load("rect.frag", string)

ProgramInfo :: struct {
	program:           gl.Program,
	attrib_locations:  AttribLocations,
	uniform_locations: UniformLocations,
}
AttribLocations :: struct {
	vertex_position: i32,
	vertex_color:    i32,
}
UniformLocations :: struct {
	projection_matrix: i32,
	model_view_matrix: i32,
}
Buffers :: struct {
	position: gl.Buffer,
	color:    gl.Buffer,
}
State :: struct {
	started:      bool,
	program_info: ProgramInfo,
	buffers:      Buffers,
	input:        Input,
	rotation:     f32,
	w:            i32,
	h:            i32,
	debug_text:   text.Batch,
}
state: State = {
	input = {has_focus = true, zoom = -6},
}

arena_buffer: [mem.Megabyte]byte
arena: mem.Arena = {
	data = arena_buffer[:],
}
arena_allocator := mem.arena_allocator(&arena)

temp_arena_buffer: [mem.Megabyte]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

init_buffers :: proc() -> Buffers {
	return {position = init_position_buffer(), color = init_color_buffer()}
}
init_position_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	data: [8]f32 = {1, 1, -1, 1, 1, -1, -1, -1}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}
init_color_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	data: [16]f32 = {0.8, 0.9, 0.6, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}

start :: proc() -> (ok: bool) {
	state.started = true
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	register_event_listeners()

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}

	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vert_source}, {frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	state.program_info = {
		program = program,
		attrib_locations = {
			vertex_position = gl.GetAttribLocation(program, "aVertexPosition"),
			vertex_color = gl.GetAttribLocation(program, "aVertexColor"),
		},
		uniform_locations = {
			projection_matrix = gl.GetUniformLocation(program, "uProjectionMatrix"),
			model_view_matrix = gl.GetUniformLocation(program, "uModelViewMatrix"),
		},
	}
	gl.UseProgram(program)

	state.buffers = init_buffers()

	return check_gl_error()
}

check_gl_error :: proc() -> (ok: bool) {
	err := gl.GetError()
	if err != gl.NO_ERROR {
		fmt.eprintln("WebGL error:", err)
		return false
	}
	return true
}

set_position_attribute :: proc() {
	num_components := 2
	type := gl.FLOAT
	normalize := false
	stride := 0
	offset: uintptr = 0
	gl.BindBuffer(gl.ARRAY_BUFFER, state.buffers.position)
	gl.VertexAttribPointer(
		state.program_info.attrib_locations.vertex_position,
		num_components,
		type,
		normalize,
		stride,
		offset,
	)
	gl.EnableVertexAttribArray(state.program_info.attrib_locations.vertex_position)
}
set_color_attribute :: proc() {
	num_components := 4
	type := gl.FLOAT
	normalize := false
	stride := 0
	offset: uintptr = 0
	gl.BindBuffer(gl.ARRAY_BUFFER, state.buffers.color)
	gl.VertexAttribPointer(
		state.program_info.attrib_locations.vertex_color,
		num_components,
		type,
		normalize,
		stride,
		offset,
	)
	gl.EnableVertexAttribArray(state.program_info.attrib_locations.vertex_color)
}

draw_scene :: proc(paused: bool) {
	if paused {
		gl.ClearColor(0.5, 0.5, 0.5, 1)
	} else {
		gl.ClearColor(0, 0, 0, 1)
	}
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Viewport(0, 0, state.w, state.h)

	fov: f32 = (45.0 * math.PI) / 180.0
	aspect: f32 = f32(state.w) / f32(state.h)
	z_near: f32 = 0.1
	z_far: f32 = 100.0
	projection_mat := glm.mat4Perspective(fov, aspect, z_near, z_far)
	zoom := state.input.zoom
	pos := state.input.pos
	model_view_mat :=
		glm.mat4Translate({pos.x, pos.y, zoom}) * glm.mat4Rotate({0, 0, 1}, state.rotation)

	set_position_attribute()
	set_color_attribute()

	gl.UseProgram(state.program_info.program)
	gl.UniformMatrix4fv(state.program_info.uniform_locations.projection_matrix, projection_mat)
	gl.UniformMatrix4fv(state.program_info.uniform_locations.model_view_matrix, model_view_mat)
	{
		offset := 0
		vertex_count := 4
		gl.DrawArrays(gl.TRIANGLE_STRIP, offset, vertex_count)
	}

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	text_projection := glm.mat4Ortho3d(0, f32(state.w), f32(state.h), 0, -1, 1)
	{
		text.batch_start(&state.debug_text, .A16, {1, 1, 1}, text_projection, 128, spacing = 2)
		text_0: string
		text_1: string
		text_2: string
		switch state.input.mode {
		case .MouseKeyboard:
			{
				text_0 = "Move rectangle [wasd] turbo [left shift]"
				text_1 = "Zoom [mouse wheel]"
				text_2 = "Slow [left mouse click]"
			}
		case .Gamepad:
			{
				text_0 = "Move rectangle [left stick] turbo [left trigger]"
				text_1 = "Zoom [right stick]"
				text_2 = "Slow [button 0]"
			}
		}
		h: i32 = state.debug_text.atlas.h
		line_gap: i32 = 8
		x: i32 = 16
		y: i32 = 16
		_, _ = text.debug({x, y}, text_0)
		y += h + line_gap
		_, _ = text.debug({x, y}, text_1)
		y += h + line_gap
		_, _ = text.debug({x, y}, text_2)
	}
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	if !state.input.has_focus && !state.input.just_lost_focus {
		return true
	}
	paused := false
	if state.input.just_lost_focus {
		// allow one frame to draw after losing focus
		// switch to paused mode
		paused = true
		state.input.just_lost_focus = false
	}
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		if ok = start(); !ok {return false}
	}

	update(dt)

	draw_scene(paused)

	return check_gl_error()
}

