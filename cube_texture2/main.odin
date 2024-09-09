package cube_texture2

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

main :: proc() {}

GeoId :: enum {
	Cube,
	Pyramid,
}
Geos :: [GeoId]Buffers
State :: struct {
	started:         bool,
	rotation:        f32,
	shader2:         CubeShader,
	current_geo:     GeoId,
	geo_buffers:     Geos,
	current_texture: TextureId,
	textures:        Textures,
}
state: State = {}

temp_arena_buffer: [mem.Megabyte * 8]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

start :: proc() -> (ok: bool) {
	state.started = true

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}

	init_input(&g_input)

	shader_init(&state.shader2)

	cube_buffers_init(&state.geo_buffers[.Cube])
	pyramid_buffers_init(&state.geo_buffers[.Pyramid])

	ok = textures_init(&state.textures)
	if !ok {return}

	return check_gl_error()
}

check_gl_error :: proc() -> (ok: bool) {
	err := gl.GetError()
	if err != gl.NO_ERROR {
		fmt.eprintln("WebGL error:", err)
		return false
	}
	return true
}

draw_scene :: proc() -> (ok: bool) {
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	fov: f32 = (45.0 * math.PI) / 180.0
	aspect: f32 = 640.0 / 480.0 // TODO: gl.canvas.clientWidth and gl.canvas.clientHeight
	z_near: f32 = 0.1
	z_far: f32 = 100.0
	projection_mat := glm.mat4Perspective(fov, aspect, z_near, z_far)

	// trans := glm.mat4Translate({-0, 0, -6})
	// rot_z := glm.mat4Rotate({0, 0, 1}, state.rotation)
	// rot_y := glm.mat4Rotate({0, 1, 0}, state.rotation * 0.7)
	// rot_x := glm.mat4Rotate({1, 0, 0}, state.rotation * 0.3)
	// model_view_mat := trans * rot_z * rot_y * rot_x

	model_view_mat := glm.mat4LookAt(g_input.camera_pos, {0, 0, 0}, {0, 1, 0})

	uniforms: CubeUniforms = {
		model_view_matrix = model_view_mat,
		projection_matrix = projection_mat,
	}
	ok = shader_use(
		&state.shader2,
		uniforms,
		state.geo_buffers[state.current_geo].pos,
		state.geo_buffers[state.current_geo].tex,
		state.textures[state.current_texture],
	)
	if !ok {return}
	ea_buffer_draw(state.geo_buffers[state.current_geo].indices)
	return ok
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		if ok = start(); !ok {return false}
	}

	state.rotation += dt * 0.2
	update_input(&g_input, dt)

	ok = draw_scene()
	if !ok {return false}

	return check_gl_error()
}

