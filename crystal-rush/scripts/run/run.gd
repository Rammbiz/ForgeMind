class_name Run
extends Node3D
## One level. The hero leads the army up the bridge at a steady pace; the player picks the lane.
## +1 tiles and gates change the army, enemy squads clash with it one for one, barricades
## cost a soldier per point of strength, and the fortress at the end needs what is left.
## The hero strikes whatever blocks its lane ahead and has an ultimate charged by the fight.

signal finished(won: bool, coins: int, reason: String)
signal army_changed(n: int)
signal ult_changed(ratio: float, ready: bool)
signal coins_changed(n: int)

enum State { READY, RUNNING, CLASH, BREACH, FINALE, WON, LOST }

const TILE_TEX := preload("res://assets/textures/plus_tile.png")
const FINALE_TIME := 5.0        # how long the hero may batter the gate alone
const CAM_HEIGHT := 8.6
const CAM_BACK := 6.0
const CAM_AHEAD := 3.2
const CAM_HFOV := 40.0          # wanted horizontal view; the vertical one is capped for tall phones

var level := 1
var hero_type := "bolt"
var def: Dictionary
var ult: Dictionary
var state := State.READY
var d := 0.0                    # distance run
var lane := 0
var leader_x := Balance.LANE_X[0]
var army := 0
var hero_hp := 0
var coins := 0
var ult_points := 0.0
var length := 100.0
var expected := 0.0
var quality_high := true

var track: Track
var effects: Effects
var hero: RunHero
var crowd: Crowd
var cam: Camera3D
var items: Array[Dictionary] = []

var _army_label: Label3D
var _foe: Dictionary = {}
var _next := 0                  # first item the leader has not passed yet
var _tick := 0.0
var _attack_cd := 0.0
var _ult_left := 0.0
var _ult_tick := 0.0
var _quake_wave := 0
var _finale_left := 0.0
var _t := 0.0
var _fx_cd := 0.0
var _end_t := 0.0
var _tiles: MultiMeshInstance3D
var _coins: MultiMeshInstance3D
var _coin_items: Array[Dictionary] = []
var _drag_from := Vector2.INF
var _cam_pos := Vector3.ZERO


func setup(p_level: int, p_hero: String) -> void:
	level = p_level
	hero_type = p_hero
	def = Balance.HEROES[hero_type]
	ult = def["ult"]
	army = Balance.start_army(int(Save.upgrades["army"]))
	hero_hp = int(def["hp"])


func _ready() -> void:
	quality_high = Save.quality == "high"
	var gen := LevelGen.build(level, army)
	length = float(gen["length"])
	expected = float(gen["expected"])
	track = Track.new()
	add_child(track)
	track.build(length, quality_high)
	effects = Effects.new()
	effects.quality_high = quality_high
	add_child(effects)
	_spawn_items(gen["items"])
	hero = RunHero.new()
	add_child(hero)
	hero.setup(hero_type)
	crowd = Crowd.new()
	add_child(crowd)
	crowd.setup(Crowd.Style.ARMY, Models.soldier_mesh(), army, _leader_pos(), 2.6)
	_army_label = Models.label(str(army), 100, Color(0.75, 0.9, 1.0), true)
	add_child(_army_label)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 260.0
	add_child(cam)
	_fit_fov()
	get_viewport().size_changed.connect(_fit_fov)
	_cam_pos = _cam_target()
	_place_camera(1.0)
	cam.make_current()
	_sync_visuals(0.0)


## Starts the run (the HUD calls this on the first touch or after the intro).
func start() -> void:
	if state == State.READY:
		state = State.RUNNING


# ------------------------------------------------------------------ building

