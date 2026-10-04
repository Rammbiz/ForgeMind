class_name Game
extends Node3D
## One playable level: owns map, enemies, towers, waves, economy and the HUD.

signal gold_changed(value: int)
signal lives_changed(value: int)
signal wave_changed(current: int, total: int)
signal finished(won: bool, stars: int)

enum State { PREP, PLAYING, WON, LOST }

const WAVE_COUNTDOWN := 18.0
const FIRST_WAVE_DELAY := -1.0

var level_index := 0
var level: Dictionary
var map: LevelMap
var cam: CameraRig
var hud: Hud
var effects: Effects
var enemies_root: Node3D
var towers_root: Node3D
var projectiles_root: Node3D
var enemies: Array[Enemy] = []
var heroes: Array[Hero] = []
var heroes_root: Node3D
var selected_hero: Hero
var towers := {}               # Vector2i -> Tower
var gold := 0
var lives := 0
var lives_max := 0
var wave := 0                  # waves started so far
var waves: Array = []
var state := State.PREP
var next_wave_timer := 0.0
var speed := 1
var stats := {"kills": 0, "gold_earned": 0, "leaked": 0}
var quality_high := true
var autoplay: Node = null
var _spawners: Array = []
var _spawn_alt := 0
var _dmg_accum := {}           # instance_id -> [Enemy, float]
var _dmg_flush := 0.0
var _seen_enemies := {}
var _cursor: MeshInstance3D
var _range_ring: MeshInstance3D
var _ghost: Node3D


func setup(index: int) -> void:
	level_index = index


func _ready() -> void:
	level = Arena.prepare_level(GameData.get_level(level_index))
	quality_high = Save.quality == "high"
	gold = int(level["start_gold"])
	lives = int(level["lives"])
	lives_max = lives
	waves = level["waves"]
	var theme: Dictionary = level["theme"]
	add_child(WorldEnv.make_environment(theme, quality_high))
	add_child(WorldEnv.make_sun(theme, quality_high))
	get_viewport().msaa_3d = Viewport.MSAA_2X if quality_high else Viewport.MSAA_DISABLED
	map = LevelMap.new()
	map.name = "Map"
	add_child(map)
	map.build(level, quality_high)
	for n in ["Towers", "Enemies", "Heroes", "Projectiles"]:
		var node := Node3D.new()
		node.name = n
		add_child(node)
	towers_root = $Towers
	enemies_root = $Enemies
	heroes_root = $Heroes
	projectiles_root = $Projectiles
	_spawn_heroes()
	effects = Effects.new()
	effects.name = "Effects"
	effects.quality_high = quality_high
	add_child(effects)
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	cam.setup(map.map_size())
	_make_selection_visuals()
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind(self)
	Audio.play_music(str(level["music"]))
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Audio.reset_laser()


## Gameplay time step for one frame. A long hitch (first-use shader compile, a GC
## pause) is capped so it slows the game for a moment instead of letting enemies
## jump through a tower's range at 2x/3x speed.
static func step(delta: float) -> float:
	return minf(delta, 0.1 * Engine.time_scale)


func is_running() -> bool:
	return state == State.PLAYING or state == State.PREP


# ------------------------------------------------------------------ waves

func can_call_wave() -> bool:
	return is_running() and wave < waves.size() and _spawners.is_empty()


