package synth_keyboard

import "../shared/text"

keys_atlas_data := #load("../assets/keys_atlas_data")

KeysAtlas :: struct {
	header: text.Header,
	chars:  [dynamic]text.Char,
}

init_keys_atlas :: proc(k: ^KeysAtlas) -> (ok: bool) {
	k.header, k.chars, ok = text.decode(keys_atlas_data)
	return ok
}

