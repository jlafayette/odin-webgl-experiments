package game

foreign import odin_mouse "odin_mouse"

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
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
	primary_down: bool,
	draw_mode:    DrawMode,
	cursor_size:  int,
	key_down:     [Key]bool,
}
Key :: enum {
	LF_1,
	LF_2,
	RT_1,
	RT_2,
	UP_1,
	UP_2,
	DN_1,
	DN_2,
	CAMERA_MODE_TOGGLE,
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

update_camera :: proc(dt: f32, vel: ^[2]f32, pos: ^[2]f32, key_state: [Key]bool) {
	acc: [2]f32
	acc_change: f32 = 120 * dt
	if key_state[.LF_1] || key_state[.LF_2] {
		acc.x -= acc_change
	}
	if key_state[.RT_1] || key_state[.RT_2] {
		acc.x += acc_change
	}
	if key_state[.UP_1] || key_state[.UP_2] {
		acc.y -= acc_change
	}
	if key_state[.DN_1] || key_state[.DN_2] {
		acc.y += acc_change
	}
	vel^ += acc
	vel^ *= {0.6, 0.6}
	max_speed: f32 = 1200 * dt
	vel.x = math.min(max_speed, vel.x)
	vel.y = math.min(max_speed, vel.y)
	if glm.length(vel^) < 0.01 {
		vel^ = {0, 0}
	}
	pos^ += vel^
	// fmt.println(pos^, vel^, acc)
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code == "Space" {
		event_add(EventResetDebugFirst{})
		event_add(EventInputKey{.CAMERA_MODE_TOGGLE, true})
	} else if e.key.code == "ControlLeft" {
		event_add(EventDrawModeChange{.REMOVE})
	} else if e.key.code == "Equal" || e.key.code == "BracketRight" {
		event_add(EventCursorSizeChange{1})
	} else if e.key.code == "Minus" || e.key.code == "BracketLeft" {
		event_add(EventCursorSizeChange{-1})
	} else if e.key.code == "KeyA" {
		event_add(EventInputKey{.LF_1, true})
	} else if e.key.code == "KeyD" {
		event_add(EventInputKey{.RT_1, true})
	} else if e.key.code == "KeyW" {
		event_add(EventInputKey{.UP_1, true})
	} else if e.key.code == "KeyS" {
		event_add(EventInputKey{.DN_1, true})
	} else if e.key.code == "ArrowLeft" {
		event_add(EventInputKey{.LF_2, true})
	} else if e.key.code == "ArrowRight" {
		event_add(EventInputKey{.RT_2, true})
	} else if e.key.code == "ArrowUp" {
		event_add(EventInputKey{.UP_2, true})
	} else if e.key.code == "ArrowDown" {
		event_add(EventInputKey{.DN_2, true})
	}
	fmt.println(e.key.code, "down")
}
on_key_up :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code == "ControlLeft" {
		event_add(EventDrawModeChange{.ADD})
	} else if e.key.code == "Space" {
		event_add(EventInputKey{.CAMERA_MODE_TOGGLE, false})
	} else if e.key.code == "KeyA" {
		event_add(EventInputKey{.LF_1, false})
	} else if e.key.code == "KeyD" {
		event_add(EventInputKey{.RT_1, false})
	} else if e.key.code == "KeyW" {
		event_add(EventInputKey{.UP_1, false})
	} else if e.key.code == "KeyS" {
		event_add(EventInputKey{.DN_1, false})
	} else if e.key.code == "ArrowLeft" {
		event_add(EventInputKey{.LF_2, false})
	} else if e.key.code == "ArrowRight" {
		event_add(EventInputKey{.RT_2, false})
	} else if e.key.code == "ArrowUp" {
		event_add(EventInputKey{.UP_2, false})
	} else if e.key.code == "ArrowDown" {
		event_add(EventInputKey{.DN_2, false})
	}
}

on_blur :: proc(e: js.Event) {
	event_add(EventFocusLost{})
}
on_focus :: proc(e: js.Event) {
	event_add(EventFocusGained{})
}

