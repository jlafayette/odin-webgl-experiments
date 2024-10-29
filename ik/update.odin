package ik

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

update_handle_resize :: proc(g: ^Game) {
	r: resize.ResizeState
	resize.resize(&r)
	g.w = r.canvas_res.x
	g.h = r.canvas_res.y
	g.dpr = r.dpr
	g.resized = r.size_changed
}
update :: proc(g: ^Game, dt: f32) {
	g.time_elapsed += f64(dt)
	update_handle_resize(g)
	update_input(&g.input, dt)
	shapes_update(&g.shapes, g.w, g.h, dt, g.time_elapsed)
	g.input = {}
}

