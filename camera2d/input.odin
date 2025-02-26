package game

foreign import odin_mouse "odin_mouse"

import "core:fmt"
import "core:math"
import "core:sys/wasm/js"

ClickType :: enum {
	DOWN,
	UP,
}
ScreenPixelPos :: [2]int
PixelPos :: [2]int
ClickEvent :: struct {
	pos:  ScreenPixelPos,
	type: ClickType,
}
DrawMode :: enum {
	ADD,
	REMOVE,
}
Input :: struct {
	pointer_pos:  PixelPos,
	enable_pan:   bool,
	primary_down: bool,
	draw_mode:    DrawMode,
	cursor_size:  int,
	ui_blocks:    bool,
}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Key_Up, {}, on_key_up)
	js.add_window_event_listener(.Pointer_Move, {}, on_pointer_move)
	js.add_window_event_listener(.Pointer_Down, {}, on_pointer_down)
	js.add_window_event_listener(.Pointer_Up, {}, on_pointer_up)
	js.add_window_event_listener(.Wheel, {}, on_wheel)
	js.add_window_event_listener(.Blur, {}, on_blur)
	js.add_window_event_listener(.Focus, {}, on_focus)
	input.draw_mode = .ADD
	input.cursor_size = 5
}
_dpr: f32 = 1

update_input :: proc(dpr: f32) {
	_dpr = dpr
	// TODO: change cursor when hovering over some ui elements
	//       https://stackoverflow.com/questions/31495344/change-cursor-depending-on-section-of-canvas	
}

on_pointer_move :: proc(e: js.Event) {
	pos := i_(f_i64(e.pointer.client) * _dpr)
	event_add(EventPointerMove{pos})
}

on_pointer_down :: proc(e: js.Event) {
	if !e.pointer.is_primary {
		return
	}
	px: ScreenPixelPos = i_(f_i64(e.pointer.client) * _dpr)
	event_add(EventPointerClick{pos = px, type = .DOWN})
}
on_pointer_up :: proc(e: js.Event) {
	if !e.pointer.is_primary {
		return
	}
	px: ScreenPixelPos = i_(f_i64(e.pointer.client) * _dpr)
	event_add(EventPointerClick{pos = px, type = .UP})
}

on_wheel :: proc(e: js.Event) {
	// fmt.println("wheel:", e.wheel.delta, " mode:", e.wheel.delta_mode)
	if e.wheel.delta.y < 0 {
		event_add(EventCursorSizeChange{1})
	} else if e.wheel.delta.y > 0 {
		event_add(EventCursorSizeChange{-1})
	}
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code == "Space" {
		event_add(EventResetDebugFirst{})
	} else if e.key.code == "ControlLeft" {
		event_add(EventDrawModeChange{.REMOVE})
	} else if e.key.code == "Equal" || e.key.code == "BracketRight" {
		event_add(EventCursorSizeChange{1})
	} else if e.key.code == "Minus" || e.key.code == "BracketLeft" {
		event_add(EventCursorSizeChange{-1})
	}
	fmt.println(e.key.code, "down")
}
on_key_up :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code == "ControlLeft" {
		event_add(EventDrawModeChange{.ADD})
	}
}

on_blur :: proc(e: js.Event) {
	event_add(EventFocusLost{})
}
on_focus :: proc(e: js.Event) {
	event_add(EventFocusGained{})
}

