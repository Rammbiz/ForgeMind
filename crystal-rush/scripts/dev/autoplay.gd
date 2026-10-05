extends Node
## Plays levels with the test bot at high speed and prints one JSON line per level.
##   godot --headless --path crystal-rush -- --autotest --level=3 [--levels=5] [--hero=titan]
##        [--skill=0.8] [--army=0] [--power=0] [--speed=4]

var args := {}
var _bot := Bot.new()
var _run: Run
var _level := 1
var _last := 1
var _results: Array = []
var _elapsed := 0.0


func _ready() -> void:
	_level = int(args.get("level", "1"))
	_last = _level + int(args.get("levels", "1")) - 1
	_bot.skill = float(args.get("skill", "1.0"))
	_bot.rng.seed = int(args.get("seed", "1"))
	Engine.time_scale = float(args.get("speed", "4"))
	_start()


func _start() -> void:
	var main := get_parent()
	var holder: Node = main.call("make_play", _level, str(args.get("hero", "bolt")))
	main.call("set_scene_now", holder)
	_run = holder.get_meta("run")
	_run.finished.connect(_on_finished)
	_elapsed = 0.0


func _process(delta: float) -> void:
	if _run == null or not is_instance_valid(_run):
		return
	_elapsed += delta
	if _run.state not in [Run.State.WON, Run.State.LOST]:
		_bot.think(_run)
	if _elapsed > 600.0:
		_on_finished(false, 0, "TIMEOUT")


func _on_finished(won: bool, coins: int, reason: String) -> void:
	var fortress := 0
	for it in _run.items:
		if str(it["kind"]) == "fortress":
			fortress = int(it["value"])
	var r := {"level": _level, "hero": _run.hero_type, "won": won, "reason": reason, "coins": coins,
		"army_left": _run.army, "fortress": fortress, "expected": int(_run.expected), "d": int(_run.d), "len": int(_run.length),
		"time": snappedf(_elapsed, 0.1)}
	print("AUTOTEST ", JSON.stringify(r))
	_run = null
	if _level < _last:
		_level += 1
		_start.call_deferred()
	else:
		get_tree().quit(0)
