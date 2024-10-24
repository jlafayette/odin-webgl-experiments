package camera

import "../shared/gamepad"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:sys/wasm/js"

g_camera_pos: glm.vec3 = {0, 0, 3}
g_camera_front: glm.vec3 = {0, 0, -1}
g_camera_up: glm.vec3 = {0, 1, 0}
g_camera_vel: glm.vec3
g_time: f32 = 0
g_has_focus: bool = true
g_yaw: f32 = -90
g_pitch: f32 = 0
g_input_mode: InputMode

InputMode :: enum {
	MouseKeyboard,
	Gamepad,
}

deadzone :: proc(v: f32) -> f32 {
	if math.abs(v) < 0.1 {return 0} else {return v}
}
update :: proc(dt: f32) {
	g_time += dt
	camera_acc: glm.vec3

	gp := gamepad.get_input()
	if gp.connected {
		// Detect if gamepad has input for input mode
		for btn in gp.buttons {
			if btn.pressed || btn.touched {
				g_input_mode = .Gamepad
				break
			}
		}
		for axis in gp.axes {
			if math.abs(axis) > 0.1 {
				g_input_mode = .Gamepad
				break
			}
		}

		state.rotation += dt + (dt * gp.buttons[6].value) + (dt * gp.buttons[7].value)
		g_fov += dt * (gp.buttons[6].value - gp.buttons[7].value)

		// forward and backwards
		camera_acc += deadzone(-gp.axes[1]) * g_camera_front
		// strafe (side to side)
		camera_acc += deadzone(gp.axes[0]) * glm.normalize(glm.cross(g_camera_front, g_camera_up))
		// yaw and pitch
		sensitivity: f32 = 100
		g_yaw += deadzone(gp.axes[2]) * dt * sensitivity
		g_pitch += deadzone(-gp.axes[3]) * dt * sensitivity
	} else {
		state.rotation += dt
	}

	// keyboard inputs
	forward: f32 = 0
	if g_key_forward {forward += 1}
	if g_key_back {forward -= 1}
	strafe: f32 = 0
	if g_key_left {strafe -= 1}
	if g_key_right {strafe += 1}
	camera_acc += forward * g_camera_front
	camera_acc += strafe * glm.normalize(glm.cross(g_camera_front, g_camera_up))

	// position += velocity * delta + acceleration * delta * delta * 0.5
	max_speed: f32 = 100
	drag: f32 = 0.995
	multiplier: f32 = 35
	acc: glm.vec3 = camera_acc * dt * multiplier
	g_camera_vel += acc
	g_camera_vel *= drag
	if glm.length(g_camera_vel) > max_speed {
		g_camera_vel *= max_speed / glm.length(g_camera_vel)
	}
	g_camera_pos += g_camera_vel * dt + camera_acc * dt * dt * 0.5
	fmt.printf("vel: %.2f, acc: %.2f\n", glm.length(g_camera_vel), glm.length(acc))

	// mouse inputs (yaw and pitch)
	sensitivity: f32 = 5
	// fmt.println(g_mouse_diff)
	g_yaw += g_mouse_diff.x * dt * sensitivity
	g_pitch += -g_mouse_diff.y * dt * sensitivity
	// reset so mouse doesn't drift. This is required since this is only
	// set in on_mouse_move handler which won't fire on mouse stopping to
	// update it to 0,0
	g_mouse_diff = {0, 0}

	// rotate camera
	if g_pitch > 89.9 {g_pitch = 89.9}
	if g_pitch < -89.9 {g_pitch = -89.9}
	yaw := glm.radians(g_yaw)
	pitch := glm.radians(g_pitch)
	dir: glm.vec3 = {0, 0, 0}
	dir.x = math.cos(yaw) * math.cos(pitch)
	dir.y = math.sin(pitch)
	dir.z = math.sin(yaw) * math.cos(pitch)
	g_camera_front = glm.normalize(dir)

	// fov control
	g_fov += g_wheel * dt
	g_wheel = 0
}

g_mouse_diff: glm.vec2
on_mouse_move :: proc(e: js.Event) {
	movement := e.mouse.movement
	g_mouse_diff = {f32(movement.x), f32(movement.y)}
	g_input_mode = .MouseKeyboard
}
g_fov: f32 = glm.radians_f32(45)
g_wheel: f32 = 0
on_wheel :: proc(e: js.Event) {
	change := cast(f32)e.wheel.delta.y
	g_wheel += change / 100
	g_input_mode = .MouseKeyboard
}
g_key_forward: bool
g_key_back: bool
g_key_left: bool
g_key_right: bool
on_key_down :: proc(e: js.Event) {
	if e.key.code == "KeyW" {g_key_forward = true}
	if e.key.code == "KeyS" {g_key_back = true}
	if e.key.code == "KeyA" {g_key_left = true}
	if e.key.code == "KeyD" {g_key_right = true}
	g_input_mode = .MouseKeyboard
}
on_key_up :: proc(e: js.Event) {
	if e.key.code == "KeyW" {g_key_forward = false}
	if e.key.code == "KeyS" {g_key_back = false}
	if e.key.code == "KeyA" {g_key_left = false}
	if e.key.code == "KeyD" {g_key_right = false}
	g_input_mode = .MouseKeyboard
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
	js.add_window_event_listener(.Mouse_Move, {}, on_mouse_move)
	js.add_window_event_listener(.Focus, {}, on_focus)
	js.add_window_event_listener(.Blur, {}, on_blur)
}

