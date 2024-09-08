package cube_texture2

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

State :: struct {
	started:         bool,
	rotation:        f32,
	shader2:         CubeShader,
	buffers2:        Buffers2,
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

	pos_data: [6][4][3]f32 = {
		{{-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1}}, // front
		{{-1, -1, -1}, {-1, 1, -1}, {1, 1, -1}, {1, -1, -1}}, // back
		{{-1, 1, -1}, {-1, 1, 1}, {1, 1, 1}, {1, 1, -1}}, // top
		{{-1, -1, -1}, {1, -1, -1}, {1, -1, 1}, {-1, -1, 1}}, // bottom
		{{1, -1, -1}, {1, 1, -1}, {1, 1, 1}, {1, -1, 1}}, // right
		{{-1, -1, -1}, {-1, -1, 1}, {-1, 1, 1}, {-1, 1, -1}}, // left
	}
	tex_data: [6][4][2]f32 = {
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // front
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // back
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // top
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // bottom
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // right
		{{0, 0}, {1, 0}, {1, 1}, {0, 1}}, // left
	}
	indices_data: [6][6]u16 = {
		{0, 1, 2, 0, 2, 3}, // front
		{4, 5, 6, 4, 6, 7}, // back
		{8, 9, 10, 8, 10, 11}, // top
		{12, 13, 14, 12, 14, 15}, // bottom
		{16, 17, 18, 16, 18, 19}, // right
		{20, 21, 22, 20, 22, 23}, // left
	}
	buffers: InitBuffers = {
		pos     = {pos_data[:], {3, gl.FLOAT, gl.ARRAY_BUFFER, gl.STATIC_DRAW}},
		tex     = {tex_data[:], {2, gl.FLOAT, gl.ARRAY_BUFFER, gl.STATIC_DRAW}},
		indices = {
			indices_data[:],
			{1, gl.UNSIGNED_SHORT, gl.ELEMENT_ARRAY_BUFFER, gl.STATIC_DRAW},
		},
	}
	shader_init(&state.shader2, buffers)
	state.buffers2.pos = buffers.pos.b
	state.buffers2.tex = buffers.tex.b
	state.buffers2.indices = buffers.indices.b

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

	trans := glm.mat4Translate({-0, 0, -6})
	rot_z := glm.mat4Rotate({0, 0, 1}, state.rotation)
	rot_y := glm.mat4Rotate({0, 1, 0}, state.rotation * 0.7)
	rot_x := glm.mat4Rotate({1, 0, 0}, state.rotation * 0.3)
	model_view_mat := trans * rot_z * rot_y * rot_x

	uniforms: Uniforms = {
		model_view_matrix = model_view_mat,
		projection_matrix = projection_mat,
	}
	ok = shader_use(
		&state.shader2,
		uniforms,
		state.buffers2,
		state.textures[state.current_texture],
	)
	if !ok {return}
	count := 36
	buffer_draw(state.shader2.buffer_indices, count, state.buffers2.indices)
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

	ok = draw_scene()
	if !ok {return false}

	return check_gl_error()
}

