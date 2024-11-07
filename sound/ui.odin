package sound

import "core:fmt"
import "core:math"

Ui :: struct {
	buttons: [BUTTON_COUNT]Button,
	slider:  Slider,
}

Slider :: struct {
	pos:        [2]i32,
	size:       [2]i32,
	pointer:    PointerState,
	drag:       bool,
	min:        int,
	max:        int,
	value:      int,
	prev_value: int,
}

@(private = "file")
_ui_first: bool = true

ui_layout :: proc(ui: ^Ui, container: Container) {
	buttons_layout(&ui.buttons, container)

	w := container.size.x
	h := container.size.y
	size: [2]i32 = {200, 30}
	ui.slider.pos = {w / 2, (h / 3) * 2} - size / 2
	ui.slider.size = size
	ui.slider.min = 0
	ui.slider.max = 100

	if _ui_first {
		ui.slider.value = 50
		ui.slider.prev_value = 50
	}
	if ui.slider.prev_value != ui.slider.value {
		set_volume(ui.slider.value)
	}
	ui.slider.prev_value = ui.slider.value

	_ui_first = false
}

slider_get_shapes :: proc(s: Slider) -> (shapes: [3]Shape) {
	c: [4]f32 = {0.2, 0.9, 0.7, 1}
	light: [4]f32 = {0.8, 0.8, 0.8, 1}
	light2: [4]f32 = {1, 1, 1, 1}
	dark: [4]f32 = {0.4, 0.4, 0.4, 1}
	shapes_i: int = 0
	{
		r: Rectangle
		size: [2]i32 = s.size - {0, 20}
		r.pos = s.pos + size / 2 + {0, 10}
		r.size = size
		r.color = dark
		shapes[shapes_i] = r
		shapes_i += 1
	}
	w: i32 = cast(i32)math.round(f32(s.size.x) * f32(s.value) / f32(s.max))
	{
		r: Rectangle
		size: [2]i32 = {w, s.size.y / 3}
		r.pos = s.pos + size / 2 + {0, s.size.y / 3}
		r.size = size
		if s.pointer == .None && !s.drag {
			r.color = light
		} else {
			r.color = c
		}
		shapes[shapes_i] = r
		shapes_i += 1
	}
	{
		r: Rectangle
		size: [2]i32 = {10, s.size.y}
		r.pos = s.pos + {w - size.x / 2, 0} + size / 2
		r.size = size
		if s.pointer == .None && !s.drag {
			r.color = {0, 0, 0, 0}
		} else {
			r.color = light2
		}
		shapes[shapes_i] = r
		shapes_i += 1
	}
	return shapes
}

slider_contains_pos :: proc(s: Slider, pos: [2]i32) -> bool {
	return(
		pos.x >= s.pos.x &&
		pos.x <= s.pos.x + s.size.x &&
		pos.y >= s.pos.y &&
		pos.y <= s.pos.y + s.size.y \
	)
}

slider_drag_to :: proc(s: ^Slider, pos: [2]i32) {
	if pos.x <= s.pos.x {
		s.value = s.min
	} else if pos.x > s.pos.x + s.size.x {
		s.value = s.max
	} else {
		s.value = cast(int)math.round(f32(pos.x - s.pos.x) * (f32(s.max) / f32(s.size.x)))
	}
	// fmt.println("drag to:", pos, "value:", s.value)
}

