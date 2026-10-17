class_name TeamBanner
extends Control
## The run's start banner (heroes design §10.5: 1.2 s during READY, <= 3 synergy icons). A slim
## porcelain-glass ribbon at the top third (ui_v3_spec §7.4: flat glass, ONE 1 dpx gold line, its
## inner light line, marquise ends, 45-degree chamfers): the champions' class glyphs in slot order
## (ChampionMedallions.ordered: front, left, right, rear) on small glass discs with their 10 px gem
## pips, a fading 1 dpx divider, then up to three synergy glyphs (Team.synergy ids: fac_<f>_<tier>
## with tier pips, cls_<class> pairs, affinity). No text. It fades in (0.15 s), holds, fades out and
## hides itself; nothing is freed, so the run can show it again. No input: MOUSE_FILTER_IGNORE.
##   banner.show_team(champions.members, profile.team.synergy_ids)

signal done

const MAX_SYNERGY := 3
const RIBBON_H := 66.0
const PAD := 22.0
## Champion cell pitch (a 40 px disc) and synergy cell pitch (a 28 px glyph).
const CELL := 52.0
const SYN_CELL := 44.0
const DIVIDER := 30.0
const DISC_R := 20.0
const GLYPH := 26.0
const SYN_GLYPH := 28.0
const PIP := 10.0
## The ribbon's centre sits at this share of the height (the top third, clear of the army and HUD).
const Y_SHARE := 1.0 / 3.0
## Entrance rise (px), skipped with Reduce Motion.
const RISE := 10.0

## [{cls, gem}] in slot order and [{icon, tier}] (<= MAX_SYNERGY), set by show_team().
var _champs: Array[Dictionary] = []
var _syn: Array[Dictionary] = []
var _tw: Tween
var _dy := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the team for `seconds` in total (fade in UITokens.FAST, hold, fade out UITokens.EXIT), then
## hides itself and emits `done`. `members` = Champions.members (or any rows with class / gem / slot);
## `synergy_ids` = profile.team.synergy_ids (unknown ids are skipped, the first MAX_SYNERGY shown).
func show_team(members: Array, synergy_ids: Array, seconds := 1.2) -> void:
	_champs.clear()
	_syn.clear()
	for m: Dictionary in ChampionMedallions.ordered(members):
		_champs.append({"cls": str(m.get("class", "")), "gem": UITokens.gem_of(str(m.get("gem", m.get("native", "C"))))})
	for sid: Variant in synergy_ids:
		var ic := synergy_icon(str(sid))
		if ic.is_empty():
			continue
		_syn.append(ic)
		if _syn.size() >= MAX_SYNERGY:
			break
	if _tw:
		_tw.kill()
	if _champs.is_empty() and _syn.is_empty():
		visible = false
		return
	visible = true
	modulate.a = 0.0
	var calm := UITokens.reduce_motion()
	_dy = 0.0 if calm else RISE
	queue_redraw()
	var hold := maxf(0.0, seconds - UITokens.FAST - UITokens.EXIT)
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 1.0, UITokens.FAST).set_ease(Tween.EASE_OUT)
	if not calm:
		_tw.parallel().tween_method(_set_dy, RISE, 0.0, UITokens.FAST).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_interval(hold)
	_tw.tween_property(self, "modulate:a", 0.0, UITokens.EXIT).set_ease(Tween.EASE_IN)
	_tw.tween_callback(_finish)


## Hides it now (a level ends during READY, a restart).
func hide_now() -> void:
	if _tw:
		_tw.kill()
	_finish()


func champion_count() -> int:
	return _champs.size()


func synergy_count() -> int:
	return _syn.size()


## The ribbon rect in this node's coordinates (it fills its parent).
func ribbon_rect() -> Rect2:
	var area := _area()
	var w := PAD * 2.0 + _champs.size() * CELL
	if not _syn.is_empty():
		w += (DIVIDER if not _champs.is_empty() else 0.0) + _syn.size() * SYN_CELL
	w = minf(w, area.x - 32.0)
	return Rect2(Vector2((area.x - w) * 0.5, area.y * Y_SHARE - RIBBON_H * 0.5), Vector2(w, RIBBON_H))


