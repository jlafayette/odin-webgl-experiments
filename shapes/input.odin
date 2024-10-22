package shapes

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"


DynamicValue :: struct {
	min:   f32,
	max:   f32,
	step:  f32,
	value: f32,
}
Input :: struct {
	prev_mouse_pos: glm.vec2,
	mouse_pos:      glm.vec2,
	values:         [2]DynamicValue,
	value_index:    int,
}
g_input := Input {
	values = {{-5, 5, 0.1, 0.9}, {-5, 5, 0.1, 1.2}},
}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)

	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Mouse_Down, {}, on_mouse_down)
	js.add_window_event_listener(.Mouse_Up, {}, on_mouse_up)
	js.add_window_event_listener(.Wheel, {}, on_mouse_wheel)
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
on_mouse_wheel :: proc(e: js.Event) {
	fmt.println("wheel:", e.wheel.delta)
	dv: ^DynamicValue = &g_input.values[g_input.value_index]
	dv.value += math.round(f32(e.wheel.delta.y) / 100) * dv.step
	dv.value = math.clamp(dv.value, dv.min, dv.max)
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
	fmt.println(e.key.code)
	if e.key.code == "ControlLeft" {
		g_input.value_index = (g_input.value_index + 1) % 2
	}
}

