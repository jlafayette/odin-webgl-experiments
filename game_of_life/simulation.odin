package game

import "core:fmt"
import glm "core:math/linalg/glsl"

PATCHES_W :: 5
Simulation :: struct {
	patches:    [PATCHES_W * PATCHES_W]Patch,
	shader:     PatchShader,
	center:     [2]int,
	lts:        [dynamic]CompressedVertexes,
	lts_lookup: map[int]int,
}
// LTS_DIM :: 65536
LTS_DIM :: 16
LTS_OFFSET :: LTS_DIM / 2
lts_lookup_get :: proc(
	lookup: ^map[int]int,
	coords: [2]int,
) -> (
	idx: int,
	found: bool,
	out_of_bounds: bool,
) {
	coords_pos: [2]int = coords + LTS_OFFSET
	if coords_pos.x < 0 || coords_pos.x >= LTS_DIM || coords_pos.y < 0 || coords_pos.y >= LTS_DIM {
		out_of_bounds = true
		return
	}
	assert(coords_pos.x >= 0)
	assert(coords_pos.y >= 0)
	index := (coords_pos.y * LTS_DIM) + coords_pos.x
	if index < 0 {
		message := fmt.tprintln("index: ", index)
		assert(index >= 0, message)
	}
	v, ok := lookup[index]
	return v, ok, false
}
lts_lookup_set :: proc(lookup: ^map[int]int, coords: [2]int, value: int) {
	coords_pos: [2]int = coords + LTS_OFFSET
	if coords_pos.x < 0 || coords_pos.x >= LTS_DIM || coords_pos.y < 0 || coords_pos.y >= LTS_DIM {
		return
	}
	assert(coords_pos.x >= 0)
	assert(coords_pos.y >= 0)
	index := (coords_pos.y * LTS_DIM) + coords_pos.x
	assert(index >= 0)
	lookup[index] = value
}

simulation_init :: proc(sim: ^Simulation) {
	for _, i in sim.patches {
		x := i % PATCHES_W
		y := i / PATCHES_W
		patch_init(&sim.patches[i], {x, y})
		sim.patches[i].color = color_random_rgb(0.65)
	}
	for _, i in sim.patches {
		cx := i % PATCHES_W
		cy := i / PATCHES_W
		for neighbor in IterNeighbors {
			x := cx + neighbor.x
			y := cy + neighbor.y
			if x < 0 || x >= PATCHES_W || y < 0 || y >= PATCHES_W {
				continue
			}
			ni := (y * PATCHES_W) + x
			assert(ni >= 0 && ni < len(sim.patches))
			sim.patches[i].neighbors[neighbor.dir] = &sim.patches[ni]
		}
	}
	ok := patch_shader_init(&sim.shader)
	assert(ok, "Patch shader init failed")
}

simulation_update :: proc(
	sim: ^Simulation,
	square_size: int,
	screen_size: [2]int,
	camera_pos: [2]f32,
	cursor: Cursor,
) {
	if _first {
		fmt.println("size of simulation:", size_of(Simulation))
		fmt.println("size of Patch:", size_of(Patch))
		fmt.println("size of CompressedVertexes:", size_of(CompressedVertexes))
		fmt.println("len lts:", len(sim.lts))
		fmt.println("lookup:", sim.lts_lookup)
		fmt.println("camera_pos:", camera_pos)
	}

	offset := i_int_round(camera_pos) / (SQUARES * square_size)
	if _first {
		fmt.println("camera offset:", offset)
	}
	if len(sim.lts) > 0 {
		for &patch in sim.patches {
			patch.vertexes = false
			patch.vertexes2 = false
		}
		// load all patches fresh from compressed version
		for _, i in sim.patches {
			x := i % PATCHES_W
			y := i / PATCHES_W

			// camera pos is [0, 0] at start
			// x, y of [0, 0] -> [-2, -2]
			// x, y of [4, 4] -> [ 2,  2]
			coords: [2]int = offset + {x, y} + {-2, -2}
			index, found, out_of_bounds := lts_lookup_get(&sim.lts_lookup, coords)
			// TODO: handle out of bounds
			if out_of_bounds {
				// patch_set_empty
				patch_set_empty(&sim.patches[i], {x, y})
				continue
			}

			if !found {
				patch_load_new(&sim.patches[i], {x, y})
				continue
			}
			assert(found && !out_of_bounds)
			compressed := sim.lts[index]
			patch_load_from_compressed(&sim.patches[i], {x, y}, compressed)
		}
	}

	for &patch in sim.patches {
		patch_update(&patch, square_size, cursor)
	}
	for &patch in sim.patches {
		patch.vertexes = patch.vertexes2
	}

	for &patch in sim.patches {
		x := patch.offset.x
		y := patch.offset.y
		coords: [2]int = offset + {x, y} + {-2, -2}
		idx, found, out_of_bounds := lts_lookup_get(&sim.lts_lookup, coords)
		if out_of_bounds {
			continue
		}
		compressed := patch_compress(patch.vertexes)
		if found {
			sim.lts[idx] = compressed
		} else {
			idx = len(sim.lts)
			append(&sim.lts, compressed)
			lts_lookup_set(&sim.lts_lookup, coords, idx)
		}
	}

}

simulation_draw :: proc(sim: ^Simulation, view: glm.mat4, size: int) {
	for &patch in sim.patches {
		patch_draw(&patch, view, size, sim.shader)
	}
}

simulation_get_shapes :: proc(
	sim: ^Simulation,
	shapes: ^[dynamic]Shape,
	square_size: int,
	screen: [2]int,
	camera_pos: [2]f32,
) {
	w: int = SQUARES.x
	h: int = SQUARES.y
	r: Rectangle
	r.color = .C3_5
	r.size = SQUARES * square_size

	offset := i_int_round(camera_pos) / (SQUARES * square_size)

	// Offset to center of screen
	offset += (screen / 2) / (SQUARES * square_size)

	r.pos = SQUARES * square_size * offset

	append(shapes, r)
}

