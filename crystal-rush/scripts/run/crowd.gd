class_name Crowd
extends MultiMeshInstance3D
## A crowd of identical soldiers drawn with one MultiMesh: the player's army (a blob that
## trails the hero) or an enemy squad (a block facing the player).
## Slots are ordered back to front, so when the count drops the front rank falls first.

enum Style { ARMY, SQUAD }

var style := Style.ARMY
var count := 0
var anchor := Vector3.ZERO      # army: the hero's feet; squad: centre of its front rank
var width := 2.6                # how wide the crowd may spread
var marching := true
var charge := 0.0               # squad: 0..1 how far the front has run at the enemy
var _pos: Array[Vector3] = []   # smoothed world positions of the drawn soldiers
var _slots: Array[Vector3] = [] # formation offsets from the anchor
var _shown := 0
var _phase: PackedFloat32Array = PackedFloat32Array()


func setup(p_style: Style, mesh: Mesh, p_count: int, p_anchor: Vector3, p_width := 2.6) -> void:
	style = p_style
	width = p_width
	anchor = p_anchor
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = Balance.MAX_SHOWN
	multimesh.visible_instance_count = 0
	material_override = Models.vertex_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_phase.resize(Balance.MAX_SHOWN)
	for i in Balance.MAX_SHOWN:
		_phase[i] = fmod(i * 2.399, TAU)
	set_count(p_count, true)


## Changes the head count. New soldiers appear at `from` (or in place when `snap`).
func set_count(n: int, snap := false, from := Vector3.INF) -> void:
	count = maxi(0, n)
	var shown := mini(count, Balance.MAX_SHOWN)
	_layout(shown)
	var old := _pos.size()
	_pos.resize(shown)
	for i in range(old, shown):
		var start := anchor + _slots[i]
		if not snap and from != Vector3.INF:
			start = from + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		_pos[i] = start
	_shown = shown
	multimesh.visible_instance_count = shown


## Formation offsets, back rank first.
func _layout(n: int) -> void:
	_slots.clear()
	if style == Style.ARMY:
		# Sunflower blob behind the hero, squeezed to the lane and stretched backwards.
		var half := width * 0.5
		for i in n:
			var r := 0.27 * sqrt(i + 0.6)
			var a := i * 2.39996
			var x := r * cos(a)
			var z := r * sin(a)
			if absf(x) > half:
				z += (absf(x) - half) * 1.6 * (1.0 if z >= 0.0 else -1.0)
				x = clampf(x, -half, half)
			_slots.append(Vector3(x, 0, 0.8 + 0.27 * sqrt(n) + z))
		_slots.sort_custom(func(a: Vector3, b: Vector3): return a.z > b.z)
	else:
		var per_row := maxi(3, int(width / 0.42))
		var rows := ceili(float(n) / per_row)
		for i in n:
			var row := rows - 1 - i / per_row     # the first slots go to the back rows
			var col := i % per_row
			var in_row := mini(per_row, n - (i / per_row) * per_row) if i / per_row == n / per_row else per_row
			var x := (col - (in_row - 1) * 0.5) * 0.42 + (0.1 if row % 2 == 1 else 0.0)
			_slots.append(Vector3(x, 0, -row * 0.45))


## Middle of the formation (for the head-count label).
func center() -> Vector3:
	if _slots.is_empty():
		return anchor
	return anchor + Vector3(0, 0, 0.8 + 0.27 * sqrt(_slots.size()))


## Front-most drawn soldier (for effects).
func front_point() -> Vector3:
	if _shown == 0:
		return anchor
	return _pos[_shown - 1]


func point(i: int) -> Vector3:
	return _pos[clampi(i, 0, maxi(_shown - 1, 0))] if _shown > 0 else anchor


func shown() -> int:
	return _shown


func tick(delta: float, t: float) -> void:
	var facing := Basis(Vector3.UP, PI) if style == Style.ARMY else Basis.IDENTITY
	var follow := minf(1.0, delta * (9.0 if style == Style.ARMY else 4.0))
	for i in _shown:
		var target := anchor + _slots[i]
		if style == Style.SQUAD and charge > 0.0:
			target.z += charge * (1.2 + 0.25 * (i % 3))
		var p := _pos[i].lerp(target, follow)
		_pos[i] = p
		var hop := 0.0
		if marching or (style == Style.SQUAD and charge > 0.0):
			hop = absf(sin(t * 13.0 + _phase[i])) * 0.08
		else:
			hop = absf(sin(t * 3.0 + _phase[i])) * 0.015
		var sway := Basis(Vector3.FORWARD, sin(t * 6.5 + _phase[i]) * 0.08)
		multimesh.set_instance_transform(i, Transform3D(facing * sway, Vector3(p.x, p.y + hop, p.z)))
