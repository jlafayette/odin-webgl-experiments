package multi

import "../shared/text"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"


ButtonBuffers :: struct {
	pos:            Buffer,
	indices:        EaBuffer,
	model_matrices: Buffer,
}
button_buffers_init :: proc(buffers: ^ButtonBuffers) {
	pos_data: [4][2]f32 = {{0, 0}, {0, 1}, {1, 1}, {1, 0}}
	buffers.pos = {
		size   = 2,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.pos, pos_data[:])

	indices_data: [6]u16 = {0, 1, 2, 0, 2, 3}
	buffers.indices = {
		usage = gl.STATIC_DRAW,
	}
	ea_buffer_init(&buffers.indices, indices_data[:])

	model_matrices: [3]glm.mat4 = glm.mat4(1)
	buffers.model_matrices = {
		size   = 4,
		type   = gl.FLOAT,
		target = gl.ARRAY_BUFFER,
		usage  = gl.STATIC_DRAW,
	}
	buffer_init(&buffers.model_matrices, model_matrices[:])
}

flat_vert_source := #load("flat.vert", string)
flat_frag_source := #load("flat.frag", string)
FlatShader :: struct {
	program:                  gl.Program,
	a_pos:                    i32,
	a_model_matrix:           i32,
	u_color:                  i32,
	u_view_projection_matrix: i32,
}
FlatUniforms :: struct {
	color:                  glm.vec4,
	view_projection_matrix: glm.mat4,
}
flat_shader_init :: proc(s: ^FlatShader) -> (ok: bool) {
	program: gl.Program
	program, ok = gl.CreateProgramFromStrings({flat_vert_source}, {flat_frag_source})
	if !ok {
		fmt.eprintln("Failed to create program")
		return false
	}
	s.program = program
	s.a_pos = gl.GetAttribLocation(program, "aPos")
	s.a_model_matrix = gl.GetAttribLocation(program, "aModelMatrix")
	s.u_color = gl.GetUniformLocation(program, "uColor")
	s.u_view_projection_matrix = gl.GetUniformLocation(program, "uViewProjectionMatrix")
	return true
}
flat_shader_use :: proc(s: FlatShader, u: FlatUniforms, buffers: ButtonBuffers) {
	gl.UseProgram(s.program)
	// set attributes
	shader_set_attribute(s.a_pos, buffers.pos)
	shader_set_instance_matrix_attribute(s.a_model_matrix, buffers.model_matrices)

	// // set uniforms
	gl.Uniform4fv(s.u_color, u.color)
	gl.UniformMatrix4fv(s.u_view_projection_matrix, u.view_projection_matrix)
}
shader_set_instance_matrix_attribute :: proc(index: i32, b: Buffer) {
	// b.size = 4, b.type = gl.FLOAT
	gl.BindBuffer(b.target, b.id)
	matrix_size := size_of(glm.mat4)
	for i in 0 ..< 4 {
		loc: i32 = i32(index) + i32(i)
		// fmt.printf("- I enable %d\n", loc)
		gl.EnableVertexAttribArray(loc)
		offset: uintptr = uintptr(i) * 16
		gl.VertexAttribPointer(loc, b.size, b.type, false, matrix_size, offset)
		gl.VertexAttribDivisor(u32(loc), 1)
	}
}

Button :: struct {
	pos:        [2]i32,
	size:       [2]i32,
	color:      [3]f32,
	text:       string,
	text_color: [3]f32,
	clicked:    bool,
	hovered:    bool,
}

Ui :: struct {
	buttons:     [3]Button,
	buffers:     ButtonBuffers,
	flat_shader: FlatShader,
	debug_text:  text.Batch,
	show:        bool,
}
_ui_texts: [3]string = {"Cycle Texture", "Cycle Geometry", "Cycle Shader"}

ui_init :: proc(ui: ^Ui) -> (ok: bool) {
	col: [3]f32 = {0.2, 0.2, 0.2}
	text_col: [3]f32 = {1, 1, 1}
	for _, i in _ui_texts {
		b: Button
		b.text = _ui_texts[i]
		b.color = col
		b.text_color = text_col
		w, h: i32
		{
			// not drawing here, so no need to give real projection matrix
			text.batch_start(&ui.debug_text, .A30, col, glm.mat4(1), 128, 5, 1)
			w = text.debug_get_width(b.text)
			h = text.debug_get_height()
		}
		b.size = {w + 40, h + 20}
		ui.buttons[i] = b
	}

	ok = flat_shader_init(&ui.flat_shader)
	if !ok {return false}

	button_buffers_init(&ui.buffers)

	return ok
}

ui_update :: proc(ui: ^Ui, w, h: i32) {
	// Position buttons
	ui.buttons[0].pos = {8, 8}
	ui.buttons[1].pos = {w / 2 - ui.buttons[1].size.x / 2, 8}
	ui.buttons[2].pos = {w - ui.buttons[2].size.x - 8, 8}

	ui.show = _mouse_down

	ui.show = g_input.mode == .TOUCH

	// TODO: update clicked and hovered for each button
	// for &btn in ui.buttons {
	// 	g_input.mouse_pos
	// }
}

ui_draw :: proc(ui: ^Ui, projection_matrix: glm.mat4) {
	if !ui.show {
		return
	}
	// draw rects for buttons
	rect_matrices: [3]glm.mat4

	for btn, i in ui.buttons {
		// fmt.println("button:", btn.pos, btn.size)
		mat: glm.mat4 = glm.mat4(1)
		mat *= glm.mat4Translate({f32(btn.pos.x), f32(btn.pos.y), -1.0})
		mat *= glm.mat4Scale({f32(btn.size.x), f32(btn.size.y), 1.0})
		rect_matrices[i] = mat
	}

	buffer_update(ui.buffers.model_matrices, rect_matrices[:])
	c := ui.buttons[0].color
	uniforms: FlatUniforms = {{c.r, c.g, c.b, 1.0}, projection_matrix}
	flat_shader_use(ui.flat_shader, uniforms, ui.buffers)

	// fmt.println("drawing ui")
	ea_buffer_draw(ui.buffers.indices, instance_count = 3)

	gl.VertexAttribDivisor(1, 0)
	gl.VertexAttribDivisor(2, 0)
	gl.VertexAttribDivisor(3, 0)
	gl.VertexAttribDivisor(4, 0)

	// draw button text
	{
		text.batch_start(
			&ui.debug_text,
			.A30,
			ui.buttons[0].text_color,
			projection_matrix,
			128,
			spacing = 5,
			scale = 1,
		)
		h: i32 = text.debug_get_height()
		for btn in ui.buttons {
			_, _ = text.debug(btn.pos + {20, 10}, btn.text)
		}
	}
}

