class_name CameraRig
extends Node3D
## Tilted perspective camera that auto-fits the map, with pan, pinch-zoom and shake.

var camera: Camera3D
var pitch_deg := 54.0
var map_size := Vector2(16, 9)
var margin := Vector4(0.035, 0.12, 0.115, 0.035)   # left, top, right, bottom (fraction of viewport)
var focus := Vector3.ZERO
var _target_focus := Vector3.ZERO
var dist := 14.0
var _target_dist := 14.0
var fit_dist := 14.0
var _shake := 0.0
var _t := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.5
	camera.far = 120.0
	add_child(camera)
	get_viewport().size_changed.connect(refit)


func setup(p_map_size: Vector2) -> void:
	map_size = p_map_size
	refit()
	dist = _target_dist
	focus = _target_focus
	_apply()


## Finds the camera distance at which the whole map fits on screen.
func refit() -> void:
	var lo := 3.0
	var hi := 80.0
	for i in 28:
		var mid := (lo + hi) * 0.5
		if _fits(mid):
			hi = mid
		else:
			lo = mid
	fit_dist = hi
	_target_dist = fit_dist
	_target_focus = Vector3.ZERO
	_clamp_target()


func _fits(d: float) -> bool:
	_place(Vector3.ZERO, d)
	var vp := get_viewport().get_visible_rect().size
	var hw := map_size.x * 0.5
	var hh := map_size.y * 0.5
	for corner in [Vector3(-hw, 0.3, -hh), Vector3(hw, 0.3, -hh), Vector3(-hw, 0.0, hh), Vector3(hw, 0.0, hh), Vector3(-hw, -0.6, hh), Vector3(hw, -0.6, hh)]:
		if camera.is_position_behind(corner):
			return false
		var p := camera.unproject_position(corner)
		if p.x < vp.x * margin.x or p.x > vp.x * (1.0 - margin.z) or p.y < vp.y * margin.y or p.y > vp.y * (1.0 - margin.w):
			return false
	return true


func _place(f: Vector3, d: float) -> void:
	var pitch := deg_to_rad(pitch_deg)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * d
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(-pitch, 0, 0)), f + offset)


func _apply() -> void:
	_place(focus, dist)
	if _shake > 0.0:
		camera.h_offset = (randf() - 0.5) * _shake
		camera.v_offset = (randf() - 0.5) * _shake
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _process(delta: float) -> void:
	_t += delta
	var k := minf(1.0, delta * 10.0)
	dist = lerpf(dist, _target_dist, k)
	focus = focus.lerp(_target_focus, k)
	_shake = maxf(_shake - delta * 1.8, 0.0)
	_apply()


func shake(amount: float) -> void:
	_shake = minf(_shake + amount, 0.5)


func zoom_by(factor: float) -> void:
	_target_dist = clampf(_target_dist * factor, fit_dist * 0.5, fit_dist * 1.08)
	_clamp_target()


func pan_screen(from: Vector2, to: Vector2) -> void:
	var a := screen_to_ground(from)
	var b := screen_to_ground(to)
	_target_focus += a - b
	_target_focus.y = 0.0
	_clamp_target()
	focus = _target_focus


func _clamp_target() -> void:
	var zoom_in := clampf(1.0 - _target_dist / fit_dist, 0.0, 0.5) * 2.0
	var lim := Vector2(map_size.x * 0.5, map_size.y * 0.5) * zoom_in
	_target_focus.x = clampf(_target_focus.x, -lim.x, lim.x)
	_target_focus.z = clampf(_target_focus.z, -lim.y, lim.y)


func screen_to_ground(screen: Vector2, plane_y := 0.0) -> Vector3:
	# Use the un-shaken transform so taps are stable.
	var o := camera.project_ray_origin(screen)
	var n := camera.project_ray_normal(screen)
	if absf(n.y) < 1e-5:
		return Vector3.ZERO
	var t := (plane_y - o.y) / n.y
	return o + n * t


func world_to_screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


func is_behind(p: Vector3) -> bool:
	return camera.is_position_behind(p)
