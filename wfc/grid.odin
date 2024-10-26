package wfc

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"

grid_arena_buffer: [mem.Megabyte * 4]byte
grid_arena: mem.Arena = {
	data = grid_arena_buffer[:],
}
grid_arena_allocator := mem.arena_allocator(&grid_arena)

OPTIONS_COUNT :: 13

Grid :: struct {
	squares:   []^Square,
	row_count: int,
	col_count: int,
	resolved:  bool,
	start_at:  Maybe([2]int),
	allocator: mem.Allocator,
}
Square :: struct {
	x:         int,
	y:         int,
	options:   [dynamic]int,
	option:    int,
	collapsed: bool,
}
square_init :: proc(
	s: ^Square,
	x, y: int,
	options_count: int,
	allocator: mem.Allocator = context.allocator,
) {
	err: mem.Allocator_Error
	s.options, err = make_dynamic_array_len_cap(
		[dynamic]int,
		options_count,
		options_count,
		allocator = allocator,
	)
	if err != nil {
		fmt.println("Square init allocation error:", err)
		return
	}
	for i := 0; i < options_count; i += 1 {
		s.options[i] = i
	}
	s.x = x
	s.y = y
}
square_reset :: proc(s: ^Square, options_count: int) {
	clear(&s.options)
	for i in 0 ..< options_count {
		append(&s.options, i)
	}
	s.collapsed = false
	if s.x == 0 && s.y == 0 {
		fmt.println("square reset")
		fmt.println(len(s.options))
		fmt.println(s.options)
	}
}
square_collapse :: proc(s: ^Square) {
	f := rand.float32() * cast(f32)len(s.options)
	i: int = cast(int)math.floor(f)
	s.option = s.options[i]
	s.collapsed = true
}
square_less_options :: proc(i, j: ^Square) -> bool {
	// collapsed should go to the end
	if j.collapsed {
		return true
	}
	if i.collapsed {
		return false
	}
	// if not collapsed, put the one with less options first
	return len(i.options) < len(j.options)
}

grid_init :: proc(grid: ^Grid, row_count, col_count: int) {
	grid.allocator = grid_arena_allocator
	grid.resolved = false
	count := row_count * col_count
	err: mem.Allocator_Error
	grid.squares, err = make_slice([]^Square, count, allocator = grid.allocator)
	if err != nil {
		fmt.println("grid_init allocation error:", err)
		return
	}
	grid.row_count = row_count
	grid.col_count = col_count
	size := grid.row_count * grid.col_count
	i: int = 0
	for y in 0 ..< grid.col_count {
		for x in 0 ..< grid.row_count {
			square: ^Square
			square, err = new(Square, allocator = grid.allocator)
			if err != nil {
				fmt.println("new Square allocation error:", err)
				return
			}
			square_init(square, x, y, OPTIONS_COUNT, allocator = grid.allocator)
			grid.squares[i] = square
			i += 1
		}
	}
	arena := transmute(^mem.Arena)grid.allocator.data

	// w: 1920, h: 1080, rows: 192, cols: 108
	// used 995360 bytes of 2097152	
	fmt.printf("used %d bytes of %d\n", arena.offset, len(arena.data))
}

grid_reset :: proc(grid: ^Grid, maybe_restart_at: Maybe([2]int)) {
	grid.resolved = false
	grid.start_at = nil
	grid.start_at = maybe_restart_at
	for y in 0 ..< grid.col_count {
		for x in 0 ..< grid.row_count {
			maybe_s := grid_get(grid, x, y)
			s, ok := maybe_s.?
			if !ok do continue
			square_reset(s, OPTIONS_COUNT)
		}
	}
}
grid_destroy :: proc(grid: ^Grid) {
	free_all(grid.allocator)
}


grid_get :: proc(g: ^Grid, x, y: int) -> (square: Maybe(^Square)) {
	if x < 0 || y < 0 || x >= g.row_count || y >= g.col_count {
		return nil
	}
	i := y * g.row_count + x
	return g.squares[i]
}
grid_get_neighbors :: proc(g: ^Grid, square: ^Square) -> [4]Maybe(^Square) {
	neighbors: [4]Maybe(^Square)
	neighbors[0] = grid_get(g, square.x - 1, square.y)
	neighbors[1] = grid_get(g, square.x, square.y - 1)
	neighbors[2] = grid_get(g, square.x + 1, square.y)
	neighbors[3] = grid_get(g, square.x, square.y + 1)
	return neighbors
}

