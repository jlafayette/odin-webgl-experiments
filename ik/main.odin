package ik

import "../shared/resize"
import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:strings"
import gl "vendor:wasm/WebGL"

main :: proc() {}

temp_arena_buffer: [mem.Megabyte * 1]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

Game :: struct {
	started:      bool,
	debug_text:   text.Batch,
	w:            i32,
	h:            i32,
	dpr:          f32,
	resized:      bool,
	shapes:       Shapes,
	time_elapsed: f64,
	input:        Input,
}
@(private = "file")
g_game: Game = {}


start :: proc(g: ^Game) -> (ok: bool) {
	g.started = true

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}

	update_handle_resize(g)
	init_input(&g.input)
	shapes_init(&g.shapes, g.w, g.h)
	return check_gl_error()
}

draw_scene :: proc(g: ^Game) -> (ok: bool) {
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Viewport(0, 0, g.w, g.h)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	projection := glm.mat4Ortho3d(0, f32(g.w), f32(g.h), 0, -10, 10)

	shapes_draw(&g.shapes, projection)

	// scale: i32 = math.max(1, i32(math.round(state.dpr)))
	// spacing: i32 = 5 * scale
	// text.batch_start(
	// 	&state.debug_text,
	// 	.A40,
	// 	{1, 1, 1},
	// 	projection,
	// 	128,
	// 	spacing = spacing,
	// 	scale = scale,
	// )
	// h: i32 = text.debug_get_height()
	// text_0 := "Click to Start"
	// w: i32 = text.debug_get_width(text_0)
	// x: i32 = state.w / 2 - w / 2
	// y: i32 = state.h / 2 - h
	// _ = text.debug({x, y}, text_0) or_return
	return true
}


@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !g_game.started {
		if ok = start(&g_game); !ok {return false}
	}

	update(&g_game, dt)

	ok = draw_scene(&g_game)
	if !ok {return false}

	return true
}

check_gl_error :: proc() -> (ok: bool) {
	err := gl.GetError()
	if err != gl.NO_ERROR {
		fmt.eprintln("WebGL error:", err)
		return false
	}
	return true
}

