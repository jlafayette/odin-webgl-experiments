package t

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
DstChar :: struct {
	w: u8,
	x: u16,
}
DstHeader :: struct {
	w:          i32,
	h:          i32,
	char_count: i32,
}

_main :: proc(png_file: string) -> (ok: bool) {
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
	grid_w: int = 12
	grid_h: int = 20
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
		spacing := 0
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
		err := bmp.save_to_file("assets/smallest_atlas/debug-20.bmp", &img2)
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
		dst_chars := make([]DstChar, len(chars))
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
		header: DstHeader
		header.w = i32(w)
		header.h = i32(h)
		header.char_count = i32(len(chars))

		// encode header + chars + pixels
		buffer: bytes.Buffer
		written: int
		written, ok = encode(&buffer, header, dst_chars, pixels)

		fmt.println("wrote:", written, "ok:", ok)


		// decode the buffer and write to bmp file to debug encode/decode
		{
			header2, chars2, pixels2, ok := decode(buffer.buf[:written])
			fmt.println("decode:", ok)
			if !ok {return false}
			fmt.println(header2)
			fmt.println("len pixels:", len(pixels2), "expected:", header2.w * header2.h)
			img3, ok3 := image.pixels_to_image(pixels2[:], int(header2.w), int(header2.h))
			fmt.println("pixels_to_image:", ok3)
			if !ok3 {return false}
			err3 := bmp.save_to_file("assets/smallest_atlas/debug-20-decode.bmp", &img3)
			if err3 != nil {
				fmt.println("error saving decoded to bmp:", err3)
				return false
			}
		}
	}

	return true
}

encode :: proc(
	output: ^bytes.Buffer,
	header: DstHeader,
	chars: []DstChar,
	pixels: []bool,
) -> (
	int,
	bool,
) {
	written: int = 0

	if header.w * header.h != i32(len(pixels)) {
		return 0, false
	}

	header_size :: size_of(DstHeader)
	char_size :: size_of(DstChar)
	pixel_size := pixel_byte_len(len(pixels))
	total_size := header_size + (char_size * len(chars)) + pixel_size
	if resize(&output.buf, total_size) != nil {return 0, false}
	header_bytes := transmute([header_size]byte)header
	written += header_size
	copy(output.buf[:], header_bytes[:written])

	for char in chars {
		char_bytes := transmute([char_size]byte)char
		copy(output.buf[written:], char_bytes[:char_size])
		written += char_size
	}
	b: byte
	c: uint
	for px in pixels {
		if c == 8 {
			c = 0
			// write b to output buf
			output.buf[written] = b
			written += 1
			b = 0
		}
		// set single bit in byte
		if px {
			b = b | (1 << c)
		}
		c += 1
	}
	if c > 0 {
		output.buf[written] = b
		written += 1
	}
	return written, true
}
pixel_byte_len :: proc(count: int) -> int {
	div, mod := math.divmod(count, 8)
	if mod > 0 {
		div = div + 1
	}
	return div
}

decode :: proc(data: []byte) -> (DstHeader, [dynamic]DstChar, [dynamic][3]u8, bool) {
	header_size :: size_of(DstHeader)
	char_size :: size_of(DstChar)

	buf: [header_size]byte
	copy(buf[:], data[:header_size])
	header := transmute(DstHeader)buf
	offset := header_size

	chars := make([dynamic]DstChar, 0, header.char_count)
	for _ in 0 ..< header.char_count {
		buf: [char_size]byte
		copy(buf[:], data[offset:offset + char_size])
		char := transmute(DstChar)buf
		append(&chars, char)
		offset += char_size
	}
	// now pixels at the end
	fmt.println("decoding pixels, expect:", header.w * header.h, "bytes:", len(data[offset:]))
	pixels := make([dynamic][3]u8, 0, header.w * header.h)
	outer: for b in data[offset:] {
		broken := false
		for i in 0 ..< 8 {
			if broken {
				// should not be doing another loop after break
				return header, chars, pixels, false
			}
			if i32(len(pixels)) >= header.w * header.h {
				fmt.println("breaking at len(pixels):", len(pixels), "i:", i)
				broken = true
				break outer
			}
			v: u8 = 1 & (b >> uint(i))
			px: [3]u8
			if v > 0 {
				px = {255, 255, 255}
			}
			append(&pixels, px)
		}
	}
	return header, chars, pixels, true
}

main :: proc() {
	// do arg handling here

	//     assets\smallest_atlas\Sprite-20.png	
	_main("assets/smallest_atlas/Sprite-20.png")
}

