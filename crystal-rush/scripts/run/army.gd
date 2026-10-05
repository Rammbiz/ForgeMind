class_name Army
extends Node3D
## The player's army as a living blob behind the hero (Etap 1 spec 5.6).
##
## The Run owns the real head count (`Run.army`); this node owns the drawn units (at most
## `max_shown`, so one drawn unit stands for `weight` soldiers) and their positions.
## Every unit has a slot in a sunflower ellipse around the blob centre (radius `radius`,
## BLOB_STRETCH longer along the run). Units spring to their slots (the rear ones a bit
## slower, so a sideways drag makes the blob trail like a snake), push their neighbours apart,
## are pushed out of solid obstacles and stay on the walkway. Removing a unit swaps the
## outermost one into its slot, so the blob stays compact without reshuffling.
## Newcomers fly in an arc from where they joined (a gate, a recruit group, a geode).
## Deaths go to UnitFx (pop, hop, tumble, puff, debris).

enum Mode { FOLLOW, CHARGE, POSE }

const FLY_TIME := 0.25
const SEP := 0.25               # neighbour repulsion distance
const CELL := 0.3
const GOLDEN := 2.39996323
const WALL := Balance.BRIDGE_HALF - Balance.UNIT_R - 0.04

var view: CrowdView
var fx: UnitFx
var max_shown := Balance.MAX_SHOWN
var shown := 0                  ## units drawn
var center := Vector3.ZERO      ## blob centre (feet level); the Run moves it every step
var radius := Balance.BLOB_MIN  ## blob radius across the run
var mode := Mode.FOLLOW
var marching := false           ## hop while marching, idle breathing otherwise
var charge_z := 0.0             ## CHARGE: the line the front units run to
var charge_x := 0.0
var charge_half := 1.5          ## CHARGE: half width of the front they spread over
var tier := 0

var _pos := PackedVector3Array()    # world feet positions
var _from := PackedVector3Array()   # newcomer flight start
var _fly := PackedFloat32Array()    # flight time left (> 0 while flying)
var _dur := PackedFloat32Array()    # flight duration
var _arc := PackedFloat32Array()    # flight arc height
var _lag := PackedFloat32Array()    # per unit follow-rate jitter
var _pose := PackedVector3Array()   # POSE: per-unit world targets
var _solids: Array = []             # [Vector3 centre, radius] obstacles units are pushed out of
var _slot_n := -1
var _slot_r := -1.0
var _slots := PackedVector3Array()
var _grid := {}
var _rng := RandomNumberGenerator.new()


func setup(p_fx: UnitFx, p_max: int, tier_mesh: Mesh) -> void:
	fx = p_fx
	max_shown = p_max
	_rng.seed = 4242
	view = CrowdView.new()
	view.name = "ArmyView"
	add_child(view)
	view.setup(tier_mesh, max_shown)
	view.set_edge(Color(0.55, 0.8, 1.0), 0.35)
	view.set_gait(12.0)


## Swaps the soldier model (army weapon tier).
func set_mesh(mesh: Mesh) -> void:
	view.multimesh.mesh = mesh
	if fx:
		fx.set_soldier_mesh(mesh)


## Solid obstacles for this step: circles [Vector3 centre, radius] (y ignored).
func set_solids(list: Array) -> void:
	_solids = list


func position_of(i: int) -> Vector3:
	return _pos[i]


func positions() -> PackedVector3Array:
	return _pos


## Index of the drawn unit nearest to `p` (xz), or -1.
func nearest(p: Vector3, max_dist := 1e9) -> int:
	var best := -1
	var bd := max_dist * max_dist
	for i in shown:
		var q := _pos[i]
		var dd := (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z)
		if dd < bd:
			bd = dd
			best = i
	return best


## The front-most units (smallest z), up to `n`, front first.
func front(n: int) -> PackedInt32Array:
	var idx: Array = range(shown)
	idx.sort_custom(func(a: int, b: int) -> bool: return _pos[a].z < _pos[b].z)
	var out := PackedInt32Array()
	for k in mini(n, idx.size()):
		out.append(int(idx[k]))
	return out


## Point at the front of the blob (for effects and volleys).
func front_point() -> Vector3:
	return center + Vector3(0, 0, -radius * Balance.BLOB_STRETCH)


func rear_point() -> Vector3:
	return center + Vector3(0, 0, radius * Balance.BLOB_STRETCH)


