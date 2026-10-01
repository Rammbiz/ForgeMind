extends Node
## Scene router: menu <-> game, with fade transitions.
## Dev flags (after `--`): --autotest[=level], --shot=path.png, --screen=menu|levels|game, --level=N, --wave=N

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
	_fade.color = Color(0.03, 0.04, 0.08, 1.0)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and current is Menu:
		(current as Menu).handle_back()
	elif what == NOTIFICATION_PREDELETE:
		Models.clear_templates()


func show_menu() -> void:
	var m := Menu.new()
	_switch(m)


func show_levels() -> void:
	var m := Menu.new()
	m.start_page = "levels"
	_switch(m)


func start_level(index: int) -> void:
	var g := Game.new()
	g.setup(index)
	_switch(g)


func _switch(next: Node, instant := false) -> void:
	if _busy:
		next.queue_free()
		return
	_busy = true
	get_tree().paused = false
	if current and not instant:
		_fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.25)
		await tw.finished
	if current:
		current.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	current = next
	add_child(next)
	move_child(next, 0)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Used by dev tools: switch immediately without fades.
func set_scene_now(next: Node) -> void:
	if current:
		current.queue_free()
	current = next
	add_child(next)
	move_child(next, 0)
	_fade.color.a = 0.0
