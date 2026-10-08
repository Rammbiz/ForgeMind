class_name HubTopBar
extends Control
## Hub top bar (UI v2, y 0-96 + safe top): the hero portrait in a fine gold ring (world
## progress as a thin amber arc, the campaign level on a small slate disc; a tap opens the
## profile card with Settings and the language, Genshin-style: no gear beside it), and slim chamfered cream currency plates on the right: Coins (with "+",
## opens the Shop) and Gems always; Wild Blueprints on the Arsenal tab; Crowns only while
## crowns fly in (RewardFly) - the Home stays as calm as the concept.
## Plates roll their numbers and are RewardFly targets (fly_arrived()).

signal settings_pressed       ## kept for callers; the gear moved into the profile card
signal avatar_pressed
signal shop_pressed

const PLATE_H := 52.0
const PLATE_Y := 22.0

var _chips := {}            ## cur -> HubChip
var _avatar: Avatar
var _tab := "play"
var _flying := {}           ## cur -> true while a reward flies to a normally hidden plate


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_avatar = Avatar.new()
	_avatar.size = Vector2(88, 88)
	_avatar.position = Vector2(14, 4)
	_avatar.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			avatar_pressed.emit())
	UIJuice.press(_avatar)
	add_child(_avatar)
	for cur: String in ["crowns", "wild", "coins", "gems"]:
		var ch := HubChip.new(cur)
		ch.plus = cur == "coins"
		if cur == "coins":
			ch.plus_pressed.connect(func(): shop_pressed.emit())
		add_child(ch)
		_chips[cur] = ch
	resized.connect(_layout)
	refresh(false)
	_render_avatar()


## Rendered portraits survive hub rebuilds (no empty ring on the first frames); until the
## first render lands the ring shows the hero's painted icon.
static var _portrait_cache := {}


func _render_avatar() -> void:
	var hid := Meta.hero()
	_avatar.hero = hid
	_avatar.tex = _portrait_cache.get(hid)
	_avatar.queue_redraw()
	if _avatar.tex:
		return
	var tex := await UIKit.render_portrait(self, hid, 160)
	if tex:
		_portrait_cache[hid] = tex
	if tex and is_instance_valid(_avatar) and _avatar.hero == hid:
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


## Which plates show (Arsenal adds Wild Blueprints; Crowns only while crowns fly in).
func set_tab(tab: String) -> void:
	_tab = tab
	(_chips["wild"] as Control).visible = tab == "arsenal"
	(_chips["crowns"] as Control).visible = _flying.has("crowns")
	_layout()


## Right-aligned plates: [third] [coins +] [gems] with 12 px gaps, 14 px from the edge.
func _layout() -> void:
	var x := size.x - 14.0
	for cur: String in ["gems", "coins", "wild", "crowns"]:
		var p: HubChip = _chips[cur]
		if not p.visible:
			continue
		var w := p.want_width()
		x -= w
		p.position = Vector2(x, PLATE_Y)
		p.size = Vector2(w, PLATE_H)
		x -= 12.0


func hero_changed() -> void:
	_render_avatar()


## The plate control of `cur` (coins | gems | crowns | wild[_R]) for RewardFly, or null.
func chip(cur: String) -> Control:
	if cur.begins_with("wild"):
		cur = "wild"
	return _chips.get(cur)


## The plate will receive a RewardFly: hold its number until the first icon lands (a hidden
## plate - Crowns on Home - fades in for the flight and out again after it).
func expect_fly(cur: String) -> void:
	var c := chip(cur) as HubChip
	if c == null:
		return
	if not c.visible:
		_flying[c.cur] = true
		c.visible = true
		_layout()
		UIJuice.soft_in(c, Vector2(0, -8))
		c.landed.connect(_after_fly.bind(c), CONNECT_ONE_SHOT)
	c.expect_fly()


func _after_fly(c: HubChip) -> void:
	get_tree().create_timer(2.2).timeout.connect(func():
		if not is_instance_valid(c) or not _flying.has(c.cur):
			return
		_flying.erase(c.cur)
		UIJuice.soft_out(c, Vector2(0, -8), func():
			if is_instance_valid(c):
				c.modulate.a = 1.0
				set_tab(_tab)))


func _amount(cur: String) -> int:
	if cur == "wild":
		var n := 0
		for r in ArsenalData.RARITY_ORDER:
			n += Meta.wild(r)
		return n
	return Meta.currency(cur)


