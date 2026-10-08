class_name HudView
extends Control
## The in-run overlay's visuals, independent of Run so it can be previewed with mock data:
## top bar (level, coins, pause), the machine column (bottom-left, 3 x 88 px, mirroring the ult
## button; Rank chevrons, rarity frame, family glow; the army-arms chip above it, design §3.7),
## the ultimate button (bottom-right), the drag hint, tutorial hint banners, toasts, the machine
## card, and the pause and result panels.
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
## Machine column (§3.7): slot size, gap, distance above the bottom safe edge.
const SLOT_PX := 88.0
const SLOT_GAP := 10.0
const COLUMN_BOTTOM := 56.0

var level := 1
var ult_icon := "storm"
var hero_color := Color(0.45, 0.75, 1.0)
var insets := Vector4.ZERO

var _top: HBoxContainer
var _level_lbl: Label
var _coins_plate: KitCurrencyPlate
var _coin_icon: Control
var _coins_shown := 0
var _coins_tw: Tween
var _slots: Array[WeaponSlot] = []
var _arm_slot: WeaponSlot
var _column: VBoxContainer
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
var _hint_hold := false
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
	if _column:
		_column.reset_size()
		_column.position = Vector2(20.0 + insets.x, vp.y - _column.size.y - COLUMN_BOTTOM - insets.w)
	if _drag:
		_drag.reset_size()
		_drag.position = Vector2((vp.x - _drag.size.x) * 0.5, vp.y * 0.6)
	_toasts.size = Vector2(vp.x, 10)
	# Above the big toast line and clear of the army counter (which rides at about 0.42).
	_toasts.position = Vector2(0, vp.y * 0.215)
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
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(row)
	# v2: porcelain plates (cream, one gold hairline, soft slate shadow) - readable on any world.
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(16, 6)))
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.custom_minimum_size.y = 52
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	lrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.add_child(lrow)
	var mark := Icons.make("map", 28.0, UIKit.GOLD_TEXT)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lrow.add_child(mark)
	_level_lbl = UIKit.label(Loc.f("LEVEL", [level]), 24, UIKit.INK, true)
	_level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_lbl.size_flags_vertical = Control.SIZE_FILL
	lrow.add_child(_level_lbl)
	row.add_child(lp)
	_coins_plate = UIKit.currency_plate("coin", "0", false, 148.0)
	_coins_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_coins_plate)
	# Display only: the plate must not eat drags that start over it.
	_coins_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_icon = _coins_plate
	# Machine column, bottom-left (display only): the army-arms chip on top, then 3 slots.
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", SLOT_GAP)
	_column.alignment = BoxContainer.ALIGNMENT_END
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_arm_slot = WeaponSlot.new()
	_arm_slot.circle = true
	_arm_slot.visible = false
	_arm_slot.custom_minimum_size = Vector2(SLOT_PX, 70)
	_column.add_child(_arm_slot)
	for i in 3:
		var s := WeaponSlot.new()
		_column.add_child(s)
		_slots.append(s)
	_top.add_child(UIKit.spacer())
	_pause_btn = UIKit.edge_button("pause", 30.0)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_top.add_child(_pause_btn)


func set_coins(n: int, animate := true) -> void:
	if not animate:
		_coins_shown = n
		_coins_plate.value = Loc.num(n)
		return
	if _coins_tw:
		_coins_tw.kill()
	var from := _coins_shown
	_coins_shown = n
	_coins_tw = _coins_plate.create_tween()
	_coins_tw.tween_method(func(v: float): _coins_plate.value = Loc.num(int(round(v))), float(from), float(n), 0.25)
	if n > from:
		UIKit.punch(_coin_icon, 1.12, 0.26)


# ------------------------------------------------------------------ ult

