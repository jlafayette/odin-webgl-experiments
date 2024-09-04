package create_atlas

import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:image/png"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:os"
import "core:strings"
import stb_image "vendor:stb/image"
import tt "vendor:stb/truetype"

FontData :: struct {
	info:     tt.fontinfo,
	scale:    f32,
	ascent:   i32,
	descent:  i32,
	line_gap: i32,
}
CharData :: struct {
	w:                 i32,
	h:                 i32,
	x:                 i32,
	y:                 i32,
	xoff:              i32,
	yoff:              i32,
	advance_width:     i32,
	left_side_bearing: i32,
}
PackData :: struct {
	w:          i32,
	h:          i32,
	x:          i32,
	y:          i32,
	row_height: i32,
	gap:        i32,
}
pack_reset :: proc(pack: ^PackData) {
	pack.x = 0
	pack.y = 0
	pack.row_height = 0
}
pack_wrap_if_needed :: proc(pack: ^PackData, ch: CharData) -> bool {
	if (pack.x + ch.w + pack.gap) >= pack.w {
		pack.y += pack.row_height + pack.gap
		pack.row_height = 0
		if pack.y + pack.gap >= pack.w - 1 {
			return false
		}
		pack.x = 0
	}
	return true
}
pack_add_char :: proc(pack: ^PackData, ch: CharData) -> bool {
	ok := pack_wrap_if_needed(pack, ch)
	if !ok {return false}
	pack.row_height = math.max(pack.row_height, ch.h)
	pack.x += ch.w + pack.gap
	return true
}
create_atlas :: proc(fd: ^FontData, ttf_file: string, pixel_height: f32) -> bool {
	data, err := os.read_entire_file_from_filename_or_err(ttf_file)
	if err != nil {
		fmt.println("ERROR: reading file:", err)
		return false
	}
	defer delete(data)

	ok := cast(bool)tt.InitFont(&fd.info, &data[0], 0)
	if !ok {
		fmt.println("ERROR: init font")
		return false
	}

	scale := tt.ScaleForPixelHeight(&fd.info, pixel_height)
	ascent, descent, line_gap: i32
	tt.GetFontVMetrics(&fd.info, &ascent, &descent, &line_gap)
	ascent = cast(i32)math.round(f32(ascent) * scale)
	descent = cast(i32)math.round(f32(descent) * scale)
	line_gap = cast(i32)math.round(f32(line_gap) * scale)
	fmt.printf(
		"Writer height:%.2f, scale:%.2f, ascent:%d, descent:%d, line_gap:%d\n",
		pixel_height,
		scale,
		ascent,
		descent,
		line_gap,
	)

	pack: PackData = {
		w   = 64,
		h   = 64,
		gap = 1,
	}
	ch: CharData
	// 0-31 are control chars, 32 is space
	for {
		pack_reset(&pack)
		done := true
		for i := 33; i < 128; i += 1 {
			tt.GetCodepointHMetrics(&fd.info, rune(i), &ch.advance_width, &ch.left_side_bearing)
			bitmap := tt.GetCodepointBitmap(
				&fd.info,
				scale,
				scale,
				rune(i),
				&ch.w,
				&ch.h,
				&ch.xoff,
				&ch.yoff,
			)
			defer tt.FreeBitmap(bitmap, nil)
			if pack.w == 256 && (i == 33 || i == 51 || i == 67) {
				fmt.printf(
					"checking if %v (%dx%d) can write to %d,%d\n",
					rune(i),
					ch.w,
					ch.h,
					pack.x,
					pack.y,
				)
			}
			prev_y := pack.y
			// fmt.printf("%v %dx%d, x,y=(%d,%d)\n", rune(i), width, height, x, y)
			ok := pack_add_char(&pack, ch)
			if !ok {
				done = false
				fmt.printf(
					"doesn't fit in %dx%d, char %d [%v] would not fit\n",
					pack.w,
					pack.h,
					i,
					rune(i),
				)
				break
			}
			if prev_y != pack.y && (i == 33 || i == 51 || i == 67) {
				fmt.println("  nope!")
			}
		}
		if done {
			break
		}
		pack.w = pack.w * 2
		pack.h = pack.h * 2
	}
	fmt.printf("will fit in %dx%d - ending x,y: %d,%d\n", pack.w, pack.h, pack.x, pack.y)

	pixels := make([][3]u8, pack.w * pack.h)
	defer delete(pixels)

	pack_reset(&pack)
	for i := 33; i < 128; i += 1 {
		tt.GetCodepointHMetrics(&fd.info, rune(i), &ch.advance_width, &ch.left_side_bearing)
		bitmap := tt.GetCodepointBitmap(
			&fd.info,
			scale,
			scale,
			rune(i),
			&ch.w,
			&ch.h,
			&ch.xoff,
			&ch.yoff,
		)
		defer tt.FreeBitmap(bitmap, nil)

		ok := pack_wrap_if_needed(&pack, ch)
		if !ok {
			fmt.printf("ERROR: doesn't fit, char %d [%v] would not fit\n", i, rune(i))
			return false
		}
		// write image into slice
		// fmt.printf("%dx%d, off: %d,%d\n", width, height, xoff, yoff)
		{
			sw := int(ch.w)
			sh := int(ch.h)
			dx_off := int(pack.x)
			dy_off := int(pack.y)
			if i == 33 || i == 51 || i == 67 {
				fmt.printf("writing %v (%dx%d) to %d,%d\n", rune(i), sw, sh, dx_off, dy_off)
			}

			for sy := 0; sy < sh; sy += 1 {
				for sx := 0; sx < sw; sx += 1 {
					// map from source x,y to dest x,y
					px1: u8 = bitmap[sx + sy * sw]
					px: [3]u8 = {px1, px1, px1}

					dx := sx + dx_off
					dy := sy + dy_off

					di := dx + dy * int(pack.w)
					pixels[di] = px
				}
			}
		}

		// fmt.printf("%v %dx%d, x,y=(%d,%d)\n", rune(i), width, height, x, y)
		ok = pack_add_char(&pack, ch)
		if !ok {
			fmt.printf("ERROR: doesn't fit, char %d [%v] would not fit\n", i, rune(i))
			return false
		}
		// fmt.printf("%dx%d\nbitmap:\n%v\n", width, height, bitmap)
	}

	img, ok2 := image.pixels_to_image(pixels, cast(int)pack.w, cast(int)pack.h)
	if !ok2 {
		fmt.println("ERROR creating Image from slice")
		return false
	}
	fmt.println(img)
	save_err := bmp.save_to_file("atlas.bmp", &img)
	if save_err != nil {
		fmt.println("ERROR: saving to bmp file:", save_err)
		return false
	}

	return true
}

main :: proc() {
	// open font file
	fd: FontData
	ok := create_atlas(&fd, "Terminal.ttf", 32)
	fmt.println(ok)

	// save all the chars to an atlas texture
	// save metadata to a data file for each char

}

