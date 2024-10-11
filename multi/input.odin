package multi

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"

Input :: struct {
	cycle_texture: bool,
	cycle_geo:     bool,
	cycle_shader:  bool,
	mouse_diff:    glm.vec2,
	camera_pos:    glm.vec3,
}
g_input := Input{}
camera_distance :: 5

init_input :: proc(input: ^Input) {
	input.camera_pos = {0, 0, camera_distance}
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	// js.add_window_event_listener(.Touch_Start, {}, on_touch_start)
	// js.add_window_event_listener(.Touch_End, {}, on_touch_end)
	// js.add_window_event_listener(.Touch_Move, {}, on_touch_move)
	// js.add_window_event_listener(.Touch_Cancel, {}, on_touch_cancel)

	js.add_window_event_listener(.Pointer_Move, {}, on_pointer_move)
	js.add_window_event_listener(.Pointer_Down, {}, on_pointer_down)
	js.add_window_event_listener(.Pointer_Up, {}, on_pointer_up)
}
update_input :: proc(
	input: ^Input,
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

	// mouse x -> pos dot product of camera_pos->origin and origin->up 
	// fmt.println(input.mouse_diff)
	sensitivity: f32 = 1.0
	xvec := glm.normalize(glm.cross_vec3(input.camera_pos, {0, 1, 0}))
	yvec := glm.normalize(glm.cross_vec3(input.camera_pos, xvec))
	xvec = xvec * input.mouse_diff.x * dt * sensitivity
	yvec = yvec * -input.mouse_diff.y * dt * sensitivity
	input.camera_pos = input.camera_pos + xvec + yvec
	input.mouse_diff = {0, 0}

	input.camera_pos = glm.normalize(input.camera_pos) * camera_distance
	// view_matrix := glm.mat4LookAt(input.camera_pos, {0, 0, 0}, {0, 1, 0})

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

_pointer_down: bool = false
on_pointer_move :: proc(e: js.Event) {
	if e.pointer.is_primary && _pointer_down {
		movement := e.pointer.movement
		g_input.mouse_diff += {f32(movement.x), f32(movement.y)}
	}
}
on_pointer_up :: proc(e: js.Event) {
	if e.pointer.is_primary {
		_pointer_down = false
	}
}
on_pointer_down :: proc(e: js.Event) {
	if e.pointer.is_primary {
		_pointer_down = true
	}
}

// on_touch_start :: proc(e: js.Event) {
// }
// on_touch_end :: proc(e: js.Event) {
// }
// on_touch_move :: proc(e: js.Event) {
// }
// on_touch_cancel :: proc(e: js.Event) {
// }

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

