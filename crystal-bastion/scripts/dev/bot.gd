class_name Bot
extends RefCounted
## Simple scripted player used for automated balance tests and screenshots.

var skill := 1.0             # 0..1: lower = builds fewer towers / upgrades less
var call_early := false
var _coverage := {}          # "type|cell" -> float
var _plan_index := 0
var _samples: Array[Vector3] = []


func _ensure_samples(game: Game) -> void:
	if not _samples.is_empty():
		return
	for ci in game.map.curves.size():
		var curve: Curve3D = game.map.curves[ci]
		var length: float = game.map.path_lengths[ci]
		var d := 0.0
		while d < length:
			var p := curve.sample_baked(d)
			# Weight earlier path a bit more: towers near spawn get more time on target.
			_samples.append(p)
			d += 0.25


func coverage(game: Game, type: String, c: Vector2i, lvl := 0) -> float:
	var key := "%s|%s|%d" % [type, c, lvl]
	if _coverage.has(key):
		return _coverage[key]
	_ensure_samples(game)
	var r := float(GameData.tower_stats(type, lvl)["range"])
	var center := game.map.cell_to_world(c)
	var n := 0.0
	for p in _samples:
		var dx := p.x - center.x
		var dz := p.z - center.z
		if dx * dx + dz * dz <= r * r:
			n += 1.0
	_coverage[key] = n
	return n


func best_cell(game: Game, type: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -1.0
	for c: Vector2i in game.map.cells:
		if not game.can_build(c):
			continue
		var s := coverage(game, type, c)
		# Splash / slow towers like long straight stretches near the start.
		if s > best_score:
			best_score = s
			best = c
	return best


func _plan(game: Game) -> Array:
	var avail: Array = game.level["towers"]
	var order := ["arrow", "arrow", "cannon", "frost", "arrow", "tesla", "cannon", "laser", "frost", "tesla", "laser", "arrow", "cannon"]
	var out := []
	for t in order:
		if t in avail:
			out.append(t)
	return out


func think(game: Game) -> void:
	if not game.is_running():
		return
	var plan := _plan(game)
	var tower_count := game.towers.size()
	var max_towers := int(lerpf(4.0, 14.0, skill))
	var want_upgrade := tower_count >= 4 and skill > 0.3
	# Upgrades first once we have a base defense.
	if want_upgrade:
		var best_t: Tower = null
		var best_v := -1.0
		for t: Tower in game.towers.values():
			if not t.can_upgrade():
				continue
			if t.level >= int(skill * 2.0 + 0.01):
				continue
			var v := coverage(game, t.type, t.cell) / float(t.upgrade_cost())
			if v > best_v:
				best_v = v
				best_t = t
		if best_t and game.gold >= best_t.upgrade_cost() and (tower_count >= max_towers or randf() < 0.5):
			game.upgrade_tower(best_t)
			return
	if tower_count < max_towers:
		var type: String = plan[_plan_index % plan.size()]
		if game.gold >= game.tower_cost(type):
			var c := best_cell(game, type)
			if c.x >= 0 and game.build_tower(c, type):
				_plan_index += 1
				return
	if game.wave == 0 and tower_count >= 2:
		game.start_next_wave()
	elif call_early and game.can_call_wave() and game.enemies.is_empty():
		game.start_next_wave()
