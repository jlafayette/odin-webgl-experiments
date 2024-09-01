package input

import "core:fmt"
import "core:math"
import "vendor:wasm/js"
import gamepad "../shared/gamepad"

KeysDown :: struct {
	w: bool,
	a: bool,
	s: bool,
	d: bool,
	lf: bool,
	rt: bool,
	up: bool,
	dn: bool,
	turbo: bool,
}
Input :: struct {
	mouse_left_down: bool,
	has_focus: bool,
	just_lost_focus: bool,
	zoom: f32,
	pos: [2]f32,
	keys_down: KeysDown,
}

on_mouse_down :: proc(e: js.Event) {
	switch e.mouse.button {
		case 0: state.input.mouse_left_down = true
		// right click opens menu, so left mouse
		// click up can be lost
		case 2: state.input.mouse_left_down = false
	}
}
on_mouse_up :: proc(e: js.Event) {
	if e.mouse.button == 0 {
		state.input.mouse_left_down = false
	}
}
zoom_min :: -15
zoom_max :: -0.1
on_wheel :: proc(e: js.Event) {
	// fmt.println("wheel:", e.wheel.delta, " mode:", e.wheel.delta_mode)
	y := cast(f32)e.wheel.delta.y
	y = y / 200
	// fmt.println("y:", y)
	zoom := state.input.zoom
	zoom = math.clamp(zoom + y, zoom_min, zoom_max)
	state.input.zoom = zoom
	// fmt.println(state.input.zoom)
}

on_key_down :: proc(e: js.Event) {
	if e.key.code == "KeyA" { state.input.keys_down.a = true }
	if e.key.code == "KeyD" { state.input.keys_down.d = true }
	if e.key.code == "KeyS" { state.input.keys_down.s = true }
	if e.key.code == "KeyW" { state.input.keys_down.w = true }
	if e.key.code == "ArrowLeft" {  state.input.keys_down.lf = true }
	if e.key.code == "ArrowRight" { state.input.keys_down.rt = true }
	if e.key.code == "ArrowDown" {  state.input.keys_down.dn = true }
	if e.key.code == "ArrowUp" {    state.input.keys_down.up = true }
	if e.key.code == "ShiftLeft" {    state.input.keys_down.turbo = true }
}
on_key_up :: proc(e: js.Event) {
	if e.key.code == "KeyA" { state.input.keys_down.a = false }
	if e.key.code == "KeyD" { state.input.keys_down.d = false }
	if e.key.code == "KeyS" { state.input.keys_down.s = false }
	if e.key.code == "KeyW" { state.input.keys_down.w = false }
	if e.key.code == "ArrowLeft" {  state.input.keys_down.lf = false }
	if e.key.code == "ArrowRight" { state.input.keys_down.rt = false }
	if e.key.code == "ArrowDown" {  state.input.keys_down.dn = false }
	if e.key.code == "ArrowUp" {    state.input.keys_down.up = false }
	if e.key.code == "ShiftLeft" {    state.input.keys_down.turbo = false }
}

on_window_focus :: proc(e: js.Event) {
	state.input.has_focus = true
	state.input.mouse_left_down = false
}
on_window_blur :: proc(e: js.Event) {
	state.input.has_focus = false
	state.input.just_lost_focus = true
	state.input.mouse_left_down = false
	state.input.keys_down = KeysDown{}
}
update :: proc(dt: f32) {
	input := state.input
	if input.mouse_left_down {
		state.rotation += dt * 0.1
	} else {
		state.rotation += dt
	}
	pos := input.pos
	if gamepad.SIZE > 0 && gamepad.POINTER.connected {
		gp := gamepad.POINTER
		// move with left stick (left trigger is turbo)
		{
			delta := dt * 2
			turbo := (gp.buttons[6].value * 4) + 1
			delta *= turbo
			stick : [2]f32 = {gp.axes[0], -1 * gp.axes[1]}
			pos += delta * stick
		}
		// zoom with right stick
		{
			stick : [2]f32 = {gp.axes[2], gp.axes[3]}
			y := dt * stick.y * 2
			zoom := state.input.zoom
			zoom = math.clamp(zoom + y, zoom_min, zoom_max)
			state.input.zoom = zoom
		}
	}
	// could turn off key input if also recieving gamepad
	// input or limit the total input from both sources
	// (if we actually cared that we weren't doubling input)
	delta := dt * 2
	if input.keys_down.turbo {
		delta *= 5
	}
	if input.keys_down.a || input.keys_down.lf {
		pos.x -= delta
	}
	if input.keys_down.d || input.keys_down.rt {
		pos.x += delta
	}
	if input.keys_down.w || input.keys_down.up {
		pos.y += delta
	}
	if input.keys_down.s || input.keys_down.dn {
		pos.y -= delta
	}
	pos.x = math.clamp(pos.x, -3, 3)
	pos.y = math.clamp(pos.y, -2, 2)
	state.input.pos = pos
}

register_event_listeners :: proc() {
	js.add_window_event_listener(.Mouse_Down, {}, on_mouse_down)
	js.add_window_event_listener(.Mouse_Up, {}, on_mouse_up)
	js.add_window_event_listener(.Wheel, {}, on_wheel)

	js.add_window_event_listener(.Key_Down, {}, on_key_down)
	js.add_window_event_listener(.Key_Up, {}, on_key_up)
	
	js.add_window_event_listener(.Focus, {}, on_window_focus)
	js.add_window_event_listener(.Blur, {}, on_window_blur)
}

