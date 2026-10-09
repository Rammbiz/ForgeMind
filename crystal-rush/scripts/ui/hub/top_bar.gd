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
## progress as a 2 dpx amber arc on a 1 dpx gold track, the level on a chamfered glass plate (v3.1).
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
		var lw := UIKit.px(1.0)
		# v3: one soft halo (no stacked discs), a translucent porcelain ring, 1 device px lines.
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.3 + Vector2(0, 3), Vector2(r, r) * 2.6), false, Color(sc.r, sc.g, sc.b, 0.14))
		draw_circle(c, r, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.78))
		draw_arc(c, r - lw * 0.5, 0, TAU, 72, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.85), lw, true)
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
		draw_arc(c, face + lw * 0.5, 0, TAU, 72, UITokens.HAIRLINE, lw, true)
		# v3.1 (§7.9): world progress = a 2 dpx key-line arc (deep gold) on a 1 dpx gold track.
		var pr := r - 3.0
		draw_arc(c, pr, 0, TAU, 72, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.6), UIKit.line_px(1.0), true)
		if progress > 0.0:
			draw_arc(c, pr, -PI / 2.0, -PI / 2.0 + TAU * progress, 72, UITokens.key_line(), UIKit.line_px(2.0), true)
		# The level on a chamfered glass plate with a 1 dpx deep-gold edge (Bold ink).
		var f := UIKit.font_w("bold")
		var txt := str(level)
		var fs := 20 if txt.length() < 3 else 18
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lc := c + Vector2(r * 0.7, r * 0.74)
		var pw := maxf(30.0, tw + 14.0)
		var plate := Rect2(Vector2(roundf(lc.x - pw * 0.5), roundf(lc.y - 13.0)), Vector2(roundf(pw), 26.0))
		draw_texture_rect(UIKit.glow_texture(), plate.grow(6.0), false, Color(sc.r, sc.g, sc.b, 0.12))
		var pp := GemDraw.chamfer_rect(plate, 5.0)
		draw_colored_polygon(pp, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.94))
		GemDraw.outline(self, pp, UITokens.LINE_GOLD_DEEP, UIKit.line_px(1.0))
		draw_string(f, Vector2(roundf(lc.x - tw * 0.5), roundf(lc.y + fs * 0.36)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
