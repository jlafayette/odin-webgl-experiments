package wfc

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"


wfc_step :: proc(game: ^Game) {
	grid := &game.grid
	if grid.resolved do return
	if len(grid.squares) == 0 do return
	// when ODIN_DEBUG {fmt.print(".")} // doesn't seem to work with wasm...
	fmt.print(".")

	// copy so sorting doesn't rearange placement in grid
	squares := slice.clone(grid.squares, allocator = context.temp_allocator)

	// sort by fewest possible states
	slice.sort_by(squares, square_less_options)
	// print_options(squares)

	// pick random out of ones with least options
	if squares[0].collapsed {
		grid.resolved = true
		return
	}
	rand_mult: int = 0 // track how many we are randomly picking from
	options_count := len(squares[0].options)
	for s in squares {
		if s.collapsed || len(s.options) > options_count {
			break
		}
		rand_mult += 1
	}
	// fmt.printf("tied with %d: %d\n", options_count, rand_mult)
	f := rand.float32()
	f *= f32(rand_mult)
	square_i := int(math.floor(f))
	square := squares[square_i]
	square_collapse(square)

	// print_options(squares)

	my_sides: [4]Side
	{
		to := game.tile_options[square.option]
		ts := tile_set[to.tile]
		my_sides = tile_sides(ts.sides, to.xform)
	}

	// remove options from neighbors
	for maybe_n, i in grid_get_neighbors(grid, square) {
		n, ok := maybe_n.?
		if !ok do continue

		my_side_i: int
		n_side_i: int
		switch i {
		case 0:
			// left
			my_side_i = 0
			n_side_i = 2
		case 1:
			// up
			my_side_i = 1
			n_side_i = 3
		case 2:
			// right
			my_side_i = 2
			n_side_i = 0
		case 3:
			// down
			my_side_i = 3
			n_side_i = 1
		case:
			assert(false, "invalid number of neighbors")
		}

		j: int = 0
		for {
			if j >= len(n.options) {
				break
			}

			to := game.tile_options[n.options[j]]
			ts := tile_set[to.tile]
			n_sides := tile_sides(ts.sides, to.xform)
			n_side := n_sides[n_side_i]
			my_side := my_sides[my_side_i]
			if n_side != my_side {
				unordered_remove(&n.options, j)
			} else {
				// only move on if the current one hasn't been deleted
				j += 1
			}
		}
	}
}

print_options :: proc(squares: []^Square) {
	for s in squares {
		fmt.println(s.collapsed, " ", len(s.options), " ", s.options)
	}
	fmt.println("")
}

