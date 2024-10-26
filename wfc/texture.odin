package wfc

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:image/png"
import gl "vendor:wasm/WebGL"

_pipes_data := #load("../assets/wfc_pipes.png")

TextureInfo :: struct {
	id:   gl.Texture,
	unit: gl.Enum,
}
texture_init :: proc(t: ^TextureInfo) -> (ok: bool) {

	img, err := png.load_from_bytes(_pipes_data)
	if err != nil {
		fmt.eprintln("error loading odin image:", err)
		return false
	}
	t.id = load_texture(img)
	t.unit = gl.TEXTURE0
	return true
}

@(private = "file")
load_texture :: proc(img: ^image.Image) -> gl.Texture {
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 2)
	texture := gl.CreateTexture()
	gl.BindTexture(gl.TEXTURE_2D, texture)
	fmt.println(img.width, "x", img.height, "chan:", img.channels)
	data := bytes.buffer_to_bytes(&img.pixels)
	fmt.println("data len:", len(data))
	level: i32 = 0
	border: i32 = 0
	internal_format := gl.RGBA
	format := gl.RGBA
	if img.channels == 3 {
		internal_format = gl.RGB
		format = gl.RGB
	}
	type := gl.UNSIGNED_BYTE
	gl.BindTexture(gl.TEXTURE_2D, texture)
	// gl.PixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
	gl.TexImage2DSlice(
		gl.TEXTURE_2D,
		level,
		internal_format,
		cast(i32)img.width,
		cast(i32)img.height,
		border,
		format,
		type,
		data,
	)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, cast(i32)gl.NEAREST)
	return texture
}

