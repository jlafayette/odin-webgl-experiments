package game

import "core:fmt"
import "core:math"
import "core:time"

SQUARES: [2]int : {64, 64}
SQ_LEN :: SQUARES.x * SQUARES.y
OFF_COLOR: Color = .C2
ON_COLOR: Color = .C4
CURSOR_MIN :: 1
CURSOR_MAX :: 5


Vert :: bool
Vertexes :: [SQ_LEN]Vert
CompressedVertexes :: [SQ_LEN / 8]byte

Patch :: struct {
	vertexes:          Vertexes,
	mouse_pos:         ScreenPixelPos,
	mouse_button_down: bool,
	draw_mode:         DrawMode,
	cursor_size:       int,
	input_blocked:     bool,
	shader:            PatchShader,
	buffers:           PatchBuffers,
	texture_info:      TextureInfo,
	texture_data:      [][4]u8,
}

patch_init :: proc(patch: ^Patch) {
	w := SQUARES.x
	h := SQUARES.y
	#no_bounds_check for y := 0; y < h; y += 1 {
		for x := 0; x < w; x += 1 {
			i := y * w + x
			threshold: int = h / 2
			v: Vert = y > threshold
			patch.vertexes[i] = v
		}
	}

	patch.draw_mode = .ADD
	patch.mouse_pos = {-100, -100}

	ok := patch_shader_init(&patch.shader)
	assert(ok, "Patch shader init failed")
	patch_buffers_init(&patch.buffers)
	patch.texture_data = make([][4]u8, w * h)
	patch.texture_info = patch_init_texture(patch.texture_data)
	fmt.println("patch size: ", size_of(Patch))
	fmt.println("vertexes size:", size_of(Vertexes))
	fmt.println("required size:", size_of(CompressedVertexes))
}

patch_compress :: proc(vertexes: Vertexes) -> CompressedVertexes {
	buffer: CompressedVertexes

	// write values to b
	b: byte
	// c holds place within byte where we are writing to
	c: uint
	// i holds index of out buffer to write to next
	i: int = 0

	for v in vertexes {
		if c == 8 {
			c = 0
			buffer[i] = b
			i += 1
			b = 0
		}
		if v {
			b = b | (1 << c)
		}
	}
	if c > 0 {
		buffer[i] = b
	}
	return buffer
}
patch_uncompress :: proc(buffer: CompressedVertexes) -> Vertexes {
	vertexes: Vertexes

	// next index in vertexes to write to
	i: int = 0

	for b in buffer {
		// b is current byte being decoded
		for c in 0 ..< 8 {
			// c is place within byte being read from
			v: u8 = 1 & (b >> uint(c))
			vertexes[i] = cast(bool)v
			i += 1
		}
	}
	return vertexes
}

patch_handle_pointer_move :: proc(patch: ^Patch, e: EventPointerMove, ui_handled_move: bool) {
	patch.mouse_pos = e.pos
	patch.input_blocked = ui_handled_move
}
patch_handle_pointer_click :: proc(patch: ^Patch, e: EventPointerClick, ui_handled_click: bool) {
	patch.mouse_pos = e.pos
	patch.mouse_button_down = e.type == .DOWN && !ui_handled_click
	patch.input_blocked = ui_handled_click
}

patch_update :: proc(patch: ^Patch, screen_dim: [2]int, draw_mode: DrawMode, cursor_size: int) {
	patch.cursor_size = cursor_size

	w := SQUARES.x
	h := SQUARES.y
	size := _size(screen_dim)
	half := size / 2

	// game of life, read from vertexes, write to vertexes2
	vertexes2: Vertexes
	defer {
		patch.vertexes = vertexes2
	}
	#no_bounds_check for y := 0; y < h; y += 1 {
		for x := 0; x < w; x += 1 {
			alive_count: int = 0
			for nx := -1; nx < 2; nx += 1 {
				for ny := -1; ny < 2; ny += 1 {
					if nx == 0 && ny == 0 {
						continue
					}
					v := _patch_get(patch, x + nx, y + ny, w, h)
					if v {
						alive_count += 1
					}
				}
			}
			v := _patch_get(patch, x, y, w, h)
			new_value: bool = false
			if v {
				if alive_count < 2 {
					// Any live cell with fewer than two live neighbours dies,
					// as if by underpopulation.
					new_value = false
				} else if alive_count < 4 {
					// Any live cell with two or three live neighbours lives
					// on to the next generation.
					new_value = true
				} else {
					// Any live cell with more than three live neighbours dies,
					// as if by overpopulation.
					new_value = false
				}
			} else {
				// Any dead cell with exactly three live neighbours becomes
				// a live cell, as if by reproduction.
				if alive_count == 3 {
					new_value = true
				} else {
					new_value = false
				}
			}
			i: int = y * w + x
			vertexes2[i] = new_value
		}
	}

	// find vert where mouse is nearest
	if patch.mouse_button_down && !patch.input_blocked {
		slice, cn := _cursor_slice(patch.mouse_pos, patch.cursor_size, size)
		for offset in slice {
			y := cn.y + offset.y
			x := cn.x + offset.x
			if x < 0 || x >= w || y < 0 || y >= h {
				continue
			}
			v: Vert
			switch draw_mode {
			case .ADD:
				v = true
			case .REMOVE:
				v = false
			}
			i := y * w + x
			vertexes2[i] = v
		}
	}
}

_patch_get :: #force_inline proc(patch: ^Patch, x, y, w, h: int) -> Vert {
	if x <= 0 || x >= w || y <= 0 || y >= h {
		return true
	}
	i := y * w + x
	return patch.vertexes[i]
}

_size :: proc(screen_dim: [2]int) -> int {
	x := screen_dim.x / SQUARES.x
	y := screen_dim.y / SQUARES.y
	return math.min(x, y)
}

patch_get_shapes :: proc(patch: ^Patch, screen_dim: [2]int, shapes: ^[dynamic]Shape) {
	w := SQUARES.x
	h := SQUARES.y
	size := _size(screen_dim)
	half := size / 2

	// Main shape drawing is done in the shader

	// Draw mouse cursor
	if !patch.input_blocked {
		slice, cn := _cursor_slice(patch.mouse_pos, patch.cursor_size, size)
		r: Rectangle
		r.color = .C3_5
		r.size = size
		for offset in slice {
			r.pos = (cn + offset) * size
			append(shapes, r)
		}
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

_cursor_slice :: proc(pos: [2]int, n: int, size: int) -> (slice: [][2]int, cn: [2]int) {
	size := math.max(1, size)
	offcenter := false
	switch n {
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
	if offcenter {
		cn = (pos - size / 2) / size
	} else {
		cn = pos / size
	}

	return
}

