extends Node
## Scene router: menu <-> run, with fade transitions.
## Dev flags (after `--`): --autotest, --shot=path.png, --screen=menu|run, --level=N, --hero=bolt|titan

var current: Node
var _fade: ColorRect
var _busy := false
var _args := {}


func _ready() -> void:
	Save.apply_performance()
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.1, 0.2, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _args.has("autotest"):
		var dev: Node = load("res://scripts/dev/autoplay.gd").new()
		dev.set("args", _args)
		add_child(dev)
		return
	if _args.has("shot"):
		var shot: Node = load("res://scripts/dev/screenshot.gd").new()
		shot.set("args", _args)
		add_child(shot)
		return
	show_menu()


func show_menu() -> void:
	var m := Menu.new()
	m.play.connect(start_run)
	_switch(m)


func start_run() -> void:
	_switch(make_play(Save.level, Save.hero))


## A run with its HUD, wired to the router. Dev tools use it too.
func make_play(level: int, hero: String) -> Node:
	var holder := Node.new()
	holder.name = "Play"
	var run := Run.new()
	run.setup(level, hero)
	holder.add_child(run)
	var hud := RunHud.new()
	hud.setup(run)
	holder.add_child(hud)
	run.finished.connect(func(won: bool, coins: int, _reason: String):
		Save.add_coins(coins)
		if won:
			Save.level_won())
	hud.retry.connect(start_run)
	hud.next.connect(start_run)
	hud.menu.connect(show_menu)
	holder.set_meta("run", run)
	holder.set_meta("hud", hud)
	Audio.play_music("meadow" if level % 2 == 1 else "canyon")
	return holder


func _switch(next: Node, instant := false) -> void:
	if _busy:
		next.queue_free()
		return
	_busy = true
	get_tree().paused = false
	if current:
		current.process_mode = Node.PROCESS_MODE_DISABLED
	if current and not instant:
		_fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := _fade_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.25)
		await tw.finished
	if current:
		current.queue_free()
		await get_tree().process_frame
	current = next
	add_child(next)
	move_child(next, 0)
	await get_tree().process_frame
	var tw2 := _fade_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_tween() -> Tween:
	return _fade.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)


## Used by dev tools: switch immediately without fades.
func set_scene_now(next: Node) -> void:
	if current:
		current.queue_free()
	current = next
	add_child(next)
	move_child(next, 0)
	_fade.color.a = 0.0