func _build_ult() -> void:
	ult_btn = RoundButton.new(ULT_RADIUS)
	ult_btn.ult_style = true
	ult_btn.custom_minimum_size = Vector2(ULT_RADIUS * 2.0 + 60.0, ULT_RADIUS * 2.0 + 48.0)
	ult_btn.glow_color = _vivid(hero_color.lerp(Color(1.0, 0.5, 1.0), 0.3))
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
		toast(Loc.t("ULT_READY"), UITokens.TOPAZ)
		UIKit.sparkles(self, ult_btn.position + Vector2(ult_btn.size.x * 0.5, ULT_RADIUS + 4.0), UIKit.GOLD_LIGHT, 22, 220.0)
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
	var l := UIKit.label(Loc.t("DRAG_HINT"), 26, UIKit.INK, true)
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
	_hint_lbl = UIKit.label("", 26, UIKit.INK, true)
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
	# Just under the weapon slots, over the far road: lower down it covered the very gate row
	# the hint talks about.
	_hint.position = Vector2((vp.x - _hint.size.x) * 0.5, maxf(vp.y * 0.115, 150.0 + insets.y))
	_hint.pivot_offset = _hint.size * 0.5


## Greedy word wrap of `text` to lines no wider than `max_w` at font size `px`.
static func _wrap_text(text: String, max_w: float, px: int) -> String:
	var font := UIKit.font(true)
	var lines: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		var cand := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			lines.append(line)
			line = word
		else:
			line = cand
	if line != "":
		lines.append(line)
	return "\n".join(lines)


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
	# One line when it fits, otherwise wrapped by hand at a comfortable width. (An autowrapped
	# Label inside the PanelContainer reported a huge minimum height on its first layout, which
	# blew the banner up to most of the screen.)
	var max_w := minf(get_viewport_rect().size.x - 48.0 - 140.0, 440.0)
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_lbl.custom_minimum_size = Vector2.ZERO
	_hint_lbl.text = _wrap_text(Loc.t(key), max_w, 26)
	_hint_lbl.reset_size()
	var ik: String = HINT_ICONS.get(key, "")
	if ik == "":
		ik = ult_icon if key == "HINT_ULT" else "star"
	_hint_badge.set_icon(ik)
	_hint.visible = not _hint_hold
	_place_hint()
	var y := _hint.position.y
	_hint.modulate.a = 0.0
	_hint.scale = Vector2(0.96, 0.96)
	_hint.position.y = y - 18.0
	_hint_tw = _hint.create_tween()
	_hint_tw.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hint_tw.tween_property(_hint, "modulate:a", 1.0, UITokens.MENU_IN)
	_hint_tw.tween_property(_hint, "scale", Vector2.ONE, 0.28)
	_hint_tw.tween_property(_hint, "position:y", y, 0.28)
	_hint_tw.chain().tween_interval(HINT_TIME)
	_hint_tw.chain().tween_property(_hint, "modulate:a", 0.0, 0.45)
	_hint_tw.chain().tween_callback(func(): _hint.visible = false)
	Audio.note(9, -14.0)


# ------------------------------------------------------------------ toasts

