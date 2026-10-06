class_name RewardFly
extends Control
## Rewards flying to their counters (arsenal_design.md §7.4; Balatro / Peggle): icons burst
## out of the source (0.2 s, 60-140 px, expo-out), hold 0.08 s, then fly 0.45-0.65 s on a
## bezier with a 30 ms stagger into the target control. Icon count
## clamp(4 + 3·log2(amount / base), 6, 20). Every arrival ticks (+1 semitone, cap +12, at most
## 15 ticks/s), the target punches 1.0 -> 1.2 -> 1.0 and wobbles; haptics on the first and last
## arrival only. A tap anywhere lands everything at once with one chord.
##
## One node on a top CanvasLayer: RewardFly.layer(get_tree()). The target may implement
## `fly_arrived(cur: String, index: int, count: int)` (e.g. a chip rolling its Odometer from
## the first arrival to the last + 150 ms); otherwise it gets UIJuice.chip_hit().
##
##   await RewardFly.layer(get_tree()).fly(from, "coins", 120, top_bar.chip("coins"))

signal landed(cur: String, amount: int)

const LAYER := 90

## One running flight; `done` fires after the last arrival (+150 ms).
class Job extends RefCounted:
	signal done
	var cur := ""
	var amount := 0
	var target: Control
	var parts: Array[Dictionary] = []
	var arrived := 0
	var finished := false

var _jobs: Array[Job] = []
var _t := 0.0
var _last_tick := -1.0


## The shared RewardFly on its own top CanvasLayer (created on first use).
static func layer(tree: SceneTree) -> RewardFly:
	var cl := tree.root.get_node_or_null("RewardFlyLayer") as CanvasLayer
	if cl == null:
		cl = CanvasLayer.new()
		cl.name = "RewardFlyLayer"
		cl.layer = LAYER
		tree.root.add_child.call_deferred(cl)
		var rf := RewardFly.new()
		rf.name = "RewardFly"
		cl.add_child(rf)
		return rf
	return cl.get_node("RewardFly") as RewardFly


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Icon count for `amount` with `base` (§7.4).
static func icon_count(amount: int, base := 10) -> int:
	var r := float(maxi(amount, 1)) / float(maxi(base, 1))
	return clampi(int(round(4.0 + 3.0 * log(maxf(r, 1e-3)) / log(2.0))), 6, 20)


## Flies `amount` of `cur` from `from_screen` (canvas px) into `target`. Returns the job's
## `done` signal (await it, or ignore it).
func fly(from_screen: Vector2, cur: String, amount: int, target: Control, base := 10) -> Signal:
	var job := Job.new()
	job.cur = cur
	job.amount = amount
	job.target = target
	var n := icon_count(amount, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()
	for i in n:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(60.0, 140.0)
		job.parts.append({
			"from": from_screen,
			"burst": from_screen + Vector2(cos(ang), sin(ang)) * dist,
			"start": _t + i * 0.03,
			"fly": rng.randf_range(0.45, 0.65),
			"curve": rng.randf_range(-1.0, 1.0),
			"spin": rng.randf_range(-3.0, 3.0),
			"size": rng.randf_range(34.0, 46.0),
			"done": false,
		})
	_jobs.append(job)
	Audio.play("coin", -8.0)
	return job.done


## Same as fly() from a 3D point seen by `cam`.
func fly_from_3d(cam: Camera3D, world_pos: Vector3, cur: String, amount: int, target: Control) -> Signal:
	var p := cam.unproject_position(world_pos)
	# Viewport pixels -> canvas units (stretch mode canvas_items).
	var vp := cam.get_viewport()
	var xf := vp.get_final_transform() if vp else Transform2D.IDENTITY
	p = xf.affine_inverse() * p if xf != Transform2D.IDENTITY else p
	return fly(p, cur, amount, target)


## Lands every flying icon now (tap-to-skip) with one chord.
func land_all() -> void:
	var any := false
	for job in _jobs:
		for p in job.parts:
			if not bool(p["done"]):
				p["done"] = true
				any = true
				job.arrived += 1
		_arrive_target(job, job.parts.size() - 1, true)
	if any:
		Audio.note(7, -10.0)
		Audio.note(11, -12.0)
		Audio.note(14, -12.0)
		UIJuice.haptic("THUD", 0.6)


func is_busy() -> bool:
	return not _jobs.is_empty()


func _input(event: InputEvent) -> void:
	if _jobs.is_empty():
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION):
		land_all()