func start_next_wave() -> void:
	if not can_call_wave():
		return
	if wave > 0:
		var bonus := GameData.wave_bonus(wave - 1)
		if next_wave_timer > 0.0:
			bonus += int(ceil(next_wave_timer))
		add_gold(bonus)
		hud.float_text_screen(hud.next_wave_center(), "+%d" % bonus, Color(1.0, 0.85, 0.3))
	var groups: Array = waves[wave]
	var hp_mult := GameData.wave_hp_mult(level_index, wave)
	var has_boss := false
	var new_types: Array[String] = []
	for g in groups:
		var type: String = g[0]
		if GameData.ENEMIES[type].get("boss", false):
			has_boss = true
		if not _seen_enemies.has(type):
			_seen_enemies[type] = true
			new_types.append(type)
		_spawners.append({
			"type": type, "left": int(g[1]), "gap": float(g[2]), "delay": float(g[3]),
			"spawn": int(g[4]), "timer": 0.0, "hp": hp_mult,
		})
	wave += 1
	state = State.PLAYING
	next_wave_timer = WAVE_COUNTDOWN
	wave_changed.emit(wave, waves.size())
	var sub := ""
	if wave == waves.size():
		sub = Loc.t("LAST_WAVE")
	elif has_boss:
		sub = Loc.t("BOSS_INCOMING")
	elif not new_types.is_empty() and wave > 1:
		sub = Loc.f("NEW_ENEMY", [Loc.t(GameData.ENEMIES[new_types[0]]["name"])])
	hud.show_banner(Loc.f("WAVE_BANNER", [wave]), sub)
	Audio.play("boss" if has_boss else "wave")


func _update_spawners(delta: float) -> void:
	for i in range(_spawners.size() - 1, -1, -1):
		var sp: Dictionary = _spawners[i]
		if sp["delay"] > 0.0:
			sp["delay"] -= delta
			continue
		sp["timer"] -= delta
		while sp["timer"] <= 0.0 and sp["left"] > 0:
			var path_idx: int = sp["spawn"]
			if path_idx < 0 or path_idx >= map.curves.size():
				path_idx = _spawn_alt % map.curves.size()
				_spawn_alt += 1
			spawn_enemy(sp["type"], path_idx, sp["hp"])
			sp["left"] -= 1
			sp["timer"] += sp["gap"]
		if sp["left"] <= 0:
			_spawners.remove_at(i)


func spawn_enemy(type: String, path_idx: int, hp_mult: float, start_dist := 0.0) -> Enemy:
	var e := Enemy.new()
	e.setup(self, type, path_idx, hp_mult)
	e.dist = start_dist
	enemies_root.add_child(e)
	enemies.append(e)
	return e


func _process(raw_delta: float) -> void:
	var delta := Game.step(raw_delta)
	if not is_running():
		return
	_update_spawners(delta)
	if wave > 0 and wave < waves.size() and _spawners.is_empty():
		next_wave_timer -= delta
		if next_wave_timer <= 0.0:
			next_wave_timer = 0.0
			start_next_wave()
	if wave >= waves.size() and _spawners.is_empty() and enemies.is_empty() and state == State.PLAYING:
		_finish(true)
	_dmg_flush -= delta
	if _dmg_flush <= 0.0:
		_dmg_flush = 0.4
		_flush_damage_numbers()


# ------------------------------------------------------------------ enemies

func on_enemy_damaged(e: Enemy, amount: float) -> void:
	if not Save.show_damage:
		return
	var id := e.get_instance_id()
	if _dmg_accum.has(id):
		_dmg_accum[id][1] += amount
	else:
		_dmg_accum[id] = [e, amount, e.aim_point()]


func _flush_damage_numbers() -> void:
	for id in _dmg_accum:
		var entry: Array = _dmg_accum[id]
		var pos: Vector3 = entry[2]
		if is_instance_valid(entry[0]):
			pos = (entry[0] as Enemy).aim_point()
		var amount: float = entry[1]
		if amount >= 1.0:
			hud.float_text(pos + Vector3(0, 0.35, 0), str(int(round(amount))), Color(1.0, 0.95, 0.85, 0.9), 0.7)
	_dmg_accum.clear()


func on_enemy_killed(e: Enemy) -> void:
	enemies.erase(e)
	stats["kills"] += 1
	add_gold(e.reward)
	var pos := e.global_position
	effects.death(pos, e.color, e.size)
	effects.coin_pop(pos)
	hud.float_text(pos + Vector3(0, 0.6, 0), "+%d" % e.reward, Color(1.0, 0.84, 0.3), 1.0, true)
	Audio.play("death", -4.0, 0.15)
	Audio.play("coin", -10.0, 0.1)
	if e.boss:
		camera_shake(0.25)
	var split_type := str(e.def.get("split", ""))
	if split_type != "":
		var count := int(e.def.get("split_count", 2))
		for i in count:
			# Children inherit the parent's wave strength, not whatever wave is current now.
			var child := spawn_enemy(split_type, e.path_index, e.hp_mult, maxf(e.dist - 0.15 * i, 0.0))
			child.spawn_in = 0.2


