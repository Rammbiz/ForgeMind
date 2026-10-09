class_name HeroesTeamStage
extends Control
## The bright formation stage of the Team screen (heroes_design.md §4.2 slots, §9.3; AFK Journey
## formation x Genshin light): a marble dais in soft perspective tinted to the team hero's gem
## (a pale marble top warming into the gem's light, a gem-light rim, an inner gold ring, faint
## veins), soft contact shadows under every card, engraved slot seats at the run's slot offsets
## (ChampionKinds.slot_offset: front / left / right / rear around the hero at the centre), gold
## formation hairlines from the hero to each occupied seat, and a faint aura ring per champion.
## The member cards are children placed by the Team screen with floor_point() / depth().
## Never dark; idle: the seats' keystones glint slowly (static with Reduce Motion).
##   var st := HeroesTeamStage.new(); st.seats = HeroesTeamLogic.slot_layout(team)
##   card.position = st.floor_point(&"front") - Vector2(card.size.x * 0.5, card.size.y)

## [{index, id, slot, state}] from HeroesTeamLogic.slot_layout().
var seats: Array[Dictionary] = []:
	set(v):
		seats = v
		queue_redraw()
## Seat being pointed at (roster sheet open): a soft amber glow under it ("" = none).
var focus_slot: StringName = &"":
	set(v):
		focus_slot = v
		queue_redraw()
## The team hero's gem (UITokens.gem key or letter): tints the dais.
var gem := "C":
	set(v):
		gem = v
		queue_redraw()
var _t := 0.0

const KX := 0.4        ## floor x unit = KX x width (wide enough that side cards clear the hero)
## Extra stage-only distance of the front seat (px, before grow()), so the front champion's role
## chip never touches the hero card. The formation semantics (slot_offset) are unchanged.
const FRONT_EXTRA := 28.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(not UITokens.reduce_motion())
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 10.0) != int((_t - delta) * 10.0):
		queue_redraw()


## Card scales on the stage (the member cards are HeroCard S / M); tall phones grow them (the
## art band grows, the chrome does not).
const CHAMP_SCALE := 0.8
const HERO_SCALE := 0.88
const CHIP_H := 34.0
const TOP_PAD := 14.0


## Growth factor of the cards on tall stages (1.0 at the 720 x 1280 stage, up to 1.22).
func grow() -> float:
	return clampf(size.y / 780.0, 1.0, 1.22)


func _champ_h() -> float:
	return 186.0 * CHAMP_SCALE * grow()


func _hero_h() -> float:
	return 208.0 * HERO_SCALE * grow()


## Floor-unit scale (x, y) for the current size: x from the width; y spreads the front and rear
## seats as far as the stage height allows, ideally far enough that the front champion's role
## chip clears the hero card.
func units() -> Vector2:
	var ux := size.x * KX
	var room := (size.y - TOP_PAD - _champ_h() - CHIP_H - CHIP_H - 10.0 - FRONT_EXTRA) / 1.32
	var ideal := (_hero_h() + CHIP_H + 6.0) / 0.63
	return Vector2(ux, clampf(minf(room, ideal * 1.08), 150.0, 460.0))


## The hero's floor point (the dais centre).
func centre() -> Vector2:
	var u := units()
	var used := TOP_PAD + _champ_h() + CHIP_H + 1.32 * u.y + CHIP_H + FRONT_EXTRA
	var y := TOP_PAD + _champ_h() + FRONT_EXTRA + 0.63 * u.y + maxf(0.0, (size.y - used) * 0.5)
	return Vector2(size.x * 0.5, y)


## Screen point of `slot` on the floor ("" / "hero" = the centre).
func floor_point(slot: StringName) -> Vector2:
	if slot == &"" or slot == &"hero":
		return centre()
	var o := HeroesTeamLogic.offset(slot)
	var u := units()
	var extra := FRONT_EXTRA if slot == ChampionKinds.FRONT else 0.0
	return centre() + Vector2(o.x * u.x, o.y * u.y - extra)


## Card scale of a member standing on `slot`.
func depth(slot: StringName) -> float:
	if slot == &"" or slot == &"hero":
		return HERO_SCALE * grow()
	return CHAMP_SCALE * grow()