func _spawn_items(list: Array) -> void:
	var tiles: Array[Dictionary] = []
	for spec: Dictionary in list:
		var it := spec.duplicate()
		it["alive"] = true
		var lane_i := int(it["lane"])
		var x := 0.0 if lane_i < 0 else Balance.LANE_X[lane_i]
		it["x"] = x
		var at := Vector3(x, 0, -float(it["d"]))
		match str(it["kind"]):
			"tile":
				tiles.append(it)
			"coin":
				_coin_items.append(it)
			"gate":
				var good := str(it["op"]) in ["+", "x"]
				var node := Models.gate(_gate_text(it), good, Balance.LANE_HALF * 2.0 - 0.2)
				node.position = at
				add_child(node)
				it["node"] = node
			"barricade":
				it["hp"] = int(it["value"])
				var b := Models.barricade(int(it["hp"]), Balance.LANE_HALF * 2.0 - 0.15)
				b.position = at
				add_child(b)
				it["node"] = b
			"squad":
				it["hp"] = int(it["value"])
				var c := Crowd.new()
				add_child(c)
				c.setup(Crowd.Style.SQUAD, Models.raider_mesh(), int(it["hp"]), at, 2.5)
				c.marching = false
				it["crowd"] = c
				var l := Models.label(str(it["hp"]), 140, Color(1.0, 0.55, 0.5), true)
				add_child(l)
				it["label"] = l
			"fortress":
				it["hp"] = int(it["value"])
				var f := Models.fortress(int(it["hp"]), Balance.BRIDGE_HALF * 2.0)
				f.position = at + Vector3(0, 0, -0.6)
				add_child(f)
				it["node"] = f
		items.append(it)
	# Pair the gates that share a row: going through one closes the other.
	for i in items.size():
		if str(items[i]["kind"]) != "gate":
			continue
		for j in items.size():
			if j != i and str(items[j]["kind"]) == "gate" and absf(float(items[j]["d"]) - float(items[i]["d"])) < 0.01:
				items[i]["pair"] = j
	_build_tiles(tiles)
	_build_coins()


func _gate_text(it: Dictionary) -> String:
	match str(it["op"]):
		"+":
			return "+%d" % int(it["value"])
		"-":
			return "−%d" % int(it["value"])
		"x":
			return "×%d" % int(it["value"])
	return "?"


func _build_tiles(tiles: Array[Dictionary]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Mats.quad(Vector2(1.15, 1.15))
	mm.instance_count = tiles.size()
	for i in tiles.size():
		var it := tiles[i]
		it["idx"] = i
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(float(it["x"]), 0.025, -float(it["d"]))))
	_tiles = MultiMeshInstance3D.new()
	_tiles.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TILE_TEX
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.emission_enabled = true
	mat.emission_texture = TILE_TEX
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.6
	_tiles.material_override = mat
	_tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tiles)


func _build_coins() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Mats.cyl(0.24, 0.24, 0.06, 14)
	mm.instance_count = _coin_items.size()
	for i in _coin_items.size():
		_coin_items[i]["idx"] = i
	_coins = MultiMeshInstance3D.new()
	_coins.multimesh = mm
	_coins.material_override = Mats.glow(Color(1.0, 0.8, 0.25), 0.8)
	add_child(_coins)


# ------------------------------------------------------------------ input

