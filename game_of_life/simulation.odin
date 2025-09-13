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

simulation_update :: proc(sim: ^Simulation, size: int, cursor: Cursor) {
	if _first {
		fmt.println("size of simulation:", size_of(Simulation))
		fmt.println("size of Patch:", size_of(Patch))
		fmt.println("size of CompressedVertexes:", size_of(CompressedVertexes))
		fmt.println("len lts:", len(sim.lts))
		fmt.println("lookup:", sim.lts_lookup)
	}

	if len(sim.lts) > 0 {
		// for &patch in sim.patches {
		// 	patch.vertexes = false
		// 	patch.vertexes2 = false
		// }
		// load all patches fresh from compressed version
		for _, i in sim.patches {
			x := i % PATCHES_W
			y := i / PATCHES_W
			index, ok := sim.lts_lookup[i]
			assert(ok)
			compressed := sim.lts[index]
			patch_load_from_compressed(&sim.patches[i], {x, y}, compressed)
		}
	}

	for &patch in sim.patches {
		patch_update(&patch, size, cursor)
	}
	for &patch in sim.patches {
		patch.vertexes = patch.vertexes2
	}

	for &patch in sim.patches {
		x := patch.offset.x
		y := patch.offset.y
		key := (y * PATCHES_W) + x
		idx, ok := sim.lts_lookup[key]
		compressed := patch_compress(patch.vertexes)
		if ok {
			sim.lts[idx] = compressed
		} else {
			idx = len(sim.lts)
			append(&sim.lts, compressed)
			sim.lts_lookup[key] = idx
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
	size: int,
	camera_pos: [2]f32,
) {
	w: int = SQUARES.x
	h: int = SQUARES.y
	r: Rectangle
	r.color = .C3_5
	r.size = SQUARES * size

	offset := i_int_round(camera_pos) / (SQUARES * size)
	offset += {2, 2}
	r.pos = SQUARES * size * offset

	append(shapes, r)
}

