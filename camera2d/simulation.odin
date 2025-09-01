package game

import "core:math"
import glm "core:math/linalg/glsl"
import "core:math/rand"

PATCHES_W :: 5
Simulation :: struct {
	patches: [PATCHES_W * PATCHES_W]Patch,
	shader:  PatchShader,
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

simulation_update :: proc(sim: ^Simulation, screen_dim: [2]int, cursor: Cursor) {
	for &patch in sim.patches {
		patch_update(&patch, screen_dim, cursor)
	}
	for &patch in sim.patches {
		patch.vertexes = patch.vertexes2
	}
}

simulation_draw :: proc(sim: ^Simulation, view: glm.mat4, w: int, h: int) {
	for &patch in sim.patches {
		patch_draw(&patch, view, w, h, sim.shader)
	}
}

