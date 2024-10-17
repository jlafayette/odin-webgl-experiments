package multi

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"

Touch :: struct {
	id:         i32,
	client_pos: glm.vec2,
}
Mode :: enum {
	KEYBOARD_MOUSE,
	TOUCH,
}

Input :: struct {
	cycle_texture:   bool,
	cycle_geo:       bool,
	cycle_shader:    bool,
	prev_mouse_pos:  glm.vec2,
	mouse_pos:       glm.vec2,
	camera_pos:      glm.vec3,
	camera_distance: f32,
	touch_count:     int,
	prev_touches:    [16]Touch,
	touches:         [16]Touch,
	mode:            Mode,
}
g_input := Input {
	camera_distance = 5,
}

init_input :: proc(input: ^Input) {
	input.camera_pos = {0, 0, input.camera_distance}
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Touch_Start, {}, on_touch_start)
	js.add_window_event_listener(.Touch_End, {}, on_touch_end)
	js.add_window_event_listener(.Touch_Move, {}, on_touch_move)
	js.add_window_event_listener(.Touch_Cancel, {}, on_touch_cancel)

	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Mouse_Down, {}, on_mouse_down)
	js.add_window_event_listener(.Mouse_Up, {}, on_mouse_up)
	for &touch in input.touches {
		touch.id = -1
	}
	for &touch in input.prev_touches {
		touch.id = -1
	}
}
update_input :: proc(
	input: ^Input,
	w: i32,
	h: i32,
	dt: f32,
	current_texture: TextureId,
	current_geo: GeoId,
	current_shader: ShaderId,
) -> (
	new_texture: TextureId,
	new_geo: GeoId,
	new_shader: ShaderId,
) {
	new_texture = current_texture
	new_geo = current_geo
	new_shader = current_shader

	g_input.mode = detect_mode()
	rotate_diff: glm.vec2
	sensitivity: f32
	switch g_input.mode {
	case .KEYBOARD_MOUSE:
		{
			rotate_diff = mouse_movement()
			sensitivity = 0.03
		}
	case .TOUCH:
		{
			rotate_diff = touch_movement()
			sensitivity = 0.05
		}
	}
	// mouse x -> pos dot product of camera_pos->origin and origin->up 
	// fmt.println(input.mouse_diff)
	xvec := glm.normalize(glm.cross_vec3(input.camera_pos, {0, 1, 0}))
	yvec := glm.normalize(glm.cross_vec3(input.camera_pos, xvec))
	xvec = xvec * rotate_diff.x * sensitivity
	yvec = yvec * -rotate_diff.y * sensitivity
	input.camera_pos = input.camera_pos + xvec + yvec
	input.camera_pos = glm.normalize(input.camera_pos) * input.camera_distance
	// view_matrix := glm.mat4LookAt(input.camera_pos, {0, 0, 0}, {0, 1, 0})

	// book-keeping
	input.prev_mouse_pos = input.mouse_pos
	input.prev_touches = input.touches

	if input.cycle_texture {
		current := current_texture
		new: TextureId
		if current == .Odin {
			new = .Uv
		} else if current == .Uv {
			new = .Odin
		}
		new_texture = new
		input.cycle_texture = false
	}
	if input.cycle_geo {
		current := current_geo
		new: GeoId
		switch current {
		case .Cube:
			new = .Pyramid
		case .Pyramid:
			new = .Icosphere0
		case .Icosphere0:
			new = .Icosphere1
		case .Icosphere1:
			new = .Icosphere2
		case .Icosphere2:
			new = .Icosphere3
		case .Icosphere3:
			new = .Icosphere4
		case .Icosphere4:
			new = .Cube
		}
		new_geo = new
		input.cycle_geo = false
	}
	if input.cycle_shader {
		current := current_shader
		new: ShaderId
		if current == .Cube {
			new = .Lighting
		} else if current == .Lighting {
			new = .Cube
		}
		new_shader = new
		input.cycle_shader = false
	}
	return
}

// _pointer_down: bool = false
// on_pointer_move :: proc(e: js.Event) {
// 	fmt.println("o pointer move")
// 	if e.pointer.is_primary && _pointer_down {
// 		movement := e.pointer.movement
// 		g_input.mouse_diff += {f32(movement.x), f32(movement.y)}
// 	}
// }
// on_pointer_up :: proc(e: js.Event) {
// 	fmt.println("o pointer up")
// 	if e.pointer.is_primary {
// 		_pointer_down = false
// 	}
// }
// on_pointer_down :: proc(e: js.Event) {
// 	fmt.println("o pointer down")
// 	if e.pointer.is_primary {
// 		_pointer_down = true
// 	}
// }

_mouse_down: bool = false
on_mouse_move :: proc(e: js.Event) {
	// fmt.println("o mouse move")
	if e.mouse.button == 0 && _mouse_down {
		g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
	}
}
on_mouse_up :: proc(e: js.Event) {
	// fmt.println("o mouse up")
	if e.mouse.button == 0 {
		g_input.prev_mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		_mouse_down = false
	}
}
on_mouse_down :: proc(e: js.Event) {
	// fmt.println("o mouse down")
	if e.mouse.button == 0 {
		g_input.prev_mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		g_input.mouse_pos = {f32(e.mouse.client.x), f32(e.mouse.client.y)}
		_mouse_down = true
	}
}

mouse_movement :: proc() -> glm.vec2 {
	m1 := g_input.mouse_pos
	m2 := g_input.prev_mouse_pos
	return m1 - m2
}

detect_mode :: proc() -> Mode {
	for t in g_input.touches {
		if glm.length(t.client_pos) > 0.0001 {
			return .TOUCH
		}
	}
	return .KEYBOARD_MOUSE
}

touch_movement :: proc() -> glm.vec2 {
	movement: glm.vec2
	for t1, i in g_input.touches {
		t2 := g_input.prev_touches[i]
		if i < g_input.touch_count && t1.id >= 0 && t2.id >= 0 {
			diff := t1.client_pos - t2.client_pos
			if glm.length(diff) > glm.length(movement) {
				movement = diff
			}
		} else {
			break
		}
	}
	return movement
}

copy_touches :: proc(touch_count: int, touches: [16]js.Touch) {
	for touch, i in touches {
		if i < touch_count {
			g_input.touches[i].client_pos = {f32(touch.client.x), f32(touch.client.y)}
			g_input.touches[i].id = i32(touch.identifier)
		} else {
			g_input.touches[i].client_pos = 0
			g_input.touches[i].id = -1
		}
	}
	g_input.touch_count = touch_count
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

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code == "KeyT" {
		g_input.cycle_texture = true
	} else if e.key.code == "KeyG" {
		g_input.cycle_geo = true
	} else if e.key.code == "KeyS" {
		g_input.cycle_shader = true
	}
}

