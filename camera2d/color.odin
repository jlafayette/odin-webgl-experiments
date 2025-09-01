package game

import "core:math"
import "core:math/rand"

// #222031
// #5a3f73
// #ca3636
// #f3ecd7  

@(private = "file")
_diff :: proc(c: [3]f32, tgt: f32) -> f32 {
	total := c.x + c.y + c.z
	diff := (tgt * 3) - total
	return diff
}

color_random_rgb :: proc(luminance: f32) -> [3]f32 {
	// TODO: use CIELAB or other colorspace
	lum: f32 = math.clamp(luminance, 0, 1)
	c: [3]f32 = {rand.float32(), rand.float32(), rand.float32()}
	outer: for _ in 0 ..< 10 {
		for _, i in c {
			c[i] += _diff(c, lum) / 3.0
			c[i] = math.clamp(c[i], 0, 1)
			if math.abs(_diff(c, lum)) < 0.01 {
				break outer
			}
		}
	}
	return c
}

@(private = "file")
_rgb :: proc(r: int, g: int, b: int) -> [4]f32 {
	r: f32 = f32(r) / 255
	g: f32 = f32(g) / 255
	b: f32 = f32(b) / 255
	return {r, g, b, 1}
}

COLOR_1: [4]f32 = _rgb(0x22, 0x20, 0x31)
COLOR_2: [4]f32 = _rgb(0x5a, 0x3f, 0x73)
COLOR_3: [4]f32 = _rgb(0xca, 0x36, 0x36)
COLOR_4: [4]f32 = _rgb(0xf3, 0xec, 0xd7)

Color :: enum u8 {
	C1,
	C2,
	C3,
	C3_5,
	C4,
}

color_enum_to_4f32 :: proc(c: Color) -> [4]f32 {
	f_color: [4]f32
	switch c {
	case .C1:
		f_color = COLOR_1
	case .C2:
		f_color = COLOR_2
	case .C3:
		f_color = COLOR_3
	case .C3_5:
		f_color = COLOR_3
		f_color.a = 0.5
	case .C4:
		f_color = COLOR_4
	}
	return f_color
}

