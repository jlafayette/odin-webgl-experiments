package synth_keyboard

foreign import odin_mouse "odin_mouse"

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

Input :: struct {
	keys_down: []bool,
	clicked:   bool,
	mouse_key: int,
	mouse_pos: [2]f32,
}
g_input := Input{}

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

pos_in_key :: proc(pos: [2]f32, key: Key) -> bool {
	if pos.x < key.pos.x {return false}
	if pos.x > key.pos.x + key.w {return false}
	if pos.y < key.pos.y {return false}
	if pos.y > key.pos.y + key.h {return false}
	return true
}

init_input :: proc(input: ^Input, number_of_keys: int) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Key_Up, {}, on_key_up)
	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Mouse_Down, {}, on_mouse_down)
	js.add_window_event_listener(.Mouse_Up, {}, on_mouse_up)
	js.add_window_event_listener(.Blur, {}, on_blur)
	input.keys_down = make([]bool, number_of_keys)
}

update_input :: proc(input: ^Input, dt: f32) {
	input.mouse_key = -1
	if input.clicked {
		for key, i in state.keys {
			if pos_in_key(input.mouse_pos, key) {
				input.mouse_key = i
				break
			}
		}
	}
}

on_mouse_move :: proc(e: js.Event) {
	// movement := e.mouse.movement
	// mouse_diff := {f32(movement.x), f32(movement.y)}
	pos := get_mouse_pos("canvas-1", e.mouse.client, true)
	fmt.println("ffi pos:", pos)
	g_input.mouse_pos = pos
}

on_mouse_down :: proc(e: js.Event) {
	// fmt.println("click:", e.mouse.button)
	if e.mouse.button != 0 {
		return
	}
	g_input.clicked = true
}
on_mouse_up :: proc(e: js.Event) {
	// fmt.println("unclick:", e.mouse.button)
	if e.mouse.button != 0 {
		return
	}
	g_input.clicked = false
}

k_map: map[string]int = {
	"KeyA"      = 0,
	"KeyS"      = 1,
	"KeyD"      = 2,
	"KeyF"      = 3,
	"KeyG"      = 4,
	"KeyH"      = 5,
	"KeyJ"      = 6,
	"KeyK"      = 7,
	"KeyL"      = 8,
	"Semicolon" = 9,
	"Quote"     = 10,
}
on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code in k_map {
		i := k_map[e.key.code]
		if i < len(g_input.keys_down) {
			g_input.keys_down[i] = true
		}
	}
}
on_key_up :: proc(e: js.Event) {
	if e.key.code in k_map {
		i := k_map[e.key.code]
		if i < len(g_input.keys_down) {
			g_input.keys_down[i] = false
		}
	}
}

on_blur :: proc(e: js.Event) {
	for &v in g_input.keys_down {
		v = false
	}
	g_input.clicked = false
	g_input.mouse_key = -1
}

