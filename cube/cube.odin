package cube

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
	vertex_color: i32,
}
UniformLocations :: struct {
	projection_matrix: i32,
	model_view_matrix: i32,
}
Buffers :: struct {
	position: gl.Buffer,
	color: gl.Buffer,
	indices: gl.Buffer,
}
State :: struct {
	started: bool,
	program_info: ProgramInfo,
	buffers: Buffers,
	rotation: f32,
}
state : State = {}


temp_arena_buffer: [mem.Megabyte]byte
temp_arena: mem.Arena = {data = temp_arena_buffer[:]}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

init_buffers :: proc() -> Buffers {
	return {
		position = init_position_buffer(),
		color = init_color_buffer(),
		indices = init_index_buffer(),
	}
}
init_position_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	data : [12*6]f32 = {
		-1,-1,  1, 1, -1, 1,  1, 1,  1,-1,  1, 1, // front
		-1,-1, -1,-1,  1,-1,  1, 1, -1, 1, -1,-1, // back
		-1, 1, -1,-1,  1, 1,  1, 1,  1, 1,  1,-1, // top
		-1,-1, -1, 1, -1,-1,  1,-1,  1,-1, -1, 1, // bottom
		 1,-1, -1, 1,  1,-1,  1, 1,  1, 1, -1, 1, // right
		-1,-1, -1,-1, -1, 1, -1, 1,  1,-1,  1,-1, // left
	}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}
init_color_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	face_colors : [6][4]f32 = {
		{0.6, 0.6, 0.6, 1},
		{0.8, 0.2, 0.2, 1},
		{0.2, 0.7, 0.2, 1},
		{0.2, 0.2, 0.9, 1},
		{0.7, 0.7, 0.2, 1},
		{0.7, 0.2, 0.7, 1},
	}
	data : [96]f32
	j := 0
	for col, i in face_colors {
		c : int
		for c in 0..<4 {
			for ch in col {
				data[j] = ch
				j += 1
			}
		}
	}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}
init_index_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer)
	data : [36]u16 = {
		 0, 1, 2,  0, 2, 3, // front
		 4, 5, 6,  4, 6, 7, // back
		 8, 9,10,  8,10,11, // top
		12,13,14, 12,14,15, // bottom
		16,17,18, 16,18,19, // right
		20,21,22, 20,22,23, // left
	}
	gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}

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
attribute vec4 aVertexColor;

uniform mat4 uModelViewMatrix;
uniform mat4 uProjectionMatrix;

varying lowp vec4 vColor;

void main() {
	gl_Position = uProjectionMatrix * uModelViewMatrix * aVertexPosition;
	vColor = aVertexColor;
}
`
	fs_source : string = `
varying lowp vec4 vColor;

void main() {
	gl_FragColor = vColor;
}
`
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vs_source}, {fs_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	state.program_info = {
		program = program,
		attrib_locations = {
			vertex_position = gl.GetAttribLocation(program, "aVertexPosition"),
			vertex_color = gl.GetAttribLocation(program, "aVertexColor"),
		}, 
		uniform_locations = {
			projection_matrix = gl.GetUniformLocation(program, "uProjectionMatrix"),
			model_view_matrix = gl.GetUniformLocation(program, "uModelViewMatrix"),
		},
	}
	gl.UseProgram(program)

	state.buffers = init_buffers()

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

set_position_attribute :: proc() {
	num_components := 3
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
}
set_color_attribute :: proc() {
	num_components := 4
	type := gl.FLOAT
	normalize := false
	stride := 0
	offset: uintptr = 0
	gl.BindBuffer(gl.ARRAY_BUFFER, state.buffers.color)
	gl.VertexAttribPointer(
		state.program_info.attrib_locations.vertex_color,
		num_components,
		type,
		normalize,
		stride,
		offset,
	)
	gl.EnableVertexAttribArray(state.program_info.attrib_locations.vertex_color)
}

draw_scene :: proc() {
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
	
	trans := glm.mat4Translate({-0, 0, -6})
	rot_z := glm.mat4Rotate({0, 0, 1}, state.rotation)
	rot_y := glm.mat4Rotate({0, 1, 0}, state.rotation * 0.7)
	rot_x := glm.mat4Rotate({1, 0, 0}, state.rotation * 0.3)
	model_view_mat := trans * rot_z * rot_y * rot_x

	set_position_attribute()
	set_color_attribute()

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, state.buffers.indices)
	
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
		vertex_count := 36
		type := gl.UNSIGNED_SHORT
		offset : rawptr
		gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
	}
}

@export
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		if ok = start(); !ok { return false }
	}

	state.rotation += dt

	draw_scene()
	
	return check_gl_error()
}
