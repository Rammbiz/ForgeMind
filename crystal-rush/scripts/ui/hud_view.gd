class_name HudView
extends Control
## The in-run overlay's visuals, independent of Run so it can be previewed with mock data:
## top bar (level, coins, pause), weapon slots, the ultimate button (bottom-right), the drag
## hint, tutorial hint banners, toasts, the weapon card, and the pause and result panels.
## RunHud owns one and feeds it from Run's signals.

signal pause_pressed
signal ult_pressed
signal resume_pressed
signal retry
signal next
signal menu

const ULT_RADIUS := 60.0
const HINT_TIME := 2.8
const HINT_ICONS := {
	"HINT_DRAG": "hand", "DRAG_HINT": "hand", "HINT_GATES": "gate", "HINT_FORECAST": "gate",
	"HINT_CRATE": "crate", "HINT_CHARGE": "bolt", "HINT_ULT": "", "HINT_SPIKES": "spikes",
	"HINT_BLADES": "blade", "HINT_RECRUITS": "soldier", "HINT_ARM": "crossbow",
	"HINT_TURRET": "turret", "HINT_GEODE": "geode",
}
const POWER_ICONS := {"rate": "rate", "dmg": "dmg", "multi": "multi"}
const ARM_ICONS: Array[String] = ["spear", "crossbow", "blaster"]
const ARM_NAMES: Array[String] = ["ARM_SPEAR", "ARM_CROSSBOW", "ARM_BLASTER"]
const WEAPON_NAMES := {
	"ballista": "W_BALLISTA", "cannon": "W_CANNON", "laser": "W_LASER", "rockets": "W_ROCKETS", "drone": "W_DRONE",
}

var level := 1
var ult_icon := "storm"
var hero_color := Color(0.45, 0.75, 1.0)
var insets := Vector4.ZERO

var _top: HBoxContainer
var _level_lbl: Label
var _coins_lbl: Label
var _coin_icon: Control
var _coins_shown := 0
var _coins_tw: Tween
var _slots: Array[WeaponSlot] = []
var _arm_slot: WeaponSlot
var _pause_btn: RoundButton
var ult_btn: RoundButton
var _ult_ready := false
var _drag: Control
var _drag_on := false
var _hint: PanelContainer
var _hint_lbl: Label
var _hint_badge: IconBadge
var _hint_tw: Tween
var _hint_key := ""
var _toasts: VBoxContainer
var _big_toast: Label
var _big_tw: Tween
var _card: Control
var _modal: Control
var _modal_kind := ""          # "", "pause", "result"


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()


## Builds the overlay. `ult_icon_kind` is the hero's ult icon (Balance.HEROES[..].ult.icon).
func setup(p_level: int, ult_icon_kind: String, p_hero_color := Color(0.45, 0.75, 1.0)) -> void:
	level = p_level
	ult_icon = ult_icon_kind
	hero_color = p_hero_color


func _ready() -> void:
	insets = UIKit.safe_insets(get_viewport())
	_build_top()
	_build_ult()
	_build_drag_hint()
	_build_hint()
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 10)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp := get_viewport_rect().size
	ult_btn.position = Vector2(vp.x - ult_btn.size.x - 26.0 - insets.z, vp.y - ult_btn.size.y - 56.0 - insets.w)
	if _drag:
		_drag.reset_size()
		_drag.position = Vector2((vp.x - _drag.size.x) * 0.5, vp.y * 0.6)
	_toasts.size = Vector2(vp.x, 10)
	_toasts.position = Vector2(0, vp.y * 0.39)
	_place_hint()


# ------------------------------------------------------------------ top bar

func _build_top() -> void:
	_top = HBoxContainer.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = 18 + insets.x
	_top.offset_right = -18 - insets.z
	_top.offset_top = 16 + insets.y
	_top.add_theme_constant_override("separation", 12)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(left)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(row)
	var lp := UIKit.pill()
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	lrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.add_child(lrow)
	lrow.add_child(Icons.make("crystal", 30.0))
	_level_lbl = UIKit.heading(Loc.f("LEVEL", [level]), 28, UIKit.TEXT, 6)
	lrow.add_child(_level_lbl)
	row.add_child(lp)
	var cp := UIKit.pill()
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.add_child(crow)
	_coin_icon = Icons.make("coin", 34.0)
	crow.add_child(_coin_icon)
	_coins_lbl = UIKit.heading("0", 30, UIKit.GOLD, 6)
	_coins_lbl.custom_minimum_size.x = 44
	crow.add_child(_coins_lbl)
	row.add_child(cp)
	# Weapon slots under the level pill: army arms chip (hidden until upgraded) + 3 machines.
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(slots)
	_arm_slot = WeaponSlot.new()
	_arm_slot.circle = true
	_arm_slot.visible = false
	slots.add_child(_arm_slot)
	for i in 3:
		var s := WeaponSlot.new()
		slots.add_child(s)
		_slots.append(s)
	_top.add_child(UIKit.spacer())
	_pause_btn = RoundButton.new(30.0)
	_pause_btn.icon_kind = "pause"
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_top.add_child(_pause_btn)