## A currency plate (KitCurrencyPlate) that rolls its number and receives RewardFly icons.
## Also used on its own by the result / loss screens and the altar:
##   var ch := HubTopBar.HubChip.new("coins"); parent.add_child(ch); ch.set_amount(n, false)
##   ch.size = ch.custom_minimum_size
class HubChip extends KitCurrencyPlate:
	signal landed
	var cur := "coins"
	var _amount := -1
	var _shown := 0.0
	var _hold := false
	var _roll: Tween

	func _init(p_cur := "coins") -> void:
		cur = p_cur
		icon = {"coins": "coin", "gems": "gem", "crowns": "crown", "wild": "blueprint"}.get(cur, cur)
		custom_minimum_size = Vector2(150, PLATE_H)

	func want_width() -> float:
		var digits := Loc.num(maxi(_amount, 0)).length()
		var base := 92.0 if plus else 64.0
		return maxf(148.0 if plus else 132.0, base + PLATE_H * 0.6 + digits * 14.5)

	func set_amount(n: int, animate := true) -> void:
		var first := _amount < 0
		_amount = n
		custom_minimum_size = Vector2(want_width(), PLATE_H)
		if _hold:
			return
		_roll_to(n, 0.0 if (first or not animate) else 0.5)

	func _roll_to(n: int, dur: float) -> void:
		if _roll and _roll.is_valid():
			_roll.kill()
		if dur <= 0.0 or UITokens.reduce_motion():
			_shown = n
			value = Loc.num(n)
			return
		_roll = create_tween()
		_roll.tween_method(func(v: float):
			_shown = v
			value = Loc.num(int(round(v))), _shown, float(n), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func expect_fly() -> void:
		_hold = true

	## RewardFly hook: roll from the first arrival to the last (+150 ms), punch at both ends.
	func fly_arrived(_c: String, index: int, count: int) -> void:
		if index == 0:
			_hold = false
			_roll_to(_amount, 0.03 * count + 0.5)
			UIJuice.chip_hit(self)
		if index >= count - 1:
			_hold = false
			UIJuice.chip_hit(self)
			landed.emit()


## The hero portrait: a cream ring with a fine gold hairline inside and out, the world
## progress as a thin amber arc on the ring, and the campaign level on a slate disc.
class Avatar extends Control:
	var tex: Texture2D
	var hero := ""
	var level := 1
	var progress := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5 - 2.0)
		var r := 38.0
		var sc := UITokens.SCRIM
		for i in 4:
			draw_circle(c + Vector2(0, 2.0 + i), r + 1.5 + i * 0.8, Color(sc.r, sc.g, sc.b, 0.05))
		draw_circle(c, r, UITokens.PAPER_0)
		draw_arc(c, r - 0.75, 0, TAU, 64, UITokens.HAIRLINE, 1.5, true)
		var face := r - 6.0
		# Portrait ground: a soft sky gradient (light top) behind the render.
		for i in 8:
			var k := float(i) / 7.0
			draw_circle(c + Vector2(0, -face * 0.25 * k), face * (1.0 - k * 0.45), UITokens.SKY_TOP.lerp(UITokens.SKY_MID, k))
		if tex == null and hero != "":
			# Until the portrait render lands: the hero's gem, cut, on the sky ground.
			GemDraw.draw_mark(self, str(HubStage.HERO_GEM.get(hero, "sapphire")), c, face * 0.8)
		if tex:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 48:
				var a := TAU * i / 48.0
				var d := Vector2(cos(a), sin(a))
				pts.append(c + d * face)
				uvs.append(Vector2(0.5, 0.46) + d * 0.5 / 1.08)
			draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
		draw_arc(c, face + 0.5, 0, TAU, 64, UITokens.HAIRLINE, 1.2, true)
		# World progress on the ring.
		var pr := r - 3.0
		draw_arc(c, pr, 0, TAU, 64, Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.9), 2.5, true)
		if progress > 0.0:
			draw_arc(c, pr, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, UITokens.CTA, 2.5, true)
		# Level disc: a gold-rimmed cream disc with an ink number (no dark navy).
		var f := UIKit.font_w("extrabold")
		var txt := str(level)
		var fs := 18 if txt.length() < 3 else 15
		var lc := c + Vector2(r * 0.72, r * 0.72)
		var lr := 16.0
		draw_circle(lc + Vector2(0, 1.5), lr + 1.0, Color(sc.r, sc.g, sc.b, 0.22))
		draw_circle(lc, lr, UITokens.PAPER_0)
		draw_arc(lc, lr - 1.0, 0, TAU, 32, UITokens.HAIRLINE, 2.0, true)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(lc.x - tw * 0.5, lc.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
