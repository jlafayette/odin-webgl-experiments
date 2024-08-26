package rectangle

import "core:fmt"
import "core:mem"
import "core:math"
import gl "vendor:wasm/WebGL"
import glm "core:math/linalg/glsl"


main :: proc() {}


ProgramInfo :: struct {
	program: gl.Program,
	attrib_locations: AttribLocations,
	uniform_locations: UniformLocations,
}
AttribLocations :: struct {
	vertex_position: i32,
}
UniformLocations :: struct {
	projection_matrix: i32,
	model_view_matrix: i32,
}
Buffers :: struct {
	position: gl.Buffer
}
State :: struct {
	started: bool,
	program_info: ProgramInfo,
	buffers: Buffers,
}
state : State = {}


temp_arena_buffer: [mem.Megabyte]byte
temp_arena: mem.Arena = {data = temp_arena_buffer[:]}
temp_arena_allocator := mem.arena_allocator(&temp_arena)


start :: proc() -> (ok: bool) {
	state.started = true
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	
	vs_source : string = `
attribute vec4 aVertexPosition;
uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;
void main() {
	gl_Position = uProjectionMatrix * uModelViewMatrix * aVertexPosition;
}
`
	fs_source : string = `
void main() {
	gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
}
`
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vs_source}, {fs_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	state.program_info.program = program
	state.program_info.attrib_locations.vertex_position = gl.GetAttribLocation(program, "aVertexPosition")
	state.program_info.uniform_locations.projection_matrix = gl.GetUniformLocation(program, "uProjectionMatrix")
	state.program_info.uniform_locations.model_view_matrix = gl.GetUniformLocation(program, "uModelViewMatrix")
	gl.UseProgram(program)

	position_buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, position_buffer)
	position_data : [8]f32 = {1, 1, -1, 1, 1, -1, -1, -1}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, position_data[:], gl.STATIC_DRAW)
	state.buffers.position = position_buffer

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

@export
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		if ok = start(); !ok { return false }
	}
	
	// draw
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	fov : f32 = (45.0 * math.PI) / 180.0
	aspect : f32 = 640.0 / 480.0 // TODO: gl.canvas.clientWidth and gl.canvas.clientHeight
	z_near : f32 = 0.1
	z_far : f32 = 100.0
	projection_mat := glm.mat4Perspective(fov, aspect, z_near, z_far)
	model_view_mat := glm.mat4Translate({-0, 0, -6})
	// set position attribute
	num_components := 2
	type := gl.FLOAT
	normalize := false
	stride := 0
	offset: uintptr = 0
	gl.BindBuffer(gl.ARRAY_BUFFER, state.buffers.position)
	gl.VertexAttribPointer(
		state.program_info.attrib_locations.vertex_position,
		num_components,
		type,
		normalize,
		stride,
		offset,
	)
	gl.EnableVertexAttribArray(state.program_info.attrib_locations.vertex_position)
	gl.UseProgram(state.program_info.program)
	gl.UniformMatrix4fv(
		state.program_info.uniform_locations.projection_matrix,
		projection_mat,
	)
	gl.UniformMatrix4fv(
		state.program_info.uniform_locations.model_view_matrix,
		model_view_mat,
	)
	{
		offset := 0
		vertex_count := 4
		gl.DrawArrays(gl.TRIANGLE_STRIP, offset, vertex_count)
	}
	
	check_gl_error()
	return false
}
