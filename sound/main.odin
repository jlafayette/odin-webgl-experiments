package sound

import "../shared/resize"
import "../shared/text"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

Layout :: struct {
	number_of_keys: int,
	w:              i32,
	h:              i32,
	dpr:            f32,
	key_dimensions: [2]f32,
	resized:        bool,
}
Arena :: struct {
	allocator: mem.Allocator,
	buffer:    []byte,
	arena:     mem.Arena,
}
arena_init :: proc(a: ^Arena, size: int) {
	a.buffer = make_slice([]byte, size)
	a.arena = {
		data = a.buffer[:],
	}
	a.allocator = mem.arena_allocator(&a.arena)
}
State :: struct {
	started:      bool,
	layout:       Layout,
	ui:           Ui,
	text_batch:   text.Batch,
	shapes:       Shapes,
	time_elapsed: f64,
	temp_arena:   Arena,
}
@(private = "file")
state: State = {}


start :: proc() -> (ok: bool) {
	state.started = true
	arena_init(&state.temp_arena, mem.Megabyte * 4)

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	update_handle_resize(&state.layout)

	init_input(&g_input, state.layout.number_of_keys)

	shapes_init(&state.shapes, state.layout.w, state.layout.h)

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
	gl.ClearColor(0.1, 0.1, 0.1, 1)
	gl.Clear(cast(u32)gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(cast(u32)(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT))
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	w := state.layout.w
	h := state.layout.h

	gl.Viewport(0, 0, w, h)

	view_projection_matrix := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -100, 100)

	shapes_draw(&state.shapes, state.ui, view_projection_matrix)

	{
		scale: i32 = state.ui.scale
		spacing: i32 = 2 * scale
		text.batch_start(
			&state.text_batch,
			.A20,
			{1, 1, 1},
			view_projection_matrix,
			128,
			spacing = int(spacing),
			scale = int(scale),
		)
		text_h: i32 = cast(i32)text.debug_get_height()
		for button in state.ui.buttons {
			if button.label == "" {
				continue
			}
			text_w: i32 = cast(i32)text.debug_get_width(button.label)
			pos := button.pos
			size := button.size
			pos.x += size.x / 2 - text_w / 2
			pos.y += size.y / 2 - text_h / 2
			_, ok = text.debug({int(pos.x), int(pos.y)}, button.label, flip_y = false)
			if !ok {
				fmt.eprintln("Failed to render text for button:", button)
			}
		}
		{
			slider := state.ui.slider
			slider_text: string = fmt.tprintf("%d", slider.value)
			text_w: i32 = cast(i32)text.debug_get_width(slider_text)
			pos := slider.pos
			pos.x += slider.size.x + 10 * scale
			pos.y += slider.size.y / 2
			pos.y -= text_h / 2
			_, ok = text.debug({int(pos.x), int(pos.y)}, slider_text, flip_y = false)
			if !ok {
				fmt.eprintln("Failed to render text for slider")
			}
		}
		{
			cb := state.ui.checkbox
			text_w: i32 = cast(i32)text.debug_get_width(cb.label)
			pos := cb.pos + {cb.size.y, 0} + {12, 0} * scale
			pos.y += cb.size.y / 2 - text_h / 2
			_, ok = text.debug({int(pos.x), int(pos.y)}, cb.label, flip_y = false)
			if !ok {
				fmt.eprintln("Failed to render text for slider")
			}

		}

	}
	return true
}

update :: proc(state: ^State, input: ^Input, dt: f32) {
	state.time_elapsed += f64(dt)
	update_handle_resize(&state.layout)
	l := state.layout
	update_input(&g_input, &state.ui, dt, l.dpr)
	ui_layout(&state.ui, {{0, 0}, {l.w, l.h}}, l.dpr)
	shapes_update(&state.shapes, l.w, l.h, dt, state.time_elapsed)
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
	ok: bool
	if !state.started {
		if ok = start(); !ok {return false}
	}
	context.temp_allocator = state.temp_arena.allocator
	defer free_all(context.temp_allocator)

	update(&state, &g_input, dt)

	ok = draw_scene(dt)
	if !ok {
		fmt.eprintln("Failed to draw scene")
		return false
	}

	return check_gl_error()
}

