extends Control
## Герої tab (arsenal_design.md §4.1, §7.1): the hero big on a warm dais (swipe or arrows to
## switch), the name and who leads the army, then a cream parchment panel with the hero level
## (cap per world), the three bonuses with the next level's gain, the milestone track (Ult
## ranks at Lv5/15/25; Awakenings at 10/20/30 come in Meta-2) and the two-tap level-up.
## Locked heroes show when they join. Level-ups without a milestone are micro ceremonies.

const HEROES: Array[String] = Balance.HERO_ORDER

var hub: Hub
var _idx := 0
var _show: HubShowcase
var _name: Label
var _desc: Label
var _sel_btn: Button
var _sel_chip: PanelContainer
var _panel: PanelContainer
var _body: VBoxContainer
var _dots: HBoxContainer
var _armed := false
var _lvl_btn: Button
var _drag_x := -1.0


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idx = maxi(0, HEROES.find(Meta.hero()))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(0, 380)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(strip)
	_show = HubShowcase.new("hero")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	_show.gui_input.connect(_swipe)
	strip.add_child(_show)
	for side in [-1, 1]:
		var arrow := RoundButton.new(30.0)
		arrow.icon_kind = "back"
		arrow.base_color = Color(0.2, 0.1, 0.06, 0.85)
		arrow.set_anchors_preset(Control.PRESET_CENTER_LEFT if side < 0 else Control.PRESET_CENTER_RIGHT)
		arrow.position = Vector2(UITokens.GUTTER if side < 0 else -UITokens.GUTTER - 68, -34)
		if side > 0:
			arrow.pivot_offset = Vector2(34, 34)
			arrow.rotation = PI
		arrow.pressed.connect(_step.bind(side))
		strip.add_child(arrow)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", -4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = UIKit.gradient_heading("", 56)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_name)
	_desc = UIKit.heading("", 22, Color(1.0, 0.9, 0.78), 6)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_desc)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_dots)
	col.add_child(head)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel_btn = UIKit.button(Loc.t("HERO_SELECT"), false, 330.0)
	_sel_btn.custom_minimum_size.y = 64
	_sel_btn.add_theme_font_size_override("font_size", 24)
	_sel_btn.pressed.connect(func():
		Meta.set_hero(HEROES[_idx])
		UIJuice.haptic("THUD", 0.6)
		Audio.play("weapon_get", -6.0)
		_show.celebrate(0.6))
	srow.add_child(_sel_btn)
	_sel_chip = PanelContainer.new()
	_sel_chip.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(20, 8)))
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 8)
	cr.add_child(Icons.make("crown", 30.0))
	cr.add_child(UIKit.heading(Loc.t("HERO_SELECTED"), 24, UIKit.GOLD_LIGHT, 5))
	_sel_chip.add_child(cr)
	srow.add_child(_sel_chip)
	col.add_child(srow)
	var pwrap := MarginContainer.new()
	pwrap.add_theme_constant_override("margin_left", 14)
	pwrap.add_theme_constant_override("margin_right", 14)
	pwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.lux("parch", Vector2(26, 20)))
	pwrap.add_child(_panel)
	col.add_child(pwrap)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_panel.add_child(_body)
	refresh()


func on_show() -> void:
	refresh()


