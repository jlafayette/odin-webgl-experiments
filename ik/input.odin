package ik

import "core:fmt"
import "core:sys/wasm/js"

Input :: struct {

}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Pointer_Down, {}, on_pointer_down)
}
update_input :: proc(input: ^Input, dt: f32) {
	return
}

on_pointer_down :: proc(e: js.Event) {
	fmt.println("click")
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	fmt.println(e.key.code)
}

