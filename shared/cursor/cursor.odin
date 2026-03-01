package cursor

foreign import odin_cursor "odin_cursor"

import "core:fmt"
import "core:sys/wasm/js"

Cursor :: enum u8 {
	auto,
	default,
	none,
	context_menu,
	help,
	pointer,
	progress,
	wait,
	cell,
	crosshair,
	text,
	vertical_text,
	alias,
	copy,
	move,
	no_drop,
	not_allowed,
	grab,
	grabbing,
	e_resize,
	n_resize,
	ne_resize,
	nw_resize,
	s_resize,
	se_resize,
	sw_resize,
	w_resize,
	ew_resize,
	ns_resize,
	nesw_resize,
	nwse_resize,
	col_resize,
	row_resize,
	all_scroll,
	zoom_in,
	zoom_out,
}

set :: proc(c: Cursor) {
	@(default_calling_convention = "contextless")
	foreign odin_cursor {
		@(link_name = "setCursor")
		_setCursor :: proc(v: u8) ---
	}
	_setCursor(u8(c))
}

