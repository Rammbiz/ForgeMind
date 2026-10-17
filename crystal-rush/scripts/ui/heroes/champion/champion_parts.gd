class_name HeroesChampionParts
extends RefCounted
## Drawn parts of the Champion Showcase (heroes_design.md §4, §9.3; part U §2.6):
##   CardArt   the art: the painted 3:4 card in one 1 dpx gold frame (UI v3.1) when HeroArt has one;
##             otherwise NO card and no frame: the class sigil in metal relief (HeroArt.draw_relief)
##             painted straight into the gem sky over a faint silhouette of the gem's cut, slow
##             0.8 % breathing and a light sweep, the honest 20 px caps line «Арт чемпіона —
##             скоро» under it (Genshin's "unknown" look); dimmed when not owned
##   SlotMap   a mini formation diagram for the АУРА plate: the hero at the dais centre and the
##             four run slots, the champion's slot lit in its gem
##   TierPips  the Action tier I..IV: four rhombus pips, each lit in its own gem (I Кварц .. IV
##             Топаз) up to the champion's tier, the rest engraved; roman numerals under them
##   RunDemo   «У забігу»: a small looping diagram of a bridge segment, the crowd, the champion
##             standing on its slot with its aura ring, and its Action beat by class (the live 3D
##             demo arrives with the model; static under Reduce Motion)


class CardArt extends Control:
	var id := ""
	var gem := "C"
	var cls := "healer"
	var dim := false
	var _t := 0.0
	var _tex: Texture2D
	var _note: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := HeroArt.state(id)
		if st in ["splash", "card"]:
			_tex = HeroArt.card_texture(id)
		if _tex == null:
			_note = UIKit.caps(HeroesText.t("CHAMP_UI_ART_SOON"), 20, UITokens.GOLD_TEXT_GLASS)
			_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(_note)
			resized.connect(_place_note)
			_place_note()
		set_process(not UITokens.reduce_motion())

	func has_art() -> bool:
		return _tex != null

	## Relief glyph size and centre (placeholder mode).
	func glyph_px() -> float:
		return clampf(minf(size.x * 0.78, size.y * 0.56), 120.0, 300.0)

	func centre() -> Vector2:
		return Vector2(size.x * 0.5, size.y * 0.44)

	func _place_note() -> void:
		if _note == null:
			return
		_note.custom_minimum_size = Vector2(size.x, 0)
		var ns := _note.get_combined_minimum_size()
		_note.size = Vector2(size.x, ns.y)
		_note.position = Vector2(0, centre().y + glyph_px() * 0.62 + 14.0)

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		if _tex == null:
			_draw_relief()
			return
		var r := Rect2(Vector2.ZERO, size)
		var g: Dictionary = UITokens.gem(gem)
		var pts := GemDraw.chamfer_rect(r, 14.0)
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(0, 10))
		draw_colored_polygon(sh, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.16))
		var top: Color = g["top"]
		var bot: Color = g["bot"]
		if UITokens.calm_cta() and UITokens.gem_of(gem) == "topaz":
			# Porcelain: the topaz portrait ground is a muted champagne-bronze, not an orange gradient.
			top = Color("#9C8667")
			bot = Color("#E4D3B0")
		if dim:
			top = top.lerp(UITokens.PAPER_3, 0.6)
			bot = bot.lerp(UITokens.PAPER_3, 0.6)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bot, p.y / maxf(size.y, 1.0)))
		draw_polygon(pts, cols)
		KitGemCard.draw_stage_fracture(self, UITokens.gem_of(gem), r)
		var glow := UIKit.glow_texture()
		var lc: Color = g["light"]
		draw_texture_rect(glow, Rect2(r.get_center() - size * 0.6, size * 1.2), false, Color(lc.r, lc.g, lc.b, 0.25 + 0.05 * sin(_t * 0.8)))
		if g.has("flecks") and not dim:
			var fl: Array = g["flecks"]
			for i in fl.size():
				var a := TAU * i / fl.size() + _t * 0.15
				var c := r.get_center() + Vector2(cos(a) * size.x * 0.28, sin(a * 1.3) * size.y * 0.3)
				var fc: Color = fl[i]
				draw_texture_rect(glow, Rect2(c - Vector2(80, 80), Vector2(160, 160)), false, Color(fc.r, fc.g, fc.b, 0.35))
		draw_texture_rect(_tex, r.grow(-6.0), false, Color(1, 1, 1, 0.5 if dim else 1.0))
		# v3.1 (§7.3): ONE 1 dpx gold frame with the 1 dpx light line inside (no double band, no
		# keystones): the painted card leads.
		HeroV3.light_line(self, r, UITokens.CHAMFER, 0.7)
		HeroV3.frame(self, pts, HeroV3.a(HeroV3.GOLD, 0.95))


	func _draw_relief() -> void:
		var g: Dictionary = UITokens.gem(gem)
		var light: Color = g["light"]
		var rim: Color = g["rim"]
		var a := 0.55 if dim else 1.0
		var c := centre()
		var gp := glyph_px()
		var glow := UIKit.glow_texture()
		# A gem-light pool and the cut, large and faint, so the rarity still reads by shape.
		draw_texture_rect(glow, Rect2(c - Vector2(gp, gp) * 1.05, Vector2(gp, gp) * 2.1), false, Color(rim.r, rim.g, rim.b, 0.22 * a))
		var cut := str(g["cut"])
		var pts := GemDraw.cut_points(cut, c, gp * 1.28)
		draw_colored_polygon(pts, Color(light.r, light.g, light.b, 0.18 * a))
		GemDraw.outline(self, pts, Color(1, 1, 1, 0.5 * a), UIKit.line_px(1.0))
		GemDraw.outline(self, GemDraw.cut_points(cut, c, gp * 1.4), Color(light.r, light.g, light.b, 0.35 * a), UIKit.px(1.0))
		var reduce := UITokens.reduce_motion()
		var k := 0.0 if reduce else sin(_t * TAU / 5.2)
		draw_set_transform(c + Vector2(0, -3.0 * k), 0.0, Vector2.ONE * (1.0 + 0.008 * k))
		HeroArt.draw_relief(self, Vector2.ZERO, gp, cls, gem, a, -1.0 if reduce else _t, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mini formation: the dais, the hero at its centre, the four run slots (ChampionKinds offsets),
## the champion's own slot lit in its gem with a small aura ring.
class SlotMap extends Control:
	var slot := "left"
	var gem := "C"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var R := Vector2(size.x * 0.4, size.y * 0.4)
		var hl := UITokens.HAIRLINE
		var ring := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			ring.append(c + Vector2(cos(a) * R.x, sin(a) * R.y))
		draw_colored_polygon(ring, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.9))
		HeroV3.frame(self, ring, hl)
		draw_circle(c, 7.0, UITokens.GOLD_HI, true, -1.0, true)
		draw_arc(c, 7.0, 0, TAU, 20, HeroV3.DEEP, UIKit.px(1.0), true)
		var gc: Color = UITokens.gem(gem)["rim"]
		for sl: StringName in ChampionKinds.SLOT_ORDER:
			var o := ChampionKinds.slot_offset(sl, 1.0)
			var p := c + Vector2(o.x / 0.69 * R.x * 0.9, o.y / 0.69 * R.y * 0.9)
			if str(sl) == slot:
				draw_circle(p, 13.0, Color(gc.r, gc.g, gc.b, 0.25))
				draw_circle(p, 7.5, gc)
				draw_arc(p, 7.5, 0, TAU, 20, HeroV3.DEEP, UIKit.line_px(1.0), true)
			else:
				draw_arc(p, 5.0, 0, TAU, 16, Color(hl.r, hl.g, hl.b, 0.7), UIKit.line_px(1.0), true)


