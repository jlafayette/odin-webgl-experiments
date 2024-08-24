package basic

import "core:fmt"

main :: proc () {}

@export
add :: proc (a: i32, b: i32) -> i32 {
	return a + b
}

count : int = 0

@export
step :: proc(dt: f32) -> (keep_going: bool) {
	count += 1
	fmt.println("dt:", dt, " count:", count)
	keep_going = count < 10
	return keep_going
}
