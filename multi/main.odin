package multi

import "../shared/resize"
import "../shared/text"
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
	debug_text:      text.Batch,
	w:               i32,
	h:               i32,
	dpr:             f32,
}
@(private = "file")
g_state: State = {
	current_geo     = .Cube,
	current_shader  = .Lighting,
	current_texture = .Odin,
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


draw_scene :: proc(state: ^State) -> (ok: bool) {
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	gl.Viewport(0, 0, state.w, state.h)

	// Compute the projection matrix
	fov: f32 = (45.0 * math.PI) / 180.0
	aspect: f32 = f32(state.w) / f32(state.h)
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

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	text_projection := glm.mat4Ortho3d(0, f32(state.w), 0, f32(state.h), -1, 1)
	{
		scale: i32 = math.max(1, i32(math.round(state.dpr)))
		spacing: i32 = 2 * scale
		text.batch_start(
			&state.debug_text,
			.A16,
			{1, 1, 1},
			text_projection,
			128,
			spacing = spacing,
			scale = scale,
		)
		text_0 := "Cycle Texture  [t]"
		text_1 := "Cycle Geometry [g]"
		text_2 := "Cycle Shader   [s]"
		h: i32 = text.debug_get_height()
		line_gap: i32 = 5 * scale
		x: i32 = 16 * scale
		y: i32 = state.h - h - 16
		_ = text.debug({x, y}, text_0) or_return
		y -= h + line_gap
		_ = text.debug({x, y}, text_1) or_return
		y -= h + line_gap
		_ = text.debug({x, y}, text_2) or_return
	}

	return ok
}

update :: proc(state: ^State, dt: f32) {
	state.rotation += dt * 0.2
	state.current_texture, state.current_geo, state.current_shader = update_input(
		&g_input,
		dt,
		state.current_texture,
		state.current_geo,
		state.current_shader,
	)
	{
		r: resize.ResizeState
		resize.resize(&r)
		state.w = r.canvas_res.x
		state.h = r.canvas_res.y
		state.dpr = r.dpr
	}
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !g_state.started {
		if ok = start(&g_state); !ok {return false}
	}

	update(&g_state, dt)

	ok = draw_scene(&g_state)
	if !ok {return false}

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

