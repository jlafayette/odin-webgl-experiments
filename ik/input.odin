package ik

import "core:fmt"
import "core:sys/wasm/js"

Input :: struct {
	mouse_pos:  [2]i64,
	mouse_down: bool,
}
@(private = "file")
g_input: Input = {}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Pointer_Down, {}, on_pointer_down)
	js.add_window_event_listener(.Pointer_Up, {}, on_pointer_up)
	js.add_window_event_listener(.Pointer_Move, {}, on_pointer_move)
}
update_input :: proc(input: ^Input, dt: f32) {
	input.mouse_pos = g_input.mouse_pos
	input.mouse_down = g_input.mouse_down
}

on_pointer_down :: proc(e: js.Event) {
	if e.pointer.button == 0 {
		g_input.mouse_down = true
	}
}
on_pointer_up :: proc(e: js.Event) {
	if e.pointer.button == 0 {
		g_input.mouse_down = false
	}
}
on_pointer_move :: proc(e: js.Event) {
	g_input.mouse_pos = e.pointer.client
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	fmt.println(e.key.code)
}

