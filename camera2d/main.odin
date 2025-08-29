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
	Start,
	MainMenu,
	Play,
	Pause,
	GameOver,
	Win,
}
State :: struct {
	game_mode:         GameMode,
	switch_to_mode:    GameMode,
	started:           bool,
	layout:            Layout,
	text_batch:        text.Batch,
	shapes:            Shapes,
	time_elapsed:      f64,
	square_size:       [2]int,
	patch:             Patch,
	// patch2:            Patch,
	cursor:            Cursor,
	input:             Input,
	camera_pos:        [2]f32,
	camera_zoom:       f32,
	camera_mouse_mode: bool,
	camera_vel:        [2]f32,
	has_focus:         bool,
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
	state.camera_pos = {0, 0}
	state.camera_zoom = 1

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	update_handle_resize(&state.layout)

	patch_init(&state.patch)
	// patch_init(&state.patch2)
	cursor_init(&state.cursor)
	init_input(&state.input)
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

	left: f32 = camera_pos.x
	right: f32 = (f32(w) * zoom) + camera_pos.x
	bottom: f32 = (f32(h) * zoom) + camera_pos.y
	top: f32 = camera_pos.y
	view := glm.mat4Ortho3d(left, right, bottom, top, -100, 100)

	// (left, right, bottom, top, near, far: f32)
	// view := glm.mat4Ortho3d(0 + pos.x, f32(w) + pos.x, f32(h) + pos.y, 0 + pos.y, -100, 100)
	// camera_pos: glm.vec3 = {0, 0, -3}
	// camera_front: glm.vec3 = {0, 0, 1}
	// camera_up: glm.vec3 = {0, 1, 0}
	// view := glm.mat4LookAt(camera_pos, camera_pos + camera_front, camera_up)
	patch_draw(&state.patch, view, w, h)
	// patch_draw(&state.patch2, view, w, h)
	shapes := make_dynamic_array([dynamic]Shape, allocator = context.temp_allocator)
	square_size: [2]int
	if state.game_mode == .Play {
		cursor_get_shapes(state.cursor, {w, h}, &shapes)
		// patch_get_shapes(&state.patch2, {w, h}, &shapes)
	}
	shapes_draw(&state.shapes, shapes[:], view)
	return true
}

update :: proc(state: ^State, dt: f32) {
	if state.switch_to_mode != state.game_mode {
		fmt.println(state.game_mode, "->", state.switch_to_mode)
	}
	state.game_mode = state.switch_to_mode
	state.time_elapsed += f64(dt)
	update_handle_resize(&state.layout)
	l := state.layout
	update_input(l.dpr)
	_ = handle_events(state)
	if !state.has_focus {
		return
	}
	// Calculate smooth camera movement based on move keys that are held down
	mv := update_camera(dt, &state.camera_vel, &state.camera_pos, state.input.key_down)
	// Update the cursor position (add camera movement so it stays at expected screen
	// position when camera is moving)
	cursor_update(&state.cursor, state.input.draw_mode, state.input.cursor_size, mv)

	if state.game_mode == .Play {
		patch_update(&state.patch, {state.layout.w, state.layout.h}, state.cursor)
		// patch_update(
		// 	&state.patch2,
		// 	{state.layout.w, state.layout.h},
		// 	state.input.draw_mode,
		// 	state.input.cursor_size,
		// )
	}
}

update_handle_resize :: proc(layout: ^Layout) {
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

