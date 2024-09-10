package text

import "core:bytes"
import "core:fmt"

Header :: struct {
	atlas_w:            i32,
	atlas_h:            i32,
	scale:              f32,
	px:                 i32,
	ascent:             i32,
	descent:            i32,
	line_gap:           i32,
	kern:               i32,
	starting_codepoint: i32,
	codepoint_count:    i32,
}

// xoff/yoff are the offset it pixel space from the glyph origin to the top-left of the bitmap
// leftSideBearing is the offset from the current horizontal position to the left edge of the character
// advanceWidth is the offset from the current horizontal position to the next horizontal position
//   these are expressed in unscaled coordinates
Char :: struct {
	w:                 f32,
	h:                 f32,
	x:                 f32,
	y:                 f32,
	xoff:              f32,
	yoff:              f32,
	advance_width:     f32,
	left_side_bearing: f32,
}
encode_len :: proc(header: Header, char_count: int) -> int {
	header_size :: size_of(Header)
	char_size :: size_of(Char)
	return header_size + (char_size * char_count)
}

encode :: proc(output: ^bytes.Buffer, header: Header, chars: []Char) -> (int, bool) {
	written: int = 0
	header_size :: size_of(Header)
	char_size :: size_of(Char)
	if resize(&output.buf, header_size + (char_size * len(chars))) != nil {
		return 0, false
	}
	header_bytes := transmute([header_size]byte)header
	// fmt.println("header_bytes:", header_bytes)
	written += header_size
	copy(output.buf[:], header_bytes[:written])
	// fmt.println("buf (header):", output.buf[:written])

	for char in chars {
		char_bytes := transmute([char_size]byte)char
		copy(output.buf[written:], char_bytes[:char_size])
		written += char_size
	}
	fmt.println("header size:", header_size)
	fmt.println("char size:", char_size)
	fmt.printf("char size * %d: %d\n", len(chars), char_size * len(chars))
	fmt.println("written (expected):", header_size + (char_size * len(chars)))
	// fmt.println("buf (header):", output.buf[:header_size])
	return written, true
}
decode :: proc(data: []byte) -> (Header, [dynamic]Char, bool) {
	header_size :: size_of(Header)
	char_size :: size_of(Char)
	// data[0:header_size]
	buf: [header_size]byte
	copy(buf[:], data[:header_size])
	header := transmute(Header)buf
	offset := header_size

	chars := make([dynamic]Char, 0, header.codepoint_count)

	for {
		// cleanly ends
		if len(data) == offset {
			break
		}
		// check and make sure there isn't some
		// dangling data at the end 
		if len(data) < offset + char_size {
			return header, chars, false
		}
		buf: [char_size]byte
		copy(buf[:], data[offset:offset + char_size])
		char := transmute(Char)buf
		append(&chars, char)
		offset += char_size
	}
	fmt.println("offset:", offset)
	fmt.printf("decoded %d chars\n", len(chars))

	return header, chars, true
}