func on_enemy_leaked(e: Enemy) -> void:
	enemies.erase(e)
	if not is_running():
		return
	lives = maxi(lives - e.lives_cost, 0)
	stats["leaked"] += e.lives_cost
	lives_changed.emit(lives)
	Save.vibrate(60 if e.lives_cost > 1 else 35)
	map.crystal_hit()
	camera_shake(0.2)
	hud.damage_flash()
	Audio.play("leak", -2.0, 0.05)
	effects.burst(map.crystal_top(), Color(1.0, 0.3, 0.35), 16, 2.5, 0.1, 0.6, -3.0)
	if lives <= 0:
		_finish(false)


func _finish(won: bool) -> void:
	if not is_running():
		return
	state = State.WON if won else State.LOST
	var stars := GameData.stars_for(lives, lives_max) if won else 0
	if won:
		Save.record_result(level_index, stars)
	Audio.reset_laser()
	Audio.play("victory" if won else "defeat")
	set_speed(1)
	if won:
		_celebrate()
	else:
		_shatter_crystal()
	finished.emit(won, stars)
	hud.show_result(won, stars)


func _celebrate() -> void:
	var colors := [Color(1.0, 0.8, 0.3), Color(0.4, 0.9, 1.0), Color(1.0, 0.45, 0.7), Color(0.6, 1.0, 0.5), Color(0.85, 0.55, 1.0)]
	var center := map.crystal_top()
	for i in 9:
		var at := center + Vector3(randf_range(-2.5, 2.5), randf_range(1.2, 2.6), randf_range(-1.5, 1.5))
		var col: Color = colors[i % colors.size()]
		get_tree().create_timer(0.25 * i, false).timeout.connect(func():
			effects.burst(at, col, 28, 3.2, 0.1, 1.1, -2.5)
			effects.flash(at, col, 0.5, 0.2)
			Audio.play("coin", -8.0, 0.3))


func _shatter_crystal() -> void:
	if map.crystal_core == null:
		return
	var at := map.crystal_top()
	effects.flash(at, Color(0.5, 0.95, 1.0), 1.4, 0.35)
	effects.burst(at, Color(0.45, 0.9, 1.0), 40, 4.5, 0.14, 1.2, -6.0, false)
	effects.burst(at, Color(1, 1, 1), 18, 3.0, 0.08, 0.6, -2.0)
	map.crystal_core.visible = false
	camera_shake(0.45)


func find_target(pos: Vector3, radius: float, air: bool, ground: bool, mode: int) -> Enemy:
	var best: Enemy = null
	var best_score := INF
	var r2 := radius * radius
	for e in enemies:
		if not e.alive or e.spawn_in > 0.2:
			continue
		if (e.flying and not air) or (not e.flying and not ground):
			continue
		var dx := e.global_position.x - pos.x
		var dz := e.global_position.z - pos.z
		var d2 := dx * dx + dz * dz
		if d2 > r2:
			continue
		var score := 0.0
		match mode:
			Tower.Target.FIRST:
				score = e.remaining()
			Tower.Target.STRONG:
				score = -e.hp
			Tower.Target.CLOSE:
				score = d2
		if score < best_score:
			best_score = score
			best = e
	return best


func enemies_in_radius(pos: Vector3, radius: float, air: bool, ground: bool) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var r2 := radius * radius
	for e in enemies:
		if not e.alive:
			continue
		if (e.flying and not air) or (not e.flying and not ground):
			continue
		var dx := e.global_position.x - pos.x
		var dz := e.global_position.z - pos.z
		if dx * dx + dz * dz <= r2:
			out.append(e)
	return out


# ------------------------------------------------------------------ heroes

