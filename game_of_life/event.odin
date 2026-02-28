package game


import "core:fmt"
import "core:math"


EventDrawModeChange :: struct {
	new_mode: DrawMode,
}
EventCursorSizeChange :: struct {
	change: int,
}
EventGameModeChange :: struct {
	new_mode: GameMode,
}
EventPointerMove :: struct {
	pos: ScreenPixelPos,
}
EventPointerClick :: struct {
	pos:  ScreenPixelPos,
	type: ClickType,
}
EventCameraMove :: struct {
	dir:  [2]f32,
	type: ClickType,
}
EventCameraMouseMode :: struct {
	on: bool,
}
EventInputKey :: struct {
	key:  Key,
	down: bool,
}
EventResetDebugFirst :: struct {}
EventFocusGained :: struct {}
EventFocusLost :: struct {}
Event :: union {
	EventDrawModeChange,
	EventCursorSizeChange,
	EventGameModeChange,
	EventPointerMove,
	EventPointerClick,
	// EventCameraMove,
	EventInputKey,
	EventResetDebugFirst,
	EventFocusGained,
	EventFocusLost,
}

event_q: [dynamic]Event
event_q_init :: proc() -> bool {
	err := reserve(&event_q, 10)
	return err == .None
}
event_q_destroy :: proc() {
	delete(event_q)
}
event_add :: proc(e: Event) {
	if e != nil {
		append(&event_q, e)
	}
}

handle_events :: proc(state: ^State) -> bool {
	for event in event_q {
		switch e in event {
		case EventDrawModeChange:
			state.input.draw_mode = e.new_mode
			fmt.println("draw mode set to:", state.input.draw_mode)
		case EventCursorSizeChange:
			state.input.cursor_size = math.clamp(
				state.input.cursor_size + e.change,
				CURSOR_MIN,
				CURSOR_MAX,
			)
		case EventGameModeChange:
			{
				state.switch_to_mode = e.new_mode
			}
		case EventPointerMove:
			{
				change: [2]int = state.input.pointer_pos - e.pos
				state.input.pointer_pos = e.pos
				handled: bool = false
				if state.camera_mouse_mode {
					handled = true
					if state.input.primary_down {
						state.camera_pos += f_(change)
					}
				}
				cursor_handle_pointer_move(
					&state.cursor,
					e,
					state.camera_pos,
					state.view_offset,
					handled,
				)
			}
		case EventPointerClick:
			{
				switch e.type {
				case .DOWN:
					state.input.primary_down = true
				case .UP:
					state.input.primary_down = false
				}
				handled: bool = false
				cursor_handle_pointer_click(
					&state.cursor,
					e,
					state.camera_pos,
					state.view_offset,
					handled,
					state.camera_mouse_mode,
				)
			}
		case EventInputKey:
			{
				if e.key == .CAMERA_MODE_TOGGLE {
					state.camera_mouse_mode = e.down
				}
				state.input.key_down[e.key] = e.down
			}
		case EventResetDebugFirst:
			{
				_first = true
			}
		case EventFocusGained:
			{
				state.has_focus = true
			}
		case EventFocusLost:
			{
				state.input.primary_down = false
				for k in Key {
					state.input.key_down[k] = false
				}
				state.camera_mouse_mode = false
				state.has_focus = false
			}
		}
	}
	clear(&event_q)
	return true
}

