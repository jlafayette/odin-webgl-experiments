package text

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:image/png"
import gl "vendor:wasm/WebGL"

// Run assets/t.odin script first
atlas_12_data := #load("../../assets/crispy_font/data/data-12.jatlas")
atlas_20_data := #load("../../assets/crispy_font/data/data-20.jatlas")
atlas_30_data := #load("../../assets/crispy_font/data/data-30.jatlas")
atlas_40_data := #load("../../assets/crispy_font/data/data-40.jatlas")

Atlas :: struct {
	w:            i32,
	h:            i32,
	header:       Header,
	chars:        []Char,
	texture_info: TextureInfo,
}
Atlases :: [AtlasSize]Atlas
AtlasSize :: enum {
	A12,
	A20,
	A30,
	A40,
}
TextureInfo :: struct {
	id:   gl.Texture,
	unit: gl.Enum,
}

g_atlases: Atlases
g_initialized: bool = false


get_closest_size :: proc(target: i32) -> (atlas_size: AtlasSize, multiplier: uint, px: uint) {
	if target <= 16 {
		return .A12, 1, 12
	}
	if target <= 25 {
		return .A20, 1, 20
	}
	if target <= 35 {
		return .A30, 1, 30
	}
	if target <= 50 {
		return .A40, 1, 40
	}
	if target <= 70 {
		return .A30, 2, 60
	}
	if target <= 85 {
		return .A40, 2, 80
	}
	if target <= 105 {
		return .A30, 3, 90
	}
	if target <= 135 {
		return .A40, 3, 120
	}
	if target <= 155 {
		return .A30, 5, 150
	}
	if target <= 170 {
		return .A40, 4, 160
	}
	if target <= 190 {
		return .A30, 6, 180
	}
	return .A40, 5, 200
}


@(private)
init :: proc(atlases: ^Atlases) -> (ok: bool) {
	if g_initialized {
		return true
	}
	for &a, size in g_atlases {
		atlas_data: []byte
		switch size {
		case .A12:
			atlas_data = atlas_12_data
		case .A20:
			atlas_data = atlas_20_data
		case .A30:
			atlas_data = atlas_30_data
		case .A40:
			atlas_data = atlas_40_data
		}
		header: Header
		chars: [dynamic]Char
		pixels: [dynamic][1]u8
		header, chars, pixels = decode(atlas_data, 1) or_return
		defer delete(pixels)
		a.w = header.w
		a.h = header.h
		a.header = header
		a.chars = chars[:]
		a.texture_info.id = load_texture(a.w, a.h, pixels[:])
		a.texture_info.unit = gl.TEXTURE0
	}
	g_initialized = true
	return ok
}

@(private = "file")
load_texture :: proc(w, h: i32, pixels: [][1]u8) -> gl.Texture {
	alignment: i32 = 1
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, alignment)
	texture := gl.CreateTexture()
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexImage2DSlice(gl.TEXTURE_2D, 0, gl.ALPHA, w, h, 0, gl.ALPHA, gl.UNSIGNED_BYTE, pixels[:])
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, cast(i32)gl.NEAREST)
	return texture
}
@(private = "file")
is_power_of_two :: proc(n: int) -> bool {
	return (n & (n - 1)) == 0
}


get_size :: proc(text: string, atlas: AtlasSize) -> [2]i32 {
	if !g_initialized {
		return {0, 0}
	}
	w: i32 = 0
	h: i32 = 0
	atlas := g_atlases[atlas]
	for rune_, rune_i in text {
		if rune_ == ' ' {
			w += atlas.h / 2
			continue
		} else if rune_ == '\n' {
			// TODO: handle newlines
			continue
		}
		ch_i: int = int(rune_) - 33
		if ch_i < 0 || ch_i >= len(atlas.chars) {
			fmt.printf("out of range '%v'(%d)\n", rune_, ch_i)
			continue
		}
		ch: Char = atlas.chars[ch_i]
		spacing: i32 = atlas.h / 10

		w += i32(ch.w)
		if rune_i < len(text) - 1 {
			w += spacing
		}
	}
	h += atlas.h
	return {w, h}
}

