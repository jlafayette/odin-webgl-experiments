package trails

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:mem"
import gl "vendor:wasm/WebGL"

main :: proc() {}


GameState :: struct {
	started:           bool,
	has_focus:         bool,
	input:             Input,
	particle1_shader:  Particle1Shader,
	particle1_buffers: Particle1Buffers,
	emitter:           ParticleEmitter,
	w:                 i32,
	h:                 i32,
}
@(private = "file")
g_: GameState = {}

temp_arena_buffer: [mem.Megabyte * 4]byte
temp_arena: mem.Arena = {
	data = temp_arena_buffer[:],
}
temp_arena_allocator := mem.arena_allocator(&temp_arena)


start :: proc(g: ^GameState) -> (ok: bool) {
	g.started = true
	g.has_focus = true

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	g.w = gl.DrawingBufferWidth()
	g.h = gl.DrawingBufferHeight()

	init_input(&g.input)

	n_particles := 10_000
	particles_per_second := 2_000
	particle1_buffers_init(&g.particle1_buffers, n_particles)
	particle1_shader_init(&g.particle1_shader) or_return
	particle_emitter_init(&g.emitter, n_particles, particles_per_second)

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

draw_scene :: proc(g: GameState, dt: f32) -> (ok: bool) {
	gl.ClearColor(0.5, 0.5, 0.5, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// 0,0 is bottom left
	view_projection_matrix := glm.mat4Ortho3d(0, f32(g.w), 0, f32(g.h), -100, 100)

	model_matrix := glm.mat4(1)
	// model_matrix *= glm.mat4Translate({g.input.mouse_pos.x, g.input.mouse_pos.y, 0})
	model_matrix *= glm.mat4Translate({f32(g.w) / 2, f32(g.h) / 2, 0})
	model_matrix *= glm.mat4Scale({1, 1, 1})

	// update instance data
	{
		b := g.particle1_buffers.colors
		gl.BindBuffer(b.target, b.id)
		gl.BufferSubDataSlice(b.target, 0, g.emitter.colors)
	}
	{
		b := g.particle1_buffers.matrices
		gl.BindBuffer(b.target, b.id)
		gl.BufferSubDataSlice(b.target, 0, g.emitter.matrices)
	}
	uniforms: Particle1Uniforms = {
		model_matrix           = model_matrix,
		view_projection_matrix = view_projection_matrix,
	}
	particle_shader_use(
		g.particle1_shader,
		uniforms,
		g.particle1_buffers.pos,
		g.particle1_buffers.tex,
		g.particle1_buffers.colors,
		g.particle1_buffers.matrices,
	)
	ea_buffer_draw(g.particle1_buffers.indices, len(g.emitter.particles))

	return true
}

update :: proc(g: ^GameState, dt: f32) {
	g.w = gl.DrawingBufferWidth()
	g.h = gl.DrawingBufferHeight()
	particle_emitter_update(&g.emitter, dt)
}

@(export)
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !g_.started {
		if ok = start(&g_); !ok {return false}
	}

	update_input(&g_.input, dt)
	update(&g_, dt)

	ok = draw_scene(g_, dt)
	if !ok {
		fmt.eprintln("draw_scene !ok")
		return false
	}

	return check_gl_error()
}

