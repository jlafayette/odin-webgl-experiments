package game

import glm "core:math/linalg/glsl"

PATCHES_W :: 2
Simulation :: struct {
	patches: [PATCHES_W * PATCHES_W]Patch,
	shader:  PatchShader,
}

_COLORS: [4][3]f32 = {{1, 1, 1}, {0, 1, 1}, {1, 0, 1}, {1, 1, 0}}

simulation_init :: proc(sim: ^Simulation) {
	for _, i in sim.patches {
		x := i % PATCHES_W
		y := i / PATCHES_W
		patch_init(&sim.patches[i], {x, y})
		sim.patches[i].color = _COLORS[i]
	}
	for _, i in sim.patches {
		cx := i % PATCHES_W
		cy := i / PATCHES_W
		for nx := -1; nx < 2; nx += 1 {
			for ny := -1; ny < 2; ny += 1 {
				if nx == 0 && ny == 0 {
					continue
				}
				x := cx + nx
				y := cy + ny
				if x < 0 || x >= PATCHES_W || y < 0 || y >= PATCHES_W {
					continue
				}
				ni := (y * PATCHES_W) + x
				assert(ni >= 0 && ni < len(sim.patches))
				switch nx {
				case -1:
					{
						switch ny {
						case -1:
							sim.patches[i].neighbors[.LfUp] = &sim.patches[ni]
						case 0:
							sim.patches[i].neighbors[.Lf] = &sim.patches[ni]
						case 1:
							sim.patches[i].neighbors[.LfDn] = &sim.patches[ni]
						}
					}
				case 0:
					{
						switch ny {
						case -1:
							sim.patches[i].neighbors[.Up] = &sim.patches[ni]
						case 0:
						case 1:
							sim.patches[i].neighbors[.Dn] = &sim.patches[ni]
						}
					}
				case 1:
					{
						switch ny {
						case -1:
							sim.patches[i].neighbors[.RtUp] = &sim.patches[ni]
						case 0:
							sim.patches[i].neighbors[.Rt] = &sim.patches[ni]
						case 1:
							sim.patches[i].neighbors[.RtDn] = &sim.patches[ni]
						}
					}
				}
			}
		}
		// patch_init(&sim.patches[i], {x, y})
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

