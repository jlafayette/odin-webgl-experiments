package game

import glm "core:math/linalg/glsl"

Simulation :: struct {
	patches: [25]Patch,
	shader:  PatchShader,
}

simulation_init :: proc(sim: ^Simulation) {
	for _, i in sim.patches {
		x := i % 5
		y := i / 5
		patch_init(&sim.patches[i], {x - 2, y - 2})
	}
	ok := patch_shader_init(&sim.shader)
	assert(ok, "Patch shader init failed")
}

simulation_update :: proc(sim: ^Simulation, screen_dim: [2]int, cursor: Cursor) {
	for &patch in sim.patches {
		patch_update(&patch, screen_dim, cursor)
	}
}

simulation_draw :: proc(sim: ^Simulation, view: glm.mat4, w: int, h: int) {
	for &patch in sim.patches {
		patch_draw(&patch, view, w, h, sim.shader)
	}
}

