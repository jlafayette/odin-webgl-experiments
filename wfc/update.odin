package wfc

import "../shared/resize"
import "core:fmt"
import "core:math"
import "core:mem"

screen_to_grid_xy :: proc(tile_size: int, screen_pos: [2]i64, dpr: f32) -> [2]int {
	pos: [2]int
	pos.x = cast(int)math.floor((f32(screen_pos.x) * dpr) / f32(tile_size))
	pos.y = cast(int)math.floor((f32(screen_pos.y) * dpr) / f32(tile_size))
	return pos
}

game_update :: proc(game: ^Game, input: Input, dpr: f32) {
	if input.play_toggle {
		switch m in game.mode {
		case ModePlay:
			game.mode = ModePause{}
		case ModePause:
			game.mode = ModePlay {
				steps_per_frame = 20,
			}
			fmt.println("play", game.mode)
		}
	}
	if input.play {
		game.mode = ModePlay {
			steps_per_frame = 8,
		}
		fmt.println("play", game.mode)
	}
	if input.restart {
		start_at: Maybe([2]int)
		screen_pos, ok := input.restart_at.?
		if ok {
			start_at = screen_to_grid_xy(TILE_SIZE, screen_pos, dpr)
		}
		grid_reset(&game.grid, start_at)
	}
	steps: int = 0
	switch mode in game.mode {
	case ModePlay:
		{
			steps = mode.steps_per_frame
		}
	case ModePause:
		{
			if input.next_step {steps += 1}
		}
	}
	for i := steps; i > 0; i -= 1 {
		wfc_step(game)
	}
}
update_handle_resize :: proc(state: ^State) {
	r: resize.ResizeState
	resize.resize(&r)
	state.w = r.canvas_res.x
	state.h = r.canvas_res.y
	state.dpr = r.dpr
	state.resized = r.size_changed
}
update :: proc(state: ^State, dt: f32) {
	state.time_elapsed += f64(dt)
	update_handle_resize(state)
	update_input(&g_input, dt)
	shapes_update(&state.shapes, state.w, state.h, dt, state.time_elapsed)
	if state.resized {
		game_destroy(&state.game)
		game_init(&state.game, state.w, state.h)
	}
	game_update(&state.game, g_input, state.dpr)
	g_input = {}
}

