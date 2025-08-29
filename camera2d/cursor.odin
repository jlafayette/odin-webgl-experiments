package game

import "core:math"

Cursor :: struct {
	draw_mode:         DrawMode,
	size:              int,
	mouse_pos:         ScreenPixelPos,
	camera_mv:         [2]f32, // movement since last move/click update
	mouse_button_down: bool,
	input_blocked:     bool,
}

cursor_init :: proc(cursor: ^Cursor) {
	cursor.draw_mode = .ADD
	cursor.mouse_pos = {-100, -100}
}

cursor_handle_pointer_move :: proc(
	cursor: ^Cursor,
	e: EventPointerMove,
	camera_pos: [2]f32,
	ui_handled_move: bool,
) {
	cursor.camera_mv = 0
	cursor.mouse_pos = e.pos + i_int_round(camera_pos)
	cursor.input_blocked = ui_handled_move
}
cursor_handle_pointer_click :: proc(
	cursor: ^Cursor,
	e: EventPointerClick,
	camera_pos: [2]f32,
	ui_handled_click: bool,
) {
	cursor.camera_mv = 0
	cursor.mouse_pos = e.pos + i_int_round(camera_pos)
	cursor.mouse_button_down = e.type == .DOWN && !ui_handled_click
	cursor.input_blocked = ui_handled_click
}

cursor_update :: proc(cursor: ^Cursor, mode: DrawMode, size: int, mv: [2]f32) {
	cursor.camera_mv += mv
	cursor.draw_mode = mode
	cursor.size = size
}

cursor_get_shapes :: proc(cursor: Cursor, screen_dim: [2]int, shapes: ^[dynamic]Shape) {
	w := SQUARES.x
	h := SQUARES.y
	size := _size(screen_dim)
	half := size / 2

	// Main shape drawing is done in the shader

	// Draw mouse cursor
	slice, cn := cursor_slice(cursor, screen_dim)
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
@(private)
_size :: proc(screen_dim: [2]int) -> int {
	x := screen_dim.x / SQUARES.x
	y := screen_dim.y / SQUARES.y
	return math.min(x, y)
}

cursor_slice :: proc(cursor: Cursor, screen_dim: [2]int) -> (slice: [][2]int, cn: [2]int) {
	size := math.max(1, _size(screen_dim))
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

	// Offset by the camera movement since last position/click update
	pos := cursor.mouse_pos - i_int_round(cursor.camera_mv)

	if offcenter {
		cn = (pos - size / 2) / size
	} else {
		cn = pos / size
	}

	return
}

