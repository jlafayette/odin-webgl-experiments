package trails

foreign import odin_mouse "odin_mouse"

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"

Touch :: struct {
	id:         i32,
	client_pos: glm.vec2,
}

Input :: struct {
	mouse_pos: [2]f32,
	mouse_vel: [2]f32,
}
ListenerInput :: struct {
	mouse_pos:      [2]f32,
	prev_mouse_pos: [2]f32,
	touch_pos:      [2]f32,
	touches:        [16]Touch,
	prev_touches:   [16]Touch,
	touch_count:    int,
}
@(private = "file")
i_: ListenerInput = {}

input_reset :: proc(li: ^ListenerInput) {
}

get_mouse_pos :: proc "contextless" (
	canvas_id: string,
	client_pos: [2]i64, // from e.mouse.client
	flip_y: bool, // if true, 0,0 is lower left instead of upper left
) -> (
	pos: [2]f32,
) {
	@(default_calling_convention = "contextless")
	foreign odin_mouse {
		@(link_name = "getMousePos")
		_getMousePos :: proc(out_pos: ^[2]f64, id: string, client_x, client_y: i64, flip_y: bool) ---
	}
	out_pos: [2]f64
	_getMousePos(&out_pos, canvas_id, client_pos.x, client_pos.y, flip_y)
	return {f32(out_pos.x), f32(out_pos.y)}
}

init_input :: proc(input: ^Input) {
	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Blur, {}, on_blur)

	js.add_window_event_listener(.Touch_Start, {}, on_touch_start)
	js.add_window_event_listener(.Touch_End, {}, on_touch_end)
	js.add_window_event_listener(.Touch_Move, {}, on_touch_move)
	js.add_window_event_listener(.Touch_Cancel, {}, on_touch_cancel)

}

// Update global gamestate with listener input
update_input :: proc(input: ^Input, dt: f32, w: i32, h: i32, dpr: f32) {
	old := input.mouse_pos
	new := input.mouse_pos

	new_mouse := i_.mouse_pos
	old_mouse := i_.prev_mouse_pos
	if glm.length(new_mouse - old_mouse) > 0.0001 {
		new = new_mouse
	}
	i_.prev_mouse_pos = i_.mouse_pos

	touch_enabled, touch_pos := touch_pos(i_.touch_count, i_.touches, i_.prev_touches)
	// fmt.println("touch pos,enabled:", touch_pos, touch_enabled)
	if touch_enabled {
		touch_pos := touch_pos * dpr
		touch_pos.y = f32(h) - touch_pos.y
		new = touch_pos
	}
	i_.prev_touches = i_.touches

	input.mouse_pos = new
	input.mouse_vel = new - old
}

on_mouse_move :: proc(e: js.Event) {
	// movement := e.mouse.movement
	// mouse_diff := {f32(movement.x), f32(movement.y)}
	pos := get_mouse_pos("canvas-1", e.mouse.client, true)
	// fmt.println("ffi pos:", pos)
	i_.mouse_pos = pos
}

on_blur :: proc(e: js.Event) {
	input_reset(&i_)
}

touch_pos :: proc(
	touch_count: int,
	touches, prev_touches: [16]Touch,
) -> (
	enabled: bool,
	pos: glm.vec2,
) {
	#reverse for t1, i in touches {
		t2 := prev_touches[i]
		if i < touch_count && t1.id >= 0 && t2.id >= 0 {
			pos = t1.client_pos
			enabled = true
		}}
	return enabled, pos
}

copy_touches :: proc(touch_count: int, touches: [16]js.Touch) {
	for touch, i in touches {
		if i < touch_count {
			i_.touches[i].client_pos = {f32(touch.client.x), f32(touch.client.y)}
			i_.touches[i].id = i32(touch.identifier)
		} else {
			i_.touches[i].client_pos = 0
			i_.touches[i].id = -1
		}
	}
	i_.touch_count = touch_count
}

on_touch_start :: proc(e: js.Event) {
	// fmt.println("o touch start")
	copy_touches(e.touch.touch_count, e.touch.touches)
}
on_touch_end :: proc(e: js.Event) {
	// fmt.println("o touch end")
	copy_touches(e.touch.touch_count, e.touch.touches)
}
on_touch_move :: proc(e: js.Event) {
	// fmt.println("o touch move")
	copy_touches(e.touch.touch_count, e.touch.touches)
}
on_touch_cancel :: proc(e: js.Event) {
	// fmt.println("o touch cancel")
	copy_touches(e.touch.touch_count, e.touch.touches)
}