func set_coins(n: int, animate := true) -> void:
	if not animate:
		_coins_shown = n
		_coins_lbl.text = str(n)
		return
	if _coins_tw:
		_coins_tw.kill()
	var from := _coins_shown
	_coins_shown = n
	_coins_tw = _coins_lbl.create_tween()
	_coins_tw.tween_method(func(v: float): _coins_lbl.text = str(int(round(v))), float(from), float(n), 0.25)
	if n > from:
		UIKit.punch(_coin_icon, 1.3, 0.28)


# ------------------------------------------------------------------ ult

func _build_ult() -> void:
	ult_btn = RoundButton.new(ULT_RADIUS)
	ult_btn.ult_style = true
	ult_btn.custom_minimum_size = Vector2(ULT_RADIUS * 2.0 + 60.0, ULT_RADIUS * 2.0 + 48.0)
	ult_btn.base_color = Color(0.08, 0.06, 0.18, 1.0)
	ult_btn.glow_color = _vivid(hero_color.lerp(Color(1.0, 0.5, 1.0), 0.3))
	ult_btn.progress_color = Color(0.55, 0.7, 1.0)
	ult_btn.icon_kind = ult_icon
	ult_btn.badge_icon = ult_icon
	ult_btn.caption = Loc.t("ULT")
	ult_btn.progress = 0.0
	ult_btn.disabled = true
	ult_btn.pressed.connect(func(): ult_pressed.emit())
	add_child(ult_btn)
	ult_btn.size = ult_btn.custom_minimum_size


## Shows charge; returns true on the not-ready → ready edge (also plays the burst + toast).
func set_ult(ratio: float, ready: bool) -> bool:
	ult_btn.progress = 1.0 if ready else clampf(ratio, 0.0, 1.0)
	ult_btn.disabled = not ready
	ult_btn.highlight = ready
	ult_btn.caption = Loc.t("ULT") if not ready else Loc.t("ULT").to_upper() + "!"
	var edge := ready and not _ult_ready
	_ult_ready = ready
	if edge:
		ult_btn.burst()
		toast(Loc.t("ULT_READY"), Color(0.86, 0.45, 1.0))
		UIKit.sparkles(self, ult_btn.position + Vector2(ult_btn.size.x * 0.5, ULT_RADIUS + 4.0), ult_btn.glow_color.lightened(0.3), 22, 220.0)
	return edge


func set_portrait(tex: Texture2D) -> void:
	if tex:
		ult_btn.icon_texture = tex


func set_ult_visible(on: bool) -> void:
	ult_btn.visible = on


# ------------------------------------------------------------------ drag hint

func _build_drag_hint() -> void:
	_drag = VBoxContainer.new()
	(_drag as VBoxContainer).add_theme_constant_override("separation", 0)
	(_drag as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag)
	var anim := DragHand.new()
	anim.custom_minimum_size = Vector2(520, 170)
	_drag.add_child(anim)
	var p := UIKit.pill()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := UIKit.heading(Loc.t("DRAG_HINT"), 30, UIKit.TEXT, 7)
	p.add_child(l)
	_drag.add_child(p)
	_drag.visible = false


func show_drag_hint(on: bool) -> void:
	if on == _drag_on:
		return
	_drag_on = on
	var tw := _drag.create_tween()
	if on:
		_drag.visible = true
		_drag.modulate.a = 0.0
		tw.tween_property(_drag, "modulate:a", 1.0, 0.35)
	else:
		tw.tween_property(_drag, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): _drag.visible = false)


func drag_hint_shown() -> bool:
	return _drag_on


# ------------------------------------------------------------------ tutorial hint banner

func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", UIKit.lux("banner", Vector2(18, 12)))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(row)
	_hint_badge = IconBadge.new()
	_hint_badge.custom_minimum_size = Vector2(66, 66)
	_hint_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_badge.icon_scale = 0.78
	row.add_child(_hint_badge)
	_hint_lbl = UIKit.heading("", 28, UIKit.TEXT, 6)
	_hint_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_hint_lbl)
	_hint.visible = false
	add_child(_hint)


