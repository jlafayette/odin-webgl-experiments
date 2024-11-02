package sound

import "core:fmt"
import glm "core:math/linalg/glsl"

Shape :: union {
	Rectangle,
	Circle,
}
Xform :: struct {
	pos:      [2]i32,
	size:     [2]i32,
	rotation: f32,
}
PointerState :: enum {
	None,
	Hover,
	Down,
	Up,
}
Button :: struct {
	pos:     [2]i32,
	shape:   Shape,
	pointer: PointerState,
}

button_color: [4]f32 = {0, 0.7, 0.7, 1}
button_hover_color: [4]f32 = {0, 0.8, 0.8, 1}

buttons_init :: proc(w, h: i32) -> []Button {
	buttons := make([]Button, 3)
	{
		b: Button
		b.pos = {8, 8}
		size: [2]i32 = {200, 40}
		b.shape = Rectangle({{size.x / 2, size.y / 2}, size, 0, button_color})
		buttons[0] = b
	}
	{
		b: Button
		size: [2]i32 = {200, 40}
		b.pos = {w - size.x - 8, h - size.y - 8}
		b.shape = Rectangle({{size.x / 2, size.y / 2}, size, 0, button_color})
		buttons[1] = b
	}
	{
		b: Button
		radius: i32 = 40
		b.pos = {w - radius * 2 - 8, 8}
		b.shape = Circle({{radius, radius}, radius, {}})
		buttons[2] = b
	}

	return buttons
}

buttons_update :: proc(buttons: []Button, resized: bool, w, h: i32) {
	if !resized {
		return
	}
	size: [2]i32 = {200, 40}
	buttons[0].pos = {8, 8}
	buttons[0].shape = Rectangle({{size.x / 2, size.y / 2}, size, 0, {}})
	buttons[1].pos = {w - size.x - 8, h - size.y - 8}
	buttons[1].shape = Rectangle({{size.x / 2, size.y / 2}, size, 0, {}})
	radius: i32 = 40
	buttons[2].pos = {w - radius * 2 - 8, 8}
	buttons[2].shape = Circle({{radius, radius}, radius, {}})
}

button_get_shape :: proc(b: Button) -> Shape {
	color: [4]f32 = button_color
	size_offset: [2]i32 = {0, 0}
	pos_offset: [2]i32 = {0, 0}
	radius_offset: i32 = 0
	switch b.pointer {
	case .None:
		color = button_color
	case .Hover:
		color = button_hover_color
		size_offset = {2, 2}
		radius_offset = 1
	case .Down:
		color = button_hover_color
		size_offset = {0, 0}
		radius_offset = 0
		pos_offset = {0, 0}
	case .Up:
		color = button_hover_color
		size_offset = {2, 2}
		radius_offset = 1
	}
	result: Shape
	switch s in b.shape {
	case Rectangle:
		{
			s_ := s
			s_.color = color
			s_.size += size_offset
			s_.pos += pos_offset + b.pos
			result = s_
		}
	case Circle:
		{
			s_ := s
			s_.color = color
			s_.radius += radius_offset
			s_.pos += pos_offset + b.pos
			result = s_
		}
	}

	return result
}

button_contains_pos :: proc(btn: Button, pos: [2]i32) -> bool {
	switch shape in btn.shape {
	case Rectangle:
		{
			btn_pos: [2]i32 = btn.pos + shape.pos - shape.size / 2
			return(
				pos.x >= btn_pos.x &&
				pos.x <= btn_pos.x + shape.size.x &&
				pos.y >= btn_pos.y &&
				pos.y <= btn_pos.y + shape.size.y \
			)
		}
	case Circle:
		{
			d: f32 = glm.length((f_(btn.pos) + f_(shape.pos)) - f_(pos))
			return d < f32(shape.radius)
		}
	}
	return false
}