## Adds `n` units flying in from a box around `from` (half extents `spread`).
func grow(n: int, from: Vector3, spread := Vector3(0.3, 0.0, 0.3), arc := 0.9) -> void:
	for k in n:
		if shown >= max_shown:
			return
		var p := from + Vector3(_rng.randf_range(-spread.x, spread.x), _rng.randf_range(0.0, spread.y), _rng.randf_range(-spread.z, spread.z))
		_append(p, FLY_TIME * _rng.randf_range(0.85, 1.25), arc * _rng.randf_range(0.7, 1.2))


## Adds one unit flying from each of `points` (e.g. grey recruits turning into soldiers).
func grow_from(points: PackedVector3Array, arc := 0.6) -> void:
	for p in points:
		if shown >= max_shown:
			return
		_append(p, FLY_TIME * _rng.randf_range(0.9, 1.4), arc * _rng.randf_range(0.6, 1.2))


## Adds `n` units with no flight at their slots (the start line).
func spawn(n: int) -> void:
	_ensure_slots()
	for k in n:
		if shown >= max_shown:
			return
		_append(center, 0.0, 0.0)
	_ensure_slots()
	for i in shown:
		_pos[i] = center + _slots[i]


func _append(p: Vector3, fly: float, arc: float) -> void:
	_pos.append(p)
	_from.append(p)
	_fly.append(fly)
	_dur.append(maxf(fly, 0.01))
	_arc.append(arc)
	_lag.append(_rng.randf_range(0.85, 1.15))
	_pose.append(p)
	shown += 1


## Unit `i` dies (death effect pushed by `push`); the outermost unit takes its slot.
func kill(i: int, push := Vector3.ZERO, team := 0) -> void:
	if i < 0 or i >= shown:
		return
	if fx:
		fx.die(_pos[i], team, push)
	_remove(i)


## Removes unit `i` with no effect (it left the crowd some other way).
func drop(i: int) -> void:
	if i >= 0 and i < shown:
		_remove(i)


func _remove(i: int) -> void:
	var last := shown - 1
	if i != last:
		_pos[i] = _pos[last]
		_from[i] = _from[last]
		_fly[i] = _fly[last]
		_dur[i] = _dur[last]
		_arc[i] = _arc[last]
		_lag[i] = _lag[last]
		_pose[i] = _pose[last]
	_pos.resize(last)
	_from.resize(last)
	_fly.resize(last)
	_dur.resize(last)
	_arc.resize(last)
	_lag.resize(last)
	_pose.resize(last)
	shown = last


## Kills the `n` front-most units (clash, siege).
func kill_front(n: int, push := Vector3(0, 0, 1.5)) -> void:
	var idx := front(n)
	var arr: Array = Array(idx)
	arr.sort()
	arr.reverse()
	for i: int in arr:
		kill(i, push + Vector3(_rng.randf_range(-0.8, 0.8), 0, 0))


## Kills `n` random units (red gates, splits).
func kill_random(n: int, push := Vector3.ZERO) -> void:
	for k in mini(n, shown):
		kill(_rng.randi() % shown, push + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)))


## Brings the drawn count to `n`: removes random units silently or grows from the rear.
func fit(n: int, from := Vector3.INF) -> void:
	n = clampi(n, 0, max_shown)
	while shown > n:
		kill(_rng.randi() % shown, Vector3(0, 0, 0.8))
	if shown < n:
		var src := from if from != Vector3.INF else rear_point() + Vector3(0, 0, 0.6)
		grow(n - shown, src, Vector3(radius * 0.6, 0.0, 0.25), 0.5)


## POSE mode: unit `i` walks to `p` (stairs, victory).
func set_pose(i: int, p: Vector3) -> void:
	if i >= 0 and i < shown:
		_pose[i] = p


## Moves the units for `dt` seconds. `advance` is how far the blob centre moved along z this
## step (fed forward so the march itself never lags).
func step(dt: float, advance: float) -> void:
	_ensure_slots()
	var rz := radius * Balance.BLOB_STRETCH
	for i in shown:
		var p := _pos[i]
		if _fly[i] > 0.0:
			# Newcomer: arc from where it joined to its slot.
			var f := _fly[i] - dt
			_fly[i] = f
			_from[i].z += advance
			var target := _target(i, rz)
			var s := clampf(1.0 - f / _dur[i], 0.0, 1.0)
			if f <= 0.0:
				s = 1.0
			var e := 1.0 - (1.0 - s) * (1.0 - s)
			p = _from[i].lerp(target, e)
			p.y = maxf(_from[i].y * (1.0 - e), 0.0) + _arc[i] * 4.0 * s * (1.0 - s)
			_pos[i] = p
			continue
		p.z += advance
		var tg := _target(i, rz)
		var depth := clampf((_slots[i].z + rz) / maxf(2.0 * rz, 0.01), 0.0, 1.0) if mode == Mode.FOLLOW else 0.5
		var kx := 1.0 - exp(-(15.0 - 6.0 * depth) * _lag[i] * dt)
		var kz := 1.0 - exp(-(12.0 if mode != Mode.CHARGE else 5.0) * _lag[i] * dt)
		p.x += (tg.x - p.x) * kx
		p.z += (tg.z - p.z) * kz
		p.y += (tg.y - p.y) * (1.0 - exp(-14.0 * dt))
		_pos[i] = p
	_separate()
	_push_out()


