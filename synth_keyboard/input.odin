package synth_keyboard

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

Key :: struct {
	pos: []f32,
	w:   f32,
	h:   f32,
}
Input :: struct {
	keys_down: []bool,
	clicked:   bool,
	mouse_key: int,
	mouse_pos: [2]f32,
}
g_input := Input{}

MousePosInterface :: struct {
	x: f32,
	y: f32,
}
MOUSE_POS_PTR: ^MousePosInterface
MOUSE_POS_SIZE: i32

@(export)
mouse_pos_alloc :: proc() -> ^MousePosInterface {
	mouse_pos := new(MousePosInterface)
	MOUSE_POS_PTR = mouse_pos
	MOUSE_POS_SIZE = size_of(MousePosInterface)
	return mouse_pos
}
@(export)
mouse_pos_x_offset :: proc() -> i32 {
	return cast(i32)offset_of(MousePosInterface, x)
}
@(export)
mouse_pos_y_offset :: proc() -> i32 {
	return cast(i32)offset_of(MousePosInterface, y)
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
	if MOUSE_POS_SIZE > 0 {
		mouse_pos := MOUSE_POS_PTR
		g_input.mouse_pos.x = mouse_pos.x
		g_input.mouse_pos.y = mouse_pos.y
	}
	// if clicked and within key, mark that key as down
	// and mark mouse key so it can be released
}

on_mouse_move :: proc(e: js.Event) {
	// movement := e.mouse.movement
	// mouse_diff := {f32(movement.x), f32(movement.y)}
	// fmt.println("mouse screen:", e.mouse.screen)
	// fmt.println("mouse client:", e.mouse.client)
	fmt.println("(odin) mouse pos:", g_input.mouse_pos)
}

on_mouse_down :: proc(e: js.Event) {
	fmt.println("click:", e.mouse.button)
	if e.mouse.button != 0 {
		return
	}
	g_input.clicked = true
}
on_mouse_up :: proc(e: js.Event) {
	fmt.println("unclick:", e.mouse.button)
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
}

