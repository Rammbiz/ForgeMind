class_name HeroesTeamStage
extends Control
## The bright formation stage of the Team screen (heroes_design.md §4.2 slots, §9.3; AFK Journey
## formation x Genshin light): an ivory marble dais seen in soft perspective, a ring of tiny crowd
## helmets (the army the champions walk inside), engraved slot seats at the run's slot offsets
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
var _t := 0.0
var _crowd: Array[Vector2] = []

const KX := 0.36       ## floor x unit = KX x width


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 30:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 1.05
		_crowd.append(Vector2(cos(a) * r, sin(a) * r * 0.95))


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
	var room := (size.y - TOP_PAD - _champ_h() - CHIP_H - CHIP_H - 10.0) / 1.32
	var ideal := (_hero_h() + CHIP_H + 6.0) / 0.63
	return Vector2(ux, clampf(minf(room, ideal * 1.08), 150.0, 460.0))


## The hero's floor point (the dais centre).
func centre() -> Vector2:
	var u := units()
	var used := TOP_PAD + _champ_h() + CHIP_H + 1.32 * u.y + CHIP_H
	var y := TOP_PAD + _champ_h() + 0.63 * u.y + maxf(0.0, (size.y - used) * 0.5)
	return Vector2(size.x * 0.5, y)


## Screen point of `slot` on the floor ("" / "hero" = the centre).
func floor_point(slot: StringName) -> Vector2:
	if slot == &"" or slot == &"hero":
		return centre()
	var o := HeroesTeamLogic.offset(slot)
	var u := units()
	return centre() + Vector2(o.x * u.x, o.y * u.y)


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
	# Dais: soft shadow, marble body (a 14 px drum), top face, rings.
	var rx := size.x * 0.47
	var ry := minf(maxf(u.y * 0.92, rx * 0.42), rx * 0.9)
	draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(rx * 1.5, ry * 1.6), Vector2(rx * 3.0, ry * 3.2)), false, Color(1, 0.97, 0.9, 0.55))
	draw_colored_polygon(_ellipse(c + Vector2(0, 26), rx * 1.02, ry * 1.02), Color(sc.r, sc.g, sc.b, 0.10))
	var drum := _ellipse(c + Vector2(0, 14), rx, ry)
	draw_colored_polygon(drum, UITokens.PAPER_3)
	var top := _ellipse(c, rx, ry)
	var cols := PackedColorArray()
	for p in top:
		var k := clampf((p.y - (c.y - ry)) / (2.0 * ry), 0.0, 1.0)
		cols.append(UITokens.PAPER_0.lerp(UITokens.PAPER_2, k * 0.8))
	draw_polygon(top, cols)
	GemDraw.outline(self, top, hl, 2.0)
	GemDraw.outline(self, _ellipse(c, rx * 0.9, ry * 0.9), Color(hl.r, hl.g, hl.b, 0.55), 1.2)
	GemDraw.outline(self, _ellipse(c, rx * 0.46, ry * 0.46), Color(hl.r, hl.g, hl.b, 0.45), 1.0)
	# Inlaid compass: four engraved spokes and keystones on the outer ring.
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + Vector2(d.x * rx * 0.5, d.y * ry * 0.5), c + Vector2(d.x * rx * 0.88, d.y * ry * 0.88), Color(hl.r, hl.g, hl.b, 0.35), 1.0, true)
		GemDraw.draw_keystone(self, c + Vector2(d.x * rx, d.y * ry), 14.0, 0.9)
	# The army: a ring of tiny crowd helmets (soft, so the cards stay the subject).
	for p in _crowd:
		var q := c + Vector2(p.x * rx * 0.86, p.y * ry * 0.86)
		var s := 5.0 + 1.5 * (p.y + 1.0)
		draw_circle(q + Vector2(0, 1.5), s * 0.8, Color(sc.r, sc.g, sc.b, 0.06))
		draw_circle(q, s * 0.75, Color(UITokens.GOLD_HI.r, UITokens.GOLD_HI.g, UITokens.GOLD_HI.b, 0.4))
		draw_circle(q + Vector2(-s * 0.2, -s * 0.25), s * 0.26, Color(1, 1, 1, 0.45))
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
			draw_line(c, p, Color(hl.r, hl.g, hl.b, 0.75), 1.6, true)
			GemDraw.draw_marquise(self, p.lerp(c, 0.5), (c - p).normalized(), 9.0, hl)
			var cd := HeroesUIModel.champion(str(s["id"]))
			var aura_r := float((ChampionData.CHAMPIONS.get(str(s["id"]), {"kit": {"radius": 1.0}}) as Dictionary)["kit"]["radius"])
			var ar := srx * 0.62 * aura_r
			var gc: Color = UITokens.gem(str(cd.get("gem", "C")))["rim"]
			draw_colored_polygon(_ellipse(p, ar * 1.5, ar * 0.54), Color(gc.r, gc.g, gc.b, 0.12))
			GemDraw.outline(self, _ellipse(p, ar * 1.5, ar * 0.54), Color(gc.r, gc.g, gc.b, 0.4), 1.2)
			draw_colored_polygon(_ellipse(p, srx, sry), Color(1, 1, 1, 0.5))
			GemDraw.outline(self, _ellipse(p, srx, sry), hl, 2.0)
		elif st == "empty":
			_dashed(_ellipse(p, srx, sry, 40), Color(hl.r, hl.g, hl.b, 0.95), 1.6)
		else:
			draw_colored_polygon(_ellipse(p, srx, sry), Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.8))
			GemDraw.outline(self, _ellipse(p, srx, sry), Color(hl.r, hl.g, hl.b, 0.6), 1.2)
	# Hero seat: a gold rosette under the leader.
	GemDraw.outline(self, _ellipse(c, 92.0, 33.0), hl, 2.2)
	GemDraw.outline(self, _ellipse(c, 80.0, 28.0), Color(hl.r, hl.g, hl.b, 0.5), 1.0)
	var gl := 0.5 + 0.5 * sin(_t * 1.3)
	GemDraw.draw_glint(self, c + Vector2(-70, -18), 14.0 + 6.0 * gl, Color(1, 1, 1, 0.5 + 0.3 * gl))


func _dashed(pts: PackedVector2Array, col: Color, w: float) -> void:
	for i in pts.size():
		if i % 2 == 0:
			draw_line(pts[i], pts[(i + 1) % pts.size()], col, w, true)