func _ellipse(c: Vector2, rx: float, ry: float, n := 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	var u := units()
	var c := centre()
	var hl := UITokens.HAIRLINE
	var sc := UITokens.SCRIM
	var g: Dictionary = UITokens.gem(gem)
	var light: Color = g["light"]
	var rim: Color = g["rim"]
	var deep: Color = g["deep"]
	# Dais: gem-light pool, soft shadow, a marble drum, the top face warming from ivory into the
	# gem's light, a gem-light rim and an inner gold ring.
	var rx := size.x * 0.47
	# Just deep enough to hold the front and rear seats, so the drum's front edge shows and the
	# dais reads as a raised pedestal, not a plate.
	var ry := minf(maxf(u.y * 0.8, rx * 0.42), rx * 0.86)
	var dh := 24.0
	var glow := UIKit.glow_texture()
	draw_texture_rect(glow, Rect2(c - Vector2(rx * 1.5, ry * 1.6), Vector2(rx * 3.0, ry * 3.2)), false, Color(light.r, light.g, light.b, 0.5))
	draw_colored_polygon(_ellipse(c + Vector2(0, dh + 14.0), rx * 1.04, ry * 1.04), Color(sc.r, sc.g, sc.b, 0.13))
	# The drum: the top ellipse swept down by dh, lit from the left, a gem-light band at its foot.
	var drum := PackedVector2Array()
	var dcols := PackedColorArray()
	var n := 64
	for i in n + 1:
		var a := PI * i / n
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		drum.append(p)
	for i in range(n, -1, -1):
		var a := PI * i / n
		drum.append(c + Vector2(cos(a) * rx, sin(a) * ry + dh))
	for p in drum:
		var k := clampf((p.x - (c.x - rx)) / (2.0 * rx), 0.0, 1.0)
		dcols.append(UITokens.PAPER_1.lerp(deep, 0.12 + 0.3 * k).lerp(rim, 0.12))
	draw_polygon(drum, dcols)
	var foot := PackedVector2Array()
	for i in n + 1:
		var a := PI * i / n
		foot.append(c + Vector2(cos(a) * rx, sin(a) * ry + dh))
	draw_polyline(foot, Color(rim.r, rim.g, rim.b, 0.8), UIKit.line_px(1.0), true)
	var lip := PackedVector2Array()
	for i in n + 1:
		var a := PI * i / n
		lip.append(c + Vector2(cos(a) * rx, sin(a) * ry + dh * 0.45))
	draw_polyline(lip, Color(hl.r, hl.g, hl.b, 0.45), 1.0, true)
	var top := _ellipse(c, rx, ry)
	var cols := PackedColorArray()
	for p in top:
		var k := clampf((p.y - (c.y - ry)) / (2.0 * ry), 0.0, 1.0)
		cols.append(UITokens.PAPER_0.lerp(light, 0.25 + 0.35 * k).lerp(rim, 0.08 * k))
	draw_polygon(top, cols)
	# A soft sheen across the upper-left of the top face.
	draw_texture_rect(glow, Rect2(c + Vector2(-rx * 0.75, -ry * 0.95), Vector2(rx * 0.9, ry * 0.9)), false, Color(1, 1, 1, 0.45))
	# Faint marble veins (deterministic arcs, the gem's deep tone).
	for i in 5:
		var a0 := 0.6 + i * 1.17
		var vc := c + Vector2(cos(a0) * rx * 0.55, sin(a0) * ry * 0.5)
		draw_arc(vc, rx * (0.22 + 0.05 * i), a0, a0 + 0.9, 18, Color(deep.r, deep.g, deep.b, 0.07), 1.2, true)
	GemDraw.outline(self, _ellipse(c, rx + 3.0, ry + 3.0), Color(rim.r, rim.g, rim.b, 0.55), UIKit.line_px(1.5))
	GemDraw.outline(self, top, hl, UIKit.line_px(1.0))
	GemDraw.outline(self, _ellipse(c, rx * 0.9, ry * 0.9), Color(UITokens.GOLD_HI.r, UITokens.GOLD_HI.g, UITokens.GOLD_HI.b, 0.85), UIKit.line_px(1.0))
	GemDraw.outline(self, _ellipse(c, rx * 0.88, ry * 0.88), Color(hl.r, hl.g, hl.b, 0.5), 1.0)
	GemDraw.outline(self, _ellipse(c, rx * 0.46, ry * 0.46), Color(hl.r, hl.g, hl.b, 0.4), 1.0)
	# Inlaid compass: four engraved spokes and keystones on the outer ring.
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + Vector2(d.x * rx * 0.5, d.y * ry * 0.5), c + Vector2(d.x * rx * 0.86, d.y * ry * 0.86), Color(hl.r, hl.g, hl.b, 0.3), 1.0, true)
		GemDraw.draw_keystone(self, c + Vector2(d.x * rx, d.y * ry), 14.0, 0.9)
	# Contact shadows under every standing card (the hero's is wider).
	for s0: Dictionary in seats:
		if str(s0["state"]) == "champion" and s0["slot"] != &"":
			_contact(floor_point(s0["slot"]), 124.0 * depth(s0["slot"]))
	_contact(c, 156.0 * depth(&"hero"))
	# Seats: engraved ellipses; occupied = gold ring + aura, empty = dashed, locked = closed.
	for s: Dictionary in seats:
		var sl: StringName = s["slot"]
		if sl == &"":
			continue
		var p := floor_point(sl)
		var st := str(s["state"])
		var srx := 66.0
		var sry := srx * 0.36
		if sl == focus_slot:
			draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(srx * 2.2, sry * 3.2), Vector2(srx * 4.4, sry * 6.4)), false, Color(UITokens.CTA.r, UITokens.CTA.g, UITokens.CTA.b, 0.45))
		if st == "champion":
			draw_line(c, p, Color(hl.r, hl.g, hl.b, 0.75), UIKit.line_px(1.0), true)
			GemDraw.draw_marquise(self, p.lerp(c, 0.5), (c - p).normalized(), 9.0, hl)
			var cd := HeroesUIModel.champion(str(s["id"]))
			var aura_r := float((ChampionData.CHAMPIONS.get(str(s["id"]), {"kit": {"radius": 1.0}}) as Dictionary)["kit"]["radius"])
			var ar := srx * 0.62 * aura_r
			var gc: Color = UITokens.gem(str(cd.get("gem", "C")))["rim"]
			draw_colored_polygon(_ellipse(p, ar * 1.5, ar * 0.54), Color(gc.r, gc.g, gc.b, 0.12))
			GemDraw.outline(self, _ellipse(p, ar * 1.5, ar * 0.54), Color(gc.r, gc.g, gc.b, 0.4), 1.2)
			draw_colored_polygon(_ellipse(p, srx, sry), Color(1, 1, 1, 0.5))
			GemDraw.outline(self, _ellipse(p, srx, sry), hl, UIKit.line_px(1.5))
		elif st == "empty":
			_dashed(_ellipse(p, srx, sry, 40), Color(hl.r, hl.g, hl.b, 0.95), 1.6)
		else:
			draw_colored_polygon(_ellipse(p, srx, sry), Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.8))
			GemDraw.outline(self, _ellipse(p, srx, sry), Color(hl.r, hl.g, hl.b, 0.6), 1.2)
	# Hero seat: a gold rosette under the leader.
	GemDraw.outline(self, _ellipse(c, 92.0, 33.0), hl, UIKit.line_px(1.5))
	GemDraw.outline(self, _ellipse(c, 80.0, 28.0), Color(hl.r, hl.g, hl.b, 0.5), 1.0)
	var gl := 0.5 + 0.5 * sin(_t * 1.3)
	GemDraw.draw_glint(self, c + Vector2(-70, -18), 14.0 + 6.0 * gl, Color(1, 1, 1, 0.5 + 0.3 * gl))


## A soft elliptical contact shadow at a card's feet (`w` = the card's drawn width).
func _contact(p: Vector2, w: float) -> void:
	var sc := UITokens.SCRIM
	var glow := UIKit.glow_texture()
	draw_texture_rect(glow, Rect2(p + Vector2(-w * 0.75, -w * 0.12), Vector2(w * 1.5, w * 0.36)), false, Color(sc.r, sc.g, sc.b, 0.32))
	draw_colored_polygon(_ellipse(p + Vector2(0, 4), w * 0.5, w * 0.08, 32), Color(sc.r, sc.g, sc.b, 0.14))


func _dashed(pts: PackedVector2Array, col: Color, w: float) -> void:
	for i in pts.size():
		if i % 2 == 0:
			draw_line(pts[i], pts[(i + 1) % pts.size()], col, w, true)
