package cube_texture2

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:image/png"
import gl "vendor:wasm/WebGL"
import "vendor:wasm/js"

odin_data := #load("odin_logo.png")
uv_data := #load("uv.bmp")

Textures :: [TextureId]TextureInfo
TextureId :: enum {
	Odin,
	Uv,
}
TextureInfo :: struct {
	id:   gl.Texture,
	unit: gl.Enum,
}

textures_init :: proc(t: ^Textures) -> (ok: bool) {
	js.add_window_event_listener(.Key_Down, {}, on_key_down)

	{
		img, err := png.load_from_bytes(odin_data, allocator = context.temp_allocator)
		if err != nil {
			fmt.eprintln("error loading odin image:", err)
			return false
		}
		t[.Odin].id = load_texture(img)
		t[.Odin].unit = gl.TEXTURE0
	}
	{
		img, err := bmp.load_from_bytes(uv_data)
		if err != nil {
			fmt.eprintln("error loading uv image:", err)
			return false
		}
		t[.Uv].id = load_texture(img)
		t[.Uv].unit = gl.TEXTURE0
	}
	return true
}

@(private = "file")
on_key_down :: proc(e: js.Event) {
	if e.key.repeat {
		return
	}
	if e.key.code == "KeyT" {
		current := state.current_texture
		new: TextureId
		if current == .Odin {
			new = .Uv
		} else if current == .Uv {
			new = .Odin
		}
		state.current_texture = new
	}
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
	gl.PixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
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
	if (is_power_of_two(img.width) && is_power_of_two(img.height)) {
		fmt.println("generating mipmaps")
		gl.GenerateMipmap(gl.TEXTURE_2D)
	} else {
		// wasn't able to test this because non-power-of-2 images fail on the
		// TexImage2D command
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, cast(i32)gl.CLAMP_TO_EDGE)
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, cast(i32)gl.LINEAR)
	}
	return texture
}
@(private = "file")
is_power_of_two :: proc(n: int) -> bool {
	return (n & (n - 1)) == 0
}