## Both heroes start on the main path just in front of the crystal.
func _spawn_heroes() -> void:
	if map.curves.is_empty():
		return
	var curve: Curve3D = map.curves[0]
	var length: float = map.path_lengths[0]
	for i in GameData.HERO_ORDER.size():
		var type: String = GameData.HERO_ORDER[i]
		var at := curve.sample_baked(maxf(length - 1.6 - 1.5 * i, 0.0))
		at.y = map.ground_y(at)
		var h := Hero.new()
		h.name = "Hero_" + type
		h.setup(self, type, at)
		heroes_root.add_child(h)
		heroes.append(h)


## The hero drawn under a screen point (generous radius for fingers), or null.
func hero_at_screen(screen_pos: Vector2) -> Hero:
	var best: Hero = null
	var best_d := 56.0
	for h in heroes:
		if not h.alive:
			continue
		var p := cam.world_to_screen(h.global_position + Vector3(0, 0.6, 0))
		var d := p.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = h
	return best


func select_hero(h: Hero) -> void:
	hud.close_menus()
	deselect_hero()
	if h == null or not h.alive:
		return
	selected_hero = h
	h.selected = true
	Audio.play("click", -6.0)
	hud.toast(Loc.f("HERO_PICK_SPOT", [Loc.t(h.def["name"])]), h.color.lightened(0.35), 2.5)


func deselect_hero() -> void:
	if selected_hero and is_instance_valid(selected_hero):
		selected_hero.selected = false
	selected_hero = null


## Sends the selected hero to a tapped ground point.
func _command_selected_hero(ground: Vector3) -> void:
	var h := selected_hero
	deselect_hero()
	if not map.cells.has(map.world_to_cell(ground)):
		hud.toast(Loc.t("HERO_CANT_GO"))
		Audio.play("error")
		return
	h.command_move(ground)
	effects.ring(Vector3(ground.x, map.ground_y(ground), ground.z), h.color, 0.45, 0.4)
	Audio.play("click", -4.0)


func use_hero_ability(h: Hero) -> void:
	if h == null or not h.use_ability():
		Audio.play("error")


# ------------------------------------------------------------------ economy & towers

func add_gold(amount: int, earned := true) -> void:
	gold += amount
	if amount > 0 and earned:
		stats["gold_earned"] += amount
	gold_changed.emit(gold)


func tower_cost(type: String) -> int:
	return int(GameData.tower_stats(type, 0)["cost"])


func can_build(c: Vector2i) -> bool:
	return is_running() and map.is_buildable(c) and not towers.has(c)


func build_tower(c: Vector2i, type: String) -> Tower:
	if not can_build(c) or not type in level["towers"]:
		return null
	var cost := tower_cost(type)
	if gold < cost:
		Audio.play("error")
		return null
	add_gold(-cost)
	var t := Tower.new()
	t.setup(self, type, c)
	t.position = map.cell_to_world(c)
	towers_root.add_child(t)
	towers[c] = t
	map.hide_deco(c)
	effects.build_puff(t.position)
	Audio.play("build")
	Save.vibrate(15)
	return t


func upgrade_tower(t: Tower) -> bool:
	if not is_instance_valid(t) or not t.can_upgrade():
		return false
	var cost := t.upgrade_cost()
	if gold < cost:
		Audio.play("error")
		return false
	add_gold(-cost)
	t.upgrade()
	effects.upgrade_fx(t.position, t.def["color"])
	Audio.play("upgrade")
	return true


func sell_tower(t: Tower) -> void:
	if not is_instance_valid(t):
		return
	var value := t.sell_value()
	add_gold(value, false)
	towers.erase(t.cell)
	map.show_deco(t.cell)
	effects.build_puff(t.position)
	effects.coin_pop(t.position)
	hud.float_text(t.position + Vector3(0, 0.8, 0), "+%d" % value, Color(1.0, 0.84, 0.3), 1.0, true)
	Audio.play("sell")
	t.queue_free()


func set_speed(s: int) -> void:
	speed = s
	Engine.time_scale = float(s)


func camera_shake(amount: float) -> void:
	if cam:
		cam.shake(amount)


func restart() -> void:
	get_tree().paused = false
	get_parent().call("start_level", level_index)


func quit_to_menu() -> void:
	get_tree().paused = false
	get_parent().call("show_menu")


# ------------------------------------------------------------------ selection visuals