## Picks a lane (0 = left, 1 = right).
func steer(to_lane: int) -> void:
	if state in [State.WON, State.LOST]:
		return
	start()
	lane = clampi(to_lane, 0, 1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
			return
		if pressed:
			_drag_from = pos
		elif _drag_from != Vector2.INF:
			var dx := pos.x - _drag_from.x
			if absf(dx) < 30.0:
				# A tap picks the lane on that side of the screen.
				steer(0 if pos.x < get_viewport().get_visible_rect().size.x * 0.5 else 1)
			_drag_from = Vector2.INF
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drag_from != Vector2.INF:
		var dx2: float = event.position.x - _drag_from.x
		if absf(dx2) > 45.0:
			steer(1 if dx2 > 0.0 else 0)
			_drag_from = Vector2.INF
	elif event.is_action_pressed("ui_left"):
		steer(0)
	elif event.is_action_pressed("ui_right"):
		steer(1)


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	_t += dt
	_fx_cd = maxf(_fx_cd - dt, 0.0)
	match state:
		State.RUNNING:
			_run(dt)
		State.CLASH:
			_clash(dt)
		State.BREACH:
			_breach(dt)
		State.FINALE:
			_finale(dt)
		State.WON, State.LOST:
			_end_t += dt
	if state in [State.RUNNING, State.CLASH, State.BREACH, State.FINALE]:
		_hero_attack(dt)
		if _ult_left > 0.0:
			_ult_step(dt)
	_sync_visuals(dt)


func _run(dt: float) -> void:
	leader_x = move_toward(leader_x, Balance.LANE_X[lane], Balance.LANE_SWITCH * dt)
	var nd := d + Balance.RUN_SPEED * dt
	var block := _blocker_within(nd + Balance.CONTACT)
	if not block.is_empty():
		nd = maxf(d, float(block["d"]) - Balance.CONTACT)
	_triggers(d, nd)
	d = nd
	if not block.is_empty():
		_engage(block)


## The first live blocker in the leader's lane whose front is at or before `reach`.
func _blocker_within(reach: float) -> Dictionary:
	for i in range(_next, items.size()):
		var it := items[i]
		if float(it["d"]) > reach:
			break
		if not it["alive"] or not str(it["kind"]) in ["squad", "barricade", "fortress"]:
			continue
		if _covers(it, leader_x):
			return it
	return {}


func _covers(it: Dictionary, x: float) -> bool:
	return int(it["lane"]) < 0 or absf(x - float(it["x"])) <= Balance.LANE_HALF


func _engage(it: Dictionary) -> void:
	_foe = it
	_tick = 0.0
	match str(it["kind"]):
		"squad":
			state = State.CLASH
			(it["crowd"] as Crowd).charge = 0.01
			Audio.play("cannon", -6.0, 0.2)
		"barricade":
			state = State.BREACH
		"fortress":
			state = State.FINALE
			_finale_left = FINALE_TIME
			Audio.play("boss", -4.0)


## Tiles, coins and gates crossed while moving from `a` to `b`.
func _triggers(a: float, b: float) -> void:
	while _next < items.size() and float(items[_next]["d"]) <= b:
		var it := items[_next]
		_next += 1
		if not it["alive"]:
			continue
		var kind := str(it["kind"])
		if kind in ["squad", "barricade", "fortress"]:
			continue   # blockers are handled by _blocker_within; passed ones were avoided
		if not _covers(it, leader_x):
			continue
		match kind:
			"tile":
				it["alive"] = false
				_tiles.multimesh.set_instance_transform(int(it["idx"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -10, 0)))
				_gain(1, Vector3(float(it["x"]), 0.2, -float(it["d"])))
				if _fx_cd <= 0.0:
					effects.burst(Vector3(float(it["x"]), 0.3, -float(it["d"])), Color(0.45, 0.75, 1.0), 6, 1.6, 0.07, 0.35, -2.0)
					_fx_cd = 0.05
				Audio.play("coin", -14.0, 0.25)
			"coin":
				it["alive"] = false
				coins += 1
				coins_changed.emit(coins)
				_coins.multimesh.set_instance_transform(int(it["idx"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -10, 0)))
				effects.coin_pop(Vector3(float(it["x"]), 0.4, -float(it["d"])))
				Audio.play("coin", -6.0, 0.2)
			"gate":
				_pass_gate(it)


func _pass_gate(it: Dictionary) -> void:
	it["alive"] = false
	if it.has("pair"):
		var other := items[int(it["pair"])]
		other["alive"] = false
		if other.has("node"):
			var on := other["node"] as Node3D
			var tw := on.create_tween()
			tw.tween_property(on, "scale", Vector3(1.0, 0.01, 1.0), 0.3)
	var before := army
	match str(it["op"]):
		"+":
			_set_army(army + int(it["value"]))
		"-":
			_set_army(army - int(it["value"]))
		"x":
			_set_army(army * int(it["value"]))
	var good := army >= before
	var at := Vector3(float(it["x"]), 1.0, -float(it["d"]))
	effects.flash(at, Color(0.45, 0.75, 1.0) if good else Color(1.0, 0.35, 0.3), 1.6, 0.3)
	effects.burst(at, Color(0.55, 0.85, 1.0) if good else Color(1.0, 0.4, 0.3), 24, 3.0, 0.1, 0.6, -3.0)
	Audio.play("upgrade" if good else "leak", -2.0)
	if army > before:
		_charge(minf(army - before, 15))
		# Newcomers pour out of the gate.
		crowd.set_count(army, false, Vector3(float(it["x"]), 0, -float(it["d"])))
	var node := it["node"] as Node3D
	var tw2 := node.create_tween()
	tw2.tween_property(node, "scale", Vector3(1.15, 1.15, 1.15), 0.08)
	tw2.tween_property(node, "scale", Vector3(1.0, 0.01, 1.0), 0.25)


func _gain(n: int, from: Vector3) -> void:
	army += n
	crowd.set_count(army, false, from)
	army_changed.emit(army)
	_charge(n)


func _set_army(n: int) -> void:
	army = maxi(0, n)
	crowd.set_count(army)
	army_changed.emit(army)


func _charge(points: float) -> void:
	if _ult_left > 0.0:
		return
	ult_points = minf(ult_points + points, float(ult["charge"]))
	ult_changed.emit(ult_points / float(ult["charge"]), ult_ready())


# ------------------------------------------------------------------ fights

## Clash with a squad: both sides fall one for one, faster in big fights.
func _clash(dt: float) -> void:
	if not _foe["alive"]:
		state = State.RUNNING   # the hero finished it off between ticks
		return
	var c := _foe["crowd"] as Crowd
	c.charge = minf(c.charge + dt * 4.0, 1.0)
	_tick -= dt
	while _tick <= 0.0 and state == State.CLASH:
		_tick += Balance.FIGHT_TICK
		var foes := int(_foe["hp"])
		if army > 0:
			var hit := mini(_burst(mini(army, foes)), mini(army, foes))
			_casualty_fx(hit)
			_set_army(army - hit)
			_hurt(_foe, hit)
		else:
			var hit2 := mini(_burst(mini(hero_hp, foes)), mini(hero_hp, foes))
			hero_hp -= hit2
			_hurt(_foe, hit2)
			effects.hit_spark(hero.muzzle(), Color(1.0, 0.4, 0.3))
			if hero_hp <= 0 and _foe["alive"]:
				_lose("ARMY_LOST")
				return
		if not _foe["alive"]:
			state = State.RUNNING


## Barricade: soldiers throw themselves on the spikes, one per point of strength. With no
## army left the hero has to hack through it alone.
func _breach(dt: float) -> void:
	_tick -= dt
	while _tick <= 0.0 and state == State.BREACH:
		_tick += Balance.FIGHT_TICK * 1.4
		if army > 0:
			var hit := mini(_burst(mini(army, int(_foe["hp"]))), mini(army, int(_foe["hp"])))
			_casualty_fx(hit)
			_set_army(army - hit)
			_hurt(_foe, hit)
		if not _foe["alive"]:
			state = State.RUNNING
		elif army <= 0:
			break


func _finale(dt: float) -> void:
	_tick -= dt
	while _tick <= 0.0 and state == State.FINALE:
		_tick += Balance.FIGHT_TICK
		if army > 0:
			var hit := mini(_burst(mini(army, int(_foe["hp"]))), mini(army, int(_foe["hp"])))
			_casualty_fx(hit)
			_set_army(army - hit)
			_hurt(_foe, hit)
		if not _foe["alive"]:
			_win()
			return
		if army <= 0:
			break
	if army <= 0 and state == State.FINALE:
		_finale_left -= dt
		if _finale_left <= 0.0:
			_lose("NOT_ENOUGH")


## How many fall per tick: 1 in small fights, more in big ones so they never drag.
func _burst(n: int) -> int:
	return maxi(1, ceili(n / 14.0))


func _casualty_fx(n: int) -> void:
	if _fx_cd > 0.0 or n <= 0:
		return
	_fx_cd = 0.06
	var p := crowd.front_point() + Vector3(0, 0.3, 0)
	effects.burst(p, Color(0.5, 0.7, 1.0), 5 + n, 2.0, 0.07, 0.35, -5.0)
	Audio.play("hit", -12.0, 0.3)


## Damages a blocker; returns the damage dealt.
func _hurt(it: Dictionary, n: int) -> int:
	if not it["alive"] or n <= 0:
		return 0
	var dealt := mini(n, int(it["hp"]))
	it["hp"] = int(it["hp"]) - dealt
	var kind := str(it["kind"])
	if kind == "squad":
		(it["crowd"] as Crowd).set_count(int(it["hp"]))
		_charge(dealt)
	if int(it["hp"]) <= 0:
		_destroy(it)
	elif it.has("node"):
		((it["node"] as Node3D).get_meta("label") as Label3D).text = str(it["hp"])
	return dealt


func _destroy(it: Dictionary) -> void:
	it["alive"] = false
	var kind := str(it["kind"])
	var at := Vector3(float(it["x"]), 0.6, -float(it["d"]))
	match kind:
		"squad":
			(it["crowd"] as Crowd).queue_free()
			(it["label"] as Label3D).queue_free()
			effects.burst(at, Color(1.0, 0.35, 0.3), 18, 2.6, 0.1, 0.5, -5.0, false)
		"barricade":
			effects.burst(at, Color(0.6, 0.4, 0.2), 30, 4.0, 0.14, 0.8, -9.0, false)
			effects.flash(at, Color(1.0, 0.85, 0.5), 1.5, 0.25)
			(it["node"] as Node3D).queue_free()
			Audio.play("explosion", -3.0)
		"fortress":
			pass   # _win plays the collapse


# ------------------------------------------------------------------ hero

func _hero_attack(dt: float) -> void:
	_attack_cd -= dt
	if _attack_cd > 0.0:
		return
	var target := _foe if state != State.RUNNING and not _foe.is_empty() and _foe["alive"] else _target_ahead()
	if target.is_empty():
		_attack_cd = 0.05
		return
	_attack_cd += 1.0 / (float(def["rate"]) * Balance.power_mult(int(Save.upgrades["power"])))
	_attack_cd = maxf(_attack_cd, 0.05)
	hero.strike()
	var at := _aim_point(target)
	var dmg := int(def["damage"])
	if str(target["kind"]) == "squad":
		dmg += int(def["splash"])
	if hero_type == "bolt":
		effects.lightning([hero.muzzle(), at], Color(0.5, 0.8, 1.0), 0.12, 0.04, false)
		effects.hit_spark(at, Color(0.6, 0.9, 1.0))
		Audio.play("tesla", -12.0, 0.25)
	else:
		effects.ring(Vector3(at.x, 0.05, at.z), Color(0.4, 1.0, 0.6), 1.2, 0.3)
		effects.burst(at, Color(0.55, 0.5, 0.42), 10, 2.2, 0.1, 0.45, -6.0, false)
		Audio.play("cannon", -9.0, 0.2)
	_hurt(target, dmg)


## The nearest live blocker in the hero's lane within striking range.
func _target_ahead() -> Dictionary:
	var reach := d + float(def["range"])
	for i in range(_next, items.size()):
		var it := items[i]
		if float(it["d"]) > reach:
			break
		if it["alive"] and str(it["kind"]) in ["squad", "barricade", "fortress"] and _covers(it, leader_x):
			return it
	return {}


func _aim_point(it: Dictionary) -> Vector3:
	match str(it["kind"]):
		"squad":
			return (it["crowd"] as Crowd).front_point() + Vector3(0, 0.35, 0)
		"barricade":
			return Vector3(float(it["x"]), 0.8, -float(it["d"]) + 0.15)
	return Vector3(leader_x * 0.3, 1.4, -float(it["d"]) + 0.2)


func ult_ready() -> bool:
	return ult_points >= float(ult["charge"]) and _ult_left <= 0.0


func use_ult() -> bool:
	if not ult_ready() or not state in [State.READY, State.RUNNING, State.CLASH, State.BREACH, State.FINALE]:
		return false
	start()
	ult_points = 0.0
	ult_changed.emit(0.0, false)
	_ult_tick = 0.0
	if hero_type == "bolt":
		_ult_left = float(ult["duration"])
		hero.cast_ult(_ult_left)
		effects.flash(hero.muzzle(), Color(0.6, 0.9, 1.0), 2.0, 0.35)
		Audio.play("tesla", 0.0)
	else:
		_quake_wave = 0
		_ult_left = 0.43 + float(ult["gap"]) * int(ult["waves"]) + 0.3
		_ult_tick = 0.43   # the leap before the first wave
		hero.cast_ult(1.6)
	Save.vibrate(30)
	return true


func _ult_step(dt: float) -> void:
	_ult_left -= dt
	_ult_tick -= dt
	if hero_type == "bolt":
		if _ult_tick > 0.0:
			return
		_ult_tick += float(ult["tick"])
		effects.ring(Vector3(leader_x, 0.05, -d), Color(0.45, 0.75, 1.0), 3.0, 0.3)
		var bolts := 5 if quality_high else 3
		for it in _blockers_in(d, d + float(ult["range"])):
			var at := _aim_point(it)
			var dmg := int(ult["kills"]) if str(it["kind"]) == "squad" else int(ult["breaks"])
			if bolts > 0:
				bolts -= 1
				effects.lightning([at + Vector3(randf_range(-0.6, 0.6), 7.0, 0), at + Vector3(0, 2.5, 0), at], Color(0.55, 0.85, 1.0), 0.2, 0.06, false)
				effects.hit_spark(at, Color(1.0, 0.9, 0.5))
			_hurt(it, dmg)
		Audio.play("tesla", -6.0, 0.2)
	else:
		while _ult_tick <= 0.0 and _quake_wave < int(ult["waves"]):
			_ult_tick += float(ult["gap"])
			var spacing := float(ult["spacing"])
			var near := d + 1.0 + spacing * _quake_wave
			var far := near + spacing
			var pts: Array[Vector3] = []
			for k in 9:
				pts.append(Vector3(-Balance.BRIDGE_HALF + 0.4 + k * (Balance.BRIDGE_HALF * 2.0 - 0.8) / 8.0, 0.0, -(near + spacing * 0.5) + randf_range(-0.6, 0.6)))
			effects.crystal_spikes(pts, Vector3(leader_x, 0, -d + 2.0), Color(0.12, 0.85, 0.4))
			for it in _blockers_in(near - 0.5, far):
				_hurt(it, int(ult["kills"]) if str(it["kind"]) == "squad" else int(ult["breaks"]))
			if _quake_wave == 0:
				effects.flash(Vector3(leader_x, 0.3, -d), Color(0.4, 1.0, 0.6), 2.0, 0.3)
				_shake(0.5)
				Audio.play("explosion", 0.0)
			else:
				Audio.play("cannon", -4.0, 0.2)
			_quake_wave += 1
	if _ult_left <= 0.0:
		_ult_left = 0.0
		ult_changed.emit(ult_points / float(ult["charge"]), ult_ready())


func _blockers_in(a: float, b: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(_next - 3, 0), items.size()):
		var it := items[i]
		var at := float(it["d"])
		if at > b:
			break
		if at >= a and it["alive"] and str(it["kind"]) in ["squad", "barricade", "fortress"]:
			out.append(it)
	return out


# ------------------------------------------------------------------ end

func _win() -> void:
	state = State.WON
	_end_t = 0.0
	var f := _foe["node"] as Node3D
	var at := f.global_position
	for i in 6:
		effects.burst(at + Vector3(randf_range(-3, 3), randf_range(0.5, 4.0), 0.5), Color(1.0, 0.6, 0.3), 26, 4.5, 0.16, 0.9, -8.0)
	effects.flash(at + Vector3(0, 2, 0.5), Color(1.0, 0.85, 0.5), 5.0, 0.5)
	for i in 4:
		effects.burst(at + Vector3(randf_range(-2.5, 2.5), 3.0, 1.0), [Color(0.4, 0.75, 1.0), Color(1.0, 0.85, 0.3), Color(0.5, 1.0, 0.6), Color(1.0, 0.5, 0.8)][i], 40, 6.0, 0.1, 1.4, -4.0)
	var tw := f.create_tween()
	tw.tween_property(f, "position:y", -6.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake(0.8)
	Audio.play("explosion", 2.0)
	Audio.play("victory", -2.0)
	Save.vibrate(60)
	var reward := Balance.victory_coins(level, army) + coins
	get_tree().create_timer(1.6).timeout.connect(func(): finished.emit(true, reward, "FORTRESS_FALLS"))


func _lose(reason: String) -> void:
	state = State.LOST
	_end_t = 0.0
	hero.running = false
	effects.death(hero.global_position, Color(0.4, 0.6, 1.0), 0.6)
	Audio.play("defeat", -2.0)
	get_tree().create_timer(1.3).timeout.connect(func(): finished.emit(false, coins, reason))


# ------------------------------------------------------------------ visuals

func _leader_pos() -> Vector3:
	return Vector3(leader_x, 0, -d)


func _sync_visuals(dt: float) -> void:
	var lp := _leader_pos()
	hero.position = lp
	hero.running = state == State.RUNNING
	hero.fighting = state in [State.CLASH, State.BREACH, State.FINALE]
	crowd.anchor = lp
	crowd.marching = state == State.RUNNING
	crowd.tick(dt, _t)
	for it in items:
		if it["alive"] and str(it["kind"]) == "squad":
			var c := it["crowd"] as Crowd
			c.tick(dt, _t)
			var l := it["label"] as Label3D
			l.text = str(it["hp"])
			l.position = c.anchor + Vector3(0, 1.4, -0.4)
	_army_label.text = str(army)
	_army_label.visible = army > 0
	_army_label.position = lp + Vector3(0, hero.top() + 0.75, 0)
	# Spin the coins.
	var spin := Basis(Vector3.UP, _t * 3.0) * Basis(Vector3.RIGHT, PI * 0.5)
	for it in _coin_items:
		if it["alive"]:
			_coins.multimesh.set_instance_transform(int(it["idx"]), Transform3D(spin, Vector3(float(it["x"]), 0.55 + sin(_t * 3.0 + float(it["d"])) * 0.08, -float(it["d"]))))
	_place_camera(minf(1.0, dt * 5.0))


## Keeps the bridge filling the width on any phone without a fisheye on tall screens.
func _fit_fov() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var vfov := rad_to_deg(2.0 * atan(tan(deg_to_rad(CAM_HFOV * 0.5)) / aspect))
	cam.fov = clampf(vfov, 50.0, 66.0)


func _cam_target() -> Vector3:
	return Vector3(leader_x * 0.3, CAM_HEIGHT, -d + CAM_BACK)


var _shake_amt := 0.0


func _shake(amount: float) -> void:
	_shake_amt = maxf(_shake_amt, amount)


func _place_camera(follow: float) -> void:
	_cam_pos = _cam_pos.lerp(_cam_target(), follow)
	# Forward motion is followed exactly so the hero never drifts on screen.
	_cam_pos.z = -d + CAM_BACK
	var shake := Vector3.ZERO
	if _shake_amt > 0.0:
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_amt * 0.25
		_shake_amt = maxf(_shake_amt - get_process_delta_time() * 2.0, 0.0)
	cam.position = _cam_pos + shake
	cam.look_at(Vector3(_cam_pos.x * 0.6, 0, -d - CAM_AHEAD) + shake)
