package shapes

import "../shared/resize"
import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

State :: struct {
	started:    bool,
	debug_text: text.Batch,
	w:          i32,
	h:          i32,
	dpr:        f32,
	shapes:     Shapes,
}
@(private = "file")
g_state: State = {}

temp_arena_buffer: [mem.Megabyte * 32]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

start :: proc(state: ^State) -> (ok: bool) {
	state.started = true

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}

	init_input(&g_input)

	shapes_init(&state.shapes)

	return check_gl_error()
}

draw_scene :: proc(state: ^State) -> (ok: bool) {
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Viewport(0, 0, state.w, state.h)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	text_projection := glm.mat4Ortho3d(0, f32(state.w), f32(state.h), 0, -10, 10)
	{
		scale: i32 = math.max(1, i32(math.round(state.dpr)))
		spacing: i32 = 2 * scale
		text.batch_start(
			&state.debug_text,
			.A16,
			{1, 1, 1},
			text_projection,
			128,
			spacing = spacing,
			scale = scale,
		)
		text_0 := "Rectangle [r]"
		text_1 := "Circle    [c]"
		text_2 := "Line      [l]"
		h: i32 = text.debug_get_height()
		line_gap: i32 = 5 * scale
		x: i32 = 16 * scale
		y: i32 = state.h - h - 16
		_ = text.debug({x, y}, text_0) or_return
		y -= h + line_gap
		_ = text.debug({x, y}, text_1) or_return
		y -= h + line_gap
		_ = text.debug({x, y}, text_2) or_return
	}

	shapes_draw(&state.shapes, text_projection)

	return check_gl_error()
}

update :: proc(state: ^State, dt: f32) {
	{
		r: resize.ResizeState
		resize.resize(&r)
		state.w = r.canvas_res.x
		state.h = r.canvas_res.y
		state.dpr = r.dpr
	}
	update_input(&g_input, dt)
	shapes_update(&state.shapes, state.w, state.h)
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !g_state.started {
		if ok = start(&g_state); !ok {return false}
	}

	update(&g_state, dt)

	ok = draw_scene(&g_state)
	if !ok {return false}

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

