package fps

import "core:math"

Fps :: struct {
	avg:   f32,
	dts_i: int,
	dts:   [60]f32,
}

init :: proc(fps: ^Fps) {
	fps.avg = 0
	fps.dts = 0.033
	fps.dts_i = 0
}

update :: proc(fps: ^Fps, dt: f32) {
	fps.dts_i = (fps.dts_i + 1) % 60
	fps.dts[fps.dts_i] = dt
	sum: f32 = 0
	for v in fps.dts {
		sum += v
	}
	fps.avg = 60.0 / sum
}

get_average :: proc(fps: Fps) -> int {
	return cast(int)math.round(fps.avg)
}

get_low :: proc(fps: Fps) -> int {
	longest: f32 = 0.0
	for v in fps.dts {
		longest = math.max(longest, v)
	}
	low_fps: f32 = 1 / longest
	return cast(int)math.round(low_fps)
}

