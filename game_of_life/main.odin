package game
import "../shared/resize"
import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

Layout :: struct {
	w:              int,
	h:              int,
	dpr:            f32,
	key_dimensions: [2]f32,
	resized:        bool,
}
GameMode :: enum {
	Play,
	Pause,
}
State :: struct {
	game_mode:        GameMode,
	switch_to_mode:   GameMode,
	started:          bool,
	layout:           Layout,
	text_batch:       text.Batch,
	shapes:           Shapes,
	time_elapsed:     f64,
	square_size:      int,
	simulation:       Simulation,
	cursor:           Cursor,
	input:            Input,
	camera_pos:       [2]f32,
	camera_zoom:      f32,
	camera_drag_mode: bool,
	camera_vel:       [2]f32,
	view_offset:      [2]f32,
	has_focus:        bool,
}
@(private = "file")
state: State = {}

temp_arena_buffer: [mem.Megabyte * 8]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

start :: proc() -> (ok: bool) {
	state.started = true
	state.camera_zoom = 1
	state.square_size = 8
	state.camera_pos = {0, 0}

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	handle_resize(&state.layout)

	simulation_init(&state.simulation)
	cursor_init(&state.cursor)
	input_init(&state.input)
	shapes_init(&state.shapes)

	// for faster debug
	state.switch_to_mode = .Play

	state.has_focus = true

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

_camera_square_offset :: proc(camera_pos: [2]f32, square_size: int) -> [2]int {
	offset := i_int_round(camera_pos) / (SQUARES * square_size)
	return offset
}

draw_scene :: proc(dt: f32) -> (ok: bool) {
	bg := COLOR_1
	gl.ClearColor(bg.r, bg.g, bg.b, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	w := state.layout.w
	h := state.layout.h

	gl.Viewport(0, 0, i32(w), i32(h))


	zoom: f32 = state.camera_zoom
	camera_pos: [2]f32 = state.camera_pos

	c_pos := state.view_offset
	left: f32 = c_pos.x
	right: f32 = (f32(w) * zoom) + c_pos.x
	bottom: f32 = (f32(h) * zoom) + c_pos.y
	top: f32 = c_pos.y
	view := glm.mat4Ortho3d(left, right, bottom, top, -100, 100)

	if _first {
		fmt.println()
		fmt.println(" camera_pos:", camera_pos)
		fmt.println("      c_pos:", c_pos)
		fmt.println("    SQUARES:", SQUARES)
		fmt.println("square size:", state.square_size)
	}

	simulation_draw(&state.simulation, view, state.square_size)
	shapes := make_dynamic_array([dynamic]Shape, allocator = context.temp_allocator)
	if state.game_mode == .Play {
		cursor_get_shapes(state.cursor, state.square_size, &shapes)
	}
	// simulation_get_shapes(&state.simulation, &shapes, state.square_size, {w, h}, state.camera_pos)

	shapes_draw(&state.shapes, shapes[:], view)
	return true
}

update :: proc(state: ^State, dt: f32) {
	if state.switch_to_mode != state.game_mode {
		fmt.println(state.game_mode, "->", state.switch_to_mode)
	}
	state.game_mode = state.switch_to_mode
	state.time_elapsed += f64(dt)
	handle_resize(&state.layout)
	l := state.layout
	input_update(l.dpr)
	_ = handle_events(state)
	if !state.has_focus {
		return
	}
	screen_size: [2]int = {state.layout.w, state.layout.h}
	// Calculate smooth camera movement based on move keys that are held down
	mv := camera_update(dt, &state.camera_vel, &state.camera_pos, state.input.key_down)
	{
		sq_i := SQUARES * state.square_size
		sq := f_(sq_i)

		// Offset to center patches on screen.  If square size is large enough,
		// new squares popping in should happen offscreen in all directions
		patch_cn: [2]int = ([2]int{PATCHES_W, PATCHES_H} * sq_i) / 2
		screen_cn: [2]int = screen_size / 2
		off: [2]int = screen_cn - patch_cn

		offset := _camera_square_offset(state.camera_pos, state.square_size)
		state.view_offset = state.camera_pos - (f_(offset) * sq) - f_(off)
	}

	// Update the cursor position (add camera movement so it stays at expected screen
	// position when camera is moving)
	cursor_update(&state.cursor, state.input.draw_mode, state.input.cursor_size, mv)

	if state.game_mode == .Play {
		simulation_update(
			&state.simulation,
			state.square_size,
			screen_size,
			state.camera_pos,
			state.cursor,
		)
	}
}

handle_resize :: proc(layout: ^Layout) {
	r: resize.ResizeState
	resize.resize(&r)
	layout.w = cast(int)r.canvas_res.x
	layout.h = cast(int)r.canvas_res.y
	layout.dpr = r.dpr
	layout.resized = r.size_changed || r.zoom_changed
}

// Use for debug prints on first frame only
_first: bool = true

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)
	defer {_first = false}
	// fmt.println("---------------- step --------------------")

	ok: bool
	if !state.started {
		if ok = start(); !ok {return false}
	}

	update(&state, dt)
	if !state.has_focus {
		return true
	}

	ok = draw_scene(dt)
	if !ok {
		fmt.eprintln("Failed to draw scene")
		return false
	}

	// return check_gl_error()
	return true
}

