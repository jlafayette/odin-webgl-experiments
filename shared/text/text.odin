package text

import "core:bytes"
// import "core:fmt"
import "core:math"

Char :: struct {
	w: u8,
	x: u16,
}
Header :: struct {
	w:          i32,
	h:          i32,
	char_count: i32,
}

encode :: proc(
	output: ^bytes.Buffer,
	header: Header,
	chars: []Char,
	pixels: []bool,
) -> (
	int,
	bool,
) {
	written: int = 0

	if header.w * header.h != i32(len(pixels)) {
		return 0, false
	}

	header_size :: size_of(Header)
	char_size :: size_of(Char)
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

decode :: proc(data: []byte, $T: uint) -> (Header, [dynamic]Char, [dynamic][T]u8, bool) {
	header_size :: size_of(Header)
	char_size :: size_of(Char)

	buf: [header_size]byte
	copy(buf[:], data[:header_size])
	header := transmute(Header)buf
	offset := header_size

	chars := make([dynamic]Char, 0, header.char_count)
	for _ in 0 ..< header.char_count {
		buf: [char_size]byte
		copy(buf[:], data[offset:offset + char_size])
		char := transmute(Char)buf
		append(&chars, char)
		offset += char_size
	}
	// now pixels at the end
	pixels := make([dynamic][T]u8, 0, header.w * header.h)
	outer: for b in data[offset:] {
		for i in 0 ..< 8 {
			if i32(len(pixels)) >= header.w * header.h {
				break outer
			}
			v: u8 = 1 & (b >> uint(i))
			px: [T]u8
			if v > 0 {
				px = 255
			}
			append(&pixels, px)
		}
	}
	ok := i32(len(pixels)) == header.w * header.h
	return header, chars, pixels, ok
}

