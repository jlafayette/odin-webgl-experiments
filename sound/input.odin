package sound

foreign import odin_mouse "odin_mouse"

import "core:fmt"
import "core:sys/wasm/js"

Input :: struct {
	pointer:   PointerState,
	mouse_pos: [2]f32,
}
g_input := Input{}


init_input :: proc(input: ^Input, number_of_keys: int) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Key_Up, {}, on_key_up)
	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Mouse_Down, {}, on_mouse_down)
	js.add_window_event_listener(.Mouse_Up, {}, on_mouse_up)
	js.add_window_event_listener(.Blur, {}, on_blur)
	input.pointer = .Hover
}

update_input :: proc(input: ^Input, buttons: []Button, dt: f32, dpr: f32) {
	input.mouse_pos *= dpr
	new_i := -1
	for &btn, i in buttons {
		btn.pointer = .None
		if button_contains_pos(btn, i_(input.mouse_pos)) {
			btn.pointer = input.pointer
		}
	}
	if input.pointer == .Up {
		input.pointer = .Hover
	}
}

on_mouse_move :: proc(e: js.Event) {
	g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
}

on_mouse_down :: proc(e: js.Event) {
	// fmt.println("click:", e.mouse.button)
	if e.mouse.button != 0 {
		return
	}
	g_input.pointer = .Down
}
on_mouse_up :: proc(e: js.Event) {
	// fmt.println("unclick:", e.mouse.button)
	if e.mouse.button != 0 {
		return
	}
	g_input.pointer = .Up
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	// fmt.println(e.key.code)
}
on_key_up :: proc(e: js.Event) {
}

on_blur :: proc(e: js.Event) {
	g_input.pointer = .Hover
}

