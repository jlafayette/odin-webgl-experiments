package trails

foreign import odin_mouse "odin_mouse"

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

Input :: struct {
	mouse_pos: [2]f32,
}
ListenerInput :: struct {
	mouse_pos: [2]f32,
}
@(private = "file")
i_: ListenerInput = {}

input_reset :: proc(li: ^ListenerInput) {
}

get_mouse_pos :: proc "contextless" (
	canvas_id: string,
	client_pos: [2]i64, // from e.mouse.client
	flip_y: bool, // if true, 0,0 is lower left instead of upper left
) -> (
	pos: [2]f32,
) {
	@(default_calling_convention = "contextless")
	foreign odin_mouse {
		@(link_name = "getMousePos")
		_getMousePos :: proc(out_pos: ^[2]f64, id: string, client_x, client_y: i64, flip_y: bool) ---
	}
	out_pos: [2]f64
	_getMousePos(&out_pos, canvas_id, client_pos.x, client_pos.y, flip_y)
	return {f32(out_pos.x), f32(out_pos.y)}
}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Blur, {}, on_blur)
}


// Update global gamestate with listener input
update_input :: proc(input: ^Input, dt: f32) {
	input.mouse_pos = i_.mouse_pos
}

on_mouse_move :: proc(e: js.Event) {
	// movement := e.mouse.movement
	// mouse_diff := {f32(movement.x), f32(movement.y)}
	pos := get_mouse_pos("canvas-1", e.mouse.client, true)
	// fmt.println("ffi pos:", pos)
	i_.mouse_pos = pos
}

on_blur :: proc(e: js.Event) {
	input_reset(&i_)
}

