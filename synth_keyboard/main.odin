package synth_keyboard

import "../shared/resize"
import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

Key :: struct {
	pos:                 [2]f32,
	w:                   f32,
	h:                   f32,
	label:               string,
	label_offset_height: f32,
}
Layout :: struct {
	number_of_keys: int,
	w:              i32,
	h:              i32,
	dpr:            f32,
	key_dimensions: [2]f32,
	resized:        bool,
}
State :: struct {
	started:     bool,
	key_shader:  KeyShader,
	key_buffers: Buffers,
	textures:    Textures,
	layout:      Layout,
	keys:        []Key,
	text_batch:  text.Batch,
}
@(private = "file")
state: State = {}

temp_arena_buffer: [mem.Megabyte * 4]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

start :: proc() -> (ok: bool) {
	state.started = true

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	update_handle_resize(&state.layout)
	state.layout.number_of_keys = 11
	state.keys = make([]Key, state.layout.number_of_keys)

	init_input(&g_input, state.layout.number_of_keys)

	key_shader_init(&state.key_shader)
	key_buffers_init(&state.key_buffers, state.keys, &state.layout)
	{
		labels: [7]string = {"C", "D", "E", "F", "G", "A", "B"}
		for i in 0 ..< state.layout.number_of_keys {
			state.keys[i].label = labels[i % 7]
		}
	}

	ok = textures_init(&state.textures)
	if !ok {return}

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

draw_scene :: proc(dt: f32) -> (ok: bool) {
	gl.ClearColor(0.5, 0.5, 0.5, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	w := state.layout.w
	h := state.layout.h

	gl.Viewport(0, 0, w, h)

	// 0,0 is bottom left
	view_projection_matrix := glm.mat4Ortho3d(0, f32(w), 0, f32(h), -100, 100)

	model_matrix := glm.mat4(1)
	// model_matrix *= glm.mat4Translate({0, 0, 0})
	// model_matrix *= glm.mat4Scale({1, 1, 1})

	uniforms: KeyUniforms = {
		model_matrix           = model_matrix,
		view_projection_matrix = view_projection_matrix,
	}
	ok = shader_use(
		&state.key_shader,
		uniforms,
		state.key_buffers.pos,
		state.key_buffers.tex,
		state.key_buffers.colors,
		state.key_buffers.matrices,
		state.textures[.Corner],
	)
	if !ok {return}
	ea_buffer_draw(state.key_buffers.indices, instance_count = state.layout.number_of_keys)

	{
		scale: int = math.max(1, int(math.round(state.layout.dpr)))
		spacing: int = 5 * scale
		text.batch_start(
			&state.text_batch,
			_pick_atlas(state.layout.dpr),
			{0, 0, 0},
			view_projection_matrix,
			64,
			spacing = spacing,
			scale = scale,
		)
		for key in state.keys {
			w: int = text.debug_get_width(key.label)
			pos: [2]int = {int(key.pos.x), int(key.pos.y)}
			pos.x += int(key.w / 2) - w / 2
			pos.y += int(key.label_offset_height)
			_ = text.debug(pos, key.label, flip_y = true) or_return
		}
	}
	return ok
}

_pick_atlas :: proc(dpr: f32) -> text.AtlasSize {
	size: f32 = 40 * dpr
	if size >= 35 {
		return .A40
	} else if size >= 25 {
		return .A30
	} else if size >= 15 {
		return .A20
	} else if size >= 18 {
		return .A16
	} else {
		return .A12
	}
}

update :: proc(state: ^State, input: ^Input, dt: f32) {
	update_handle_resize(&state.layout)
	if state.layout.resized {
		update_keys(state.key_buffers, state.keys, state.layout)
	}
	update_input(&g_input, state.keys, dt)
	{
		// update instance colors
		color_data := make([]glm.vec4, state.layout.number_of_keys)
		defer delete(color_data)
		for i in 0 ..< state.layout.number_of_keys {
			if input_state(i) {
				color_data[i] = {0.4, 0.9, 1, 1}
			} else {
				color_data[i] = {1, 1, 1, 1}
			}
		}
		b := state.key_buffers.colors
		gl.BindBuffer(b.target, b.id)
		gl.BufferSubDataSlice(b.target, 0, color_data)
	}
}

update_handle_resize :: proc(layout: ^Layout) {
	r: resize.ResizeState
	resize.resize(&r)
	layout.w = r.canvas_res.x
	layout.h = r.canvas_res.y
	layout.dpr = r.dpr
	layout.resized = r.size_changed || r.zoom_changed
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		if ok = start(); !ok {return false}
	}

	update(&state, &g_input, dt)

	ok = draw_scene(dt)
	if !ok {return false}

	return check_gl_error()
}

