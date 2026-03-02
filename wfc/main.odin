package wfc

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

ModePlay :: struct {
	steps_per_frame: int,
}
ModePause :: struct {}
Mode :: union #no_nil {
	ModePlay,
	ModePause,
}

Game :: struct {
	grid:         Grid,
	tile_options: [dynamic]TileOption,
	mode:         Mode,
	tile_size:    f32,
}
MAX_ROWS :: 192
MAX_COLS :: 192
TILE_SIZE :: 20
game_init :: proc(g: ^Game, width, height: i32) {
	size: f32 = TILE_SIZE
	rows := math.min(MAX_ROWS, cast(int)math.floor(f32(width) / size))
	cols := math.min(MAX_COLS, cast(int)math.floor(f32(height) / size))
	g.tile_size = size
	fmt.printf("w: %d, h: %d, rows: %d, cols: %d\n", width, height, rows, cols)

	g.mode = ModePause{}
	grid_init(&g.grid, rows, cols)
	for tile in Tile {
		ts := tile_set[tile]
		for xform in ts.xforms {
			append(&g.tile_options, TileOption{tile, xform})
		}
	}
}
game_destroy :: proc(g: ^Game) {
	grid_destroy(&g.grid)
}

State :: struct {
	started:      bool,
	debug_text:   text.Batch,
	w:            i32,
	h:            i32,
	dpr:          f32,
	resized:      bool,
	shapes:       Shapes,
	time_elapsed: f64,
	game:         Game,
}
@(private = "file")
g_state: State = {}


start :: proc(state: ^State) -> (ok: bool) {
	state.started = true

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}

	update_handle_resize(state)
	init_input(&g_input)
	shapes_init(&state.shapes, state.w, state.h)
	game_init(&state.game, state.w, state.h)
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
	projection := glm.mat4Ortho3d(0, f32(state.w), f32(state.h), 0, -10, 10)

	shapes_draw(&state.game, &state.shapes, projection)

	_, paused := state.game.mode.(ModePause)
	if paused {
		scale: int = math.max(1, int(math.round(state.dpr)))
		spacing: int = 5 * scale
		text.batch_start(
			&state.debug_text,
			.A40,
			{1, 1, 1},
			projection,
			128,
			spacing = spacing,
			scale = scale,
		)
		h: int = text.debug_get_height()
		text_0 := "Click to Start"
		w: int = text.debug_get_width(text_0)
		x: int = int(state.w) / 2 - w / 2
		y: int = int(state.h) / 2 - h
		_ = text.debug({x, y}, text_0) or_return
	}
	return true
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

