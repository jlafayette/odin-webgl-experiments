package text

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:image/png"
import gl "vendor:wasm/WebGL"

// Run assets/t.odin script first
atlas_12_data := #load("../../assets/crispy_font/data/data-12.jatlas")
atlas_16_bold_data := #load("../../assets/crispy_font/data/data-16-8-2.jatlas")
atlas_16_data := #load("../../assets/crispy_font/data/data-16-7-1.jatlas")
atlas_20_data := #load("../../assets/crispy_font/data/data-20.jatlas")
atlas_30_data := #load("../../assets/crispy_font/data/data-30.jatlas")
atlas_40_data := #load("../../assets/crispy_font/data/data-40.jatlas")

Atlas :: struct {
	w:            i32,
	h:            i32,
	header:       Header,
	chars:        []Char,
	texture_info: TextureInfo,
	_loaded:      bool,
}
Atlases :: [AtlasSize]Atlas
AtlasSize :: enum {
	A12,
	A16,
	A16_bold,
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


@(private)
init :: proc(a: ^Atlas, size: AtlasSize) -> (ok: bool) {
	if a._loaded {
		return true
	}
	atlas_data: []byte
	switch size {
	case .A12:
		atlas_data = atlas_12_data
	case .A16:
		atlas_data = atlas_16_data
	case .A16_bold:
		atlas_data = atlas_16_bold_data
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
	header, chars, pixels, ok = decode(atlas_data, 1)
	if !ok {
		fmt.println("ok:", ok)
		return ok
	}
	fmt.println(header)
	defer delete(pixels)
	a.w = header.w
	a.h = header.h
	a.header = header
	a.chars = chars[:]
	a.texture_info.id = load_texture(a.w, a.h, pixels[:])
	a.texture_info.unit = gl.TEXTURE0

	a._loaded = true
	return ok
}
@(private)
init_all :: proc(atlases: ^Atlases) -> (ok: bool) {
	if g_initialized {
		return true
	}
	for &a, size in g_atlases {
		init(&a, size) or_return
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

