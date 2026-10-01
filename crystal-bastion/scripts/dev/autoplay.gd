extends Node
## Headless balance test: a bot plays levels at high speed and prints results.
## Usage: godot --headless --fixed-fps 60 -- --autotest=all [--level=N] [--skill=1.0] [--speed=3]
##        [--seed=N] [--early] [--botlog] [--botdebug] [--hpx=K]
## --skill: 1.0 ~ good player, 0.6 ~ casual. --seed (default 1) makes a run reproducible.
## --botlog prints every build / upgrade, --botdebug also the bot's per-stream reasoning.
## --hpx=1.2 scales every enemy's health (to measure how much margin a skill level has).

var args := {}
var _levels: Array[int] = []
var _cur := -1
var _game: Game
var _bot: Bot
var _think := 0.0
var _elapsed := 0.0
var _results := []
var _last_wave := -1


func _ready() -> void:
	var spec := str(args.get("autotest", "all"))
	if spec == "all" or spec == "1" and not args.has("level"):
		for i in GameData.level_count():
			_levels.append(i)
	else:
		_levels.append(clampi(int(spec) - 1, 0, GameData.level_count() - 1))
	if args.has("level"):
		_levels = [clampi(int(args["level"]) - 1, 0, GameData.level_count() - 1)]
	_next_level()


func _next_level() -> void:
	_cur += 1
	if _cur >= _levels.size():
		print("AUTOTEST_SUMMARY ", JSON.stringify(_results))
		get_tree().quit(0)
		return
	_bot = Bot.new()
	_bot.skill = float(args.get("skill", "1.0"))
	_bot.call_early = args.has("early")
	_bot.verbose = args.has("botlog") or args.has("botdebug")
	_bot.debug = args.has("botdebug")
	_bot.set_seed(int(args.get("seed", "1")) * 7919 + _levels[_cur])
	# The game itself draws from the global RNG (enemy animation phase, which
	# bobs flyers and so shifts aim points; effects): seed it too so a run is
	# reproducible.
	seed(int(args.get("seed", "1")) * 104729 + _levels[_cur])
	_game = Game.new()
	_game.setup(_levels[_cur])
	get_parent().call("set_scene_now", _game)
	_game.finished.connect(_on_finished)
	if args.has("hpx"):
		_game.enemies_root.child_entered_tree.connect(_on_enemy_spawned)
	_elapsed = 0.0
	_last_wave = -1
	await get_tree().process_frame
	Engine.time_scale = float(args.get("speed", "3"))


func _process(delta: float) -> void:
	if _game == null or not is_instance_valid(_game) or not _game.is_running():
		return
	Engine.time_scale = float(args.get("speed", "3"))
	_elapsed += delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.5
		_bot.think(_game)
	if _game.wave != _last_wave:
		_last_wave = _game.wave
		print("  L%d wave %d/%d  lives=%d gold=%d towers=%d enemies=%d t=%.0fs" % [_game.level_index + 1, _game.wave, _game.waves.size(), _game.lives, _game.gold, _game.towers.size(), _game.enemies.size(), _elapsed])
	if _elapsed > 3600.0:
		print("AUTOTEST timeout")
		_on_finished(false, 0)


func _on_enemy_spawned(node: Node) -> void:
	var e := node as Enemy
	if e:
		e.max_hp *= float(args["hpx"])
		e.hp = e.max_hp


func _on_finished(won: bool, stars: int) -> void:
	var levels_lvls := {}
	for t: Tower in _game.towers.values():
		levels_lvls[t.type] = str(levels_lvls.get(t.type, "")) + str(t.level + 1)
	var r := {
		"level": _game.level_index + 1, "skill": _bot.skill, "seed": int(args.get("seed", "1")),
		"hpx": float(args.get("hpx", "1")),
		"won": won, "stars": stars, "lives": _game.lives,
		"wave": _game.wave, "kills": _game.stats["kills"], "gold_earned": _game.stats["gold_earned"],
		"gold_left": _game.gold, "towers": levels_lvls, "time": int(_elapsed),
	}
	_results.append(r)
	print("AUTOTEST ", JSON.stringify(r))
	Engine.time_scale = 1.0
	_game = null
	await get_tree().create_timer(0.1, true, false, true).timeout
	_next_level()