func _process(delta: float) -> void:
	_t += delta
	if _jobs.is_empty():
		return
	for job in _jobs.duplicate():
		for i in job.parts.size():
			var p: Dictionary = job.parts[i]
			if bool(p["done"]):
				continue
			var age := _t - float(p["start"])
			if age >= 0.28 + float(p["fly"]):
				p["done"] = true
				job.arrived += 1
				_arrive_target(job, i, false)
		if job.arrived >= job.parts.size() and not job.finished:
			job.finished = true
			get_tree().create_timer(0.15).timeout.connect(func():
				_jobs.erase(job)
				landed.emit(job.cur, job.amount)
				job.done.emit())
	queue_redraw()


func _arrive_target(job: Job, i: int, all_at_once: bool) -> void:
	var tgt := job.target
	var last := job.arrived >= job.parts.size()
	if is_instance_valid(tgt):
		if tgt.has_method("fly_arrived"):
			tgt.call("fly_arrived", job.cur, job.arrived - 1 if not all_at_once else job.parts.size() - 1, job.parts.size())
		elif job.arrived == 1 or last or all_at_once:
			UIJuice.chip_hit(tgt)
	if all_at_once:
		return
	if job.arrived == 1 or last:
		UIJuice.haptic("TICK", 0.5 if not last else 0.8)
	# ≤ 15 ticks/s, rising a semitone per arrival (cap +12).
	if _t - _last_tick >= 1.0 / 15.0:
		_last_tick = _t
		Audio.note(mini(job.arrived, 12), -16.0)


func _target_point(job: Job) -> Vector2:
	if not is_instance_valid(job.target):
		return Vector2(size.x * 0.5, 40.0)
	var r := job.target.get_global_rect()
	# The chip's icon sits at its left end; aim a little inside.
	return r.position + Vector2(minf(r.size.y * 0.5, r.size.x * 0.5), r.size.y * 0.5)


func _draw() -> void:
	var glow := UIKit.glow_texture()
	for job in _jobs:
		var to := _target_point(job)
		var icon := _icon_for(job.cur)
		for p in job.parts:
			if bool(p["done"]):
				continue
			var age := _t - float(p["start"])
			if age < 0.0:
				continue
			var pos: Vector2
			var s := float(p["size"])
			var a := 1.0
			if age < 0.2:
				var k := age / 0.2
				var e := 1.0 - pow(1.0 - k, 4.0)
				pos = (p["from"] as Vector2).lerp(p["burst"], e)
				s *= 0.4 + 0.6 * e
			elif age < 0.28:
				pos = p["burst"]
			else:
				var k2 := clampf((age - 0.28) / float(p["fly"]), 0.0, 1.0)
				var e2 := k2 * k2 * (3.0 - 2.0 * k2)
				var b0: Vector2 = p["burst"]
				var mid := (b0 + to) * 0.5
				var n := (to - b0).orthogonal().normalized()
				var ctrl := mid + n * float(p["curve"]) * 140.0 + Vector2(0, -60)
				pos = b0.lerp(ctrl, e2).lerp(ctrl.lerp(to, e2), e2)
				s *= lerpf(1.0, 0.62, e2)
			draw_texture_rect(glow, Rect2(pos - Vector2(s, s) * 0.9, Vector2(s, s) * 1.8), false, _glow_color(job.cur) * Color(1, 1, 1, 0.55 * a))
			draw_set_transform(pos, float(p["spin"]) * age * 0.6, Vector2.ONE)
			Icons.draw_icon(self, icon, Rect2(-Vector2(s, s) * 0.5, Vector2(s, s)), Color(1, 1, 1, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _icon_for(cur: String) -> String:
	if cur.begins_with("wild"):
		return "wild"
	match cur:
		"coins": return "coin"
		"gems": return "gem"
		"crowns": return "crown"
		"bp", "blueprints": return "blueprint"
		"cores": return "core"
	return cur


static func _glow_color(cur: String) -> Color:
	match cur:
		"gems": return Color(0.5, 0.9, 1.0)
		"bp", "blueprints": return Color(0.55, 0.8, 1.0)
		"crowns": return Color(1.0, 0.85, 0.4)
	if cur.begins_with("wild"):
		return Color(0.8, 0.6, 1.0)
	return Color(1.0, 0.78, 0.3)