func _make_selection_visuals() -> void:
	_cursor = MeshInstance3D.new()
	_cursor.mesh = Mats.quad(Vector2(1.0, 1.0))
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.5, 1.0);
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = max(d.x, d.y);
	float border = smoothstep(0.78, 0.92, edge) * (1.0 - smoothstep(0.96, 1.0, edge));
	float fill = 0.12 + 0.06 * sin(TIME * 5.0);
	ALBEDO = tint.rgb;
	ALPHA = border * (0.75 + 0.25 * sin(TIME * 5.0)) + fill * (1.0 - border);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_cursor.material_override = m
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false
	add_child(_cursor)
	_range_ring = MeshInstance3D.new()
	_range_ring.mesh = Mats.quad(Vector2(2.0, 2.0))
	var sh2 := Shader.new()
	sh2.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.6, 0.9, 1.0, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ring = smoothstep(0.93, 0.975, r) * (1.0 - smoothstep(0.985, 1.0, r));
	float dash = step(0.0, sin(a * 28.0 + TIME * 2.0));
	float fill = (1.0 - smoothstep(0.96, 0.99, r)) * 0.13 * (0.6 + 0.4 * r);
	ALBEDO = tint.rgb;
	ALPHA = ring * (0.55 + 0.45 * dash) + fill;
}
"""
	var m2 := ShaderMaterial.new()
	m2.shader = sh2
	_range_ring.material_override = m2
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_ring.visible = false
	add_child(_range_ring)


func show_cursor(c: Vector2i, valid := true) -> void:
	_cursor.visible = true
	_cursor.position = map.cell_to_world(c) + Vector3(0, 0.02, 0)
	(_cursor.material_override as ShaderMaterial).set_shader_parameter("tint", Color(1.0, 0.9, 0.5) if valid else Color(1.0, 0.35, 0.3))


func hide_cursor() -> void:
	_cursor.visible = false


func show_range(pos: Vector3, radius: float, color := Color(0.6, 0.9, 1.0)) -> void:
	_range_ring.visible = true
	_range_ring.position = Vector3(pos.x, pos.y + 0.05, pos.z)
	_range_ring.scale = Vector3(radius, 1.0, radius)
	(_range_ring.material_override as ShaderMaterial).set_shader_parameter("tint", color)


func hide_range() -> void:
	_range_ring.visible = false


func show_ghost(c: Vector2i, type: String, lvl := 0) -> void:
	hide_ghost()
	_ghost = Models.tower(type, lvl)
	_ghost.position = map.cell_to_world(c)
	add_child(_ghost)
	_set_ghost_material(_ghost)


static var _ghost_mat: StandardMaterial3D


func _set_ghost_material(n: Node) -> void:
	if _ghost_mat == null:
		_ghost_mat = StandardMaterial3D.new()
		_ghost_mat.vertex_color_use_as_albedo = true
		_ghost_mat.vertex_color_is_srgb = true
		_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat.albedo_color = Color(0.75, 1.0, 0.85, 0.5)
		_ghost_mat.emission_enabled = true
		_ghost_mat.emission = Color(0.2, 0.45, 0.3)
	for ch in n.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = _ghost_mat
			(ch as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_set_ghost_material(ch)


func hide_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null


func clear_selection() -> void:
	hide_cursor()
	hide_range()
	hide_ghost()


## Called by the HUD when the player taps the 3D world.
func world_tap(screen_pos: Vector2) -> void:
	if not is_running():
		return
	var ground := cam.screen_to_ground(screen_pos)
	var tapped_hero := hero_at_screen(screen_pos)
	if selected_hero:
		if tapped_hero == selected_hero:
			deselect_hero()
		elif tapped_hero:
			select_hero(tapped_hero)
		else:
			_command_selected_hero(ground)
		return
	if tapped_hero:
		select_hero(tapped_hero)
		return
	var c := map.world_to_cell(ground)
	if towers.has(c):
		Audio.play("click", -6.0)
		hud.open_tower_panel(towers[c])
	elif can_build(c):
		Audio.play("click", -6.0)
		hud.open_build_menu(c)
	else:
		hud.close_menus()
