extends SceneTree
## Dev check for the LEVELS role: drives the Bot against a mock Run (spec section 2 fields)
## whose world is LevelSim itself, and compares with LevelSim.best_path. Validates the bot's
## snapshot / steering code while the real Run is being rewritten.
##   godot --headless --path . --script res://scripts/dev/levels_mockrun.gd -- --from=1 --to=6
##        [--hero=bolt] [--bot=best|lazy|random] [--skill=1.0]


## Minimal stand-in for Run: same public fields, state indices as Run.State in the spec.
class MockRun extends RefCounted:
	var state := 0
	var d := 0.0
	var hx := 0.0
	var t := 0.0
	var army := 0
	var coins := 0
	var hero_hp := 0
	var items: Array[Dictionary] = []
	var weapons: Array[Dictionary] = []
	var arm_tier := 0
	var power := {"rate": 0.0, "dmg": 0, "multi": 0}
	var level := 1
	var hero_type := "bolt"
	var length := 0.0
	var ult_points := 0.0
	var lv: LevelSim.Level
	var s: LevelSim.State
	var target := 0.0

	func setup(p_level: int, hero: String) -> void:
		level = p_level
		hero_type = hero
		var def := LevelGen.build(level, Balance.START_ARMY)
		length = float(def["length"])
		for it: Dictionary in def["items"]:
			var c := it.duplicate(true)
			c["alive"] = true
			if c.has("value"):
				c["hp"] = int(c["value"])
			c["revealed"] = not bool(c.get("hidden", false))
			items.append(c)
		lv = LevelSim.make_level(def, level)
		s = LevelSim.start_state(lv, hero, Balance.START_ARMY, {"ult": false, "trace": OS.get_cmdline_user_args().has("--trace")})
		_sync()

	func start() -> void:
		if state == 0:
			state = 1

	func steer_to(x: float) -> void:
		target = clampf(x, -Balance.X_LIMIT, Balance.X_LIMIT)

	func ult_ready() -> bool:
		return LevelSim.ult_ready(s)

	func use_ult() -> bool:
		return LevelSim.use_ult(lv, s)

	func tick(dt: float) -> void:
		if state == 0 or state >= 5:
			return
		# The hero spring: halve the distance every STEER_HALFLIFE.
		var k := 1.0 - pow(0.5, dt / Balance.STEER_HALFLIFE)
		var nx := lerpf(s.hx, target, k)
		LevelSim.step(lv, s, PackedFloat32Array([s.d, nx]), dt)
		_sync()

	func _sync() -> void:
		d = s.d
		hx = s.hx
		t = s.t
		army = int(round(s.army))
		coins = s.coins
		hero_hp = int(s.hero_hp)
		arm_tier = s.arm
		power = {"rate": s.p_rate, "dmg": s.p_dmg, "multi": s.p_multi}
		ult_points = s.ult
		weapons.clear()
		for w: Array in s.weapons:
			weapons.append({"kind": w[0], "level": w[1]})
		state = [1, 2, 3, 5, 6][s.mode] if state != 0 else 0
		for i in items.size():
			var it := items[i]
			it["alive"] = s.alive[i] == 1
			it["hp"] = int(ceil(s.hp[i]))
			if str(it["kind"]) == "gate":
				var v := LevelSim.gate_view(lv, s, i)
				it["op"] = v[0]
				it["value"] = int(v[1])
				it["revealed"] = s.rev[i] == 1 or float(it["d"]) - d < Balance.REVEAL_DIST
				if it.has("move"):
					it["x"] = LevelSim.gate_x(lv, i, t)


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var hero := str(args.get("hero", "bolt"))
	var bot := Bot.new()
	bot.mode = str(args.get("bot", "best"))
	bot.skill = float(args.get("skill", "1.0"))
	bot.rng.seed = 1
	for level in range(int(args.get("from", "1")), int(args.get("to", "6")) + 1):
		var t0 := Time.get_ticks_msec()
		bot.reset()
		var run := MockRun.new()
		run.setup(level, hero)
		var guard := 0
		while run.state < 5 and guard < 20000:
			bot.think(run)
			run.tick(0.05)
			guard += 1
		var r := LevelSim.result(run.lv, run.s)
		var ms := Time.get_ticks_msec() - t0
		var bp: Dictionary = LevelSim.best_path(run.lv, hero, Balance.START_ARMY, {"trace": args.has("trace")})
		var ref: Dictionary = bp["result"]
		if args.has("trace"):
			print("--- bot")
			for l in run.s.trace:
				print("  ", l)
			print("--- planner")
			for l in bp["trace"]:
				print("  ", l)
		print("MOCK L%d %s bot=%s skill=%.2f: %s army@fort %d surv %d x%s haz %d | planner: %s %d surv %d | %d ms (%.1f ms/think)" % [
			level, hero, bot.mode, bot.skill, "WON " if r["won"] else "LOST", r["army_at_fortress"], r["survivors"], str(r["stairs_mult"]),
			r["hazard_deaths"], "WON" if ref["won"] else "LOST", ref["army_at_fortress"], ref["survivors"], ms, ms / maxf(r["time"] / Bot.THINK, 1.0)])
	quit(0)