func _swipe(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag_x = e.position.x
		elif _drag_x >= 0.0:
			var dx: float = e.position.x - _drag_x
			_drag_x = -1.0
			if absf(dx) > 70.0:
				_step(-1 if dx > 0 else 1)


func _step(d: int) -> void:
	_idx = posmod(_idx + d, HEROES.size())
	_armed = false
	Audio.play("click", -6.0)
	UIJuice.haptic("TICK", 0.4)
	refresh()
	UIJuice.fade_in(_panel, 0.0, UITokens.FAST)


func refresh() -> void:
	if not is_node_ready():
		return
	var id := HEROES[_idx]
	var def: Dictionary = Balance.HEROES[id]
	_show.show_hero(id)
	_name.text = Loc.t(str(def["name"]))
	_desc.text = Loc.t(str(def["desc"]))
	for d in _dots.get_children():
		d.queue_free()
	for i in HEROES.size():
		var dot := Dot.new()
		dot.on = i == _idx
		dot.custom_minimum_size = Vector2(34 if dot.on else 16, 18)
		_dots.add_child(dot)
	var unlocked := Meta.hero_unlocked(id)
	var chosen := Meta.hero() == id
	_sel_btn.visible = unlocked and not chosen
	_sel_chip.visible = chosen
	_fill_body(id, unlocked)


func _ink(text: String, size := 24, dim := false) -> Label:
	var l := UIKit.label(text, size, UITokens.PARCH_INK_DIM if dim else UITokens.PARCH_INK, true)
	return l


func _fill_body(id: String, unlocked: bool) -> void:
	for c in _body.get_children():
		c.queue_free()
	_lvl_btn = null
	if not unlocked:
		var at := int(EconData.HERO_UNLOCK.get(id, 0))
		var l := _ink(Loc.f("HERO_LOCKED", [at]), 28)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(l)
		var s := _ink(Loc.t("HERO_SOON"), 20, true)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(s)
		return
	var lvl := Meta.hero_level(id)
	var cap := Meta.hero_cap()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var lv := UIKit.gradient_heading(Loc.f("HERO_LEVEL", [lvl]), 34)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lv)
	var capl := _ink(Loc.f("HERO_CAP", [cap]), 20, true)
	capl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(capl)
	_body.add_child(top)
	var bar := LevelBar.new()
	bar.lvl = lvl
	bar.cap = cap
	bar.max_lvl = int(EconData.HERO["max"])
	bar.custom_minimum_size = Vector2(0, 40)
	_body.add_child(bar)
	# Bonuses: now and next level.
	var now := EconData.hero_mults(lvl)
	var nxt := EconData.hero_mults(lvl + 1) if lvl < cap else {}
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	stats.add_child(_stat("dmg", Loc.f("HERO_DMG", [int(round((float(now["dmg_mult"]) - 1.0) * 100.0))]), float(nxt.get("dmg_mult", 0.0)) - float(now["dmg_mult"])))
	stats.add_child(_stat("heart", Loc.f("HERO_HP", [int(round((float(now["hp_mult"]) - 1.0) * 100.0))]), float(nxt.get("hp_mult", 0.0)) - float(now["hp_mult"])))
	var ult_icon := str((Balance.HEROES[id]["ult"] as Dictionary).get("icon", "storm"))
	stats.add_child(_stat(ult_icon, Loc.f("ULT_RANK", [_roman(int(now["ult_rank"]))]), 0.0))
	_body.add_child(stats)
	# Milestones
	var ms := Milestones.new()
	ms.lvl = lvl
	ms.ult_icon = ult_icon
	ms.custom_minimum_size = Vector2(0, 92)
	_body.add_child(ms)
	# Level up
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_lvl_btn = UIKit.styled_button("", "green", Vector2(520, 96))
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_bottom = -7
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", -4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := UIKit.heading("", 32, Color(1, 1, 1), 8)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t1)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := Icons.make("coin", 26.0)
	line.add_child(coin)
	var t2 := UIKit.heading("", 24, Color(0.92, 1.0, 0.9), 5)
	line.add_child(t2)
	inner.add_child(line)
	_lvl_btn.add_child(inner)
	var cost := Meta.hero_cost(id)
	var can := Meta.can_level_hero(id)
	if lvl >= cap:
		t1.text = Loc.t("LV_MAX")
		t2.text = Loc.t("HERO_MAX_WORLD")
		t2.add_theme_font_size_override("font_size", 18)
		coin.visible = false
		_lvl_btn.disabled = true
	elif _armed and can:
		for st: String in ["normal", "hover"]:
			_lvl_btn.add_theme_stylebox_override(st, UIKit.lux("primary"))
		_lvl_btn.add_theme_stylebox_override("pressed", UIKit.lux("primary_pressed"))
		t1.text = Loc.f("CONFIRM_COST", [Loc.num(cost) if cost > 0 else Loc.t("FREE")])
		t1.add_theme_color_override("font_color", UIKit.BROWN)
		t1.add_theme_constant_override("outline_size", 0)
		t1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		line.visible = false
	else:
		if not can:
			for st2: String in ["normal", "hover"]:
				_lvl_btn.add_theme_stylebox_override(st2, UIKit.lux("button"))
		t1.text = Loc.t("LEVEL_UP")
		t2.text = Loc.num(cost) if cost > 0 else Loc.t("HERO_FREE_LEVEL")
		coin.visible = cost > 0
		if not can and cost > Meta.currency("coins"):
			t2.text = Loc.num(cost) + " · " + Loc.t("NEED_COINS")
	_lvl_btn.pressed.connect(_press_level.bind(id))
	row.add_child(_lvl_btn)
	_body.add_child(row)


func _press_level(id: String) -> void:
	if not Meta.can_level_hero(id):
		Audio.play("error", -6.0)
		UIJuice.wobble(_lvl_btn, 0.3, 0.3)
		return
	if not _armed:
		_armed = true
		UIJuice.haptic("CLICK", 0.5)
		_fill_body(id, true)
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(self) and _armed:
				_armed = false
				_fill_body(HEROES[_idx], Meta.hero_unlocked(HEROES[_idx])))
		return
	_armed = false
	var res := Meta.level_hero(id)
	if not bool(res.get("ok", false)):
		Audio.play("error", -6.0)
		return
	var tier := "full" if str(res.get("milestone", "")) != "" else "micro"
	Audio.play("upgrade", -2.0)
	var center := _show.get_global_rect().get_center() - global_position
	UIJuice.flare(self, center, Color(1.0, 0.75, 0.35), tier, 140.0)
	_show.celebrate(0.8)
	if str(res.get("milestone", "")) == "ult_rank":
		hub.toast(Loc.f("ULT_RANK", [_roman(int(EconData.hero_ult_rank(int(res["lvl"]))))]) + "!", "star")
	refresh()