func _place_hint() -> void:
	if _hint == null:
		return
	var vp := get_viewport_rect().size
	_hint.reset_size()
	_hint.size.x = minf(vp.x - 48.0, maxf(_hint.get_combined_minimum_size().x, 0.0))
	_hint.position = Vector2((vp.x - _hint.size.x) * 0.5, maxf(vp.y * 0.22, 190.0 + insets.y))
	_hint.pivot_offset = _hint.size * 0.5


## Tutorial banner: "" hides it; otherwise shows Loc.t(key) for HINT_TIME seconds.
func show_hint(key: String) -> void:
	if _hint_tw:
		_hint_tw.kill()
	if key == "":
		_hint_key = ""
		_hint_tw = _hint.create_tween()
		_hint_tw.tween_property(_hint, "modulate:a", 0.0, 0.25)
		_hint_tw.tween_callback(func(): _hint.visible = false)
		return
	_hint_key = key
	_hint_lbl.text = Loc.t(key)
	# One line when it fits, otherwise wrap at a comfortable width.
	var tw := UIKit.font(true).get_string_size(_hint_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var max_w := get_viewport_rect().size.x - 48.0 - 140.0
	if tw > max_w:
		_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint_lbl.custom_minimum_size = Vector2(minf(max_w, 440.0), 0)
	else:
		_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_hint_lbl.custom_minimum_size = Vector2.ZERO
	var ik: String = HINT_ICONS.get(key, "")
	if ik == "":
		ik = ult_icon if key == "HINT_ULT" else "star"
	_hint_badge.set_icon(ik)
	_hint.visible = true
	_place_hint()
	var y := _hint.position.y
	_hint.modulate.a = 0.0
	_hint.scale = Vector2(0.9, 0.9)
	_hint.position.y = y - 26.0
	_hint_tw = _hint.create_tween()
	_hint_tw.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hint_tw.tween_property(_hint, "modulate:a", 1.0, 0.25)
	_hint_tw.tween_property(_hint, "scale", Vector2.ONE, 0.4)
	_hint_tw.tween_property(_hint, "position:y", y, 0.4)
	_hint_tw.chain().tween_interval(HINT_TIME)
	_hint_tw.chain().tween_property(_hint, "modulate:a", 0.0, 0.45)
	_hint_tw.chain().tween_callback(func(): _hint.visible = false)
	Audio.note(9, -14.0)


# ------------------------------------------------------------------ toasts

## Big centred gradient text (ult ready, ult name, armour, stairs multiplier).
func toast(text: String, color := Color(1.0, 0.9, 0.5), size_px := 54) -> void:
	if _big_toast:
		_big_toast.queue_free()
	if _big_tw:
		_big_tw.kill()
	var vp := get_viewport_rect().size
	var l := UIKit.gradient_heading(text, size_px, color.lightened(0.7), color, color.darkened(0.35), 12)
	l.add_theme_color_override("font_outline_color", color.darkened(0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(vp.x, size_px * 1.6)
	l.position = Vector2(0, vp.y * 0.305)
	l.pivot_offset = l.size * 0.5
	add_child(l)
	_big_toast = l
	l.scale = Vector2(0.4, 0.4)
	l.modulate.a = 0.0
	_big_tw = l.create_tween()
	_big_tw.set_parallel(true)
	_big_tw.tween_property(l, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_big_tw.tween_property(l, "modulate:a", 1.0, 0.12)
	_big_tw.chain().tween_property(l, "scale", Vector2.ONE, 0.18)
	_big_tw.chain().tween_interval(0.9)
	_big_tw.chain().tween_property(l, "position:y", l.position.y - 30.0, 0.4)
	_big_tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4)
	_big_tw.chain().tween_callback(func():
		if _big_toast == l:
			_big_toast = null
		l.queue_free())


## Small pill toast with an icon, stacking under the big toast line (power-ups, arms).
func pill_toast(text: String, icon := "", color := UIKit.GOLD) -> void:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := UIKit.pill()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if icon != "":
		row.add_child(Icons.make(icon, 42.0))
	var l := UIKit.heading(text, 32, color, 7)
	row.add_child(l)
	holder.add_child(p)
	_toasts.add_child(holder)
	_layout()
	UIKit.pop_in(p, 0.0, 0.35)
	var tw := holder.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(holder, "modulate:a", 0.0, 0.35)
	tw.tween_callback(holder.queue_free)


## Hero power gate (stat "rate"|"dmg"|"multi"|"arm"); total is this run's bonus so far.
func power_toast(stat: String, total: float) -> void:
	match stat:
		"rate":
			pill_toast(Loc.t("POWER_RATE") % int(round(total * 100.0)), "rate", Color(1.0, 0.86, 0.4))
		"dmg":
			pill_toast(Loc.t("POWER_DMG") % int(round(total)), "dmg", Color(1.0, 0.6, 0.45))
		"multi":
			pill_toast(Loc.t("POWER_MULTI"), "multi", Color(0.6, 0.9, 1.0))
		"arm":
			var tier := clampi(int(total), 0, 2)
			set_arm(tier)
			pill_toast(Loc.t(ARM_NAMES[tier]) + "!", ARM_ICONS[tier], Color(0.5, 1.0, 0.85))
		_:
			pill_toast(stat, "star")


## Army weapon tier chip next to the slots (0 hides it).
func set_arm(tier: int) -> void:
	_arm_slot.visible = tier > 0
	if tier > 0:
		_arm_slot.set_weapon(ARM_ICONS[clampi(tier, 0, 2)], 0, Color(0.4, 1.0, 0.85))
		UIKit.punch(_arm_slot, 1.3)


# ------------------------------------------------------------------ weapons

## Fills the slots from Run.weapons ([{kind, level}]).
func set_weapons(list: Array) -> void:
	for i in _slots.size():
		if i < list.size():
			var wd: Dictionary = list[i]
			_slots[i].set_weapon(str(wd.get("kind", "")), int(wd.get("level", 1)), _weapon_color(str(wd.get("kind", ""))))
		else:
			_slots[i].set_weapon("", 0, Color.WHITE)


## A weapon was acquired or levelled up: centred reward card, then it flies into its slot.
func weapon_added(kind: String, lvl: int, list: Array = []) -> void:
	var slot_i := -1
	for i in _slots.size():
		if _slots[i].kind == kind:
			slot_i = i
			break
	if slot_i == -1:
		for i in _slots.size():
			if _slots[i].kind == "":
				slot_i = i
				break
	slot_i = maxi(slot_i, 0)
	if _card:
		_card.queue_free()
	_card = build_weapon_card(kind, lvl)
	add_child(_card)
	var vp := get_viewport_rect().size
	_card.reset_size()
	_card.position = Vector2((vp.x - _card.size.x) * 0.5, maxf(vp.y * 0.47 - _card.size.y * 0.5, 380.0 + insets.y))
	_card.pivot_offset = _card.size * 0.5
	var card := _card
	var target_slot := _slots[slot_i]
	_card.scale = Vector2(0.3, 0.3)
	_card.modulate.a = 0.0
	var tw := _card.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.chain().tween_callback(func(): UIKit.sparkles(self, card.position + card.size * 0.5, _weapon_color(kind).lightened(0.4), 30, 320.0))
	tw.chain().tween_interval(1.25)
	# Fly into the slot.
	tw.chain().tween_callback(func(): card.pivot_offset = Vector2.ZERO)
	var dest := target_slot.global_position - global_position
	tw.chain().tween_property(card, "position", dest, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "scale", Vector2(0.18, 0.18), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "modulate:a", 0.2, 0.4)
	tw.chain().tween_callback(func():
		if not list.is_empty():
			set_weapons(list)
		if target_slot.kind != kind:
			target_slot.set_weapon(kind, lvl, _weapon_color(kind))
		UIKit.punch(target_slot, 1.45, 0.4)
		target_slot.flash()
		if _card == card:
			_card = null
		card.queue_free())


static func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, maxf(c.s, 0.7), 1.0)


static func _weapon_color(kind: String) -> Color:
	if kind == "":
		return Color.WHITE
	return WeaponModels.icon_color(kind)


## The reward card shown when a weapon is acquired (also used by previews).
static func build_weapon_card(kind: String, lvl: int) -> Control:
	var col := _weapon_color(kind)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(420, 430)
	var shade := TextureRect.new()
	shade.texture = UIKit.glow_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.modulate = Color(0.0, 0.0, 0.04, 0.7)
	shade.size = Vector2(760, 760)
	shade.position = Vector2(210 - 380, 200 - 380)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var rays := UIKit.Rays.new()
	rays.color = Color(col.r, col.g, col.b, 0.55).lerp(Color(1, 0.92, 0.65, 0.55), 0.4)
	rays.inner = 0.12
	rays.count = 16
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.size = Vector2(900, 900)
	rays.position = Vector2(210 - 450, 190 - 450)
	root.add_child(rays)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.lux("card_sel", Vector2(26, 20)))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(360, 0)
	card.position = Vector2(30, 14)
	root.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var head := UIKit.heading(Loc.t("NEW_WEAPON").to_upper() if lvl <= 1 else "★".repeat(clampi(lvl, 1, 3)), 22, UIKit.GOLD, 5)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var art := IconBadge.new()
	art.ring = col
	art.big = true
	art.icon = kind
	art.icon_scale = 0.8
	art.custom_minimum_size = Vector2(190, 190)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var name_key: String = WEAPON_NAMES.get(kind, kind)
	var title := Loc.t("WEAPON_GOT") % Loc.t(name_key) if lvl <= 1 else Loc.t("WEAPON_UP") % [Loc.t(name_key), lvl]
	var t := UIKit.gradient_heading(title, 44 if title.length() < 16 else 38, Color(1, 1, 0.92), col.lightened(0.45), col.darkened(0.1), 10)
	t.add_theme_color_override("font_outline_color", col.darkened(0.8))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 4)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var st := Icons.make("star", 38.0)
		st.filled = i < lvl
		stars.add_child(st)
	v.add_child(stars)
	UIKit.add_shine(card, 26.0, 0.35, 1.4, 0.6)
	card.resized.connect(func():
		root.custom_minimum_size = Vector2(420, card.size.y + 28.0)
		rays.position = Vector2(210 - 450, 14 + card.size.y * 0.42 - 450)
		shade.position = Vector2(210 - 380, 14 + card.size.y * 0.45 - 380))
	return root