## Big centred title on the scene (ult ready, ult name, armour, stairs multiplier): warm white
## into `color`, no stroke - a soft slate shadow and halo carry it on any world.
func toast(text: String, color := Color(1.0, 0.9, 0.5), size_px := 54) -> void:
	if _big_toast:
		_big_toast.queue_free()
	if _big_tw:
		_big_tw.kill()
	var vp := get_viewport_rect().size
	var hue := Color.from_hsv(color.h, minf(color.s, 0.75), maxf(color.v, 0.92))
	var l := UIKit.gradient_heading(text, size_px, UIKit.ON_SCENE, hue.lerp(UIKit.ON_SCENE, 0.35), hue)
	UIKit.soft_shadow(l, size_px, 1.3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(vp.x, size_px * 1.6)
	l.position = Vector2(0, vp.y * 0.305)
	l.pivot_offset = l.size * 0.5
	add_child(l)
	_halo_behind(l, UIKit.font_w("extrabold").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x, 1.0)
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


## A soft slate glow behind on-scene text `l` (no panel, no stroke), sized to the text width.
static func _halo_behind(l: Control, text_w: float, strength := 1.0) -> TextureRect:
	var g := TextureRect.new()
	g.texture = UIKit.glow_texture()
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.modulate = Color(UIKit.SCRIM.r, UIKit.SCRIM.g, UIKit.SCRIM.b, 0.34 * strength)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.show_behind_parent = true
	l.add_child(g)
	g.size = Vector2(text_w * 1.45 + 40.0, l.size.y * 1.5)
	g.position = (l.size - g.size) * 0.5
	return g


## Small porcelain toast with an icon, stacking under the big toast line (power-ups, arms).
## `color` tints the gem keystone at its left (the text stays ink on cream).
func pill_toast(text: String, icon := "", color := UIKit.GOLD) -> void:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(18, 6)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if icon != "":
		var b := IconBadge.new()
		b.ring = color
		b.set_icon(icon)
		b.custom_minimum_size = Vector2(48, 48)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	var l := UIKit.label(text, 28, UIKit.INK, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	row.add_child(UIKit.gap(4))
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

## Fills the column from Run.weapons ([{kind, level, id, rank, over}]).
func set_weapons(list: Array) -> void:
	for i in _slots.size():
		if i < list.size():
			var wd: Dictionary = list[i]
			var id := str(wd.get("id", wd.get("kind", "")))
			_slots[i].set_machine(id, int(wd.get("rank", wd.get("level", 1))), int(wd.get("over", 0)))
		else:
			_slots[i].set_machine("", 0, 0)


## A machine's Rank changed (crate, BONUS, RANK gate, overflow): its slot punches and flashes.
func machine_ranked(id: String, list: Array) -> void:
	set_weapons(list)
	for s in _slots:
		if s.kind == id:
			UIKit.punch(s, 1.3, 0.35)
			s.flash()


## A machine was fielded or ranked up from a crate: a centred machine card, then it flies into
## its slot in the column.
func weapon_added(kind: String, lvl: int, list: Array = []) -> void:
	var slot_i := -1
	# The Run's list is authoritative (several machines can arrive in one frame, before any
	# card has landed in its slot).
	for i in mini(list.size(), _slots.size()):
		var wd: Dictionary = list[i]
		if str(wd.get("id", wd.get("kind", ""))) == kind:
			slot_i = i
			break
	if slot_i == -1:
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
	_card.position = Vector2((vp.x - _card.size.x) * 0.5, maxf(vp.y * 0.29 - _card.size.y * 0.5, 160.0 + insets.y))
	# The card stands where the tutorial banner sits: the banner steps aside while it is up.
	_hold_hint(true)
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
	tw.chain().tween_interval(1.1)
	# Fly into the slot.
	tw.chain().tween_callback(func(): card.pivot_offset = Vector2.ZERO)
	var dest := target_slot.global_position - global_position
	tw.chain().tween_property(card, "position", dest, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "scale", Vector2(0.2, 0.2), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "modulate:a", 0.2, 0.4)
	tw.chain().tween_callback(func():
		if not list.is_empty():
			set_weapons(list)
		if list.is_empty() and target_slot.kind != kind:
			target_slot.set_machine(kind, lvl, 0)
		UIKit.punch(target_slot, 1.45, 0.4)
		target_slot.flash()
		if _card == card:
			_card = null
			_hold_hint(false)
		card.queue_free())


## Hides the tutorial banner while a machine card is up (its own tween keeps running).
func _hold_hint(on: bool) -> void:
	_hint_hold = on
	if _hint:
		_hint.visible = not on and _hint_key != ""


static func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, maxf(c.s, 0.7), 1.0)


## A machine's family accent, made vivid for the UI (glow rims, card rays).
static func _weapon_color(kind: String) -> Color:
	if kind == "":
		return Color.WHITE
	if ArsenalData.MACHINES.has(kind):
		return _vivid(WeaponModels.glow_color(kind)).lerp(Color.WHITE, 0.1)
	return WeaponModels.icon_color(kind)


## Rarity frame colour of a machine (§2.1: rarity lives in the frame, the family in the glow).
static func _rarity_color(kind: String) -> Color:
	if not ArsenalData.MACHINES.has(kind):
		return Color(1.0, 0.85, 0.45)
	return (ArsenalData.RARITIES[ArsenalData.rarity_of(kind)] as Dictionary)["ui_color"]


## Localised machine name.
static func machine_name(kind: String) -> String:
	if ArsenalData.MACHINES.has(kind):
		return Loc.t(str((ArsenalData.MACHINES[kind] as Dictionary)["name"]))
	return kind


## Gem key of a machine's rarity frame ("quartz".."opal"); topaz for non-machines.
static func _gem_of(kind: String) -> String:
	if not ArsenalData.MACHINES.has(kind):
		return "topaz"
	return UITokens.gem_of(ArsenalData.rarity_of(kind))


## The card shown when a machine joins (or ranks up from a crate); also used by previews.
## `lvl` = its Rank after the crate. v2: a gem-ground rarity card (Genshin item card) with the
## machine render, its name on the cream footer and the Rank as facet pips on the seam, under
## an engraved "НОВА МАШИНА" plate; a warm halo and slow rays behind (juicy, but no dark).
static func build_weapon_card(kind: String, lvl: int) -> Control:
	var col := _weapon_color(kind)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var W := 300.0
	var H := 392.0
	root.custom_minimum_size = Vector2(W + 80.0, H + 76.0)
	root.size = root.custom_minimum_size
	var cx := root.size.x * 0.5
	var shade := TextureRect.new()
	shade.texture = UIKit.glow_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.modulate = Color(UIKit.SCRIM.r, UIKit.SCRIM.g, UIKit.SCRIM.b, 0.42)
	shade.size = Vector2(720, 720)
	shade.position = Vector2(cx - 360, 54 + H * 0.5 - 360)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var warm := TextureRect.new()
	warm.texture = UIKit.glow_texture()
	warm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	warm.modulate = Color(1.0, 0.86, 0.55, 0.55)
	warm.size = Vector2(560, 560)
	warm.position = Vector2(cx - 280, 54 + H * 0.42 - 280)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(warm)
	var rays := UIKit.Rays.new()
	rays.color = Color(1.0, 0.9, 0.66, 0.34).lerp(Color(col.r, col.g, col.b, 0.34), 0.25)
	rays.inner = 0.14
	rays.count = 14
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.size = Vector2(860, 860)
	rays.position = Vector2(cx - 430, 54 + H * 0.42 - 430)
	root.add_child(rays)
	var gk := _gem_of(kind)
	var card := UIKit.gem_card(gk, Vector2(W, H))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = Vector2(W, H)
	card.position = Vector2(cx - W * 0.5, 54)
	card.footer_ratio = 0.27
	card.title = machine_name(kind)
	if ArsenalData.MACHINES.has(kind):
		card.footer = Loc.t(str((ArsenalData.RARITIES[ArsenalData.rarity_of(kind)] as Dictionary)["name"])) + "  ·  " + \
				Loc.t(str((ArsenalData.FAMILIES[ArsenalData.family_of(kind)] as Dictionary)["name"]))
	card.pip_count = 3
	card.pips = clampi(lvl, 1, 3)
	root.add_child(card)
	# The machine: its 3D render when cached (else the painted icon), on a family-accent glow.
	var glow := TextureRect.new()
	glow.texture = UIKit.glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.modulate = Color(col.r, col.g, col.b, 0.42)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(W * 0.95, W * 0.95)
	glow.position = Vector2(W * 0.025, H * 0.36 - W * 0.475)
	card.content.add_child(glow)
	var ic := Icons.make(kind, W * 0.62)
	ic.position = Vector2((W - W * 0.62) * 0.5, H * 0.36 - W * 0.31)
	ic.size = Vector2(W * 0.62, W * 0.62)
	card.content.add_child(ic)
	var set_thumb := func(tex: Texture2D):
		if tex == null or not is_instance_valid(card):
			return
		card.art.texture = tex
		card.art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.art.offset_left = -W * 0.22
		card.art.offset_right = W * 0.22
		card.art.offset_top = -H * 0.06
		ic.visible = false
	card.ready.connect(func():
		var tex := MachineThumbs.get_thumb(card, kind, false)
		if tex:
			set_thumb.call(tex)
		elif DisplayServer.get_name() != "headless" and card.is_inside_tree():
			MachineThumbs.service(card.get_tree()).rendered.connect(func(key: String, t: Texture2D):
				if is_instance_valid(card) and key == MachineThumbs.key_of(kind, false):
					set_thumb.call(t)))
	var head_text := Loc.t("NEW_MACHINE") if lvl <= 1 else Loc.t("RANK_UP") % ["I", "II", "III"][clampi(lvl, 1, 3) - 1]
	var plate := UIKit.title_plate(head_text.trim_suffix("!"), 280.0, false)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = Vector2(280, 44)
	plate.position = Vector2(cx - 140, 0)
	root.add_child(plate)
	UIKit.add_shine(card, 12.0, 0.45, 0.0, 0.22)
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
	# Warm translucent scrim + vignette (no blur): the road and its gate numbers recede.
	var dim := ResultFlow.scrim(get_viewport_rect().size, 0.62, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
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
	panel.add_theme_stylebox_override("panel", UIKit.lux("modal", Vector2(44, 36)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var cap := UIKit.section(Loc.f("LEVEL", [level]))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var t := UIKit.heading(Loc.t("PAUSED"), 52, UIKit.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var div := UIKit.divider(400.0)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(div)
	box.add_child(UIKit.gap(4))
	var resume := UIKit.cta_button(Loc.t("RESUME"), "", Vector2(420, 96), 34)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)
	var again := UIKit.secondary_button(Loc.t("RETRY"), "restart", Vector2(420, 76), 26)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func(): retry.emit())
	box.add_child(again)
	var to_menu := UIKit.secondary_button(Loc.t("MENU"), "home", Vector2(420, 76), 26)
	to_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	to_menu.pressed.connect(func(): menu.emit())
	box.add_child(to_menu)
	UIJuice.soft_in(panel, Vector2(0, 24))
	UIKit.stagger([resume, again, to_menu], 0.1, 0.05, 0.3)


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
	var title := ResultFlow.ribbon_title(Loc.t("VICTORY") if won else Loc.t("DEFEAT"), won, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size = Vector2(560, 92)
	title.position = Vector2(30, 6)
	ribbon_holder.add_child(title)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.lux("modal", Vector2(40, 30)))
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
		var why := UIKit.label(Loc.t(reason), 26, UIKit.INK_DIM, true)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(why)
		anim.append(why)
	if won or survivors > 0:
		var srow := HBoxContainer.new()
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		srow.add_theme_constant_override("separation", 10)
		srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		srow.add_child(Icons.make("soldier", 40.0))
		srow.add_child(UIKit.label(Loc.f("SURVIVORS", [survivors]), 28, UIKit.INK, true))
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
	var tl := UIKit.caps(Loc.t("COINS_TOTAL"), 22)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tl)
	var tcoin := Icons.make("coin", 58.0)
	tcoin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tcoin)
	var tnum := UIKit.number("0", 72)
	tnum.custom_minimum_size.x = 150
	trow.add_child(tnum)
	box.add_child(trow)
	box.add_child(UIKit.gap(6))
	# Buttons.
	var primary := UIKit.cta_button(Loc.t("NEXT") if won else Loc.t("RETRY"), "", Vector2(440, 96), 38)
	primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if won:
		primary.pressed.connect(func(): next.emit())
	else:
		primary.pressed.connect(func(): retry.emit())
	box.add_child(primary)
	var to_menu := UIKit.secondary_button(Loc.t("MENU"), "home", Vector2(440, 72), 26)
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
	glow.modulate = Color(1.0, 0.8, 0.4, 0.4)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(360, 200)
	glow.position = Vector2(60, -26)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var cap := UIKit.section(Loc.t("MULTIPLIER"))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(480, 26)
	cap.position = Vector2(0, 0)
	holder.add_child(cap)
	var big := UIKit.gradient_heading(Loc.t("STAIRS_MULT") % _fmt_mult(mult), 104, UIKit.CTA, UIKit.CTA_LO, UIKit.CTA_RIM)
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


func _coin_row(text: String, value: String, value_color := UIKit.INK, coin := true) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(460, 40)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, 24, UIKit.INK_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := UIKit.label(value, 28, value_color, true)
	row.add_child(v)
	if coin:
		row.add_child(Icons.make("coin", 32.0))
	else:
		row.add_child(UIKit.gap(32))
	return row


# ------------------------------------------------------------------ drawn widgets

## Machine slot of the column (§3.7), v2: a small gem-ground card (the rarity's gradient, its
## faint light pool, a gold hairline and an inner rim in the gem's light tone, the gem-cut mark
## top-left) with the machine render (or its painted icon), the Rank as facet pips on a cream
## seam bed and the overflow "+N%" on a cream chip. Empty = a faint porcelain socket. The
## circle variant is the army-arms chip (cream disc, gold ring).
class WeaponSlot extends Control:
	var kind := ""
	var lvl := 0
	var over := 0
	var color := Color.WHITE
	var gem := "quartz"
	var circle := false
	var _flash := 0.0
	var _tex: Texture2D
	var _wired := false

	func _init() -> void:
		custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Etap-1 setter (the arms chip): icon kind, level 0 = no pips, accent colour.
	func set_weapon(k: String, level: int, c: Color) -> void:
		kind = k
		lvl = level
		color = c
		_tex = null
		queue_redraw()

	func set_machine(id: String, rank: int, p_over: int) -> void:
		var changed := id != kind
		kind = id
		lvl = rank
		over = p_over
		color = HudView._weapon_color(id)
		gem = HudView._gem_of(id)
		if changed:
			_tex = null
			_fetch_thumb()
		queue_redraw()

	func _ready() -> void:
		_fetch_thumb()

	func _fetch_thumb() -> void:
		if circle or kind == "" or not is_inside_tree() or not ArsenalData.MACHINES.has(kind):
			return
		_tex = MachineThumbs.get_thumb(self, kind, false)
		if _tex == null and not _wired and DisplayServer.get_name() != "headless":
			_wired = true
			MachineThumbs.service(get_tree()).rendered.connect(func(key: String, tex: Texture2D):
				if is_instance_valid(self) and key == MachineThumbs.key_of(kind, false):
					_tex = tex
					queue_redraw())

	func flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 2.0)
			queue_redraw()

	func _draw() -> void:
		if circle:
			_draw_arms()
			return
		var side := minf(size.x, size.y)
		var r := Rect2(Vector2(2, 2), Vector2(side - 4, side - 4))
		var ch := 9.0
		var pts := GemDraw.chamfer_rect(r, ch)
		var sc := UITokens.SCRIM
		if kind == "":
			draw_colored_polygon(pts, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.26))
			GemDraw.outline(self, pts, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.55), 1.5)
			GemDraw.draw_keystone(self, r.get_center(), 14.0, 0.5)
			return
		# Family glow (the machine's accent) round the card, brighter on a flash.
		draw_texture_rect(UIKit.glow_texture(), r.grow(16), false, Color(color.r, color.g, color.b, 0.2 + _flash * 0.6))
		for i in 4:
			var o := Vector2(0, 2.0 + i * 1.5)
			var sp := PackedVector2Array()
			for p in pts:
				sp.append(p + o)
			draw_colored_polygon(sp, Color(sc.r, sc.g, sc.b, 0.08))
		var g: Dictionary = UITokens.gem(gem)
		var top: Color = g["top"]
		var bot: Color = g["bot"]
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bot, (p.y - r.position.y) / maxf(r.size.y, 1.0)))
		draw_polygon(pts, cols)
		var lc: Color = g["light"]
		draw_texture_rect(UIKit.glow_texture(), Rect2(r.get_center() - Vector2(r.size.x, r.size.x) * 0.62 - Vector2(0, 6), Vector2(r.size.x, r.size.x) * 1.24), false, Color(lc.r, lc.g, lc.b, 0.3))
		var ir := Rect2(r.position + Vector2(6, 4), r.size - Vector2(12, 18))
		if _tex:
			var s := ir.size.x * 1.6
			draw_texture_rect(_tex, Rect2(ir.get_center() - Vector2(s, s) * 0.5 + Vector2(0, 2), Vector2(s, s)), false)
		else:
			Icons.draw_icon(self, kind, Rect2(ir.position + Vector2(4, 6), ir.size - Vector2(8, 8)), Color.WHITE)
		if _flash > 0.0:
			draw_colored_polygon(pts, Color(1, 0.98, 0.9, _flash * 0.55))
		var rim: Color = g["rim"]
		GemDraw.outline(self, GemDraw.chamfer_rect(r.grow(-3.0), ch - 1.5), Color(rim.r, rim.g, rim.b, 0.7), 1.0)
		GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.5)
		GemDraw.draw_mark(self, gem, r.position + Vector2(ch + 3.0, ch + 3.0), 13.0)
		if lvl > 0:
			# Rank I-III: facet pips on a cream bed across the bottom edge.
			var pw := 52.0
			var bed := Rect2(Vector2(r.get_center().x - pw * 0.5, r.end.y - 10.0), Vector2(pw, 18.0))
			var bp := GemDraw.chamfer_rect(bed, 5.0)
			draw_colored_polygon(bp, UITokens.PAPER_0)
			GemDraw.outline(self, bp, UITokens.HAIRLINE, 1.2)
			for i in 3:
				GemDraw.draw_pip(self, Vector2(bed.get_center().x + (i - 1) * 14.0, bed.get_center().y), 13.0, i < lvl, UITokens.TOPAZ)
		if over > 0:
			var f := UIKit.font_w("extrabold")
			var txt := "+%d%%" % int(round(_over_pct(over) * 100.0))
			var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var cr := Rect2(Vector2(r.end.x - w - 10.0, r.position.y - 8.0), Vector2(w + 12.0, 22.0))
			var cp := GemDraw.chamfer_rect(cr, 5.0)
			draw_colored_polygon(cp, UITokens.PAPER_0)
			GemDraw.outline(self, cp, UITokens.HAIRLINE, 1.2)
			draw_string(f, Vector2(cr.position.x + 6.0, cr.end.y - 5.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITokens.GOLD_TEXT)

	func _draw_arms() -> void:
		var c := Vector2(size.x * 0.5, 34.0)
		var rr := 31.0
		var sc := UITokens.SCRIM
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(rr, rr) * 1.6, Vector2(rr, rr) * 3.2), false, Color(color.r, color.g, color.b, 0.25 + _flash * 0.5))
		for i in 3:
			draw_circle(c + Vector2(0, 2.0 + i * 1.2), rr + i, Color(sc.r, sc.g, sc.b, 0.07), true, -1.0, true)
		draw_circle(c, rr, UITokens.PAPER_1, true, -1.0, true)
		draw_circle(c + Vector2(0, -rr * 0.1), rr * 0.84, UITokens.PAPER_0, true, -1.0, true)
		draw_arc(c, rr - 0.75, 0, TAU, 48, UITokens.HAIRLINE, 1.5, true)
		draw_arc(c, rr - 4.0, 0, TAU, 48, Color(color.r, color.g, color.b, 0.55), 1.5, true)
		if kind != "":
			var isz := rr * 1.3
			Icons.draw_icon(self, kind, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)))
		if _flash > 0.0:
			draw_circle(c, rr, Color(1, 0.98, 0.9, _flash * 0.5), true, -1.0, true)

	static func _over_pct(n: int) -> float:
		var t := 0.0
		for k in n:
			t += ArsenalData.overflow_bonus(k + 1)
		return t


