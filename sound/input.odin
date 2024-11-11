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
	pointer_pos:   [2]f32,
	click_events:  [4]ClickEvent,
	click_event_i: int,
	enable_pan:    bool,
}
g_input := Input{}


init_input :: proc(input: ^Input, number_of_keys: int) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Key_Up, {}, on_key_up)
	js.add_window_event_listener(.Pointer_Move, {}, on_pointer_move)
	js.add_window_event_listener(.Pointer_Down, {}, on_pointer_down)
	js.add_window_event_listener(.Pointer_Up, {}, on_pointer_up)
	js.add_window_event_listener(.Blur, {}, on_blur)
	input.pointer = .Hover
}

update_input :: proc(input: ^Input, ui: ^Ui, dt: f32, dpr: f32) {

	// TODO: change cursor when hovering over some ui elements
	//       https://stackoverflow.com/questions/31495344/change-cursor-depending-on-section-of-canvas	

	pointer_pos: [2]i32 = i_(input.pointer_pos * dpr)
	new_i := -1
	for &btn, i in ui.buttons {
		btn.pointer = .None
		btn.fire_down_command = false
		btn.fire_up_command = false
		if button_contains_pos(btn, pointer_pos) {
			btn.pointer = input.pointer
		}
	}
	ui.slider.pointer = .None
	if slider_contains_pos(ui.slider, pointer_pos) {
		ui.slider.pointer = input.pointer
		if input.pointer == .Down {
			ui.slider.drag = true
		}
	}
	ui.checkbox.pointer = .None
	if checkbox_contains_pos(ui.checkbox, pointer_pos) {
		ui.checkbox.pointer = input.pointer
	}
	if input.pointer == .Down {
		if ui.slider.drag {
			slider_drag_to(&ui.slider, pointer_pos)
		}
	} else {
		ui.slider.drag = false
	}
	for me, i in input.click_events {
		if i >= input.click_event_i {
			break
		}
		pos: [2]i32 = i_(me.pos * dpr)
		for &btn in ui.buttons {
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
		if checkbox_contains_pos(ui.checkbox, pos) {
			#partial switch me.type {
			case .DOWN:
				ui.checkbox.value = !ui.checkbox.value
			}
		}
	}
	if input.pointer == .Up {
		input.pointer = .Hover
	}
	input.click_event_i = 0
}

on_pointer_move :: proc(e: js.Event) {
	g_input.pointer_pos = {f32(e.pointer.client.x), f32(e.pointer.client.y)}
}

_record_pointer_click :: proc(pos: [2]f32, type: ClickType) {
	i := g_input.click_event_i
	if i < len(g_input.click_events) {
		g_input.click_events[i] = ClickEvent({pos, type})
		g_input.click_event_i += 1
	}
}

on_pointer_down :: proc(e: js.Event) {
	if !e.pointer.is_primary {
		return
	}
	g_input.pointer = .Down
	_record_pointer_click({f32(e.pointer.client.x), f32(e.pointer.client.y)}, .DOWN)
}
on_pointer_up :: proc(e: js.Event) {
	// fmt.println("unclick:", e.mouse.button)
	if !e.pointer.is_primary {
		return
	}
	g_input.pointer = .Up
	_record_pointer_click({f32(e.pointer.client.x), f32(e.pointer.client.y)}, .UP)
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

