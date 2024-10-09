package resize

foreign import odin_resize "odin_resize"

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"

SizeInfo :: struct {
	window_inner_width:  f32,
	window_inner_height: f32,
	rect_width:          f32,
	rect_height:         f32,
	rect_left:           f32,
	rect_top:            f32,
	dpr:                 f32,
}

update_size_info :: proc() -> SizeInfo {
	@(default_calling_convention = "contextless")
	foreign odin_resize {
		@(link_name = "updateSizeInfo")
		_updateSizeInfo :: proc(out: ^[7]f64) ---
	}
	out: [7]f64
	_updateSizeInfo(&out)
	return {
		window_inner_width = f32(out[0]),
		window_inner_height = f32(out[1]),
		rect_width = f32(out[2]),
		rect_height = f32(out[3]),
		rect_left = f32(out[4]),
		rect_top = f32(out[5]),
		dpr = f32(out[6]),
	}
}
get_scroll :: proc() -> [2]f32 {
	@(default_calling_convention = "contextless")
	foreign odin_resize {
		@(link_name = "getScroll")
		_getScroll :: proc(out: ^[2]f64) ---
	}
	out: [2]f64
	_getScroll(&out)
	return {f32(out[0]), f32(out[1])}
}

_prev_sizes: SizeInfo

ResizeState :: struct {
	window_size:  [2]i32,
	canvas_size:  [2]i32,
	canvas_pos:   [2]i32,
	canvas_res:   [2]i32,
	aspect_ratio: f32,
	dpr:          f32,
	zoom_changed: bool,
	size_changed: bool,
}


resize :: proc(state: ^ResizeState) {
	sizes := update_size_info()
	if sizes.dpr != _prev_sizes.dpr {
		state.zoom_changed = true
	} else if sizes.window_inner_width != _prev_sizes.window_inner_width ||
	   sizes.window_inner_height != _prev_sizes.window_inner_height {
		state.size_changed = true
	}
	window_size: [2]f32 = {sizes.window_inner_width, sizes.window_inner_height}
	canvas_size: [2]f32 = {sizes.rect_width, sizes.rect_height}
	canvas_pos: [2]f32 = {sizes.rect_left, sizes.rect_top}
	canvas_res: [2]f32 = {sizes.rect_width * sizes.dpr, sizes.rect_height * sizes.dpr}
	aspect_ratio: f32 = sizes.rect_width / sizes.rect_height

	state.window_size = {i32(math.round(window_size.x)), i32(math.round(window_size.y))}
	state.canvas_size = {i32(math.round(canvas_size.x)), i32(math.round(canvas_size.y))}
	state.canvas_pos = {i32(math.round(canvas_pos.x)), i32(math.round(canvas_pos.y))}
	state.canvas_res = {i32(math.round(canvas_res.x)), i32(math.round(canvas_res.y))}
	state.aspect_ratio = aspect_ratio
	state.dpr = sizes.dpr

	_prev_sizes = sizes
}

Size :: struct {
	w:            i32,
	h:            i32,
	dpr:          f32,
	zoom_changed: bool,
	size_changed: bool,
}
get :: proc() -> Size {
	r: ResizeState
	resize(&r)
	return {r.canvas_res.x, r.canvas_res.y, r.dpr, r.zoom_changed, r.size_changed}
}

