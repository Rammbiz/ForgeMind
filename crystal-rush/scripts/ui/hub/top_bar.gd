class_name HubTopBar
extends Control
## Hub top bar (arsenal_design.md §7.1, 0-7 %): the hero avatar with the world-progress ring
## and the campaign level, the settings gear, and at most three currency chips on the right:
## Coins, Gems and one chip that depends on the tab (Play = Crowns, Arsenal = Wild Blueprints).
## Chips roll their numbers (Odometer) and are RewardFly targets (fly_arrived()).

signal settings_pressed
signal avatar_pressed

var _chips := {}            ## cur -> HubChip
var _row: HBoxContainer
var _avatar: Avatar
var _tab := "play"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row.add_theme_constant_override("separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_avatar = Avatar.new()
	_avatar.custom_minimum_size = Vector2(84, 84)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_avatar.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			avatar_pressed.emit())
	UIJuice.press(_avatar)
	_row.add_child(_avatar)
	var gear := RoundButton.new(27.0)
	gear.icon_kind = "gear"
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(func():
		UIJuice.haptic("CLICK", 0.5)
		settings_pressed.emit())
	_row.add_child(gear)
	_row.add_child(UIKit.spacer())
	for cur: String in ["crowns", "wild", "gems", "coins"]:
		var ch := HubChip.new(cur)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(ch)
		_chips[cur] = ch
	refresh(false)
	_render_avatar()


func _render_avatar() -> void:
	var tex := await UIKit.render_portrait(self, Meta.hero(), 160)
	if tex and is_instance_valid(_avatar):
		_avatar.tex = tex
		_avatar.queue_redraw()


## Re-reads the wallet and the level (rolls the numbers when `animate`).
func refresh(animate := true) -> void:
	for cur: String in _chips:
		(_chips[cur] as HubChip).set_amount(_amount(cur), animate)
	var lv := Meta.level()
	_avatar.level = lv
	_avatar.progress = float(ArsenalData.level_in_world(lv) - 1) / float(ArsenalData.LEVELS_PER_WORLD)
	_avatar.queue_redraw()
	set_tab(_tab)


## Which tab chip shows (Play: Crowns, Arsenal: Wild Blueprints, others: none).
func set_tab(tab: String) -> void:
	_tab = tab
	(_chips["crowns"] as Control).visible = tab == "play"
	(_chips["wild"] as Control).visible = tab == "arsenal"


func hero_changed() -> void:
	_render_avatar()


## The chip control of `cur` (coins | gems | crowns | wild[_R]) for RewardFly, or null.
func chip(cur: String) -> Control:
	if cur.begins_with("wild"):
		cur = "wild"
	return _chips.get(cur)


## The chip will receive a RewardFly: hold its number until the first icon lands.
func expect_fly(cur: String) -> void:
	var c := chip(cur) as HubChip
	if c:
		c.expect_fly()


func _amount(cur: String) -> int:
	if cur == "wild":
		var n := 0
		for r in ArsenalData.RARITY_ORDER:
			n += Meta.wild(r)
		return n
	return Meta.currency(cur)


## A currency chip: dark glass pill with a gold rim, the icon overlapping its left end and the
## rolling amount.
class HubChip extends Control:
	var cur := "coins"
	var _odo: Odometer
	var _amount := 0
	var _hold := false

	func _init(p_cur := "coins") -> void:
		cur = p_cur
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(150, 58)
		_odo = Odometer.new()
		_odo.font_size = 30
		_odo.color = UIKit.GOLD_LIGHT if cur == "coins" else UIKit.TEXT
		_odo.align = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_odo)
		resized.connect(_layout)

	func _layout() -> void:
		_odo.position = Vector2(44, 0)
		_odo.size = Vector2(size.x - 44 - 18, size.y)

	func set_amount(n: int, animate := true) -> void:
		_amount = n
		var digits := Loc.num(n).length()
		custom_minimum_size.x = maxf(132.0, 70.0 + digits * 19.0)
		if _hold:
			return
		_odo.set_value(n, animate, 0.5)

	func expect_fly() -> void:
		_hold = true

	## RewardFly hook: roll from the first arrival to the last (+150 ms), punch at both ends.
	func fly_arrived(_c: String, index: int, count: int) -> void:
		if index == 0:
			_hold = false
			_odo.set_value(_amount, true, 0.03 * count + 0.5)
			UIJuice.chip_hit(self)
		elif index >= count - 1:
			_hold = false
			UIJuice.chip_hit(self)

	func _draw() -> void:
		var r := Rect2(Vector2(20, 6), Vector2(size.x - 20, size.y - 12))
		draw_style_box(UIKit.lux("chip"), r)
		var ic := {"coins": "coin", "gems": "gem", "crowns": "crown", "wild": "wild"}.get(cur, cur) as String
		var s := size.y + 4.0
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(-14, -16), Vector2(s + 28, s + 28)), false, Color(1, 0.8, 0.4, 0.25))
		Icons.draw_icon(self, ic, Rect2(Vector2(-2, -2), Vector2(s, s)))


## The hero avatar: portrait in a gold medallion, a ring showing progress through the world,
## and the campaign level on a ribbon below.
class Avatar extends Control:
	var tex: Texture2D
	var level := 1
	var progress := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.46)
		var r := minf(size.x, size.y) * 0.44
		draw_circle(c + Vector2(0, 4), r + 3.0, Color(0, 0, 0.03, 0.45))
		draw_circle(c, r + 2.0, Color(0.36, 0.2, 0.05))
		draw_circle(c + Vector2(0, -1), r, Color(1.0, 0.88, 0.5))
		draw_circle(c + Vector2(0, 1.5), r - 3.0, Color(0.72, 0.44, 0.12))
		var face := r - 6.0
		draw_circle(c, face, Color(0.12, 0.16, 0.34))
		draw_circle(c + Vector2(0, -face * 0.2), face * 0.8, Color(0.2, 0.28, 0.55))
		if tex:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				var d := Vector2(cos(a), sin(a))
				pts.append(c + d * face)
				uvs.append(Vector2(0.5, 0.47) + d * 0.5 / 1.05)
			draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
		draw_arc(c, face - 0.5, PI * 1.1, PI * 1.9, 20, Color(1, 1, 1, 0.3), 2.0, true)
		# World progress ring.
		draw_arc(c, r + 5.5, -PI / 2.0, -PI / 2.0 + TAU, 48, Color(0.02, 0.03, 0.08, 0.85), 5.0, true)
		if progress > 0.0:
			draw_arc(c, r + 5.5, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color(0.45, 0.9, 1.0), 4.0, true)
		# Level ribbon.
		var f := UIKit.font(true)
		var txt := str(level)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var br := Rect2(Vector2(c.x - tw * 0.5 - 12, size.y - 26), Vector2(tw + 24, 28))
		draw_style_box(UIKit.box(Color(0.98, 0.62, 0.18), Color(0.45, 0.2, 0.03), 12, 2, 0, Vector2.ZERO), br)
		draw_rect(Rect2(br.position + Vector2(4, 3), Vector2(br.size.x - 8, 7)), Color(1, 1, 0.85, 0.35))
		draw_string_outline(f, Vector2(c.x - tw * 0.5, br.position.y + 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0.35, 0.12, 0.0))
		draw_string(f, Vector2(c.x - tw * 0.5, br.position.y + 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.98, 0.9))