# ------------------------------------------------------------------ panels

func has_modal() -> bool:
	return _modal != null


func modal_kind() -> String:
	return _modal_kind


func close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null
		_modal_kind = ""


func _open_modal(kind: String, rays := false, ray_color := Color(1.0, 0.85, 0.45, 0.3)) -> Control:
	close_modal()
	_modal_kind = kind
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var dim := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.04, 0.1, 0.55))
	g.set_color(1, Color(0.0, 0.0, 0.03, 0.88))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.15, 1.0)
	gt.width = 256
	gt.height = 256
	dim.texture = gt
	dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dim.stretch_mode = TextureRect.STRETCH_SCALE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.3)
	if rays:
		var r := UIKit.Rays.new()
		r.color = ray_color
		r.count = 18
		r.inner = 0.08
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := get_viewport_rect().size
		r.size = Vector2(vp.x * 1.7, vp.x * 1.7)
		r.position = Vector2(vp.x * 0.5, vp.y * 0.2) - r.size * 0.5
		_modal.add_child(r)
		r.modulate.a = 0.0
		r.create_tween().tween_property(r, "modulate:a", 1.0, 0.6)
	return _modal


func show_pause() -> void:
	var m := _open_modal("pause")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(48, 40)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var t := UIKit.gradient_heading(Loc.t("PAUSED"), 64)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(UIKit.divider(380.0))
	var resume := UIKit.button(Loc.t("RESUME"), true, 400.0)
	resume.theme_type_variation = "GreenButton"
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)
	var again := UIKit.button(Loc.t("RETRY"), false, 400.0)
	again.pressed.connect(func(): retry.emit())
	box.add_child(again)
	var to_menu := UIKit.button(Loc.t("MENU"), false, 400.0)
	to_menu.pressed.connect(func(): menu.emit())
	box.add_child(to_menu)
	UIKit.pop_in(panel, 0.0, 0.4)
	UIKit.stagger([t, resume, again, to_menu], 0.08, 0.06, 0.35)