## A synergy id (Team.synergy: fac_<faction>_<tier> | cls_<class> | affinity) -> {icon, tier}, or {}
## when it has no line glyph. Affinity uses the Team screen's glyph ("odds").
static func synergy_icon(sid: String) -> Dictionary:
	var icon := ""
	var tier := 0
	if sid == "affinity":
		icon = "odds"
	elif sid.begins_with("cls_"):
		icon = sid
	elif sid.begins_with("fac_"):
		var parts := sid.split("_")
		if parts.size() >= 3 and parts[parts.size() - 1].is_valid_int():
			tier = clampi(int(parts[parts.size() - 1]), 0, 3)
			icon = "_".join(parts.slice(0, parts.size() - 1))
		else:
			icon = sid
	if icon == "" or not KitIcons.has_line(icon):
		return {}
	return {"icon": icon, "tier": tier}


## This node's size (it fills its parent), else the parent area, else the 720 x 1280 canvas.
func _area() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	if is_inside_tree():
		var a := get_parent_area_size()
		if a.x > 1.0 and a.y > 1.0:
			return a
	return Vector2(720, 1280)


func _set_dy(v: float) -> void:
	_dy = v
	queue_redraw()


func _finish() -> void:
	modulate.a = 0.0
	visible = false
	done.emit()


func _draw() -> void:
	if _champs.is_empty() and _syn.is_empty():
		return
	var r := ribbon_rect()
	r.position.y += _dy
	var cy := r.get_center().y
	# The ribbon: flat glass (GLASS_THIN_A + 0.14 over the 3D), one soft halo, the gold line with its
	# light line, and marquise terminals pointing out of both ends.
	HeroV3.glass(self, r, UITokens.CHAMFER_L, UITokens.GLASS_THIN_A + 0.14, HeroV3.GOLD, 0.78, 0.62, 0.1)
	var lg := UITokens.LINE_GOLD_DEEP
	GemDraw.draw_marquise(self, Vector2(r.position.x - 7.0, cy), Vector2.LEFT, 10.0, lg)
	GemDraw.draw_marquise(self, Vector2(r.end.x + 7.0, cy), Vector2.RIGHT, 10.0, lg)
	var x := r.position.x + PAD
	# Champions: a glass disc each, the class glyph in ink, the 10 px gem pip on its lower rim.
	for ch: Dictionary in _champs:
		var c := Vector2(x + CELL * 0.5, cy - 3.0)
		HeroV3.disc(self, c, DISC_R, 0.92, HeroV3.GOLD, 0.8)
		var gr := Rect2(c - Vector2(GLYPH, GLYPH) * 0.5, Vector2(GLYPH, GLYPH))
		Icons.draw_icon(self, "cls_" + str(ch["cls"]), gr, UITokens.INK)
		GemDraw.draw_mark(self, str(ch["gem"]), c + Vector2(0.0, DISC_R), PIP)
		x += CELL
	if _syn.is_empty():
		return
	if not _champs.is_empty():
		# A vertical 1 dpx gold rule fading toward both ends.
		var dx := x + DIVIDER * 0.5
		var y0 := r.position.y + 12.0
		var y1 := r.end.y - 12.0
		var gc := UITokens.LINE_GOLD
		var pts := PackedVector2Array([Vector2(dx, y0), Vector2(dx, lerpf(y0, y1, 0.3)), Vector2(dx, lerpf(y0, y1, 0.7)),
				Vector2(dx, y1)])
		var off := Color(gc.r, gc.g, gc.b, 0.0)
		var on := Color(gc.r, gc.g, gc.b, 0.6)
		var cols := PackedColorArray([off, on, on, off])
		draw_polyline_colors(pts, cols, UIKit.line_px(1.0))
		x += DIVIDER
	# Synergies: engraved gold-ink glyphs (no chip frames inside the ribbon, ui_v3_spec §3.2) and
	# pale-gold tier pips under a faction glyph.
	for sy: Dictionary in _syn:
		var c2 := Vector2(x + SYN_CELL * 0.5, cy - (5.0 if int(sy["tier"]) > 0 else 0.0))
		var sr := Rect2(c2 - Vector2(SYN_GLYPH, SYN_GLYPH) * 0.5, Vector2(SYN_GLYPH, SYN_GLYPH))
		Icons.draw_icon(self, str(sy["icon"]), sr, UITokens.GOLD_TEXT_GLASS)
		var t := int(sy["tier"])
		for i in t:
			GemDraw.draw_diamond(self, Vector2(c2.x + (i - (t - 1) * 0.5) * 10.0, c2.y + SYN_GLYPH * 0.5 + 8.0), 8.0,
					UITokens.PIP_WALKED, UITokens.LINE_GOLD_DEEP)
		x += SYN_CELL
