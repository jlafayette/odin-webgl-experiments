package synth_keyboard

foreign import odin_synth "odin_synth"

@(default_calling_convention = "contextless")
foreign odin_synth {
	@(link_name = "note_pressed")
	_note_pressed :: proc(index: int, freq: f64) ---
	note_released :: proc(index: int) ---
}

note_pressed :: proc(key_index: int) {
	freq := lookup_freq(key_index)
	_note_pressed(key_index, freq)
}

lookup_freq :: proc(key_index: int) -> f64 {
	switch key_index {
	case 0:
		return note_freq[0][.C]
	case 1:
		return note_freq[0][.D]
	case 2:
		return note_freq[0][.E]
	case 3:
		return note_freq[0][.F]
	case 4:
		return note_freq[0][.G]
	case 5:
		return note_freq[0][.A]
	case 6:
		return note_freq[0][.B]
	case 7:
		return note_freq[1][.C]
	case 8:
		return note_freq[1][.D]
	case 9:
		return note_freq[1][.E]
	case 10:
		return note_freq[1][.F]
	case 11:
		return note_freq[1][.G]
	case 12:
		return note_freq[1][.A]
	case 13:
		return note_freq[1][.B]
	case:
		return note_freq[0][.C]
	}
}

Note :: enum {
	C,
	CS,
	D,
	DS,
	E,
	F,
	FS,
	G,
	GS,
	A,
	AS,
	B,
}

note_freq: [2][Note]f64 = {
	{
		.C = 130.812782650299317,
		.CS = 138.591315488436048,
		.D = 146.83238395870378,
		.DS = 155.563491861040455,
		.E = 164.813778456434964,
		.F = 174.614115716501942,
		.FS = 184.997211355817199,
		.G = 195.997717990874647,
		.GS = 207.652348789972569,
		.A = 220.0,
		.AS = 233.081880759044958,
		.B = 246.941650628062055,
	},
	{
		.C = 261.625565300598634,
		.CS = 277.182630976872096,
		.D = 293.66476791740756,
		.DS = 311.12698372208091,
		.E = 329.627556912869929,
		.F = 349.228231433003884,
		.FS = 369.994422711634398,
		.G = 391.995435981749294,
		.GS = 415.304697579945138,
		.A = 440.0,
		.AS = 466.163761518089916,
		.B = 493.883301256124111,
	},
}

