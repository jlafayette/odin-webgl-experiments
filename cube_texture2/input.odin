package cube_texture2

import "core:fmt"
import glm "core:math/linalg/glsl"
import "vendor:wasm/js"

Input :: struct {
	cycle_texture: bool,
	cycle_geo:     bool,
	mouse_diff:    glm.vec2,
	camera_pos:    glm.vec3,
}
g_input := Input{}
camera_distance :: 5

init_input :: proc(input: ^Input) {
	input.camera_pos = {0, 0, camera_distance}
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
}
update_input :: proc(input: ^Input, dt: f32) {

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
		current := state.current_texture
		new: TextureId
		if current == .Odin {
			new = .Uv
		} else if current == .Uv {
			new = .Odin
		}
		state.current_texture = new
		input.cycle_texture = false
	}
	if input.cycle_geo {
		current := state.current_geo
		new: GeoId
		if current == .Cube {
			new = .Pyramid
		} else if current == .Pyramid {
			new = .Cube
		}
		state.current_geo = new
		input.cycle_geo = false
	}
}

on_mouse_move :: proc(e: js.Event) {
	movement := e.mouse.movement
	g_input.mouse_diff = {f32(movement.x), f32(movement.y)}
}

on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code == "KeyT" {
		g_input.cycle_texture = true
	} else if e.key.code == "KeyG" {
		g_input.cycle_geo = true
	}
}

