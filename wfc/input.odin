package wfc

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"

Input :: struct {
	quit:        bool,
	next_step:   bool,
	play_toggle: bool,
	restart:     bool,
	restart_at:  Maybe([2]i64),
	play:        bool,
}
g_input := Input{}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Pointer_Down, {}, on_pointer_down)
}
update_input :: proc(input: ^Input, dt: f32) {
	return
}

on_pointer_down :: proc(e: js.Event) {
	g_input.restart = true
	g_input.restart_at = e.pointer.client
	g_input.play = true
	fmt.println("click")
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	fmt.println(e.key.code)
	switch e.key.code {
	case "KeyD":
		g_input.next_step = true
	case "KeyR":
		g_input.restart = true
	case "Space":
		g_input.play_toggle = true
	}
}

