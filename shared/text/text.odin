package text

import "core:bytes"
import "core:fmt"
import "core:mem"

Header :: struct {
	scale:              f32,
	pixel_height:       f32,
	ascent:             i32,
	descent:            i32,
	line_gap:           i32,
	starting_codepoint: i32,
	codepoint_count:    i32,
}
Char :: struct {
	w:                 i32,
	h:                 i32,
	x:                 i32,
	y:                 i32,
	xoff:              i32,
	yoff:              i32,
	advance_width:     i32,
	left_side_bearing: i32,
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

	for char, i in chars {
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

