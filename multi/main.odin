package multi

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
	resize:          ResizeState,
	ui_writers:      [3]text.Writer,
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

	{
		text_0 := "Cycle Texture  [t]"
		text_1 := "Cycle Geometry [g]"
		text_2 := "Cycle Shader   [s]"
		// positions will be overwritten in update
		text.writer_init(
			&state.ui_writers[0],
			64,
			12,
			{5, 5},
			text_0,
			state.resize.canvas_res.x,
			2,
		) or_return
		text.writer_init(
			&state.ui_writers[1],
			64,
			12,
			{5, 5},
			text_1,
			state.resize.canvas_res.x,
			2,
		) or_return
		text.writer_init(
			&state.ui_writers[2],
			64,
			12,
			{5, 5},
			text_2,
			state.resize.canvas_res.x,
			2,
		) or_return
	}

	return check_gl_error()
}


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

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	text_projection := glm.mat4Ortho3d(
		0,
		f32(state.resize.canvas_res.x),
		0,
		f32(state.resize.canvas_res.y),
		-1,
		1,
	)
	for &writer in state.ui_writers {
		text.writer_draw(&writer, text_projection, {1, 1, 1}, state.resize.canvas_res.x) or_return
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
	resize(&state.resize)

	// update text positions in case of resize
	{
		line_gap: i32 = 5
		x: i32 = 8
		text_size := text.writer_get_size(&state.ui_writers[0], state.resize.canvas_res.x)
		h: i32 = state.resize.canvas_res.y
		th: i32 = text_size.y
		y: i32 = h - 8 - th
		text.writer_set_pos(&state.ui_writers[0], {x, y})
		y -= th + line_gap
		text.writer_set_pos(&state.ui_writers[1], {x, y})
		y -= th + line_gap
		text.writer_set_pos(&state.ui_writers[2], {x, y})
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

	ok = draw_scene(g_state)
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

