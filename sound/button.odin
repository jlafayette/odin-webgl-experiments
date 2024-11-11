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
	pointer:           PointerState,
	fire_down_command: bool,
	fire_up_command:   bool,
	label:             string,
}
Container :: struct {
	pos:  [2]i32,
	size: [2]i32,
}

button_color: [4]f32 = {0, 0.7, 0.7, 1}
button_hover_color: [4]f32 = {0, 0.8, 0.8, 1}

BUTTON_COUNT :: 8


buttons_layout :: proc(buttons: ^[BUTTON_COUNT]Button, container: Container, scale: i32) {
	w := container.size.x
	h := container.size.y
	size: [2]i32 = {200, 40} * scale
	offset: [2]i32 = {8, 8} * scale
	buttons[0].pos = _button_calc_pos(offset, size, .Left, .Top, container)
	buttons[0].size = size
	buttons[0].shape = .Rectangle
	buttons[0].label = "button 0"

	buttons[1].pos = _button_calc_pos(offset, size, .Right, .Bottom, container)
	buttons[1].size = size
	buttons[1].shape = .Rectangle
	buttons[1].label = "button 1"

	size = {80, 80} * scale
	buttons[2].pos = _button_calc_pos(offset, size, .Right, .Top, container)
	buttons[2].size = size
	buttons[2].shape = .Circle
	buttons[2].label = "2"

	buttons[3].pos = _button_calc_pos(offset, size, .Left, .Bottom, container)
	buttons[3].size = size
	buttons[3].shape = .Circle
	buttons[3].label = "3"

	for b, i in buttons[:4] {
		_button_print_fired(b, i)
		pan := button_get_pan(b, w)
		switch b.shape {
		case .Rectangle:
			{
				rate := rand.float64() * 0.2 + 0.9
				if b.fire_down_command {
					rate -= 0.1
					play_sound(0, rate, pan)
				}
				if b.fire_up_command {
					rate += 0.1
					play_sound(1, rate, pan)
				}
			}
		case .Circle:
			{
				if b.fire_down_command {
					rate := rand.float64() * 0.2 + 0.7
					play_sound(2, rate, pan)
				}
				if b.fire_up_command {
					rate := rand.float64() * 0.2 + 0.9
					play_sound(2, rate, pan)
				}
			}
		}
	}

	{
		size: [2]i32 = {60, 60} * scale
		gap: i32 = 10 * scale
		cn_size: [2]i32 = {size.x * 4 + gap * 3, size.y}
		cn_container: Container = {{w / 2 - cn_size.x / 2, h / 2 - cn_size.y / 2}, cn_size}
		x: i32 = 0
		for i: i32 = 4; i < 8; i += 1 {
			b: ^Button = &buttons[i]
			b.pos = _button_calc_pos({x, 0}, size, .Left, .Top, cn_container)
			x += size.x + gap
			b.size = size
			b.shape = .Circle
			b.label = _itos(i)
			if b.fire_down_command {
				rate := rand.float64() * 0.2 + 0.8
				pan := button_get_pan(b^, w)
				play_sound(int(i - 4), rate, pan)
			}
			if b.fire_up_command {
				rate := rand.float64() * 0.2 + 1.0
				pan := button_get_pan(b^, w)
				play_sound(int(i - 4), rate, pan)
			}
		}
	}
}
_itos :: proc(i: i32) -> string {
	switch i {
	case 0:
		return "0"
	case 1:
		return "1"
	case 2:
		return "2"
	case 3:
		return "3"
	case 4:
		return "4"
	case 5:
		return "5"
	case 6:
		return "6"
	case 7:
		return "7"
	case 8:
		return "8"
	case 9:
		return "9"
	case:
		return "-"
	}
}
button_get_pan :: proc(b: Button, w: i32) -> (pan: f64) {
	pan_x: i32 = b.pos.x + b.size.x / 2 - w / 2
	pan = (f64(pan_x) / f64(w)) * 2
	return
}

_button_print_fired :: proc(b: Button, i: int) {
	if b.fire_down_command {
		fmt.printfln("button[%d] fire down", i)
	}
	if b.fire_up_command {
		fmt.printfln("button[%d] fire up command", i)
	}
}

_button_calc_pos :: proc(
	b_pos: [2]i32,
	b_size: [2]i32,
	h_align: HAlign,
	v_align: VAlign,
	container: Container,
) -> [2]i32 {
	pos: [2]i32
	switch h_align {
	case .Left:
		{
			pos.x = b_pos.x
		}
	case .Center:
		{
			pos.x = container.size.x / 2 - b_size.x / 2
		}
	case .Right:
		{
			pos.x = container.size.x - b_size.x - b_pos.x
		}
	}
	switch v_align {
	case .Top:
		{
			pos.y = b_pos.y
		}
	case .Center:
		{
			pos.y = container.size.y / 2 - b_size.y / 2
		}
	case .Bottom:
		{
			pos.y = container.size.y - b_pos.y - b_size.y
		}
	}
	return pos + container.pos
}

button_get_shape :: proc(b: Button, scale: i32) -> Shape {
	color: [4]f32 = button_color
	size_offset: [2]i32 = {0, 0}
	pos_offset: [2]i32 = {0, 0}
	radius_offset: i32 = 0
	switch b.pointer {
	case .None:
		color = button_color
	case .Hover:
		color = button_hover_color
		size_offset = {2, 2} * scale
		radius_offset = 1 * scale
	case .Down:
		color = button_hover_color
		size_offset = {0, 0}
		radius_offset = 0
		pos_offset = {0, 0}
	case .Up:
		color = button_hover_color
		size_offset = {2, 2} * scale
		radius_offset = 1 * scale
	}
	pos := b.pos
	size := b.size
	pos += pos_offset - size_offset / 2
	size += size_offset

	result: Shape
	switch b.shape {
	case .Rectangle:
		{
			r: Rectangle = {pos + size / 2, size, 0, color}
			result = r
		}
	case .Circle:
		{
			c: Circle = {pos + size / 2, size.x / 2, color}
			result = c
		}
	}
	return result
}

button_contains_pos :: proc(btn: Button, pos: [2]i32) -> bool {
	switch btn.shape {
	case .Rectangle:
		{
			return(
				pos.x >= btn.pos.x &&
				pos.x <= btn.pos.x + btn.size.x &&
				pos.y >= btn.pos.y &&
				pos.y <= btn.pos.y + btn.size.y \
			)
		}
	case .Circle:
		{
			radius := btn.size.x / 2
			center := btn.pos + btn.size / 2
			d: f32 = glm.length(f_(center) - f_(pos))
			return d < f32(radius)
		}
	}
	return false
}

