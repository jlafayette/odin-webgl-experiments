package wfc

import glm "core:math/linalg/glsl"

Tile :: enum {
	CORNER,
	CROSS,
	EMPTY,
	LINE,
	T,
}
TileOption :: struct {
	tile:  Tile,
	xform: Transform,
}

Sym :: enum {
	X, // None (-)
	T, // (-, rotate90, flipV, flipV+rotate90)
	I, // (-, rotate90)
	L, // corner (-, flipH, flipV, flipV+rotate90)
	// D, // \
}
Transform :: enum {
	None,
	Rotate90,
	FlipH,
	FlipV,
	FlipV_Rotate90,
}
T_COUNT :: 5
all_transforms: [T_COUNT]Transform = {.None, .Rotate90, .FlipH, .FlipV, .FlipV_Rotate90}
Side :: enum {
	OPEN,
	PIPE,
}
X_xforms: [1]Transform = {.None}
T_xforms: [4]Transform = {.None, .Rotate90, .FlipV, .FlipV_Rotate90}
I_xforms: [2]Transform = {.None, .Rotate90}
L_xforms: [4]Transform = {.None, .FlipH, .FlipV, .FlipV_Rotate90}

TileSource :: struct {
	sym:    Sym,
	sides:  [4]Side,
	xforms: []Transform,
}
tile_set: [Tile]TileSource = {
	.CORNER = {.L, {.OPEN, .PIPE, .PIPE, .OPEN}, L_xforms[:]},
	.CROSS  = {.I, {.PIPE, .PIPE, .PIPE, .PIPE}, I_xforms[:]},
	.EMPTY  = {.X, {.OPEN, .OPEN, .OPEN, .OPEN}, X_xforms[:]},
	.LINE   = {.I, {.PIPE, .OPEN, .PIPE, .OPEN}, I_xforms[:]},
	.T      = {.T, {.PIPE, .OPEN, .PIPE, .PIPE}, T_xforms[:]},
}
tile_sides :: proc(base_sides: [4]Side, xform: Transform) -> [4]Side {
	sides: [4]Side = base_sides
	switch xform {
	case .None:
	case .Rotate90:
		sides = sides.wxyz
	case .FlipH:
		sides = sides.zyxw
	case .FlipV:
		sides = sides.xwzy
	case .FlipV_Rotate90:
		sides = sides.ywxz
	}
	return sides
}
transform_mat4 :: proc(t: Transform) -> glm.mat4 {
	m: glm.mat4
	switch t {
	case .None:
		m = glm.mat4(1)
	case .Rotate90:
		m = glm.mat4Rotate({0, 0, 1}, glm.radians_f32(90))
	case .FlipH:
		m = glm.mat4Scale({-1, 1, 1})
	case .FlipV:
		m = glm.mat4Scale({1, -1, 1})
	case .FlipV_Rotate90:
		m = glm.mat4(1)
		m = m * glm.mat4Rotate({0, 0, 1}, glm.radians_f32(90))
		m = m * glm.mat4Scale({1, -1, 1})
	}
	return m
}
tile_offset :: proc(tile: Tile) -> (f32, f32) {
	start, end: f32
	switch tile {
	case .CORNER:
		start = 0;end = 0.2
	case .CROSS:
		start = 0.2;end = 0.4
	case .EMPTY:
		start = 0.4;end = 0.6
	case .LINE:
		start = 0.6;end = 0.8
	case .T:
		start = 0.8;end = 1
	}
	return start, end
}