## Rank I-III as facet pips (topaz lit for the Ranks reached, engraved for the rest).
class RankPips extends Control:
	var rank := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.y * 0.8, 28.0)
		for i in 3:
			GemDraw.draw_pip(self, size * 0.5 + Vector2((i - 1) * s * 0.95, 0), s, i < rank, UITokens.TOPAZ)

	## Old call sites: chevrons are pips now (same footprint).
	static func draw_chevrons(ci: CanvasItem, c: Vector2, n: int, s: float) -> void:
		for i in 3:
			GemDraw.draw_pip(ci, c + Vector2((i - 1) * s * 0.95, 0), s, i < n, UITokens.TOPAZ)


## v2 icon socket (hint banner, power toasts, legacy weapon card): a cream disc with a thin
## gold ring and a second ring in the accent colour; the painted item icon on it. `big` adds a
## breathing warm glow.
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
		var sc := UITokens.SCRIM
		if big:
			var k := 0.75 + 0.25 * sin(_t * 3.0)
			draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.5, Vector2(r, r) * 3.0), false, Color(ring.r, ring.g, ring.b, 0.45 * k))
		for i in 3:
			draw_circle(c + Vector2(0, 1.5 + i), r - 1.0 + i, Color(sc.r, sc.g, sc.b, 0.06), true, -1.0, true)
		draw_circle(c, r, UITokens.PAPER_1, true, -1.0, true)
		draw_circle(c + Vector2(0, -r * 0.1), r * 0.84, UITokens.PAPER_0, true, -1.0, true)
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), false, Color(ring.r, ring.g, ring.b, 0.22))
		draw_arc(c, r - 0.75, 0, TAU, 48, UITokens.HAIRLINE, 1.5, true)
		draw_arc(c, r - 4.0, 0, TAU, 48, Color(ring.r, ring.g, ring.b, 0.6), 1.2, true)
		if icon != "":
			var isz := (r - 4.0) * 2.0 * icon_scale
			Icons.draw_icon(self, icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)))