## The relic socket: a cream disc in a thin gold ring with the engraved relic glyph.
class RelicSocket extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5 - 2.0
		HeroV3.disc(self, c, R, 0.92, HeroV3.GOLD, 0.85, 0.08)
		var s := R * 1.1
		HeroIcons.paint(self, "sk_relic", Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), UITokens.GOLD_TEXT_GLASS)


class TierPips extends Control:
	var tier := 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(4 * 44.0, 56)

	func _draw() -> void:
		var f := UIKit.font(true)
		for i in 4:
			var c := Vector2(22.0 + i * 44.0, 16.0)
			var g := Ladder.GEMS[i]
			var lit := i < tier
			GemDraw.draw_pip(self, c, 28.0, lit, HeroFacetPips.pip_color(g) if lit else UITokens.TOPAZ)
			draw_string(f, Vector2(c.x - 22.0, 52.0), HeroesText.roman(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 44.0, 20,
					UITokens.INK if lit else Color(UITokens.INK_DIM_GLASS.r, UITokens.INK_DIM_GLASS.g, UITokens.INK_DIM_GLASS.b, 0.7))


class RunDemo extends Control:
	var cls := "healer"
	var gem := "C"
	var slot := "left"
	var _t := 0.0
	var _crowd: Array[Vector2] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 24:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf())
			_crowd.append(Vector2(cos(a) * r, sin(a) * r))
		set_process(not UITokens.reduce_motion())

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var W := size.x
		var H := size.y
		var r := Rect2(Vector2.ZERO, size)
		var pts := GemDraw.chamfer_rect(r, 8.0)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(UITokens.PAPER_0.lerp(UITokens.SKY_MID, 0.35 + 0.4 * p.y / maxf(H, 1.0)))
		draw_polygon(pts, cols)
		# The bridge: a light deck in perspective with planks scrolling toward the camera.
		var top_w := W * 0.34
		var bot_w := W * 0.86
		var deck := PackedVector2Array([Vector2((W - top_w) * 0.5, 8), Vector2((W + top_w) * 0.5, 8),
				Vector2((W + bot_w) * 0.5, H - 6), Vector2((W - bot_w) * 0.5, H - 6)])
		draw_colored_polygon(deck, UITokens.BRIDGE_BODY)
		GemDraw.outline(self, deck, UITokens.BRIDGE_EDGE, UIKit.line_px(1.0))
		var scroll := fposmod(_t * 0.45, 1.0)
		for k in 7:
			var v := fposmod(float(k) / 7.0 + scroll, 1.0)
			var y := lerpf(8.0, H - 6.0, v * v)
			var hw := lerpf(top_w, bot_w, v * v) * 0.5
			draw_line(Vector2(W * 0.5 - hw, y), Vector2(W * 0.5 + hw, y), Color(UITokens.BRIDGE_EDGE.r, UITokens.BRIDGE_EDGE.g, UITokens.BRIDGE_EDGE.b, 0.5), 1.0, true)
		# The crowd blob and the champion on its slot (ChampionKinds offsets, x across, y along).
		var c := Vector2(W * 0.5, H * 0.58)
		var R := Vector2(W * 0.2, H * 0.3)
		var so := ChampionKinds.slot_offset(StringName(slot), 1.0)
		var cp := c + Vector2(so.x * R.x * 1.25, so.y * R.y * 1.1)
		var gc: Color = UITokens.gem(gem)["rim"]
		# Aura ring (pulses on each Action beat).
		var beat := fposmod(_t, 1.5) / 1.5
		var pulse := 1.0 + 0.12 * (1.0 - beat) * (1.0 - beat)
		var ar := Vector2(R.x * 0.55, R.y * 0.42) * pulse
		var ring := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			ring.append(cp + Vector2(cos(a) * ar.x, sin(a) * ar.y))
		draw_colored_polygon(ring, Color(gc.r, gc.g, gc.b, 0.16))
		GemDraw.outline(self, ring, Color(gc.r, gc.g, gc.b, 0.6), UIKit.line_px(1.0))
		for p in _crowd:
			var q := c + Vector2(p.x * R.x, p.y * R.y) + Vector2(0, sin(_t * 6.0 + p.x * 9.0) * 1.2)
			var inside := ((q - cp) / ar).length() < 1.0
			draw_circle(q + Vector2(0, 2), 5.5, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.12))
			draw_circle(q, 5.0, UITokens.INK if not inside else UITokens.INK.lerp(gc, 0.45))
			draw_circle(q + Vector2(-1.5, -2), 1.6, Color(1, 1, 1, 0.7))
		# The hero leads at the centre (white-gold ring, the run palette, §2.1).
		draw_circle(c, 11.0, UITokens.GOLD_HI, true, -1.0, true)
		draw_arc(c, 11.0, 0, TAU, 24, HeroV3.DEEP, UIKit.line_px(1.0), true)
		# The champion token: gem-cut mark in a white-gold ring.
		HeroV3.disc(self, cp, 16.0, 0.96, HeroV3.DEEP, 0.9, 0.12)
		Icons.draw_icon(self, "cls_" + cls, Rect2(cp - Vector2(11, 11), Vector2(22, 22)), UITokens.INK)
		# The Action beat by class (every 1.5 s).
		var k := beat
		var fx := Color(1, 0.93, 0.62, 1.0 - k)
		match cls:
			"ranger":
				var tip := cp + Vector2(0, -20 - k * (H * 0.55))
				draw_line(tip + Vector2(0, 14), tip, fx, 2.0, true)
				draw_line(tip, tip + Vector2(-4, 6), fx, 2.0, true)
				draw_line(tip, tip + Vector2(4, 6), fx, 2.0, true)
			"mage":
				var tc := Vector2(cp.x, 26)
				draw_arc(tc, 6.0 + k * 22.0, 0, TAU, 32, fx, 2.0, true)
			"guardian":
				draw_arc(cp + Vector2(0, -8), 24.0, PI * 1.15, PI * 1.85, 16, fx, 3.0, true)
			"warrior":
				var a0 := cp + Vector2(-16, -26)
				draw_line(a0, a0 + Vector2(32, -12) * minf(1.0, k * 3.0), fx, 3.0, true)
			_:
				for i in 3:
					var sp := cp + Vector2(-14 + i * 14, -18 - k * 26.0 - i * 4.0)
					draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), fx, 2.0, true)
					draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), fx, 2.0, true)
		HeroV3.frame(self, pts, UITokens.HAIRLINE)
