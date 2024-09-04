package create_atlas

import "core:bytes"
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

import "./shared/text"

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
pack_wrap_if_needed :: proc(pack: ^PackData, ch: text.Char) -> bool {
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
pack_add_char :: proc(pack: ^PackData, ch: text.Char) -> bool {
	ok := pack_wrap_if_needed(pack, ch)
	if !ok {return false}
	pack.row_height = math.max(pack.row_height, ch.h)
	pack.x += ch.w + pack.gap
	return true
}
scaled :: proc(value: i32, scale: f32) -> i32 {
	return cast(i32)math.round(f32(value) * scale)
}
create_atlas :: proc(ttf_file: string, pixel_height: i32) -> bool {
	data, err := os.read_entire_file_from_filename_or_err(ttf_file)
	if err != nil {
		fmt.println("ERROR: reading file:", err)
		return false
	}
	defer delete(data)

	info: tt.fontinfo
	ok := cast(bool)tt.InitFont(&info, &data[0], 0)
	if !ok {
		fmt.println("ERROR: init font")
		return false
	}
	scale := tt.ScaleForPixelHeight(&info, f32(pixel_height))
	ascent, descent, line_gap: i32
	tt.GetFontVMetrics(&info, &ascent, &descent, &line_gap)
	out_header: text.Header = {
		scale              = scale,
		px                 = pixel_height,
		ascent             = scaled(ascent, scale),
		descent            = scaled(descent, scale),
		line_gap           = scaled(line_gap, scale),
		starting_codepoint = 33,
	}
	out_chars: [dynamic]text.Char
	fmt.printf(
		"px:%d, scale:%.2f, ascent:%d, descent:%d, line_gap:%d\n",
		out_header.px,
		out_header.scale,
		out_header.ascent,
		out_header.descent,
		out_header.line_gap,
	)

	pack: PackData = {
		w   = 64,
		h   = 64,
		gap = 1,
	}
	ch: text.Char
	// 0-31 are control chars, 32 is space
	for {
		pack_reset(&pack)
		done := true
		for i := 33; i < 128; i += 1 {
			x0, y0, x1, y1: i32
			tt.GetCodepointBitmapBox(&info, rune(i), scale, scale, &x0, &y0, &x1, &y1)
			ch.w = x1 - x0
			ch.h = y1 - y0
			prev_y := pack.y
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
	raw_pixels := make([]u8, pack.w * pack.h)
	defer delete(raw_pixels)

	pack_reset(&pack)
	for i := 33; i < 128; i += 1 {
		out_header.codepoint_count += 1
		tt.GetCodepointHMetrics(&info, rune(i), &ch.advance_width, &ch.left_side_bearing)
		ch.advance_width = scaled(ch.advance_width, scale)
		ch.left_side_bearing = scaled(ch.left_side_bearing, scale)
		bitmap := tt.GetCodepointBitmap(
			&info,
			scale,
			scale,
			rune(i),
			&ch.w,
			&ch.h,
			&ch.xoff,
			&ch.yoff,
		)
		defer tt.FreeBitmap(bitmap, nil)
		append(&out_chars, ch)

		ok := pack_wrap_if_needed(&pack, ch)
		if !ok {
			fmt.printf("ERROR: doesn't fit, char %d [%v] would not fit\n", i, rune(i))
			return false
		}
		// write image into pixels slice
		{
			sw := int(ch.w)
			sh := int(ch.h)
			dx_off := int(pack.x)
			dy_off := int(pack.y)
			for sy := 0; sy < sh; sy += 1 {
				for sx := 0; sx < sw; sx += 1 {
					// map from source x,y to dest x,y
					px1: u8 = bitmap[sx + sy * sw]
					px: [3]u8 = {px1, px1, px1}

					dx := sx + dx_off
					dy := sy + dy_off

					di := dx + dy * int(pack.w)
					pixels[di] = px
					raw_pixels[di] = px1
				}
			}
		}
		ok = pack_add_char(&pack, ch)
		if !ok {
			fmt.printf("ERROR: doesn't fit, char %d [%v] would not fit\n", i, rune(i))
			return false
		}
	}
	img, ok2 := image.pixels_to_image(pixels, cast(int)pack.w, cast(int)pack.h)
	if !ok2 {
		fmt.println("ERROR creating Image from slice")
		return false
	}
	fmt.println(img)
	save_err := bmp.save_to_file(fmt.tprintf("atlas_%d.bmp", pixel_height), &img)
	if save_err != nil {
		fmt.println("ERROR: saving to bmp file:", save_err)
		return false
	}

	// save raw pixel data (single channel)
	err = os.write_entire_file_or_err(fmt.tprintf("atlas_pixel_data_%d", pixel_height), raw_pixels)
	if err != nil {
		fmt.println("ERROR: failed to save pixel data with:", err)
		return false
	}

	// encode data and write to file
	buffer: bytes.Buffer
	buffer_len := text.encode_len(out_header, len(out_chars))
	bytes.buffer_init_allocator(&buffer, buffer_len, buffer_len)
	written: int
	written, ok = text.encode(&buffer, out_header, out_chars[:])
	if !ok {
		fmt.println("ERROR: failed to encode atlas data")
		return false
	}
	fmt.printf("written %d bytes\n", written)
	// decode for testing
	{
		header2, chars2, ok := text.decode(buffer.buf[:written])
		if !ok {
			fmt.println("ERROR: failed to decode atlas data")
			return false
		}
		fmt.println(header2)
		fmt.println(len(chars2))
		fmt.println(chars2[0])
	}
	err = os.write_entire_file_or_err(
		fmt.tprintf("atlas_data_%d", pixel_height),
		buffer.buf[:written],
	)
	if err != nil {
		fmt.println("ERROR: failed to save data with:", err)
		return false
	}
	return true
}

main :: proc() {
	sizes: [7]i32 = {72, 60, 48, 36, 24, 18, 12}
	for size, i in sizes {
		ok := create_atlas("Terminal.ttf", size)
		fmt.println(size, ok)
	}
}

