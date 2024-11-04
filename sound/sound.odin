package sound

foreign import odin_sound "odin_sound"

@(default_calling_convention = "contextless")
foreign odin_sound {
	@(link_name = "play_sound")
	_play_sound :: proc(index: int, rate: f64, pan: f64) ---
}

play_sound :: proc(index: int, rate: f64 = 1.0, pan: f64 = 0) {
	_play_sound(index, rate, pan)
}

