package camera

import "core:bytes"
import "core:fmt"
import "core:image/png"
import "core:math"
import "core:mem"
import gl "vendor:wasm/WebGL"
import glm "core:math/linalg/glsl"

main :: proc() {}

vert_source := #load("cube.vert", string)
frag_source := #load("cube.frag", string)

ProgramInfo :: struct {
	program: gl.Program,
	attrib_locations: AttribLocations,
	uniform_locations: UniformLocations,
}
AttribLocations :: struct {
	vertex_position: i32,
	vertex_color: i32,
	vertex_normal: i32,
}
UniformLocations :: struct {
	projection_matrix: i32,
	model_matrix: i32,
	view_matrix: i32,
	normal_matrix: i32,
}
Buffers :: struct {
	position: gl.Buffer,
	color: gl.Buffer,
	normal: gl.Buffer,
	indices: gl.Buffer,
}
State :: struct {
	started: bool,
	program_info: ProgramInfo,
	buffers: Buffers,
	rotation: f32,
}
state : State = {}


temp_arena_buffer: [mem.Megabyte*4]byte
temp_arena: mem.Arena = {data = temp_arena_buffer[:]}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

init_buffers :: proc() -> Buffers {
	return {
		position = init_position_buffer(),
		color = init_color_buffer(),
		normal = init_normal_buffer(),
		indices = init_index_buffer(),
	}
}
init_position_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	data : [6*4][3]f32 = {
		{-1,-1, 1}, { 1,-1, 1}, { 1, 1, 1}, {-1, 1, 1}, // front
		{-1,-1,-1}, {-1, 1,-1}, { 1, 1,-1}, { 1,-1,-1}, // back
		{-1, 1,-1}, {-1, 1, 1}, { 1, 1, 1}, { 1, 1,-1}, // top
		{-1,-1,-1}, { 1,-1,-1}, { 1,-1, 1}, {-1,-1, 1}, // bottom
		{ 1,-1,-1}, { 1, 1,-1}, { 1, 1, 1}, { 1,-1, 1}, // right
		{-1,-1,-1}, {-1,-1, 1}, {-1, 1, 1}, {-1, 1,-1}, // left
	}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}
init_color_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	c : [4]f32 = {0.5, 0.5, 0.5, 1}
	data : [6*4][4]f32 = {
		c, c, c, c, // front
		c, c, c, c, // back
		c, c, c, c, // top
		c, c, c, c, // bottom
		c, c, c, c, // right
		c, c, c, c, // left
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
init_normal_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	data : [6*4][3]f32 = {
		{ 0, 0, 1}, { 0, 0, 1}, { 0, 0, 1}, { 0, 0, 1}, // front
		{ 0, 0,-1}, { 0, 0,-1}, { 0, 0,-1}, { 0, 0,-1}, // back
		{ 0, 1, 0}, { 0, 1, 0}, { 0, 1, 0}, { 0, 1, 0}, // top
		{ 0,-1, 0}, { 0,-1, 0}, { 0,-1, 0}, { 0,-1, 0}, // bottom
		{ 1, 0, 0}, { 1, 0, 0}, { 1, 0, 0}, { 1, 0, 0}, // right
		{-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0}, // left
	}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}

start :: proc() -> (ok: bool) {
	state.started = true
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	setup_event_listeners()

	if ok = gl.SetCurrentContextById("canvas-1"); !ok {
		fmt.eprintln("Failed to set current context to 'canvas-1'")
		return false
	}
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({vert_source}, {frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	state.program_info = {
		program = program,
		attrib_locations = {
			vertex_position = gl.GetAttribLocation(program, "aVertexPosition"),
			vertex_color = gl.GetAttribLocation(program, "aVertexColor"),
			vertex_normal = gl.GetAttribLocation(program, "aVertexNormal"),
		}, 
		uniform_locations = {
			projection_matrix = gl.GetUniformLocation(program, "uProjectionMatrix"),
			model_matrix = gl.GetUniformLocation(program, "uModelMatrix"),
			view_matrix = gl.GetUniformLocation(program, "uViewMatrix"),
			normal_matrix = gl.GetUniformLocation(program, "uNormalMatrix"),
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
set_normal_attribute :: proc() {
	num_components : int = 3
	type := gl.FLOAT
	normalize := false
	stride : int = 0
	offset : uintptr = 0
	gl.BindBuffer(gl.ARRAY_BUFFER, state.buffers.normal)
	gl.VertexAttribPointer(
		state.program_info.attrib_locations.vertex_normal,
		num_components,
		type,
		normalize,
		stride,
		offset,
	)
	gl.EnableVertexAttribArray(state.program_info.attrib_locations.vertex_normal)
}

draw_scene :: proc() {
	gl.ClearColor(0, 0, 0, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	gl.ClearDepth(1)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	// camera pos
	camera_pos := g_camera_mov
	camera_tgt : glm.vec3 = {0, 0, 0}
	// camera_dir := glm.normalize(camera_pos - camera_tgt)
	up : glm.vec3 = {0, 1, 0}
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

	// fov : f32 = glm.radians_f32(45)
	aspect : f32 = 640.0 / 480.0 // TODO: gl.canvas.clientWidth and gl.canvas.clientHeight
	z_near : f32 = 0.1
	z_far : f32 = 100.0
	projection_mat := glm.mat4Perspective(g_fov, aspect, z_near, z_far)
	
	set_position_attribute()
	set_color_attribute()
	set_normal_attribute()

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, state.buffers.indices)
	
	gl.UseProgram(state.program_info.program)
	gl.UniformMatrix4fv(
		state.program_info.uniform_locations.projection_matrix,
		projection_mat,
	)
	gl.UniformMatrix4fv(
		state.program_info.uniform_locations.view_matrix,
		view_mat,
	)

	cube_positions : [10]glm.vec3 = {
		{0, 0, 0}, // 0
		{2, 5, -15},
		{-1.5, -2.2, -2.5},
		{-3.8, -2, -12.3}, // 3
		{2.4, -0.4, -3.5},
		{-1.7, 3, -7.5},
		{1.3, -2, -2.5}, // 6
		{1.5, 2, -2.5},
		{1.5, 0.2, -1.5},
		{-1.3, 1, -1.5}, // 9
	}
	for &pos, i in cube_positions {
		pos *= 2
		// rotating around zero length vectors results in a matrix
		// with Nan values and the cube disapears
		if glm.length(pos) == 0.0 {
			pos += {0.0003, 0.0007, 0.0002}
		}
		model := glm.mat4(1)
		
		// scale
		model *= glm.mat4Scale({0.5, 0.5, 0.5})
		// rotate
		angle : f32 = glm.radians_f32(20.0 * f32(i))
		// if i % 3 == 0 {
		// 	angle = state.rotation
		// }
		model *= glm.mat4Rotate(pos, angle)
		// translate
		model *= glm.mat4Translate(pos)
		
		gl.UniformMatrix4fv(
			state.program_info.uniform_locations.model_matrix,
			model,
		)
		gl.UniformMatrix4fv(
			state.program_info.uniform_locations.normal_matrix,
			glm.inverse_transpose_matrix4x4(model),
		)
		vertex_count := 36
		type := gl.UNSIGNED_SHORT
		offset : rawptr
		gl.DrawElements(gl.TRIANGLES, vertex_count, type, offset)
	}
	
	check_gl_error()
}

@export
step :: proc(dt: f32) -> (keep_going: bool) {
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

	ok: bool
	if !state.started {
		if ok = start(); !ok { return false }
	}

	update(dt)

	draw_scene()
	
	return check_gl_error()
}