## Result screen. `data` follows Run.result: {coins_run, victory, mult, total, survivors};
## `earned` (Run.finished coins) is the fallback total when data is empty.
func show_result(won: bool, reason: String, data: Dictionary, earned := 0) -> void:
	ult_btn.visible = false
	show_drag_hint(false)
	if _hint.visible:
		show_hint("")
	var m := _open_modal("result", won, Color(1.0, 0.82, 0.4, 0.26))
	var collected := int(data.get("coins_run", earned if data.is_empty() else 0))
	var base := int(data.get("victory", 0))
	var mult := float(data.get("mult", 1.0))
	var total := int(data.get("total", earned if earned > 0 else int(round((base + collected) * mult))))
	var survivors := int(data.get("survivors", 0))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	# Ribbon title overlapping the panel's top edge.
	var ribbon_holder := Control.new()
	ribbon_holder.custom_minimum_size = Vector2(620, 70)
	ribbon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon_holder.z_index = 2
	col.add_child(ribbon_holder)
	var ribbon := UIKit.Ribbon.new()
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.size = Vector2(560, 96)
	ribbon.position = Vector2(30, 6)
	if not won:
		ribbon.set_palette(Color(0.62, 0.66, 0.8), Color(0.3, 0.33, 0.46), Color(0.14, 0.15, 0.24))
	ribbon_holder.add_child(ribbon)
	var title: Label
	if won:
		title = UIKit.gradient_heading(Loc.t("VICTORY"), 60, Color(1, 1, 1), Color(1.0, 0.96, 0.78), Color(1.0, 0.82, 0.45), 12)
		title.add_theme_color_override("font_outline_color", Color(0.42, 0.18, 0.02))
	else:
		title = UIKit.gradient_heading(Loc.t("DEFEAT"), 60, Color(1, 0.9, 0.88), Color(1.0, 0.55, 0.5), Color(0.82, 0.25, 0.25), 12)
		title.add_theme_color_override("font_outline_color", Color(0.16, 0.04, 0.06))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size = Vector2(560, 92)
	title.position = Vector2(30, 6)
	ribbon_holder.add_child(title)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(40, 30)))
	panel.custom_minimum_size = Vector2(620, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(UIKit.gap(34))
	var anim: Array[Control] = []
	if reason != "":
		var why := UIKit.heading(Loc.t(reason), 30, UIKit.TEXT_DIM, 5)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(why)
		anim.append(why)
	if won or survivors > 0:
		var srow := HBoxContainer.new()
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		srow.add_theme_constant_override("separation", 10)
		srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		srow.add_child(Icons.make("soldier", 40.0))
		srow.add_child(UIKit.heading(Loc.f("SURVIVORS", [survivors]), 32, UIKit.TEXT, 6))
		box.add_child(srow)
		anim.append(srow)
	var mult_node: Control = null
	if won and mult > 1.0:
		box.add_child(UIKit.gap(6))
		mult_node = _mult_block(mult)
		box.add_child(mult_node)
	box.add_child(UIKit.divider(480.0))
	# Coins breakdown.
	var rows: Array[Control] = []
	if base > 0:
		rows.append(_coin_row(Loc.t("COINS_BASE"), "+%d" % base))
	if base > 0 or (mult > 1.0 and won):
		rows.append(_coin_row(Loc.t("COINS_COLLECTED"), "+%d" % collected))
	if mult > 1.0 and won:
		rows.append(_coin_row(Loc.t("MULTIPLIER"), Loc.t("STAIRS_MULT") % _fmt_mult(mult), UIKit.GOLD, false))
	for r in rows:
		box.add_child(r)
	# Total with count-up.
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 14)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := UIKit.heading(Loc.t("COINS_TOTAL"), 30, UIKit.TEXT_DIM, 5)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tl)
	var tcoin := Icons.make("coin", 58.0)
	tcoin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tcoin)
	var tnum := UIKit.gradient_heading("0", 72)
	tnum.custom_minimum_size.x = 150
	trow.add_child(tnum)
	box.add_child(trow)
	box.add_child(UIKit.gap(6))
	# Buttons.
	var primary := UIKit.button(Loc.t("NEXT") if won else Loc.t("RETRY"), true, 440.0)
	primary.custom_minimum_size.y = 96
	primary.add_theme_font_size_override("font_size", 40)
	primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if won:
		primary.pressed.connect(func(): next.emit())
	else:
		primary.pressed.connect(func(): retry.emit())
	box.add_child(primary)
	var to_menu := UIKit.button(Loc.t("MENU"), false, 440.0)
	to_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	to_menu.pressed.connect(func(): menu.emit())
	box.add_child(to_menu)
	# Choreography.
	UIKit.pop_in(panel, 0.0, 0.45)
	_ribbon_in(ribbon, title, 0.12)
	UIKit.stagger(anim, 0.3, 0.1, 0.4)
	var t_mult := 0.3 + anim.size() * 0.1 + 0.1
	if mult_node:
		_slam(mult_node, t_mult)
		t_mult += 0.35
	UIKit.stagger(rows, t_mult, 0.09, 0.35)
	var t_total := t_mult + rows.size() * 0.09 + 0.15
	UIKit.pop_in(trow, t_total, 0.4)
	UIKit.count_up(tnum, 0, total, clampf(0.5 + total * 0.004, 0.6, 1.4), t_total + 0.15)
	UIKit.stagger([primary, to_menu], t_total + 0.5, 0.1, 0.4)
	UIKit.add_shine(primary, 30.0, t_total + 1.2, 2.4, 0.5)
	if won:
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_callback(func(): UIKit.sparkles(self, get_viewport_rect().size * Vector2(0.5, 0.2), UIKit.GOLD_LIGHT, 40, 420.0))
		Audio.play("victory", -2.0)
	else:
		Audio.play("defeat", -2.0)


