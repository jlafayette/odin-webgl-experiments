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
EventResetDebugFirst :: struct {}
EventFocusGained :: struct {}
EventFocusLost :: struct {}
Event :: union {
	EventDrawModeChange,
	EventCursorSizeChange,
	EventGameModeChange,
	EventPointerMove,
	EventPointerClick,
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
				state.input.pointer_pos = e.pos
				handled: bool = false
				patch_handle_pointer_move(&state.patch, e, handled)
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
				patch_handle_pointer_click(&state.patch, e, handled)
			}
		case EventResetDebugFirst:
			{
				_first = true
			}
		case EventFocusGained:
		case EventFocusLost:
			{
				state.input.primary_down = false
			}
		}
	}
	clear(&event_q)
	return true
}

