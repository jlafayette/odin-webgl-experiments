package sound

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:math/rand"

ShapeType :: enum {
	Rectangle,
	Circle,
}
Shape :: union {
	Rectangle,
	Circle,
}
PointerState :: enum {
	None,
	Hover,
	Down,
	Up,
}
VAlign :: enum {
	Top,
	Center,
	Bottom,
}
HAlign :: enum {
	Left,
	Center,
	Right,
}
Button :: struct {
	pos:               [2]i32,
	size:              [2]i32,
	shape:             ShapeType,
	v_align:           VAlign,
	h_align:           HAlign,
	pointer:           PointerState,
	fire_down_command: bool,
	fire_up_command:   bool,
	container:         Container,
	label:             string,
}
Container :: struct {
	pos:  [2]i32,
	size: [2]i32,
}
Bbox :: struct {
	pos:  [2]i32,
	size: [2]i32,
}

button_color: [4]f32 = {0, 0.7, 0.7, 1}
button_hover_color: [4]f32 = {0, 0.8, 0.8, 1}

BUTTON_COUNT :: 8


buttons_layout :: proc(buttons: ^[BUTTON_COUNT]Button, container: Container) {
	w := container.size.x
	h := container.size.y
	size: [2]i32 = {200, 40}
	buttons[0].pos = {8, 8}
	buttons[0].size = size
	buttons[0].v_align = .Top
	buttons[0].h_align = .Left
	buttons[0].shape = .Rectangle
	buttons[0].label = "button 0"

	buttons[1].pos = {8, 8}
	buttons[1].size = size
	buttons[1].v_align = .Bottom
	buttons[1].h_align = .Right
	buttons[1].shape = .Rectangle
	buttons[1].label = "button 1"

	size = {80, 80}
	buttons[2].pos = {8, 8}
	buttons[2].size = size
	buttons[2].v_align = .Top
	buttons[2].h_align = .Right
	buttons[2].shape = .Circle
	buttons[2].label = "2"

	buttons[3].pos = {8, 8}
	buttons[3].size = size
	buttons[3].v_align = .Bottom
	buttons[3].h_align = .Left
	buttons[3].shape = .Circle
	buttons[3].label = "3"

	for &b in buttons[:] {
		b.container = container
	}
	for b, i in buttons[:] {
		_button_print_fired(b, i)
		switch b.shape {
		case .Rectangle:
			{
				rate := rand.float64() * 0.2 + 0.9
				if b.fire_down_command {
					rate -= 0.1
					play_sound(0, rate)
				}
				if b.fire_up_command {
					rate += 0.1
					play_sound(1, rate)
				}
			}
		case .Circle:
			{
				if b.fire_down_command {
					rate := rand.float64() * 0.2 + 0.7
					play_sound(2, rate)
				}
				if b.fire_up_command {
					rate := rand.float64() * 0.2 + 0.9
					play_sound(2, rate)
				}
			}
		}
	}

	{
		size: [2]i32 = {60, 60}
		gap: i32 = 10
		cn_size: [2]i32 = {size.x * 4 + gap * 3, size.y}
		cn_container: Container = {{w / 2 - cn_size.x / 2, h / 2 - cn_size.y / 2}, cn_size}
		x: i32 = 0
		for i: i32 = 4; i < 8; i += 1 {
			buttons[i].pos = {x, 0}
			x += size.x + gap
			buttons[i].size = size
			buttons[i].v_align = .Top
			buttons[i].h_align = .Left
			buttons[i].shape = .Circle
			buttons[i].label = "-"
			buttons[i].container = cn_container
		}
	}
}

_button_print_fired :: proc(b: Button, i: int) {
	if b.fire_down_command {
		fmt.printfln("button[%d] fire down", i)
	}
	if b.fire_up_command {
		fmt.printfln("button[%d] fire up command", i)
	}
}

button_get_bbox :: proc(b: Button) -> Bbox {
	pos: [2]i32
	switch b.h_align {
	case .Left:
		{
			pos.x = b.pos.x
		}
	case .Center:
		{
			pos.x = b.container.size.x / 2 - b.size.x / 2
		}
	case .Right:
		{
			pos.x = b.container.size.x - b.size.x - b.pos.x
		}
	}
	switch b.v_align {
	case .Top:
		{
			pos.y = b.pos.y
		}
	case .Center:
		{
			pos.y = b.container.size.y / 2 - b.size.y / 2
		}
	case .Bottom:
		{
			pos.y = b.container.size.y - b.pos.y - b.size.y
		}
	}
	return {pos + b.container.pos, b.size}
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
	bbox := button_get_bbox(b)
	bbox.pos += pos_offset - size_offset / 2
	bbox.size += size_offset

	result: Shape
	switch b.shape {
	case .Rectangle:
		{
			r: Rectangle = {bbox.pos + bbox.size / 2, bbox.size, 0, color}
			result = r
		}
	case .Circle:
		{
			c: Circle = {bbox.pos + bbox.size / 2, bbox.size.x / 2, color}
			result = c
		}
	}
	return result
}

button_contains_pos :: proc(btn: Button, pos: [2]i32) -> bool {
	bbox := button_get_bbox(btn)
	btn_pos := bbox.pos
	btn_size := bbox.size
	switch btn.shape {
	case .Rectangle:
		{
			return(
				pos.x >= btn_pos.x &&
				pos.x <= btn_pos.x + btn_size.x &&
				pos.y >= btn_pos.y &&
				pos.y <= btn_pos.y + btn_size.y \
			)
		}
	case .Circle:
		{
			radius := btn_size.x / 2
			center := btn_pos + btn_size / 2
			d: f32 = glm.length(f_(center) - f_(pos))
			return d < f32(radius)
		}
	}
	return false
}