static func _fmt_mult(m: float) -> String:
	if is_equal_approx(m, round(m)):
		return str(int(round(m)))
	return ("%.1f" % m).replace(".0", "")


func _mult_block(mult: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(480, 150)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := TextureRect.new()
	glow.texture = UIKit.glow_texture()
	glow.modulate = Color(1.0, 0.7, 0.25, 0.55)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(360, 200)
	glow.position = Vector2(60, -26)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var cap := UIKit.heading(Loc.t("MULTIPLIER").to_upper(), 22, UIKit.GOLD, 5)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(480, 26)
	cap.position = Vector2(0, 0)
	holder.add_child(cap)
	var big := UIKit.gradient_heading(Loc.t("STAIRS_MULT") % _fmt_mult(mult), 104, Color(1, 1, 0.9), Color(1.0, 0.8, 0.3), Color(0.9, 0.42, 0.08), 14)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.size = Vector2(480, 124)
	big.position = Vector2(0, 24)
	holder.add_child(big)
	return holder


func _slam(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = c.custom_minimum_size * 0.5
	c.scale = Vector2(2.2, 2.2)
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): Audio.play("upgrade", -4.0))
	tw.tween_property(c, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): UIKit.sparkles(self, c.global_position - global_position + c.size * 0.5, UIKit.GOLD_LIGHT, 22, 260.0))


