package camera

import "core:math"

g_fps: f32

@(private = "file")
_dts: [60]f32 = 0.033
@(private = "file")
_dts_i: int = 0

update_fps :: proc(dt: f32) {
	_dts_i = (_dts_i + 1) % 60
	_dts[_dts_i] = dt
	sum: f32 = 0
	for v in _dts {
		sum += v
	}
	g_fps = 60.0 / sum
}

get_fps_average :: proc() -> int {
	return cast(int)math.round(g_fps)
}
get_fps_low :: proc() -> int {
	longest: f32 = 0.0
	for v in _dts {
		longest = math.max(longest, v)
	}
	low_fps: f32 = 1 / longest
	return cast(int)math.round(low_fps)
}

