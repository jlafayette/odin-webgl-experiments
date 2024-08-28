package cube_lighting

import "core:bytes"
import "core:fmt"
import "core:image/png"
import "core:math"
import "core:mem"
import gl "vendor:wasm/WebGL"
import glm "core:math/linalg/glsl"

main :: proc() {}

texture_data := #load("odin_logo.png")
vert_source := #load("cube.vert", string)
frag_source := #load("cube.frag", string)

ProgramInfo :: struct {
	program: gl.Program,
	attrib_locations: AttribLocations,
	uniform_locations: UniformLocations,
}
AttribLocations :: struct {
	vertex_position: i32,
	vertex_normal: i32,
	texture_coord: i32,
}
UniformLocations :: struct {
	projection_matrix: i32,
	model_view_matrix: i32,
	normal_matrix: i32,
	u_sampler: i32,
}
Buffers :: struct {
	position: gl.Buffer,
	normal: gl.Buffer,
	indices: gl.Buffer,
	texture_coord: gl.Buffer,
}
State :: struct {
	started: bool,
	program_info: ProgramInfo,
	buffers: Buffers,
	rotation: f32,
	texture: gl.Texture,
}
state : State = {}


temp_arena_buffer: [mem.Megabyte*4]byte
temp_arena: mem.Arena = {data = temp_arena_buffer[:]}
temp_arena_allocator := mem.arena_allocator(&temp_arena)

init_buffers :: proc() -> Buffers {
	return {
		position = init_position_buffer(),
		normal = init_normal_buffer(),
		indices = init_index_buffer(),
		texture_coord = init_texture_buffer(),
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
init_texture_buffer :: proc() -> gl.Buffer {
	tex_coord_buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, tex_coord_buffer)
	data : [8*6]f32 = {
		0, 0, 1, 0, 1, 1, 0, 1, // front
		0, 0, 1, 0, 1, 1, 0, 1, // back
		0, 0, 1, 0, 1, 1, 0, 1, // top
		0, 0, 1, 0, 1, 1, 0, 1, // bottom
		0, 0, 1, 0, 1, 1, 0, 1, // right
		0, 0, 1, 0, 1, 1, 0, 1, // left
	}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return tex_coord_buffer
}
init_normal_buffer :: proc() -> gl.Buffer {
	buffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer)
	data : [12*6]f32 = {
		 0, 0,  1, 0,  0, 1,  0, 0,  1, 0,  0, 1, // front
		 0, 0, -1, 0,  0,-1,  0, 0, -1, 0,  0,-1, // back
		 0, 1,  0, 0,  1, 0,  0, 1,  0, 0,  1, 0, // top
		 0,-1,  0, 0, -1, 0,  0,-1,  0, 0, -1, 0, // bottom
		 1, 0,  0, 1,  0, 0,  1, 0,  0, 1,  0, 0, // right
		-1, 0,  0,-1,  0, 0, -1, 0,  0,-1,  0, 0, // left
	}
	gl.BufferDataSlice(gl.ARRAY_BUFFER, data[:], gl.STATIC_DRAW)
	return buffer
}

load_texture :: proc() -> gl.Texture {
	texture := gl.CreateTexture()
	gl.BindTexture(gl.TEXTURE_2D, texture)
	fmt.println("texture data len:", len(texture_data))

	// options : png.Options = {.do_not_decompress_image}
	options : png.Options = {}
	img, err := png.load_from_bytes(texture_data, options=options, allocator=context.temp_allocator)
	if err != nil {
		fmt.eprintln("error loading image:", err)
		return texture
	}
	fmt.println(img.width, "x", img.height, "chan:", img.channels)
	data := bytes.buffer_to_bytes(&img.pixels)
	fmt.println("data len:", len(data))
	level : i32 = 0
	border : i32 = 0
	internal_format := gl.RGBA
	format := gl.RGBA
	if img.channels == 3 {
		internal_format = gl.RGB
		format = gl.RGB
	}
	type := gl.UNSIGNED_BYTE
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexImage2DSlice(
		gl.TEXTURE_2D,
		level,
		internal_format,
		cast(i32)img.width,
		cast(i32)img.height,
		border,
		format,
		type,
		data,
	)
	if (is_power_of_two(img.width) && is_power_of_two(img.height)) {
		fmt.println("generating mipmaps")
		gl.GenerateMipmap(gl.TEXTURE_2D)
	} else {
		// wasn't able to test this because non-power-of-2 images fail on the
		// TexImage2D command
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.LINEAR)
	}
	return texture
}
is_power_of_two :: proc(n: int) -> bool {
	return (n & (n - 1)) == 0
}

start :: proc() -> (ok: bool) {
	state.started = true
	context.temp_allocator = temp_arena_allocator
	defer free_all(context.temp_allocator)

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
			vertex_normal = gl.GetAttribLocation(program, "aVertexNormal"),
			texture_coord = gl.GetAttribLocation(program, "aTextureCoord"),
		}, 
		uniform_locations = {
			projection_matrix = gl.GetUniformLocation(program, "uProjectionMatrix"),
			model_view_matrix = gl.GetUniformLocation(program, "uModelViewMatrix"),
			normal_matrix = gl.GetUniformLocation(program, "uNormalMatrix"),
			u_sampler = gl.GetUniformLocation(program, "uSampler"),
		},
	}
	gl.UseProgram(program)

	state.buffers = init_buffers()
	state.texture = load_texture()
	gl.PixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)

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
set_texture_attribute :: proc() {
	num := 2
	type := gl.FLOAT
	normalize := false
	stride := 0
	offset : uintptr = 0
	gl.BindBuffer(gl.ARRAY_BUFFER, state.buffers.texture_coord)
	gl.VertexAttribPointer(
		state.program_info.attrib_locations.texture_coord,
		num,
		type,
		normalize,
		stride,
		offset,
	)
	gl.EnableVertexAttribArray(state.program_info.attrib_locations.texture_coord)
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
	normal_matrix := glm.inverse_transpose_matrix4x4(model_view_mat)

	set_position_attribute()
	set_normal_attribute()
	set_texture_attribute()

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
	gl.UniformMatrix4fv(
		state.program_info.uniform_locations.normal_matrix,
		normal_matrix,
	)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, state.texture)
	gl.Uniform1i(state.program_info.uniform_locations.u_sampler, 0)
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
