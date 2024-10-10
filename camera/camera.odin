package camera

import "../shared/resize"
import "../shared/text"
import "core:bytes"
import "core:fmt"
import "core:image/png"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

State :: struct {
	started:    bool,
	shader:     Shader,
	buffers:    Buffers,
	rotation:   f32,
	w:          i32,
	h:          i32,
	dpr:        f32,
	debug_text: text.Batch,
}
state: State = {}

N_CUBES :: 100_000
SPHERE_RADIUS :: 500
Z_FAR :: SPHERE_RADIUS * 2

temp_arena_buffer: [mem.Megabyte * 4]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

start :: proc() -> (ok: bool) {
	fmt.println("running start")
	state.started = true
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	setup_event_listeners()

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	ok = shader_init(&state.shader)
	if (!ok) {
		fmt.eprintln("Failed to initialize shader")
		return false
	}
	init_buffers(&state.buffers, N_CUBES)

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

	gl.Viewport(0, 0, state.w, state.h)

	// camera pos
	camera_pos := g_camera_pos
	camera_tgt: glm.vec3 = {0, 0, 0}
	// camera_dir := glm.normalize(camera_pos - camera_tgt)
	up: glm.vec3 = {0, 1, 0}
	// camera_right := glm.normalize(glm.cross(up, camera_dir))
	// camera_up := glm.cross(camera_dir, camera_right)

	view_mat := glm.mat4LookAt(camera_pos, camera_tgt, up)
	// view_mat = glm.mat4Translate(g_camera_mov)
	{
		radius: f32 = 10
		cam_x := math.sin(g_time) * radius
		cam_z := math.cos(g_time) * radius
		view_mat = glm.mat4LookAt({cam_x, 0, cam_z}, {0, 0, 0}, {0, 1, 0})
	}
	{
		view_mat = glm.mat4LookAt(g_camera_pos, g_camera_pos + g_camera_front, g_camera_up)
	}

	aspect: f32 = f32(state.w) / f32(state.h)
	z_near: f32 = 0.1
	z_far: f32 = Z_FAR
	projection_mat := glm.mat4Perspective(g_fov, aspect, z_near, z_far)

	uniforms: Uniforms
	uniforms.view_matrix = view_mat
	uniforms.projection_matrix = projection_mat
	ok = shader_use(state.shader, uniforms, state.buffers)
	if !ok {
		fmt.eprintln("Error using shader")
		return false
	}
	ea_buffer_draw(state.buffers.indices, N_CUBES)

	// Draw text
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	text_projection := glm.mat4Ortho3d(0, f32(state.w), f32(state.h), 0, -1, 1)
	spacing: i32 = 2
	scale: i32 = math.max(1, i32(math.round(state.dpr)))
	{
		text.batch_start(
			&state.debug_text,
			.A16,
			{1, 1, 1},
			text_projection,
			128,
			spacing = spacing * scale,
			scale = scale,
		)
		text_0: string
		text_1: string
		text_2: string
		switch g_input_mode {
		case .MouseKeyboard:
			{
				text_0 = "Move [wasd]"
				text_1 = "Look [mouse]"
				text_2 = "Change FOV [mouse wheel]"
			}
		case .Gamepad:
			{
				text_0 = "Move [left stick]"
				text_1 = "Look [right stick]"
				text_2 = "Change FOV [triggers]"
			}
		}
		h: i32 = text.debug_get_height()
		line_gap: i32 = 8 * scale
		x: i32 = 16 * scale
		y: i32 = 16 * scale
		_, _ = text.debug({x, y}, text_0)
		y += h + line_gap
		_, _ = text.debug({x, y}, text_1)
		y += h + line_gap
		_, _ = text.debug({x, y}, text_2)

		fps_text: string = fmt.tprintf("FPS (avg, low): %d, %d", get_fps_average(), get_fps_low())
		fps_w: i32 = text.debug_get_width(fps_text)
		x = state.w - fps_w - 16 * scale
		y = 16 * scale
		_, _ = text.debug({x, y}, fps_text)

		fov_text: string = fmt.tprintf("FOV: %.2f", glm.degrees_f32(g_fov))
		fov_w: i32 = text.debug_get_width(fov_text)
		x = state.w - fov_w - 16 * scale
		y += h + line_gap
		_, _ = text.debug({x, y}, fov_text)
	}
	return true
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		state.started = true
		if ok = start(); !ok {return false}
	}

	if (!g_has_focus) {return true}

	{
		r: resize.ResizeState
		resize.resize(&r)
		state.w = r.canvas_res.x
		state.h = r.canvas_res.y
		state.dpr = r.dpr
	}
	update_fps(dt)
	update(dt)

	ok = draw_scene()
	if !ok {return false}

	return check_gl_error()
}