## Animated hand sliding left and right over a dotted track (drag tutorial). Warm white
## dots and hairline chevrons with a soft slate shadow (no strokes) - reads on any world.
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
		var sc := UITokens.SCRIM
		var ws := UITokens.ON_SCENE
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(cx - span * 1.3, cy - 40), Vector2(span * 2.6, 80)), false, Color(sc.r, sc.g, sc.b, 0.22))
		for i in 21:
			var f := float(i) / 20.0 * 2.0 - 1.0
			var a := 0.85 * (1.0 - absf(f) * 0.6)
			var p := Vector2(cx + f * span, cy)
			if i % 5 == 0:
				GemDraw.draw_pip(self, p + Vector2(0, 1.5), 13.0, true, Color(sc.r, sc.g, sc.b, 0.25 * a))
				GemDraw.draw_pip(self, p, 12.0, true, Color(1.0, 0.86, 0.5, a))
			else:
				draw_circle(p + Vector2(0, 1.5), 3.4, Color(sc.r, sc.g, sc.b, 0.3 * a))
				draw_circle(p, 2.8, Color(ws.r, ws.g, ws.b, a))
		for sgn: float in [-1.0, 1.0]:
			var tip := Vector2(cx + sgn * (span + 34.0), cy)
			var arm := PackedVector2Array([tip + Vector2(-sgn * 18.0, -16.0), tip, tip + Vector2(-sgn * 18.0, 16.0)])
			var sh := PackedVector2Array()
			for q in arm:
				sh.append(q + Vector2(0, 2.0))
			draw_polyline(sh, Color(sc.r, sc.g, sc.b, 0.35), 5.0, true)
			draw_polyline(arm, Color(1.0, 0.9, 0.62), 3.5, true)
		var s := sin(_t * 2.4)
		var x := cx + s * span
		var hs := 112.0
		for k in [3, 2, 1]:
			var sk := sin(_t * 2.4 - k * 0.16)
			var xk := cx + sk * span
			Icons.draw_icon(self, "hand", Rect2(Vector2(xk - hs * 0.485, cy - hs * 0.04), Vector2(hs, hs)), Color(1, 1, 1, 0.1 / k))
		var ph := fmod(_t * 1.6, 1.0)
		draw_arc(Vector2(x, cy), 10.0 + ph * 26.0, 0, TAU, 32, Color(1.0, 0.92, 0.7, 0.7 * (1.0 - ph)), 2.5, true)
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(x, cy) - Vector2(26, 26), Vector2(52, 52)), false, Color(1.0, 0.86, 0.5, 0.75))
		Icons.draw_icon(self, "hand", Rect2(Vector2(x - hs * 0.485 + 3.0, cy - hs * 0.04 + 5.0), Vector2(hs, hs)), Color(sc.r, sc.g, sc.b, 0.3))
		Icons.draw_icon(self, "hand", Rect2(Vector2(x - hs * 0.485, cy - hs * 0.04), Vector2(hs, hs)), Color.WHITE)
