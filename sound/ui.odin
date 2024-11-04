package sound

Ui :: struct {
	buttons: [BUTTON_COUNT]Button,
	slider:  Slider,
}

Slider :: struct {
	pos:   [2]i32,
	size:  [2]i32,
	min:   int,
	max:   int,
	step:  int,
	value: int,
}

ui_layout :: proc(ui: ^Ui, container: Container) {
	buttons_layout(&ui.buttons, container)
}