func _ribbon_in(ribbon: Control, title: Label, delay: float) -> void:
	for n: Control in [ribbon, title]:
		n.pivot_offset = n.size * 0.5
		n.scale = Vector2(0.2, 1.0)
		n.modulate.a = 0.0
		var tw := n.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(n, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _coin_row(text: String, value: String, value_color := UIKit.TEXT, coin := true) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(460, 40)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, 28, UIKit.TEXT_DIM, false, 4)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := UIKit.heading(value, 32, value_color, 6)
	row.add_child(v)
	if coin:
		row.add_child(Icons.make("coin", 32.0))
	else:
		row.add_child(UIKit.gap(32))
	return row


# ------------------------------------------------------------------ drawn widgets

## Weapon slot: glass tile with the weapon icon, a coloured glow rim and level stars.
class WeaponSlot extends Control:
	var kind := ""
	var lvl := 0
	var color := Color.WHITE
	var circle := false
	var _flash := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(66, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_weapon(k: String, level: int, c: Color) -> void:
		kind = k
		lvl = level
		color = c
		queue_redraw()

	func flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 2.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), Vector2(64, 64))
		var rad := 32 if circle else 16
		if kind == "":
			draw_style_box(UIKit.box(Color(0.03, 0.04, 0.1, 0.42), Color(1, 1, 1, 0.16), rad, 2, 0, Vector2.ZERO), r)
			var c := r.get_center()
			draw_line(c - Vector2(9, 0), c + Vector2(9, 0), Color(1, 1, 1, 0.22), 3.0)
			draw_line(c - Vector2(0, 9), c + Vector2(0, 9), Color(1, 1, 1, 0.22), 3.0)
			return
		draw_texture_rect(UIKit.glow_texture(), r.grow(16), false, Color(color.r, color.g, color.b, 0.35 + _flash * 0.6))
		draw_style_box(UIKit.box(Color(0.0, 0.0, 0.03, 0.4), Color(0, 0, 0, 0), rad + 2, 0, 0, Vector2.ZERO), Rect2(r.position + Vector2(0, 4), r.size))
		draw_style_box(UIKit.box(Color(0.08, 0.1, 0.22, 0.95), color.lerp(Color(1, 0.85, 0.45), 0.35), rad, 3, 0, Vector2.ZERO), r)
		draw_style_box(UIKit.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), rad - 3, 0, 0, Vector2.ZERO), Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y * 0.42)))
		Icons.draw_icon(self, kind, Rect2(r.position + Vector2(5, 3), r.size - Vector2(10, 10)), Color.WHITE)
		if _flash > 0.0:
			draw_style_box(UIKit.box(Color(1, 1, 1, _flash * 0.6), Color(0, 0, 0, 0), rad, 0, 0, Vector2.ZERO), r)
		if lvl > 0:
			var sw := 22.0
			var x0 := r.get_center().x - sw * 1.5 + 2.0
			draw_style_box(UIKit.box(Color(0.02, 0.03, 0.08, 0.9), Color(1, 0.85, 0.45, 0.5), 9, 1, 0, Vector2.ZERO), Rect2(Vector2(x0 - 4.0, r.end.y - 11.0), Vector2(sw * 3.0 + 4.0, 20.0)))
			for i in 3:
				var sr := Rect2(Vector2(x0 + i * (sw - 2.0), r.end.y - 12.0), Vector2(sw, sw))
				Icons.draw_icon(self, "star", sr, Color.WHITE if i < lvl else Color(0.5, 0.52, 0.6, 0.9), i < lvl)


