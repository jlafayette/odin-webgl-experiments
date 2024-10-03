package multi

import "../shared/utils"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

GeoId :: enum {
	Cube,
	Pyramid,
	Icosphere0,
	Icosphere1,
	Icosphere2,
	Icosphere3,
	Icosphere4,
}
Geos :: [GeoId]Buffers
ShaderId :: enum {
	Cube,
	Lighting,
}
State :: struct {
	started:         bool,
	rotation:        f32,
	current_shader:  ShaderId,
	cube_shader:     CubeShader,
	lighting_shader: LightingShader,
	current_geo:     GeoId,
	geo_buffers:     Geos,
	current_texture: TextureId,
	textures:        Textures,
	resize:          ResizeState,
}
@(private = "file")
g_state: State = {
	current_geo = .Cube,
}

temp_arena_buffer: [mem.Megabyte * 32]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

start :: proc(state: ^State) -> (ok: bool) {
	state.started = true

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}

	init_input(&g_input)

	shader_init(&state.cube_shader)
	lighting_shader_init(&state.lighting_shader)

	cube_buffers_init(&state.geo_buffers[.Cube])
	pyramid_buffers_init(&state.geo_buffers[.Pyramid])
	icosphere_buffers_init(&state.geo_buffers[.Icosphere0], 0)
	icosphere_buffers_init(&state.geo_buffers[.Icosphere1], 1)
	icosphere_buffers_init(&state.geo_buffers[.Icosphere2], 2)
	icosphere_buffers_init(&state.geo_buffers[.Icosphere3], 3)
	icosphere_buffers_init(&state.geo_buffers[.Icosphere4], 4)

	ok = textures_init(&state.textures)
	if !ok {return}

	return check_gl_error()
}

check_gl_error :: utils.check_gl_error

draw_scene :: proc(state: State) -> (ok: bool) {
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Viewport(0, 0, state.resize.canvas_res.x, state.resize.canvas_res.y)

	// Compute the projection matrix
	fov: f32 = (45.0 * math.PI) / 180.0
	aspect: f32 = state.resize.aspect_ratio // TODO: gl.canvas.clientWidth and gl.canvas.clientHeight
	z_near: f32 = 0.1
	z_far: f32 = 2000.0
	projection_matrix := glm.mat4Perspective(fov, aspect, z_near, z_far)

	camera_matrix := glm.mat4LookAt(g_input.camera_pos, {0, 0, 0}, {0, 1, 0})
	view_projection_matrix := projection_matrix * camera_matrix
	world_matrix := glm.mat4(1) * glm.mat4Rotate({0, 1, 0}, state.rotation * 5.0)
	world_inverse_transpose_matrix := glm.inverse_transpose_matrix4x4(world_matrix)

	if state.current_shader == .Cube {
		uniforms: CubeUniforms = {
			model_view_matrix = camera_matrix * world_matrix,
			projection_matrix = projection_matrix,
		}
		ok = shader_use(
			state.cube_shader,
			uniforms,
			state.geo_buffers[state.current_geo].pos,
			state.geo_buffers[state.current_geo].tex,
			state.textures[state.current_texture],
		)
		if !ok {return}
	} else if state.current_shader == .Lighting {
		uniforms: LightingUniforms = {
			normal_matrix          = world_inverse_transpose_matrix,
			model_matrix           = world_matrix,
			view_projection_matrix = view_projection_matrix,
		}
		ok = lighting_shader_use(
			state.lighting_shader,
			uniforms,
			state.geo_buffers[state.current_geo].pos,
			state.geo_buffers[state.current_geo].tex,
			state.geo_buffers[state.current_geo].normal,
			state.textures[state.current_texture],
		)
		if !ok {return}
	}
	ea_buffer_draw(state.geo_buffers[state.current_geo].indices)
	return ok
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !g_state.started {
		if ok = start(&g_state); !ok {return false}
	}

	g_state.rotation += dt * 0.2
	g_state.current_texture, g_state.current_geo, g_state.current_shader = update_input(
		&g_input,
		dt,
		g_state.current_texture,
		g_state.current_geo,
		g_state.current_shader,
	)
	resize(&g_state.resize)

	ok = draw_scene(g_state)
	if !ok {return false}

	return check_gl_error()
}

