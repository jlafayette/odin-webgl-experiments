package shapes

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"


Input :: struct {
	prev_mouse_pos: glm.vec2,
	mouse_pos:      glm.vec2,
}
g_input := Input{}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)

	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Mouse_Down, {}, on_mouse_down)
	js.add_window_event_listener(.Mouse_Up, {}, on_mouse_up)
}
update_input :: proc(input: ^Input, dt: f32) {
	// book-keeping
	input.prev_mouse_pos = input.mouse_pos

	return
}

_mouse_down: bool = false
on_mouse_move :: proc(e: js.Event) {
	if e.mouse.button == 0 && _mouse_down {
		g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
	}
}
on_mouse_up :: proc(e: js.Event) {
	if e.mouse.button == 0 {
		g_input.prev_mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		_mouse_down = false
	}
}
on_mouse_down :: proc(e: js.Event) {
	if e.mouse.button == 0 {
		g_input.prev_mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		_mouse_down = true
	}
}

mouse_movement :: proc(mouse_pos, prev_mouse_pos: glm.vec2) -> glm.vec2 {
	m1 := mouse_pos
	m2 := prev_mouse_pos
	return m1 - m2
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
}

