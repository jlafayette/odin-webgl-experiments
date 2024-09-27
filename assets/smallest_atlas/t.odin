package t

import text "../../shared/text2"
import "core:bytes"
import "core:fmt"
import "core:image"
import "core:image/bmp"
import "core:image/png"
import "core:math"
import "core:os"

SrcChar :: struct {
	w:          int,
	h:          int,
	y_from_top: int,
	pixels:     []bool,
}

_main :: proc(png_file: string, grid_w: int, grid_h: int) -> (ok: bool) {
	// read png 2,824 bytes
	img: ^image.Image
	{
		data, err := os.read_entire_file_from_filename_or_err(png_file)
		if err != nil {
			fmt.println("ERROR: reading file:", err)
			return false
		}
		defer delete(data)
		fmt.printf("read %d bytes\n", len(data))

		img_err: png.Error
		img, img_err = png.load_from_bytes(data)
		if img_err != nil {
			fmt.println("ERROR: loading png:", err)
			return false
		}

		img, ok = image.return_single_channel(img, .R)
		if !ok {
			fmt.println("ERROR: converting to single channel")
			return false
		}
	}
	fmt.printf("loaded pixel data: %dx%d\n", img.width, img.height)
	fmt.println(img)

	// using grid, isolate chars
	chars := make([]SrcChar, '~' - '!' + 1)
	char_i := 33
	read_loop: for grid_y in 0 ..< img.height / grid_h {
		for grid_x in 0 ..< img.width / grid_w {
			// trim to char, record offset on y
			// fmt.printf("reading grid %dx%d\n", grid_x, grid_y)
			left := grid_w
			right := 0
			top := grid_h
			bottom := 0
			for sub_y in 0 ..< grid_h {
				for sub_x in 0 ..< grid_w {
					// read pixel
					x := grid_x * grid_w + sub_x
					y := grid_y * grid_h + sub_y
					i := y * img.width + x
					r := img.pixels.buf[i]
					// v := '.'
					// if r > 0 {v = '8'}
					// fmt.print(v)
					if r > 0 {
						left = min(left, sub_x)
						right = max(right, sub_x)
						top = min(top, sub_y)
						bottom = max(bottom, sub_y)
					}
				}
				// fmt.print("\n")
			}
			// fmt.printf("char %d,%d->%d,%d\n", left, top, right, bottom)
			char := &chars[char_i - '!']
			char.y_from_top = top
			char.w = right - left + 1
			char.h = bottom - top + 1
			char.pixels = make([]bool, char.w * char.h)
			// fmt.printf(
			// 	"char %v %dx%d len(%d)\n",
			// 	rune(char_i),
			// 	char.w,
			// 	char.h,
			// 	len(chars[char_i - '!'].pixels),
			// )
			for sub_y in top ..= bottom {
				for sub_x in left ..= right {
					x := grid_x * grid_w + sub_x
					y := grid_y * grid_h + sub_y
					i := y * img.width + x
					r := img.pixels.buf[i]
					v := r > 127
					char_pixel_i := (sub_y - top) * char.w + (sub_x - left)
					char.pixels[char_pixel_i] = v
				}
			}
			char_i += 1
			if char_i > '~' {
				break read_loop
			}
		}
		// fmt.print("\n\n")
	}

	// resave to packed png for debugging
	{
		h := grid_h
		w: int
		spacing := 2
		for ch in chars {
			w += ch.w + spacing
		}
		pixels := make([][3]u8, w * h)

		// convert Chars to pixels
		dst_left_x := 0
		for char, char_i in chars {
			for src_y in 0 ..< char.h {
				for src_x in 0 ..< char.w {
					dst_x := dst_left_x + src_x
					dst_y := src_y + char.y_from_top
					dst_i := dst_y * w + dst_x
					v: u8 = 0
					if char.pixels[src_y * char.w + src_x] {
						v = 255
					}
					pixels[dst_i] = {v, v, v}
				}
			}
			dst_left_x += char.w + spacing
		}

		img2, ok := image.pixels_to_image(pixels, w, h)
		if !ok {
			fmt.println("ERROR: converting to debug Image")
			return false
		}
		err := bmp.save_to_file(fmt.tprintf("assets/smallest_atlas/debug-%d.bmp", grid_h), &img2)
		if err != nil {
			fmt.println("ERROR: saving bmp:", err)
			return false
		}
		fmt.printf("saved debug bmp file %dx%d\n", w, h)
	}

	// save char data and bitdepth 1 to data file
	{
		h := grid_h
		w: int
		spacing := 0
		for ch in chars {
			w += ch.w + spacing
		}
		dst_chars := make([]text.Char, len(chars))
		// unpacked pixels
		pixels := make([]bool, w * h)

		// convert Chars to pixels
		dst_left_x := 0
		for char, char_i in chars {
			for src_y in 0 ..< char.h {
				for src_x in 0 ..< char.w {
					dst_x := dst_left_x + src_x
					dst_y := src_y + char.y_from_top
					dst_i := dst_y * w + dst_x
					v: bool = char.pixels[src_y * char.w + src_x]
					pixels[dst_i] = v
				}
			}
			dst_chars[char_i].w = u8(char.w)
			dst_chars[char_i].x = u16(dst_left_x)
			dst_left_x += char.w + spacing
		}
		// resave to bitdepth 1
		header: text.Header
		header.w = i32(w)
		header.h = i32(h)
		header.char_count = i32(len(chars))

		// encode header + chars + pixels
		buffer: bytes.Buffer
		written: int
		written, ok = text.encode(&buffer, header, dst_chars, pixels)
		fmt.println("wrote:", written, "ok:", ok)

		// decode the buffer and write to bmp file to debug encode/decode
		{
			header, chars, pixels, ok := text.decode(buffer.buf[:written], 3)
			fmt.println("decode:", ok)
			if !ok {return false}
			fmt.println(header)
			fmt.println("len pixels:", len(pixels), "expected:", header.w * header.h)
			img: image.Image
			img, ok = image.pixels_to_image(pixels[:], int(header.w), int(header.h))
			fmt.println("pixels_to_image:", ok)
			if !ok {return false}
			err := bmp.save_to_file(
				fmt.tprintf("assets/smallest_atlas/debug-%d-decode.bmp", grid_h),
				&img,
			)
			if err != nil {
				fmt.println("error saving decoded img to bmp:", err)
				return false
			}
		}

		// write encoded data to file
		err := os.write_entire_file_or_err(
			fmt.tprintf("assets/smallest_atlas/data-%d.jatlas", grid_h),
			buffer.buf[:written],
		)
		if err != nil {
			fmt.println("ERROR: failed to save data with:", err)
			return false
		}
	}

	return true
}


main :: proc() {
	// do arg handling here

	// assets\smallest_atlas\Sprite-20.png	
	ok := _main("assets/smallest_atlas/Sprite-20_2.png", 12, 20)
	fmt.println("ok:", ok)
	ok = _main("assets/smallest_atlas/Sprite-30.png", 18, 30)
	fmt.println("ok:", ok)
	ok = _main("assets/smallest_atlas/Sprite-40.png", 24, 40)
	fmt.println("ok:", ok)
}

