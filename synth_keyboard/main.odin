package synth_keyboard

import "../shared/text"
import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}

Layout :: struct {
	number_of_keys:      int,
	spacing:             f32,
	key_width:           f32,
	key_height:          f32,
	label_offset_height: f32,
}
State :: struct {
	started:       bool,
	key_shader:    KeyShader,
	key_buffers:   Buffers,
	atlas_shader:  AtlasShader,
	atlas_buffers: AtlasBuffers,
	textures:      Textures,
	keys_atlas:    KeysAtlas,
	layout:        Layout,
}
state: State = {}

temp_arena_buffer: [mem.Megabyte * 4]byte
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


	// gl.VertexAttribDivisor(...)
	// gl.DrawArraysInstanced(...)
	// gl.DrawElementsInstanced(...)

	init_input(&g_input)
	ok = init_keys_atlas(&state.keys_atlas)
	if !ok {return}

	state.layout.number_of_keys = 10
	state.layout.label_offset_height = 86
	state.layout.spacing = 52

	key_shader_init(&state.key_shader)
	// will fill in key width and height
	key_buffers_init(&state.key_buffers, &state.layout)

	atlas_shader_init(&state.atlas_shader)


	chars := make([]text.Char, state.layout.number_of_keys)
	keys_in_scale: int = 7
	c_index: int = 3
	char_i := c_index // start at 'C'
	for i in 0 ..< state.layout.number_of_keys {
		fmt.printf("i: %d, char_i: %d\n", i, char_i)
		chars[i] = state.keys_atlas.chars[char_i]
		char_i = (char_i + 1) % len(state.keys_atlas.chars)
		// skip '#' at index 0
		if char_i == 0 {
			char_i += 1
		}
	}
	atlas_buffers_init(&state.atlas_buffers, state.keys_atlas.header, chars, state.layout)

	ok = textures_init(
		&state.textures,
		state.keys_atlas.header.atlas_w,
		state.keys_atlas.header.atlas_h,
	)
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

draw_scene :: proc(dt: f32) -> (ok: bool) {
	gl.ClearColor(0.5, 0.5, 0.5, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	w := gl.DrawingBufferWidth()
	h := gl.DrawingBufferHeight()

	view_projection_matrix := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -100, 100)

	model_matrix := glm.mat4(1)
	model_matrix *= glm.mat4Translate({5, 5, 0})
	model_matrix *= glm.mat4Scale({1, 1, 1})

	// update matrix data per frame

	// matrix_data: [3]glm.mat4 = {
	// 	glm.mat4Translate({0, 0, 0}),
	// 	glm.mat4Translate({52, 0, 0}),
	// 	glm.mat4Translate({104, 0, 0}),
	// }
	// gl.BindBuffer(gl.ARRAY_BUFFER, state.key_buffers.matrices.id)
	// gl.BufferSubDataSlice(gl.ARRAY_BUFFER, 0, matrix_data[:])

	// shader_set_matrix_attribute(state.key_shader.a_matrix, state.key_buffers.matrices)

	uniforms: KeyUniforms = {
		model_matrix           = model_matrix,
		view_projection_matrix = view_projection_matrix,
	}
	ok = shader_use(
		&state.key_shader,
		uniforms,
		state.key_buffers.pos,
		state.key_buffers.tex,
		state.key_buffers.matrices,
		state.textures[.Corner],
	)
	if !ok {return}
	// ea_buffer_draw(state.key_buffers.indices)
	{
		b := state.key_buffers.indices
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, b.id)
		// fmt.println("count:", b.count)
		instance_count := state.layout.number_of_keys
		gl.DrawElementsInstanced(gl.TRIANGLES, b.count, gl.UNSIGNED_SHORT, 0, instance_count)
	}

	{
		uniforms: AtlasUniforms = {
			projection = view_projection_matrix * model_matrix,
			text_color = {0, 0, 0},
		}
		ok = atlas_shader_use(
			&state.atlas_shader,
			uniforms,
			state.atlas_buffers.pos,
			state.atlas_buffers.tex,
			state.textures[.KeysAtlas],
		)
		ea_buffer_draw(state.atlas_buffers.indices)
	}

	return ok
}

g_r: f32 = 0

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		if ok = start(); !ok {return false}
	}

	update_input(&g_input, dt)
	g_r += dt * 1

	ok = draw_scene(dt)
	if !ok {return false}

	return check_gl_error()
}

