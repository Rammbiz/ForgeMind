extends Node
## Run bench (heroes design §10.6, phase H0 baseline): plays one level with the test bot through
## the normal router (main.gd + the autotest tool) and records the real cost of every frame.
## Prints one BENCH JSON line on exit: frames, wall ms p50 / p95 / p99 / max, process ms p50 /
## p95 (Performance.TIME_PROCESS), mean draw calls and primitives, and the run result.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 360x640 --fixed-fps 30 \
##       res://scenes/dev/bench_run.tscn -- --autotest --level=9 --hero=bolt --speed=1
##
## With --fixed-fps the game advances 1/30 s per frame whatever a frame costs, so every build
## renders the same frames: wall times compare across builds on the same machine (the container
## renders with llvmpipe, so only ratios mean anything; phone numbers come from the device bench).
## --skip=N ignores the first N frames (load, shader compiles; default 30).

const MAIN := "res://scripts/main.gd"

var _wall: PackedFloat32Array = PackedFloat32Array()
var _proc: PackedFloat32Array = PackedFloat32Array()
var _draws := 0.0
var _prims := 0.0
var _last_us := 0
var _skip := 30
var _n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skip="):
			_skip = int(a.trim_prefix("--skip="))
	process_priority = -1000
	var main: Node = (load(MAIN) as GDScript).new()
	main.name = "Main"
	add_child(main)
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var wall := float(now - _last_us) / 1000.0
	_last_us = now
	_n += 1
	if _n <= _skip:
		return
	_wall.append(wall)
	_proc.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	_draws += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_prims += float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _exit_tree() -> void:
	var n := _wall.size()
	var w := _wall.duplicate()
	w.sort()
	var p := _proc.duplicate()
	p.sort()
	print("BENCH " + JSON.stringify({
		"frames": n,
		"wall_p50": _pct(w, 0.5), "wall_p95": _pct(w, 0.95), "wall_p99": _pct(w, 0.99),
		"wall_max": w[n - 1] if n > 0 else 0.0,
		"wall_mean": _mean(w),
		"process_p50": _pct(p, 0.5), "process_p95": _pct(p, 0.95),
		"draws_mean": _draws / maxf(n, 1), "prims_mean": _prims / maxf(n, 1),
	}))


static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	return snappedf(a[clampi(int(floor(q * (a.size() - 1))), 0, a.size() - 1)], 0.01)


static func _mean(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return snappedf(s / maxf(a.size(), 1), 0.01)
