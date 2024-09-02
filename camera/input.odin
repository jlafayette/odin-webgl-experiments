package camera

import "core:math"
import "vendor:wasm/js"
import glm "core:math/linalg/glsl"
import "../shared/gamepad"

g_fov : f32 = glm.radians_f32(45)
g_wheel : f32 = 0
g_camera_pos   : glm.vec3 = {0, 0, 3}
g_camera_front : glm.vec3 = {0, 0, -1}
g_camera_up    : glm.vec3 = {0, 1, 0}
g_time : f32 = 0
g_has_focus : bool = true

update :: proc(dt: f32) {
	g_time += dt
	camera_speed := 2.5 * dt
	
	if gamepad.SIZE > 0 && gamepad.POINTER.connected {
		gp := gamepad.POINTER
		state.rotation += dt + (dt * gp.buttons[6].value) + (dt * gp.buttons[7].value)

		// prev
		// g_camera_pos.x += dt * gp.axes[0]
		// g_camera_pos.y += dt * -gp.axes[1]
		// g_camera_pos.z += (dt * gp.buttons[6].value) + (dt * -gp.buttons[7].value)
		
		// forward and backwards
		g_camera_pos += -gp.axes[1] * camera_speed * g_camera_front
		// strafe (side to side)
		g_camera_pos += gp.axes[0] * glm.normalize(glm.cross(g_camera_front, g_camera_up)) * camera_speed
		
	} else {
		state.rotation += dt
	}

	// keyboard inputs
	forward : f32 = 0
	if g_key_forward { forward += 1 }
	if g_key_back { forward -= 1 }
	strafe : f32 = 0
	if g_key_left { strafe -= 1 }
	if g_key_right { strafe += 1 }
	g_camera_pos += forward * camera_speed * g_camera_front
	g_camera_pos += strafe * camera_speed * glm.normalize(glm.cross(g_camera_front, g_camera_up))
	
	g_fov += g_wheel * dt
	g_wheel = 0
}

on_wheel :: proc(e: js.Event) {
	change := cast(f32)e.wheel.delta.y
}
g_key_forward : bool
g_key_back : bool
g_key_left : bool
g_key_right : bool
on_key_down :: proc(e: js.Event) {
	if e.key.code == "KeyW" { g_key_forward = true }
	if e.key.code == "KeyS" { g_key_back    = true }
	if e.key.code == "KeyA" { g_key_left    = true }
	if e.key.code == "KeyD" { g_key_right   = true }
}
on_key_up :: proc(e: js.Event) {
	if e.key.code == "KeyW" { g_key_forward = false }
	if e.key.code == "KeyS" { g_key_back    = false }
	if e.key.code == "KeyA" { g_key_left    = false }
	if e.key.code == "KeyD" { g_key_right   = false }
}
on_blur :: proc(e: js.Event) {
	g_key_forward = false
	g_key_back = false
	g_key_left = false
	g_key_right = false
	g_has_focus = false
}
on_focus :: proc(e: js.Event) {
	g_has_focus = true
}

setup_event_listeners :: proc() {
	js.add_window_event_listener(.Wheel, {}, on_wheel)
	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Key_Up, {}, on_key_up)
	js.add_window_event_listener(.Focus, {}, on_focus)
	js.add_window_event_listener(.Blur, {}, on_blur)
}