## Round gold-rimmed medallion behind an icon (hint banner, weapon card).
class IconBadge extends Control:
	var ring := Color(1.0, 0.8, 0.34)
	var big := false
	var icon := ""
	var icon_scale := 0.66
	var _t := 0.0

	func set_icon(k: String) -> void:
		icon = k
		queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if big:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		if big:
			var k := 0.75 + 0.25 * sin(_t * 3.0)
			draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.5, Vector2(r, r) * 3.0), false, Color(ring.r, ring.g, ring.b, 0.55 * k))
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0.02, 0.4))
		draw_circle(c, r, Color(0.42, 0.22, 0.05))
		draw_circle(c + Vector2(0, -1), r - 1.5, Color(1.0, 0.88, 0.5))
		draw_circle(c + Vector2(0, 1), r - (5.0 if big else 3.5), Color(0.75, 0.46, 0.12))
		var face := r - (8.0 if big else 5.5)
		for i in 5:
			var kk := 1.0 - i * 0.14
			draw_circle(c - Vector2(0, face * 0.06 * i), face * kk, Color(0.06, 0.08, 0.2).lerp(ring.darkened(0.2), i * 0.11))
		draw_arc(c, face - 1.0, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.22), 2.0, true)
		if icon != "":
			var isz := face * 2.0 * icon_scale
			var ir := Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz))
			Icons.draw_icon(self, icon, Rect2(ir.position + Vector2(0, isz * 0.04), ir.size), Color(0, 0, 0.05, 0.4))
			Icons.draw_icon(self, icon, ir, Color.WHITE)


## Animated hand sliding left and right over a dotted track (drag tutorial).
class DragHand extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var cy := 34.0
		var span := w * 0.36
		var cx := w * 0.5
		# Track: glowing dots fading to the ends, chevrons at both ends.
		for i in 21:
			var f := float(i) / 20.0 * 2.0 - 1.0
			var a := 0.75 * (1.0 - absf(f) * 0.6)
			draw_circle(Vector2(cx + f * span, cy), 4.0, Color(0, 0, 0.05, a * 0.6))
			draw_circle(Vector2(cx + f * span, cy), 3.0, Color(1, 1, 1, a))
		for sgn: float in [-1.0, 1.0]:
			var tip := Vector2(cx + sgn * (span + 34.0), cy)
			var pts := PackedVector2Array([tip, tip + Vector2(-sgn * 22.0, -18.0), tip + Vector2(-sgn * 12.0, 0), tip + Vector2(-sgn * 22.0, 18.0)])
			var out := pts.duplicate()
			out.append(pts[0])
			draw_polyline(out, Color(0.04, 0.05, 0.12, 0.9), 6.0, true)
			draw_colored_polygon(pts, UIKit.GOLD)
		# Hand position: smooth ease back and forth.
		var s := sin(_t * 2.4)
		var x := cx + s * span
		var hs := 112.0
		# Motion trail.
		for k in [3, 2, 1]:
			var sk := sin(_t * 2.4 - k * 0.16)
			var xk := cx + sk * span
			Icons.draw_icon(self, "hand", Rect2(Vector2(xk - hs * 0.485, cy - hs * 0.04), Vector2(hs, hs)), Color(1, 1, 1, 0.1 / k))
		# Touch ripple under the fingertip.
		var ph := fmod(_t * 1.6, 1.0)
		draw_arc(Vector2(x, cy), 10.0 + ph * 26.0, 0, TAU, 32, Color(1, 1, 1, 0.6 * (1.0 - ph)), 3.0, true)
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(x, cy) - Vector2(26, 26), Vector2(52, 52)), false, Color(0.6, 0.9, 1.0, 0.8))
		Icons.draw_icon(self, "hand", Rect2(Vector2(x - hs * 0.485 + 4.0, cy - hs * 0.04 + 6.0), Vector2(hs, hs)), Color(0, 0, 0.05, 0.35))
		Icons.draw_icon(self, "hand", Rect2(Vector2(x - hs * 0.485, cy - hs * 0.04), Vector2(hs, hs)), Color.WHITE)
