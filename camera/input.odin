package camera

import "vendor:wasm/js"
import glm "core:math/linalg/glsl"
import "../shared/gamepad"

g_fov : f32 = glm.radians_f32(45)
g_wheel : f32 = 0
g_camera_mov : glm.vec3 = {0, 0, 3}
g_time : f32 = 0

update :: proc(dt: f32) {
	g_time += dt
	
	if gamepad.SIZE > 0 && gamepad.POINTER.connected {
		gp := gamepad.POINTER
		state.rotation += dt + (dt * gp.buttons[6].value) + (dt * gp.buttons[7].value)

		g_camera_mov.x += dt * -gp.axes[0]
		g_camera_mov.y += dt * gp.axes[1]
		g_camera_mov.z += (dt * -gp.buttons[6].value) + (dt * gp.buttons[7].value)
		
	} else {
		state.rotation += dt
	}
	
	g_fov += g_wheel * dt
	g_wheel = 0

	
}

on_wheel :: proc(e: js.Event) {
	change := cast(f32)e.wheel.delta.y
	g_wheel = change / 100.0
}

setup_event_listeners :: proc() {
	js.add_window_event_listener(.Wheel, {}, on_wheel)
}

