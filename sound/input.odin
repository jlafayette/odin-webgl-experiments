package sound

foreign import odin_mouse "odin_mouse"

import "core:fmt"
import "core:sys/wasm/js"

ClickType :: enum {
	DOWN,
	UP,
}
ClickEvent :: struct {
	pos:  [2]f32,
	type: ClickType,
}
Input :: struct {
	pointer:       PointerState,
	mouse_pos:     [2]f32,
	click_events:  [4]ClickEvent,
	click_event_i: int,
	enable_pan:    bool,
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
		btn.fire_down_command = false
		btn.fire_up_command = false
		if button_contains_pos(btn, i_(input.mouse_pos)) {
			btn.pointer = input.pointer
		}
	}
	for me, i in input.click_events {
		if i >= input.click_event_i {
			break
		}
		pos: [2]i32 = i_(me.pos * dpr)
		for &btn in buttons {
			if button_contains_pos(btn, pos) {
				switch me.type {
				case .DOWN:
					btn.fire_down_command = true
				case .UP:
					btn.fire_up_command = true
				}
				break
			}
		}
	}
	if input.pointer == .Up {
		input.pointer = .Hover
	}
	input.click_event_i = 0
}

on_mouse_move :: proc(e: js.Event) {
	g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
}

_record_mouse_click :: proc(pos: [2]f32, type: ClickType) {
	i := g_input.click_event_i
	if i < len(g_input.click_events) {
		g_input.click_events[i] = ClickEvent({pos, type})
		g_input.click_event_i += 1
	}
}

on_mouse_down :: proc(e: js.Event) {
	// fmt.println("click:", e.mouse.button)
	if e.mouse.button != 0 {
		return
	}
	g_input.pointer = .Down
	_record_mouse_click({f32(e.mouse.client.x), f32(e.mouse.client.y)}, .DOWN)
}
on_mouse_up :: proc(e: js.Event) {
	// fmt.println("unclick:", e.mouse.button)
	if e.mouse.button != 0 {
		return
	}
	g_input.pointer = .Up
	_record_mouse_click({f32(e.mouse.client.x), f32(e.mouse.client.y)}, .UP)
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	// fmt.println(e.key.code)
	if e.key.code == "ControlLeft" {
		g_input.enable_pan = true
	}
}
on_key_up :: proc(e: js.Event) {
	if e.key.code == "ControlLeft" {
		g_input.enable_pan = false
	}
}

on_blur :: proc(e: js.Event) {
	g_input.pointer = .Hover
}