func _stat(icon: String, text: String, delta: float) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("parch_card", Vector2(10, 8)))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var ic := TabBarracksMedal.new()
	ic.icon = icon
	ic.custom_minimum_size = Vector2(52, 52)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := _ink(text, UIKit.fit_size(text, 180.0, 22, 16))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if delta > 0.0005:
		var d := UIKit.label("+%d%%" % int(round(delta * 100.0)), 19, Color(0.12, 0.55, 0.18), true)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(d)
	p.add_child(v)
	return p


static func _roman(n: int) -> String:
	return ["I", "II", "III", "IV", "V"][clampi(n - 1, 0, 4)]


const TabBarracksMedal := preload("res://scripts/ui/hub/tab_barracks.gd").Medal


## Carousel dot (gold pill when current).
class Dot extends Control:
	var on := false

	func _draw() -> void:
		var r := Rect2(Vector2(0, 3), Vector2(size.x, size.y - 6))
		draw_style_box(UIKit.box(UIKit.GOLD if on else Color(1, 1, 1, 0.3), Color(0.35, 0.18, 0.04) if on else Color(0, 0, 0, 0), 6, 2 if on else 0, 0, Vector2.ZERO), r)


## Hero level bar on parchment: filled to the level, a gold tick at the world cap.
class LevelBar extends Control:
	var lvl := 1
	var cap := 9
	var max_lvl := 30

	func _draw() -> void:
		var r := Rect2(Vector2(0, 8), Vector2(size.x, size.y - 16))
		draw_style_box(UIKit.lux("parch_well"), r)
		var inner := r.grow(-4)
		var k := float(lvl) / float(max_lvl)
		var kc := float(cap) / float(max_lvl)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * k, 0), Vector2(inner.size.x * (kc - k), inner.size.y)), Color(0.55, 0.4, 0.2, 0.25))
		MachineCard.grad_box(self, Rect2(inner.position, Vector2(maxf(inner.size.x * k, 12.0), inner.size.y)), Color(1.0, 0.82, 0.35), Color(0.88, 0.5, 0.1), 8)
		draw_rect(Rect2(inner.position + Vector2(4, 2), Vector2(maxf(inner.size.x * k - 8.0, 0.0), 4)), Color(1, 1, 0.9, 0.5))
		var cx := inner.position.x + inner.size.x * kc
		draw_line(Vector2(cx, r.position.y - 6), Vector2(cx, r.end.y + 6), Color(0.45, 0.22, 0.05), 4.0)
		draw_circle(Vector2(cx, r.position.y - 8), 6, Color(1.0, 0.8, 0.3))


## Ult ranks (Lv1/5/15/25) and Awakenings (10/20/30, Meta-2) on a parchment track.
class Milestones extends Control:
	var lvl := 1
	var ult_icon := "storm"

	func _draw() -> void:
		var f := UIKit.font(true)
		var x0 := 30.0
		var x1 := size.x - 30.0
		var y := 34.0
		var mx := float(EconData.HERO["max"])
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.55, 0.38, 0.2, 0.5), 8.0, true)
		draw_line(Vector2(x0, y), Vector2(lerpf(x0, x1, float(lvl - 1) / (mx - 1.0)), y), Color(0.9, 0.55, 0.12), 8.0, true)
		var marks: Array = []
		var ranks: Array = EconData.HERO["ult_rank_at"]
		for i in ranks.size():
			if int(ranks[i]) > 1:
				marks.append([int(ranks[i]), ult_icon, Loc.f("MS_ULT", [_roman(i + 1)]), true])
		var aw: Array = EconData.HERO["awakening_at"]
		for j in aw.size():
			marks.append([int(aw[j]), "star", Loc.f("MS_AWAKEN", [_roman(j + 1)]), false])
		for m: Array in marks:
			var l := int(m[0])
			var x := lerpf(x0, x1, float(l - 1) / (mx - 1.0))
			var done := lvl >= l
			var live := bool(m[3])
			draw_circle(Vector2(x, y), 21, Color(0.42, 0.22, 0.06))
			draw_circle(Vector2(x, y), 18, (Color(1.0, 0.78, 0.3) if done else Color(0.98, 0.92, 0.78)) if live else Color(0.8, 0.74, 0.64))
			Icons.draw_icon(self, str(m[1]), Rect2(Vector2(x, y) - Vector2(13, 13), Vector2(26, 26)), Color.WHITE if live else Color(0.6, 0.55, 0.5))
			var t := str(m[2]) if live else Loc.t("SOON")
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(f, Vector2(clampf(x - tw * 0.5, 0, size.x - tw), y + 40), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITokens.PARCH_INK if live else UITokens.PARCH_INK_DIM)
			var lt := str(l)
			var lw := f.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, Vector2(x - lw * 0.5, y + 58), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITokens.PARCH_INK_DIM)

	static func _roman(n: int) -> String:
		return ["I", "II", "III", "IV", "V"][clampi(n - 1, 0, 4)]
