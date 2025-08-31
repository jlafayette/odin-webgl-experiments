package game

import "core:fmt"
import "core:math"
import "core:time"

SQUARES: [2]int : {64, 64}
SQ_LEN :: SQUARES.x * SQUARES.y
CURSOR_MIN :: 1
CURSOR_MAX :: 5


Vert :: bool
Vertexes :: [SQ_LEN]Vert
CompressedVertexes :: [SQ_LEN / 8]byte

NeighborDir :: enum {
	Lf,
	LfUp,
	Up,
	RtUp,
	Rt,
	RtDn,
	Dn,
	LfDn,
}
Neighbor :: struct {
	dir: NeighborDir,
	x:   int,
	y:   int,
}
IterNeighbors: [8]Neighbor = {
	{.Lf, -1, 0},
	{.LfUp, -1, -1},
	{.Up, 0, -1},
	{.RtUp, 1, -1},
	{.Rt, 1, 0},
	{.RtDn, 1, 1},
	{.Dn, 0, 1},
	{.LfDn, -1, 1},
}

Patch :: struct {
	neighbors:    [NeighborDir]Maybe(^Patch),
	offset:       [2]int,
	vertexes:     Vertexes,
	vertexes2:    Vertexes,
	buffers:      PatchBuffers,
	texture_info: TextureInfo,
	texture_data: [][4]u8,
	color:        [3]f32,
}

patch_init :: proc(patch: ^Patch, offset: [2]int) {
	patch.offset = offset
	w := SQUARES.x
	h := SQUARES.y
	#no_bounds_check for y := 0; y < h; y += 1 {
		for x := 0; x < w; x += 1 {
			i := y * w + x
			threshold: int = w / 2
			v: Vert = x > threshold
			patch.vertexes[i] = v
		}
	}
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

_NeighborLookup :: struct {
	other_patch: bool,
	dir:         NeighborDir,
	new_x:       int,
	new_y:       int,
}
_find_neighbor_lookup :: proc(n: Neighbor, x, y: int) -> _NeighborLookup {
	w := SQUARES.x
	h := SQUARES.y
	lookup: _NeighborLookup

	// Final (f) version of coordinates
	fx := x + n.x
	fy := y + n.y

	// Check if this final coordinates is out of bounds for
	// current patch and in which direction

	// Neighbor(n) patch(p) coordinates (x,y)
	npx, npy: int = 0, 0

	switch fx {
	case -1:
		{
			fx = w - 1
			npx = -1
		}
	case w:
		{
			fx = 0
			npx = 1
		}
	}
	switch fy {
	case -1:
		{
			fy = h - 1
			npy = -1
		}
	case h:
		{
			fy = 0
			npy = 1
		}
	}

	/*
	asociate nx and ny with Dir
	
	start with -1..=1 range, but add +1 so
	all indexes will be in the range of 0..=8

	{.LfUp, 0, 0},
	{  .Up, 1, 0},
	{.RtUp, 2, 0},
	{.Lf,   0, 1},
	{.Rt,   2, 1},
	{.LfDn, 0, 2},
	{  .Dn, 1, 2},
	{.RtDn, 2, 2},

	y * 3 + x (and sorted)
	
	0 {.LfUp, 0, 0},
	1 {  .Up, 1, 0},
	2 {.RtUp, 2, 0},
	3 {.Lf,   0, 1},
	4 {.--,   1, 1}
	5 {.Rt,   2, 1},
	6 {.LfDn, 0, 2},
	7 {  .Dn, 1, 2},
	8 {.RtDn, 2, 2},

	*/

	// Neighbor(n) patch(p) index(i)
	npi := ((npy + 1) * 3) + (npx + 1)

	switch npi {
	case 0:
		lookup.dir = .LfUp
		lookup.other_patch = true
	case 1:
		lookup.dir = .Up
		lookup.other_patch = true
	case 2:
		lookup.dir = .RtUp
		lookup.other_patch = true
	case 3:
		lookup.dir = .Lf
		lookup.other_patch = true
	case 4:
		lookup.other_patch = false
	case 5:
		lookup.dir = .Rt
		lookup.other_patch = true
	case 6:
		lookup.dir = .LfDn
		lookup.other_patch = true
	case 7:
		lookup.dir = .Dn
		lookup.other_patch = true
	case 8:
		lookup.dir = .RtDn
		lookup.other_patch = true
	}

	// _coords_to_dir: [9]NeighborDir = {
	// 	.LfUp, // 0 {.LfUp, 0, 0},
	// 	.Up, // 1 {.Up, 1, 0},
	// 	.RtUp, // 2 {.RtUp, 2, 0},
	// 	.Lf, // 3 {.Lf, 0, 1},
	// 	.Lf, // 4 {.--, 1, 1}
	// 	.Rt, // 5 {.Rt, 2, 1},
	// 	.LfDn, // 6 {.LfDn, 0, 2},
	// 	.Dn, // 7 {.Dn, 1, 2},
	// 	.RtDn, // 8 {.RtDn, 2, 2},
	// }
	// return _NeighborCoordsToDir[i]

	lookup.new_x = fx
	lookup.new_y = fy

	return lookup
}


patch_update :: proc(patch: ^Patch, screen_dim: [2]int, cursor: Cursor) {
	w := SQUARES.x
	h := SQUARES.y
	size := _size(screen_dim)
	half := size / 2

	// game of life, read from vertexes, write to vertexes2
	#no_bounds_check for y := 0; y < h; y += 1 {
		for x := 0; x < w; x += 1 {
			alive_count: int = 0
			for neighbor in IterNeighbors {
				p: ^Patch = patch
				p_ok: bool = true
				lookup := _find_neighbor_lookup(neighbor, x, y)
				if lookup.other_patch {
					p, p_ok = patch.neighbors[lookup.dir].?
				}
				v: bool = false
				if p_ok {
					v = _patch_get(p, lookup.new_x, lookup.new_y, w, h)
				}
				if v {
					alive_count += 1
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
			patch.vertexes2[i] = new_value
		}
	}

	// find vert where mouse is nearest
	if cursor.mouse_button_down && !cursor.input_blocked {
		slice, cn := cursor_slice(cursor, screen_dim)
		for offset in slice {
			y := cn.y + offset.y - (patch.offset.y * h)
			x := cn.x + offset.x - (patch.offset.x * w)
			if x < 0 || x >= w || y < 0 || y >= h {
				continue
			}
			v: Vert
			switch cursor.draw_mode {
			case .ADD:
				v = true
			case .REMOVE:
				v = false
			}
			i := y * w + x
			patch.vertexes2[i] = v
		}
	}
}

_patch_neighbor_get :: #force_inline proc(
	patch: ^Patch,
	maybe_lf, maybe_up, maybe_rt, maybe_dn: Maybe(Patch),
	x, y, w, h: int,
) -> Vert {
	switch x {
	case -1:
		{
			lf, ok := maybe_lf.?
			if !ok {return false}
			i := y * w + (w - 1)
			return lf.vertexes[i]
		}
	case w:
	case 0 ..< w:
		{
			switch y {
			case -1:
			case h:
			case 0 ..< h:
				{
					i := y * w + x
					return patch.vertexes[i]
				}
			case:
				{return false}

			}
		}
	case:
		{return false}
	}
	if x < -1 || x > w || y < -1 || y > h {
		return false
	}
	i := y * w + x
	return patch.vertexes[i]
}

_patch_get :: #force_inline proc(patch: ^Patch, x, y, w, h: int) -> Vert {
	if x < 0 || x >= w || y < 0 || y >= h {
		return false
	}
	i := y * w + x
	return patch.vertexes[i]
}

