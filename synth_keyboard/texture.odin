package synth_keyboard

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/png"
import gl "vendor:wasm/WebGL"

corner_texture_data := #load("../assets/corner.png")
// keys_atlas_texture_data := #load("../assets/keys_atlas_pixel_data")

Textures :: [TextureId]TextureInfo
TextureId :: enum {
	Corner,
	// KeysAtlas,
}
TextureInfo :: struct {
	id:   gl.Texture,
	unit: gl.Enum,
}

textures_init :: proc(t: ^Textures) -> (ok: bool) {
	{
		img, err := png.load_from_bytes(corner_texture_data)
		defer image.destroy(img)
		if err != nil {
			fmt.eprintln("error loading corner.png image:", err)
			return false
		}
		t[.Corner].id = load_texture(img)
		t[.Corner].unit = gl.TEXTURE0
	}
	// {
	// 	t[.KeysAtlas].id = load_pixels_to_texture(
	// 		keys_atlas_texture_data,
	// 		keys_atlas_w,
	// 		keys_atlas_h,
	// 	)
	// 	t[.KeysAtlas].unit = gl.TEXTURE0
	// }

	return true
}

@(private = "file")
load_pixels_to_texture :: proc(pixels: []byte, w, h: i32) -> gl.Texture {
	texture := gl.CreateTexture()
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexImage2DSlice(gl.TEXTURE_2D, 0, gl.ALPHA, w, h, 0, gl.ALPHA, gl.UNSIGNED_BYTE, pixels)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.LINEAR))
	return texture
}

@(private = "file")
load_texture :: proc(img: ^image.Image) -> gl.Texture {
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
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.LINEAR)
	return texture
}
@(private = "file")
is_power_of_two :: proc(n: int) -> bool {
	return (n & (n - 1)) == 0
}

