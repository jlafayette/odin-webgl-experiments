package sound

import "core:fmt"
import "core:math"

Ui :: struct {
	buttons:  [BUTTON_COUNT]Button,
	slider:   Slider,
	checkbox: Checkbox,
	scale:    i32,
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

Checkbox :: struct {
	pos:        [2]i32,
	size:       [2]i32,
	label:      string,
	pointer:    PointerState,
	value:      bool,
	prev_value: bool,
}
CheckboxShape :: union {
	Rectangle,
	Line,
}

@(private = "file")
_ui_first: bool = true

ui_layout :: proc(ui: ^Ui, container: Container, scale: f32) {
	i_scale: i32 = cast(i32)math.round(scale)
	ui.scale = i_scale

	buttons_layout(&ui.buttons, container, ui.scale)

	// Slider
	w := container.size.x
	h := container.size.y
	size: [2]i32 = {200, 30} * i_scale
	last_btn := ui.buttons[BUTTON_COUNT - 1]
	last_btn_y := last_btn.pos.y + last_btn.size.y
	ui.slider.pos = {w / 2, last_btn_y} - {size.x / 2, 0} + ({0, 20} - {14, 0}) * i_scale
	ui.slider.size = size
	ui.slider.min = 0
	ui.slider.max = 100
	if _ui_first {
		ui.slider.value = 50
		ui.slider.prev_value = 50
	}
	if ui.slider.prev_value != ui.slider.value {
		set_volume(ui.slider.value, _slider_get_pan(ui.slider))
	}
	ui.slider.prev_value = ui.slider.value
	// Checkbox
	ui.checkbox.label = "Spatial Audio"
	ui.checkbox.pos = ui.slider.pos + {0, 40} * i_scale
	ui.checkbox.size = {200, 24} * i_scale
	if _ui_first {
		ui.checkbox.value = true
		ui.checkbox.prev_value = true
	}
	if ui.checkbox.value != ui.checkbox.prev_value {
		if ui.checkbox.value {
			play_sound(0)
		} else {
			play_sound(1)
		}
	}
	ui.checkbox.prev_value = ui.checkbox.value
	g_input.enable_pan = ui.checkbox.value

	_ui_first = false
}

_slider_get_pan :: proc(s: Slider) -> f64 {
	pan := f64(s.value) / 100
	pan *= 2
	pan -= 1
	pan *= 0.2 // scale back down
	return pan
}

slider_get_shapes :: proc(s: Slider, scale: i32) -> (shapes: [3]Shape) {
	c: [4]f32 = {0.2, 0.9, 0.7, 1}
	light: [4]f32 = {0.8, 0.8, 0.8, 1}
	light2: [4]f32 = {1, 1, 1, 1}
	dark: [4]f32 = {0.4, 0.4, 0.4, 1}
	shapes_i: int = 0
	{
		r: Rectangle
		size: [2]i32 = s.size - {0, 20} * scale
		r.pos = s.pos + size / 2 + {0, 10} * scale
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
		size: [2]i32 = {s.size.y / 3, s.size.y}
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

checkbox_get_shapes :: proc(c: Checkbox, scale: i32) -> (shapes: [7]CheckboxShape) {
	hilite: [4]f32 = {0.2, 0.9, 0.7, 1}
	bg: [4]f32 = {0.2, 0.2, 0.2, 0}
	bg_hover: [4]f32 = {0.2, 0.2, 0.2, 0}
	fg: [4]f32 = {0.9, 0.9, 0.9, 1}
	if c.pointer != .None {
		fg = hilite
		bg = bg_hover
	}

	i: int = 0
	{
		r: Rectangle
		r.pos = c.pos + c.size / 2
		r.size = c.size
		r.color = bg
		shapes[i] = r
		i += 1
	}
	stroke_w: i32 = 2 * scale
	{
		line_tp: Line
		line_lf: Line
		line_rt: Line
		line_bt: Line
		w: i32 = stroke_w
		w_off := w / 2

		line_tp.start = c.pos + {0, w_off}
		line_tp.end = c.pos + {c.size.y, w_off}
		line_lf.start = c.pos + {w_off, 0}
		line_lf.end = c.pos + {w_off, c.size.y}
		line_rt.start = c.pos + {c.size.y - w_off, 0}
		line_rt.end = c.pos + {c.size.y - w_off, c.size.y}
		line_bt.start = c.pos + {0, c.size.y - w_off}
		line_bt.end = c.pos + {c.size.y, c.size.y - w_off}

		size: [2]i32 = {c.size.y, c.size.y} - {w * 2, w * 2}

		line_tp.thickness = w
		line_lf.thickness = w
		line_rt.thickness = w
		line_bt.thickness = w
		line_tp.color = fg
		line_lf.color = fg
		line_rt.color = fg
		line_bt.color = fg
		shapes[i + 0] = line_tp
		shapes[i + 1] = line_lf
		shapes[i + 2] = line_rt
		shapes[i + 3] = line_bt
		i += 4
	}
	{
		line1: Line
		line2: Line
		w: i32 = stroke_w
		line1.start = c.pos + {w, w} * 2
		line1.end = c.pos + {c.size.y, c.size.y} - {w, w} * 2
		line2.start = c.pos + {0, c.size.y} + {w, -w} * 2
		line2.end = c.pos + {c.size.y, 0} + {-w, w} * 2
		line1.thickness = w
		line2.thickness = w
		if c.value {
			line1.color = fg
			line2.color = fg
		} else {
			line1.color = {0, 0, 0, 0}
			line2.color = {0, 0, 0, 0}
		}
		shapes[i] = line1
		i += 1
		shapes[i] = line2
		i += 1
	}

	return
}

checkbox_contains_pos :: proc(c: Checkbox, pos: [2]i32) -> bool {
	return(
		pos.x >= c.pos.x &&
		pos.x <= c.pos.x + c.size.x &&
		pos.y >= c.pos.y &&
		pos.y <= c.pos.y + c.size.y \
	)
}

