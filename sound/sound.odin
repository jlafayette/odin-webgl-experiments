package sound

import "core:math"
import "core:math/rand"

foreign import odin_sound "odin_sound"

@(default_calling_convention = "contextless")
foreign odin_sound {
	@(link_name = "play_sound")
	_play_sound :: proc(index: int, rate: f64, pan: f64) ---
	@(link_name = "set_volume")
	_set_volume :: proc(level: f64) ---
}

_last_sound: int = 2
play_sound :: proc(index: int, rate: f64 = 1.0, pan: f64 = 0) {
	pan_: f64 = 0
	if g_input.enable_pan {
		pan_ = pan
	}
	_play_sound(index, rate, pan_)
	_last_sound = index
}

set_volume :: proc(raw_value: int, pan: f64) {
	value := f64(raw_value) / 100
	value = math.clamp(value, 0, 1)
	_set_volume(value)
	_play_sound(_last_sound, rand.float64() * 0.5 + 0.75, pan)
}

