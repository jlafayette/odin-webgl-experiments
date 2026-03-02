package game

import jscursor "../shared/cursor"
import "core:math"

JsCursor :: struct {
	c:          jscursor.Cursor,
	drag_mode:  bool,
	mouse_down: bool,
}
Cursor :: struct {
	draw_mode:  DrawMode,
	size:       int,
	mouse_pos:  ScreenPixelPos,
	is_drawing: bool,
	js:         JsCursor,
}

cursor_init :: proc(cursor: ^Cursor) {
	cursor.draw_mode = .ADD
	cursor.mouse_pos = {-100, -100}
	cursor.js.c = .default
}

cursor_handle_pointer_move :: proc(cursor: ^Cursor, e: EventPointerMove) {
	cursor.mouse_pos = e.pos
}
cursor_handle_pointer_click :: proc(
	cursor: ^Cursor,
	e: EventPointerClick,
	drag_mode_active: bool,
) {
	cursor.mouse_pos = e.pos
	cursor.is_drawing = e.type == .DOWN && !drag_mode_active

	{
		new_c: jscursor.Cursor = cursor.js.c
		primary_down: bool = e.type == .DOWN

		if cursor.js.mouse_down != primary_down && cursor.js.drag_mode {
			if primary_down {
				new_c = .grabbing
			} else {
				new_c = .grab
			}
		}
		cursor.js.mouse_down = primary_down

		if new_c != cursor.js.c {
			cursor.js.c = new_c
			jscursor.set(new_c)
		}
	}
}
cursor_handle_camera_mode_toggled :: proc(cursor: ^Cursor, drag_mode: bool) {
	new_c: jscursor.Cursor = cursor.js.c

	if drag_mode {
		if cursor.js.mouse_down {
			new_c = .grabbing
		} else {
			new_c = .grab
		}
	} else {
		new_c = .default
	}
	cursor.js.drag_mode = drag_mode

	if new_c != cursor.js.c {
		cursor.js.c = new_c
		jscursor.set(new_c)
	}
}
cursor_handle_focus_lost :: proc(cursor: ^Cursor) {
	cursor.js.c = .default
	cursor.js.drag_mode = false
	cursor.js.mouse_down = false
}

cursor_update :: proc(cursor: ^Cursor, mode: DrawMode, size: int, view_offset: [2]f32) {
	cursor.draw_mode = mode
	cursor.size = size
	cursor.is_drawing = cursor.js.mouse_down && !cursor.js.drag_mode
}

cursor_get_shapes :: proc(
	cursor: Cursor,
	size: int,
	view_offset: [2]f32,
	shapes: ^[dynamic]Shape,
) {
	// Main shape drawing is done in the shader

	if cursor.js.drag_mode {
		return
	}
	// Draw mouse cursor
	slice, cn := cursor_slice(cursor, size, view_offset)
	r: Rectangle
	r.color = .C3_5
	r.size = size
	for offset in slice {
		r.pos = (cn + offset) * size
		append(shapes, r)
	}
}

_cursor_1: [1][2]int = {{0, 0}}
_cursor_2: [4][2]int = {{0, 0}, {0, 1}, {1, 0}, {1, 1}}
_cursor_3: [5][2]int = {{-1, 0}, {0, -1}, {0, 0}, {1, 0}, {0, 1}}
_cursor_4: [9][2]int = {
	{-1, -1},
	{0, -1},
	{1, -1},
	{-1, 0},
	{0, 0},
	{1, 0},
	{-1, 1},
	{0, 1},
	{1, 1},
}

_cursor_5: [12][2]int = {
	{0, -1},
	{1, -1},
	{-1, 0},
	{0, 0},
	{1, 0},
	{2, 0},
	{-1, 1},
	{0, 1},
	{1, 1},
	{2, 1},
	{0, 2},
	{1, 2},
}

cursor_slice :: proc(
	cursor: Cursor,
	size: int,
	view_offset: [2]f32,
) -> (
	slice: [][2]int,
	cn: [2]int,
) {
	assert(size >= 1)

	offcenter := false
	switch cursor.size {
	case 1:
		slice = _cursor_1[:]
	case 2:
		slice = _cursor_2[:];offcenter = true
	case 3:
		slice = _cursor_3[:]
	case 4:
		slice = _cursor_4[:]
	case 5:
		slice = _cursor_5[:];offcenter = true
	}

	pos := cursor.mouse_pos + i_int_round(view_offset)

	if offcenter {
		cn = (pos - size / 2) / size
	} else {
		cn = pos / size
	}

	return
}