func _target(i: int, rz: float) -> Vector3:
	match mode:
		Mode.POSE:
			return _pose[i]
		Mode.CHARGE:
			# The blob surges forward: units spread across the front and run at the line.
			var s := _slots[i]
			var tg := center + s
			tg.x = charge_x + clampf(s.x * 1.25, -charge_half, charge_half)
			tg.z = minf(tg.z, charge_z + (s.z + rz) * 0.35)
			return tg
	return center + _slots[i]


## Sunflower slots for the current count and radius (offsets from the centre).
func _ensure_slots() -> void:
	if _slot_n == shown and absf(_slot_r - radius) < 0.002:
		return
	_slot_n = shown
	_slot_r = radius
	_slots.resize(shown)
	var n := maxi(shown, 1)
	var rz := radius * Balance.BLOB_STRETCH
	for k in shown:
		var rr := sqrt((k + 0.5) / n)
		var a := k * GOLDEN
		_slots[k] = Vector3(cos(a) * rr * radius, 0.0, sin(a) * rr * rz)


## Light neighbour repulsion on a hash grid.
func _separate() -> void:
	if shown < 2:
		return
	_grid.clear()
	for i in shown:
		var p := _pos[i]
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		var cell_list: PackedInt32Array = _grid.get(key, PackedInt32Array())
		cell_list.append(i)
		_grid[key] = cell_list
	var sep2 := SEP * SEP
	for key: Vector2i in _grid:
		var cell: PackedInt32Array = _grid[key]
		for ox: int in [-1, 0, 1]:
			for oz: int in [0, 1]:
				if oz == 0 and ox < 0:
					continue
				var other_key := Vector2i(key.x + ox, key.y + oz)
				if not _grid.has(other_key):
					continue
				var other: PackedInt32Array = _grid[other_key]
				var same := ox == 0 and oz == 0
				for a in cell.size():
					var i: int = cell[a]
					if _fly[i] > 0.0:
						continue
					var b0 := a + 1 if same else 0
					for b in range(b0, other.size()):
						var j: int = other[b]
						if _fly[j] > 0.0:
							continue
						var dx := _pos[j].x - _pos[i].x
						var dz := _pos[j].z - _pos[i].z
						var dd := dx * dx + dz * dz
						if dd >= sep2 or dd < 1e-8:
							continue
						var dist := sqrt(dd)
						var push := (SEP - dist) * 0.25 / dist
						_pos[i].x -= dx * push
						_pos[i].z -= dz * push
						_pos[j].x += dx * push
						_pos[j].z += dz * push


## Pushes units out of solid obstacles and keeps them on the walkway.
func _push_out() -> void:
	for i in shown:
		var p := _pos[i]
		for s: Array in _solids:
			var c: Vector3 = s[0]
			var r: float = s[1] + Balance.UNIT_R
			var dx := p.x - c.x
			var dz := p.z - c.z
			var dd := dx * dx + dz * dz
			if dd < r * r:
				var dist := sqrt(dd)
				if dist < 0.001:
					dx = 1.0 if p.x >= c.x else -1.0
					dz = 0.0
					dist = 1.0
				p.x = c.x + dx / dist * r
				p.z = c.z + dz / dist * r
		p.x = clampf(p.x, -WALL, WALL)
		_pos[i] = p


## Uploads this frame's instances (one buffer upload).
func draw() -> void:
	var hop := 0.08 if marching else 0.015
	if mode == Mode.CHARGE:
		hop = 0.09
	view.draw(_pos, shown, PI, hop, 0.08)
	if fx:
		fx.set_blob(center, radius if shown > 0 and mode == Mode.FOLLOW else (radius * 0.8 if shown > 0 else 0.0))


## Bounds of the drawn units: [min x, max x, min z, max z].
func bounds() -> Array:
	if shown == 0:
		return [center.x, center.x, center.z, center.z]
	var x0 := 1e9
	var x1 := -1e9
	var z0 := 1e9
	var z1 := -1e9
	for i in shown:
		var p := _pos[i]
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
		z0 = minf(z0, p.z)
		z1 = maxf(z1, p.z)
	return [x0, x1, z0, z1]
