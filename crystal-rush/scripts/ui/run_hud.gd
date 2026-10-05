class_name RunHud
extends CanvasLayer
## In-run overlay wired to Run (spec §2). The visuals live in HudView (Run-independent, so dev
## previews can drive them with mock data); this node connects Run's signals, owns pausing
## (pause button, app focus loss, Android back) and the drag-hint lifetime.

signal retry
signal next
signal menu

## The drag hint hides once the player has dragged this far (px) or the run is past this d.
const DRAG_HIDE_PX := 24.0
const DRAG_HIDE_D := 6.0

var run: Run
var view: HudView
var _dragged := false
var _drag_px := 0.0
var _finished := false


func setup(p_run: Run) -> void:
	run = p_run


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = HudView.new()
	var col: Color = run.def.get("color", Color(0.45, 0.75, 1.0))
	view.setup(run.level, str(run.ult.get("icon", "storm")), col)
	add_child(view)
	view.pause_pressed.connect(pause)
	view.resume_pressed.connect(resume)
	view.ult_pressed.connect(_on_ult)
	view.retry.connect(func(): _leave(); retry.emit())
	view.next.connect(func(): _leave(); next.emit())
	view.menu.connect(func(): _leave(); menu.emit())
	view.set_coins(run.coins, false)
	view.set_weapons(run.weapons)
	view.set_arm(run.arm_tier)
	view.set_ult(0.0, run.ult_ready())
	view.show_drag_hint(run.state == Run.State.READY)
	run.coins_changed.connect(func(n: int): view.set_coins(n))
	run.ult_changed.connect(_on_ult_changed)
	run.hint.connect(_on_hint)
	run.weapon_added.connect(func(kind: String, level: int): view.weapon_added(kind, level, run.weapons))
	run.power_changed.connect(view.power_toast)
	run.stairs_done.connect(_on_stairs_done)
	run.finished.connect(_on_finished)
	_load_portrait()


func _load_portrait() -> void:
	var tex := await UIKit.render_portrait(self, run.hero_type, 200)
	if tex and is_instance_valid(view):
		view.set_portrait(tex)


## Tutorial banner; the drag hint already says "drag" while it is up, so that banner is skipped.
func _on_hint(key: String) -> void:
	if (key == "HINT_DRAG" or key == "DRAG_HINT") and view.drag_hint_shown():
		return
	view.show_hint(key)


func _process(_delta: float) -> void:
	# The ult button has nothing to do once the fortress fell (stairs, victory).
	var ult_on := run.state != Run.State.STAIRS and run.state != Run.State.WON
	if view.ult_btn.visible != ult_on:
		view.set_ult_visible(ult_on)
	if view.drag_hint_shown():
		if _dragged or (run.state != Run.State.READY and run.d > DRAG_HIDE_D):
			view.show_drag_hint(false)


func _input(event: InputEvent) -> void:
	if _dragged:
		return
	if event is InputEventScreenDrag:
		_drag_px += absf((event as InputEventScreenDrag).relative.x)
		if _drag_px > DRAG_HIDE_PX:
			_dragged = true


func _on_ult_changed(ratio: float, ready: bool) -> void:
	# HudView toasts only on the not-ready → ready edge (Run may re-emit while full).
	view.set_ult(ratio, ready)


func _on_ult() -> void:
	if get_tree().paused:
		return
	if run.use_ult():
		view.toast(Loc.t(run.ult["name"]), Color(0.6, 0.85, 1.0) if run.hero_type == "bolt" else Color(0.5, 1.0, 0.65))
	else:
		Audio.play("error", -6.0)


func _on_stairs_done(mult: float) -> void:
	if mult > 1.0:
		view.toast(Loc.t("STAIRS_MULT") % HudView._fmt_mult(mult), Color(1.0, 0.8, 0.3), 96)


func _on_finished(won: bool, earned: int, reason: String) -> void:
	_finished = true
	get_tree().paused = false
	view.show_result(won, reason, run.result, earned)


# ------------------------------------------------------------------ pause

func _in_play() -> bool:
	return not _finished and run.state != Run.State.WON and run.state != Run.State.LOST


func pause() -> void:
	if view.has_modal() or not _in_play():
		return
	get_tree().paused = true
	view.show_pause()


func resume() -> void:
	if view.modal_kind() == "pause":
		view.close_modal()
	get_tree().paused = false


func _leave() -> void:
	view.close_modal()
	get_tree().paused = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Auto-pause when the phone locks or another app comes up (not before the start).
			if is_node_ready() and run and run.state != Run.State.READY:
				pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if not is_node_ready():
				return
			match view.modal_kind():
				"pause":
					resume()
				"result":
					_leave()
					menu.emit()
				_:
					pause()
