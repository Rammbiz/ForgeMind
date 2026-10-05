class_name RunHud
extends CanvasLayer
## In-run overlay: level, coins, pause, the ultimate button with the hero's portrait, the
## lane hint, toasts, and the pause and result panels.

signal retry
signal next
signal menu

var run: Run
var root: Control
var _level_lbl: Label
var _coins_lbl: Label
var _ult_btn: RoundButton
var _hint: PanelContainer
var _toast: Label
var _toast_tw: Tween
var _modal: Control
var _portrait: Texture2D


func setup(p_run: Run) -> void:
	run = p_run


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 18 + _safe_top()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_level_lbl = _pill(top, "", UIKit.TEXT)
	_level_lbl.text = Loc.f("LEVEL", [run.level])
	_coins_lbl = _pill(top, "0", UIKit.GOLD, "coin")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var pause := RoundButton.new(32.0)
	pause.icon_kind = "pause"
	pause.pressed.connect(_on_pause)
	top.add_child(pause)
	_ult_btn = RoundButton.new(56.0)
	_ult_btn.base_color = Color(0.1, 0.12, 0.22, 0.95)
	_ult_btn.ring_color = Color(1.0, 0.55, 0.95)
	_ult_btn.progress_color = Color(1.0, 0.6, 0.95)
	_ult_btn.icon_kind = str(run.ult["icon"])
	_ult_btn.icon_tint = Color(1.0, 0.9, 0.55)
	_ult_btn.progress = 0.0
	_ult_btn.disabled = true
	_ult_btn.pressed.connect(_on_ult)
	root.add_child(_ult_btn)
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.08, 0.18, 0.78), Color(0, 0, 0, 0), 22, 0, 0, Vector2(22, 14)))
	var hl := UIKit.label(Loc.t("SWIPE_HINT"), 28, UIKit.TEXT, true)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.custom_minimum_size = Vector2(520, 0)
	_hint.add_child(hl)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	_toast = UIKit.label("", 46, Color(1.0, 0.9, 0.5), true, 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)
	run.coins_changed.connect(func(n: int): _coins_lbl.text = str(n))
	run.ult_changed.connect(_on_ult_changed)
	run.finished.connect(_on_finished)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_render_portrait()


func _safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return float(safe.position.y) * get_viewport().get_visible_rect().size.y / float(win.y)


func _pill(parent: Control, text: String, color: Color, icon := "") -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.08, 0.18, 0.75), Color(0, 0, 0, 0), 20, 0, 0, Vector2(18, 6)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if icon != "":
		row.add_child(Icons.make(icon, 30.0))
	var l := UIKit.label(text, 30, color, true)
	row.add_child(l)
	parent.add_child(p)
	return l


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_ult_btn.position = Vector2(vp.x * 0.5 - _ult_btn.size.x * 0.5, vp.y - _ult_btn.size.y - 46)
	_hint.reset_size()
	_hint.position = Vector2((vp.x - _hint.size.x) * 0.5, vp.y * 0.62)
	_toast.reset_size()
	_toast.size.x = vp.x
	_toast.position = Vector2(0, vp.y * 0.3)


func _process(_delta: float) -> void:
	if _hint.visible and run.state != Run.State.READY and run.d > 8.0:
		_hint.visible = false


func _on_ult_changed(ratio: float, ready: bool) -> void:
	_ult_btn.progress = ratio if not ready else 1.0
	_ult_btn.disabled = not ready
	_ult_btn.highlight = ready
	if ready:
		toast(Loc.t("ULT_READY"), Color(1.0, 0.7, 0.95))


func _on_ult() -> void:
	if run.use_ult():
		toast(Loc.t(run.ult["name"]), Color(0.6, 0.85, 1.0) if run.hero_type == "bolt" else Color(0.5, 1.0, 0.65))
	else:
		Audio.play("error", -6.0)


func toast(text: String, color := Color(1.0, 0.9, 0.5)) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_layout()
	if _toast_tw:
		_toast_tw.kill()
	_toast.modulate.a = 1.0
	_toast.scale = Vector2.ONE
	_toast_tw = _toast.create_tween()
	_toast_tw.tween_interval(1.0)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ------------------------------------------------------------------ portrait

func _render_portrait() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	vp.add_child(sun)
	var m := HeroModels.hero(run.hero_type)
	m.rotation_degrees.y = 18.0
	vp.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var frame: Array = m.get_meta("portrait")
	cam.look_at_from_position(frame[0], frame[1])
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img and not img.is_empty():
		_portrait = ImageTexture.create_from_image(img)
		_ult_btn.icon_texture = _portrait
		_ult_btn.icon_tint = Color.WHITE
	vp.queue_free()


# ------------------------------------------------------------------ panels

func _on_pause() -> void:
	if _modal or run.state in [Run.State.WON, Run.State.LOST]:
		return
	get_tree().paused = true
	var box := _panel(Loc.t("PAUSED"))
	var resume := UIKit.button(Loc.t("RESUME"), true, 360.0)
	resume.pressed.connect(_close_modal)
	box.add_child(resume)
	var again := UIKit.button(Loc.t("RETRY"), false, 360.0)
	again.pressed.connect(func(): _close_modal(); retry.emit())
	box.add_child(again)
	var to_menu := UIKit.button(Loc.t("MENU"), false, 360.0)
	to_menu.pressed.connect(func(): _close_modal(); menu.emit())
	box.add_child(to_menu)


func _close_modal() -> void:
	get_tree().paused = false
	if _modal:
		_modal.queue_free()
		_modal = null


func _panel(title: String) -> VBoxContainer:
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, UIKit.GOLD.darkened(0.2), 28, 3, 10, Vector2(40, 30)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var t := UIKit.label(title, 52, UIKit.GOLD, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	UIKit.pop_in(panel)
	return box


func _on_finished(won: bool, earned: int, reason: String) -> void:
	_close_modal()
	_ult_btn.visible = false
	var box := _panel(Loc.t("VICTORY") if won else Loc.t("DEFEAT"))
	var why := UIKit.label(Loc.t(reason), 30, UIKit.TEXT, false)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(why)
	if earned > 0:
		var c := UIKit.label(Loc.f("COINS_EARNED", [earned]), 40, UIKit.GOLD, true, 6)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(c)
	if won:
		var go := UIKit.button(Loc.t("NEXT"), true, 360.0)
		go.pressed.connect(func(): next.emit())
		box.add_child(go)
	else:
		var again := UIKit.button(Loc.t("RETRY"), true, 360.0)
		again.pressed.connect(func(): retry.emit())
		box.add_child(again)
	var to_menu := UIKit.button(Loc.t("MENU"), false, 360.0)
	to_menu.pressed.connect(func(): menu.emit())
	box.add_child(to_menu)
