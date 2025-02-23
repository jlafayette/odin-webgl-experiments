package text

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"

/* usage

ok: bool
ok = text.init(64)

size: [2]int
size, ok = text.add("Dig", {12, 20}, .Atlas_12)
size, ok = text.add("Dump", {12+size.x, 20}, .Atlas_12)

// like batch end, draw all the accumulated added text
ok = text.draw_all()


// can be done multiple layers if you want to draw text under/on-top of other elements


// maybe add version with error return, and another version that just logs error
// generally this should just mean to allocate more memory for text
// could try to allocate, but then that could fail...

size, ok = text.add(...)
size = text.add_yolo(...)

*/

@(private)
Add :: struct {
	s:    string,
	pos:  [2]int,
	font: Font,
	// todo: add color
}
Font :: struct {
	size:    AtlasSize,
	spacing: int,
	scale:   int,
	// todo: add color
}

@(private = "file")
_BatchAdds :: struct {
	adds: [dynamic]Add,
	b:    Batch,
}

@(private = "file")
g_adds: map[int]_BatchAdds


@(private = "file")
_add_key :: proc(f: Font) -> int {
	// todo: add color
	return cast(int)f.size * 100 + f.spacing * 10 + f.scale * 1
}

add :: proc(s: string, pos: [2]int, font: Font) -> (size: [2]int, ok: bool) {
	if g_adds == nil {
		err: runtime.Allocator_Error
		g_adds, err = make(map[int]_BatchAdds)
		if err != nil {
			fmt.eprintln("Failed to alloc memory for text Add map:", err)
			ok = false
			return
		}
	}

	add_ := Add{s, pos, font}
	key := _add_key(add_.font)
	ba_ref, exists := &g_adds[key]

	if !exists {
		ba: _BatchAdds
		ba.adds = make([dynamic]Add)
		ba_ref = &ba
		append_elem(&ba_ref.adds, add_)
		g_adds[key] = ba_ref^
	} else {
		append_elem(&ba_ref.adds, add_)
	}

	// check to make sure atlas in initialized
	atlas := atlas_get(font.size)

	// calculate width and height of text
	size.x = _debug_get_width(atlas, cast(i32)font.spacing, cast(i32)font.scale, s)
	size.y = _debug_get_height(atlas, cast(i32)font.scale)
	ok = true
	return
}

get_width :: proc(s: string, font: Font) -> int {
	atlas := atlas_get(font.size)
	return _debug_get_width(atlas, cast(i32)font.spacing, cast(i32)font.scale, s)
}
get_height :: proc(font: Font) -> int {
	atlas := atlas_get(font.size)
	return _debug_get_height(atlas, cast(i32)font.scale)
}

draw_all :: proc(c: glm.vec3, proj: glm.mat4) -> (ok: bool) {
	if g_adds == nil {
		return false
	}
	defer {
		for _, &ba in g_adds {
			clear(&ba.adds)
		}
	}

	for _, &ba in g_adds {
		if len(ba.adds) == 0 {
			continue
		}
		a := ba.adds[0]
		capacity: uint = 0
		for add_ in ba.adds {
			capacity += len(add_.s)
		}
		ok = batch_reload(&ba.b, capacity)
		if !ok {
			fmt.eprintln("Failed to reload batch")
			continue
		}
		batch_start(&ba.b, a.font.size, c, proj, capacity, a.font.spacing, a.font.scale)

		for add_ in ba.adds {
			_, ok = debug(add_.pos, add_.s, flip_y = false)
			if !ok {
				fmt.println("Error: rendering text", add_.s, "at", add_.pos)
			}
		}
	}
	// fmt.println("-- end drawing for in g_adds (ok:", ok, ")")
	return
}

