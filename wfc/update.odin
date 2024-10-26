package wfc

import "../shared/resize"
import "core:fmt"
import "core:mem"

game_update :: proc(game: ^Game, input: Input) {
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
	if input.restart {
		grid_reset(&game.grid)
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
update :: proc(state: ^State, dt: f32) {
	state.time_elapsed += f64(dt)
	{
		r: resize.ResizeState
		resize.resize(&r)
		state.w = r.canvas_res.x
		state.h = r.canvas_res.y
		state.dpr = r.dpr
		state.resized = r.size_changed
	}

	update_input(&g_input, dt)
	shapes_update(&state.shapes, state.w, state.h, dt, state.time_elapsed)
	// if state.resized {
	// 	// delete(state._a)
	// 	free_all(arena_allocator)
	// 	err: mem.Allocator_Error
	// 	state._a, err = make_slice([]int, state.w * state.h, allocator = arena_allocator)
	// 	fmt.println("state._a, resized to:", len(state._a), err)
	// 	if err != nil {
	// 	}
	// }
	if state.resized {
		game_destroy(&state.game)
		game_init(&state.game, state.w, state.h)
	}
	game_update(&state.game, g_input)
	g_input = {}
}

