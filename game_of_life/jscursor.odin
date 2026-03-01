package game

import jscursor "../shared/cursor"

JsCursor :: struct {
	c:          jscursor.Cursor,
	drag_mode:  bool,
	mouse_down: bool,
}

jscursor_init :: proc(jsc: ^JsCursor) {
	jsc.c = .default
}

jscursor_handle_camera_mode_toggled :: proc(js_cursor: ^JsCursor, drag_mode: bool) {
	new_c: jscursor.Cursor = js_cursor.c

	if drag_mode {
		if js_cursor.mouse_down {
			new_c = .grabbing
		} else {
			new_c = .grab
		}
	} else {
		new_c = .default
	}
	js_cursor.drag_mode = drag_mode

	if new_c != js_cursor.c {
		js_cursor.c = new_c
		jscursor.set(new_c)
	}
}
jscursor_handle_pointer_click :: proc(js_cursor: ^JsCursor, primary_down: bool) {
	new_c: jscursor.Cursor = js_cursor.c

	if js_cursor.mouse_down != primary_down && js_cursor.drag_mode {
		if primary_down {
			new_c = .grabbing
		} else {
			new_c = .grab
		}
	}
	js_cursor.mouse_down = primary_down

	if new_c != js_cursor.c {
		js_cursor.c = new_c
		jscursor.set(new_c)
	}
}
jscursor_handle_focus_lost :: proc(js_cursor: ^JsCursor) {
	js_cursor.c = .default
	js_cursor.drag_mode = false
	js_cursor.mouse_down = false
}

