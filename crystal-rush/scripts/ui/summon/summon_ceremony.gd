class_name SummonCeremony
extends Control
## The summon ceremonies (heroes_design.md §7.1, §9.4 CeremonyData, §9.5, §9.7; part U §3.2-§3.5,
## §3.9; fusion §6.8 #4) - the «важкий люкс» peak of the heroes meta:
##   prologue (0.6 s) - the Portal ring charges, the seed(s) rise from the dais as clear crystal, a
##     pulse runs round the ring (Topaz+: gold glints crawl it), and at the TELL every seed lights in
##     its FINAL gem colour and cut at once; the ring takes the best gem's colour (Opal: the world
##     greys, only the stones keep colour). Tells never lie and nothing changes colour afterwards.
##   Кварц / Сапфір ×1 - the seed cracks into frosted / crisp shards and the card flies in (NEW:
##     crystallises + «НОВИЙ» wax seal; duplicate: «+15 фрагм.» flies into its fragment bar).
##   Аметист / Топаз / Опал WALKOUT - the light pillar in the gem colour (quartz silver, sapphire
##     blue, amethyst violet, topaz gold + twin pillars, black opal with iridescent fire), the crystal
##     grows in its cut, Class -> Element -> Faction light inside it, cracks follow the gem's own
##     fracture pattern, the crystal SHATTERS (hit-stop, shards, one capped flash), the splash steps
##     out through a facet "crystallise" wipe with parallax and a rim light, the gem emblem flies
##     top-left and rings, the name and title slam in on a cream ribbon with the identity chips, then
##     the «НОВИЙ» seal stamps (or the duplicate's fragments line). Lengths from CeremonyData
##     (Аметист 2.6 · Топаз 3.6 · Опал 5.0 after the prologue; short walkout 1.2 for duplicates,
##     Quick reveal and Fast ceremonies).
##   ×10 - ten seeds in an arc, the tell, a sort into ascending gem order, the Кварц / Сапфір seeds
##     crack together (batch_crack 0.5 s), the Аметист+ walkouts in ascending order (NEW = full,
##     duplicate = short), then the summary frame (SummonSummary, x10_frame 1.2 s).
##   Seal pick - known contents (the X-Ray rule): no tell, no identity beats; seals stream into the
##     ring, pillar, shatter, step-out, name (seal_pick_new 1.8 / seal_pick_owned 1.2).
## GRANTS FIRST: setup() calls HeroesUIModel.summon() / seal_pick() before the first frame (§9.5
## row 5); skipping never changes a result. Skippable from CeremonyData.SKIP_FROM: a tap finishes
## the current beat (×10: the current walkout), «Пропустити» or Android back jumps to the end state.
## Reduce Motion: ×1 Кварц / Сапфір = 200 ms cross-fade; walkouts = a static splash + name <= 1.0 s;
## ×10 = the summary only. Photosensitivity: every flash <= SummonFx.FLASH_PEAK white, <= 3 / s.
## The end state never shows an offer or a shop link: «До героя: …» and «Готово» only.
## Everything is a pure function of the ceremony time `_t` (gallery_seek(t) freezes any frame).
##
## Route "summon" (HeroesNav, host "ceremony"): "summon/x1", "summon/x10",
## "summon/walkout/<gem>" (a ×1 whose result HeroesUIModel.force_next decides - the gallery - and
## that always plays the full walkout of its gem), "summon/replay/<id>" (Повтор появи: the full
## walkout of an owned hero, no grant), "summon/seal/<id>" (a Seal pick).

signal closed

## Beat times of a full walkout, as fractions of its CeremonyData length (part U §3.2 C / D / E).
const BEATS := {
	"E": {"pillar": 0.0, "land": 0.3, "cls": 0.3, "el": 0.65, "fac": 1.0, "gather": 1.0, "shatter": 1.35, "hit": 0.08, "step": 1.43, "wipe": 0.35, "emblem": 1.8, "name": 2.0, "hold": 2.35, "ref": 2.6},
	"L": {"pillar": 0.0, "land": 0.4, "cls": 0.4, "el": 0.85, "fac": 1.3, "gather": 1.75, "shatter": 2.0, "hit": 0.1, "step": 2.1, "wipe": 0.45, "emblem": 2.55, "name": 2.8, "hold": 3.2, "ref": 3.6},
	"M": {"pillar": 0.0, "land": 0.5, "cls": 0.5, "el": 1.0, "fac": 1.5, "gather": 2.0, "shatter": 2.3, "hit": 0.12, "step": 2.45, "wipe": 0.6, "emblem": 3.05, "name": 3.45, "hold": 4.0, "ref": 5.0},
}
## Short walkout (part U §3.2 F) and Seal pick (§3.5), in seconds of their reference length.
const SHORT := {"pillar": 0.0, "land": 0.08, "shatter": 0.2, "hit": 0.05, "step": 0.35, "wipe": 0.3, "emblem": 0.5, "name": 0.65, "hold": 0.85, "ref": 1.2}
const SEAL := {"stream": 0.0, "pillar": 0.3, "land": 0.38, "shatter": 0.5, "hit": 0.06, "step": 0.6, "wipe": 0.35, "emblem": 0.85, "name": 0.95, "hold": 1.3, "ref": 1.8}
## ×1 Кварц / Сапфір card beats after the prologue (part U §3.2 A / B), of their reference length.
const CARD := {"C": {"crack": 0.1, "card": 0.18, "new": 0.25, "stamp": 0.5, "ref": 0.6},
		"R": {"crack": 0.2, "card": 0.32, "new": 0.4, "stamp": 0.7, "glint": 0.7, "ref": 1.2}}
## Gem -> pentatonic step for the tell ring (C6 E6 G6 B6 D7 rising; Audio.chord).
const RING_STEP := {"C": 5, "R": 7, "E": 8, "L": 10, "M": 12}
## Per-hero signature beats added on top of a FULL walkout (the sheets' «Signature beat»; no extra length, no new
## flash, nothing in Reduce Motion, short walkouts or Seal picks). "doves" = H27 Ольга (§6.29): before she appears a
## blizzard of white feathers fills the screen and doves fly out of it as she steps out; all of it is gone before the
## name lands, so her face and the name are never covered.
const SIGNATURE := {"olha": "doves"}

var hub: Hub
var mode := "x1"                   ## x1 | x10 | seal | replay
var full_walk := false             ## walkout route: always the full walkout
var results: Array[Dictionary] = []
var _before: Dictionary = {}
var _after: Dictionary = {}
var _segs: Array[Dictionary] = []
var _total := 0.0
var _t := 0.0
var _t_prev := -1.0
var _frozen := false
var _hold_wait := -1               ## x10: index of the walkout waiting for a tap at its end
var _released := {}
var _reduce := false
var _quick := false
var _fast := false
var _fired := {}
var _cur := -1                     ## result index the walkout stage shows
var _best := "C"
var _done_close := false
var _press_t := -1.0

# ---- nodes
var _sky: PortalSky
var _ring: PortalRing
var _back: _Fx
var _pillar: ColorRect
var _pillar_mat: ShaderMaterial
var _art: Control
var _splash: TextureRect
var _splash_open: TextureRect   ## signature beat: the eyes-open splash fading in over the eyes-closed one
var _wipe: ShaderMaterial
var _sigil: _Sigil
var _fx: _Fx
var _fx_add: _Fx
var _card: HeroCard
var _card_seal: HeroWaxSeal
var _card_dup: VBoxContainer
var _card_dup_bar: HeroEngravedBar
var _ribbon: VBoxContainer         ## the name block, set straight on the art (Genshin wish style)
var _name: Label
var _rtitle: Label
var _chips: HBoxContainer
var _rseal: HeroWaxSeal
var _rdup: PanelContainer
var _rdup_label: Label
var _rdup_bar: HeroEngravedBar
var _emblem: HeroGemEmblem
var _summary: SummonSummary
var _scrim: TextureRect
var _skip: Button
var _tap: Label
var _dock: HBoxContainer
var _to_hero: Button
var _done: Button
# ---- layout
var _W := 720.0
var _H := 1280.0
var _ins := Vector4.ZERO
var _cc := Vector2(360, 540)       ## crystal / ring centre


# ================================================================== setup (grants first)

func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	var a0 := str(args[0]) if args.size() > 0 else "x1"
	_before = HeroesUIModel.portal_state()
	match a0:
		"x10":
			mode = "x10"
			results = HeroesUIModel.summon("portal", PortalData.X10_SUMMONS)
		"walkout":
			mode = "x1"
			full_walk = true
			results = HeroesUIModel.summon("portal", 1)
		"replay":
			mode = "replay"
			var id := str(args[1]) if args.size() > 1 else "vesta"
			results = [{"id": id, "kind": "hero", "gem": HeroData.native(id), "is_new": false, "fragments": 0, "tomes": 0, "forced": false, "replay": true}]
		"seal":
			mode = "seal"
			var id := str(args[1]) if args.size() > 1 else ""
			var r := HeroesUIModel.seal_pick(id)
			if not r.is_empty():
				results = [r]
		_:
			mode = "x1"
			results = HeroesUIModel.summon("portal", 1)
	_after = HeroesUIModel.portal_state()
	for r in results:
		if Ladder.gem_index(str(r["gem"])) > Ladder.gem_index(_best):
			_best = str(r["gem"])
	_reduce = UITokens.reduce_motion()
	_fast = bool(_setting("fast_ceremonies", false))
	_quick = bool(_setting("quick_reveal", false)) or _fast
	_build_timeline()


static func _setting(key: String, default: Variant) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	var meta := tree.root.get_node_or_null("Meta") if tree else null
	if meta == null or (meta.get("account") as Dictionary).is_empty():
		return default
	return meta.call("setting", key, default)


func _walk_kind(r: Dictionary) -> String:
	if _reduce:
		return "static"
	if mode == "seal":
		return "seal"
	if mode == "replay" or full_walk:
		return "full"
	if bool(r["is_new"]) and not _quick:
		return "full"
	return "short"


func _walk_len(kind: String, g: String) -> float:
	match kind:
		"full": return float((CeremonyData.CEREMONY["walkout"] as Dictionary)[str(Ladder.gem_index(g))])
		"short": return float(CeremonyData.CEREMONY["short_walkout"])
		"seal":
			var key := "seal_pick_new" if bool(results[0]["is_new"]) else "seal_pick_owned"
			var tbl := CeremonyData.CEREMONY_FAST if _fast else CeremonyData.CEREMONY
			return float(tbl.get(key, CeremonyData.CEREMONY[key]))
		# Reduce Motion: the static walkout ends (buttons up) by 0.8 s, inside the 1.0 s cap.
		"static": return minf(0.8, float(CeremonyData.CEREMONY_REDUCED["walkout_static_max"]))
	return 1.2


func _build_timeline() -> void:
	_segs.clear()
	var t := 0.0
	var P := float(CeremonyData.CEREMONY["prologue"])
	if results.is_empty():
		_total = 0.0
		return
	if mode == "seal" or mode == "replay":
		var k := _walk_kind(results[0])
		var L := _walk_len(k, str(results[0]["gem"]))
		_segs.append({"kind": "walk", "a": 0.0, "len": L, "idx": 0, "walk": k})
		_total = L
		return
	if mode == "x1":
		var r := results[0]
		var g := str(r["gem"])
		var gi := Ladder.gem_index(g)
		if _reduce:
			if gi < 2:
				_segs.append({"kind": "card", "a": 0.0, "len": float((CeremonyData.CEREMONY_REDUCED["x1"] as Array)[gi]), "idx": 0})
			else:
				_segs.append({"kind": "walk", "a": 0.0, "len": _walk_len("static", g), "idx": 0, "walk": "static"})
			_total = float(_segs[0]["len"])
			return
		_segs.append({"kind": "prologue", "a": 0.0, "len": P})
		if gi < 2:
			var x1: Array = (CeremonyData.CEREMONY_FAST if _fast else CeremonyData.CEREMONY)["x1"]
			_segs.append({"kind": "card", "a": P, "len": maxf(0.3, float(x1[gi]) - P), "idx": 0})
		else:
			var k := _walk_kind(r)
			_segs.append({"kind": "walk", "a": P, "len": _walk_len(k, g), "idx": 0, "walk": k})
		var last: Dictionary = _segs.back()
		_total = float(last["a"]) + float(last["len"])
		return
	# ×10
	var frame := float(CeremonyData.CEREMONY["x10_frame"])
	if _reduce:
		_segs.append({"kind": "summary", "a": 0.0, "len": 0.3})
		_total = 0.3
		return
	_segs.append({"kind": "prologue", "a": 0.0, "len": P})
	t = P + 0.25
	_segs.append({"kind": "sort", "a": t, "len": 0.3})
	t += 0.3
	var low := false
	for r in results:
		if Ladder.gem_index(str(r["gem"])) < 2:
			low = true
	if low:
		var bc := float(CeremonyData.CEREMONY["batch_crack"])
		_segs.append({"kind": "crack", "a": t, "len": bc})
		t += bc
	var walks: Array[int] = []
	for i in results.size():
		if Ladder.gem_index(str(results[i]["gem"])) >= 2:
			walks.append(i)
	walks.sort_custom(func(a: int, b: int) -> bool:
		var ga := Ladder.gem_index(str(results[a]["gem"]))
		var gb := Ladder.gem_index(str(results[b]["gem"]))
		return ga < gb if ga != gb else a < b)
	for i in walks:
		var k := _walk_kind(results[i])
		var L := _walk_len(k, str(results[i]["gem"]))
		_segs.append({"kind": "walk", "a": t, "len": L, "idx": i, "walk": k})
		t += L
	_segs.append({"kind": "summary", "a": t, "len": frame})
	_total = t + frame


func _seg_at(t: float) -> Dictionary:
	var cur: Dictionary = _segs[0] if not _segs.is_empty() else {}
	for s in _segs:
		if t >= float(s["a"]):
			cur = s
	return cur


func _first_walk_a() -> float:
	for s in _segs:
		if str(s["kind"]) in ["walk", "summary"]:
			return float(s["a"])
	return INF


# ================================================================== build

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.theme()
	if results.is_empty():
		# Nothing granted (e.g. a Seal pick that could not be afforded): close at once.
		_close.call_deferred()
		return
	_sky = PortalSky.new()
	_sky.driven = true
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.set_pool(_before.get("pool", []))
	add_child(_sky)
	_back = _Fx.new()
	_back.owner_c = self
	_back.layer = "back"
	_back.additive = true
	add_child(_back)
	_ring = PortalRing.new()
	_ring.driven = true
	add_child(_ring)
	_pillar = ColorRect.new()
	_pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pillar_mat = ShaderMaterial.new()
	_pillar_mat.shader = preload("res://shaders/heroes/light_pillar.gdshader")
	_pillar.material = _pillar_mat
	add_child(_pillar)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_sigil = _Sigil.new()
	_sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_sigil)
	_splash = TextureRect.new()
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wipe = ShaderMaterial.new()
	_wipe.shader = preload("res://shaders/heroes/facet_wipe.gdshader")
	_splash.material = _wipe
	_art.add_child(_splash)
	_splash_open = TextureRect.new()
	_splash_open.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_open.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_splash_open.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_splash_open.use_parent_material = true
	_splash_open.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash_open.visible = false
	_splash.add_child(_splash_open)
	_fx = _Fx.new()
	_fx.owner_c = self
	_fx.layer = "mid"
	add_child(_fx)
	_fx_add = _Fx.new()
	_fx_add.owner_c = self
	_fx_add.layer = "front"
	_fx_add.additive = true
	add_child(_fx_add)
	# A soft scrim under the dock (dark only as a gradient under text on art, contract §0.1).
	_scrim = TextureRect.new()
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt := GradientTexture2D.new()
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var gr := Gradient.new()
	gr.set_color(0, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.0))
	gr.set_color(1, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.66))
	gr.add_point(0.5, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.4))
	gt.gradient = gr
	gt.width = 4
	gt.height = 64
	_scrim.texture = gt
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_scrim)
	_build_card()
	_build_ribbon()
	# The cut already names the gem: no 12 px rarity caption under the medallion (critic P2).
	_emblem = HeroGemEmblem.make("L", 112.0)
	_emblem.show_name = false
	_emblem.size = Vector2(112, 112)
	_emblem.custom_minimum_size = _emblem.size
	add_child(_emblem)
	if mode == "x10":
		_summary = SummonSummary.new()
		_summary.setup(results, _before, _after, float(CeremonyData.CEREMONY["x10_frame"]))
		_summary.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_summary)
	_tap = UIKit.scene_label(HeroesText.t("SUMMON_TAP"), 24, false)
	_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tap)
	# «Пропустити» (UI v3.1 §7.7): a ghost on the night: 0.16 glass with ONE 1 dpx gold line and
	# warm-white Medium text with the scene shadow (never a solid tile over the cinematic).
	_skip = UIKit.ghost_button(HeroesText.t("SUMMON_SKIP"), Vector2(176, 88), 22, true)
	_skip.add_theme_font_override("font", UIKit.font_w("medium"))
	_skip.pressed.connect(skip_to_end)
	add_child(_skip)
	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 14)
	_dock.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_dock)
	var target := _hero_target()
	if target != "":
		_to_hero = UIKit.button(HeroesText.t("SUMMON_TO_HERO", [HeroesText.name_of(target)]), false, 300)
		_to_hero.custom_minimum_size = Vector2(300, 88)
		_to_hero.add_theme_font_size_override("font_size", 24)
		_to_hero.pressed.connect(func(): _open_hero(target))
		_dock.add_child(_to_hero)
	# «Готово» is a ghost on the night (0.16 glass, one 1 dpx line, warm-white text), «До героя»
	# the one secondary glass: never two equal cream slabs under the art.
	_done = UIKit.ghost_button(HeroesText.t("SUMMON_DONE"), Vector2(300, 88), 24, true)
	_done.pressed.connect(_close)
	_dock.add_child(_done)
	resized.connect(_layout)
	_layout()
	# Starters (live 3D) bake their portrait while the prologue plays.
	for r in results:
		if Ladder.gem_index(str(r["gem"])) >= 2 and HeroArt.state(str(r["id"])) == "live3d":
			_bake(str(r["id"]))
	_render()


func _bake(id: String) -> void:
	await HeroArt.live_portrait(self, id, 512)
	if is_instance_valid(self) and _cur >= 0 and str(results[_cur]["id"]) == id:
		_cur = -1


func _build_card() -> void:
	var r := results[0]
	if str(r.get("kind", "hero")) != "hero" or mode != "x1":
		return
	var d := HeroesUIModel.hero(str(r["id"])).duplicate()
	d["is_new"] = false
	d["owned"] = true
	_card = HeroCard.make(d, "L")
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_card_seal = HeroWaxSeal.make(92)
	add_child(_card_seal)
	_card_dup = VBoxContainer.new()
	_card_dup.add_theme_constant_override("separation", 6)
	_card_dup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HeroesUIModel.hero(str(r["id"]))
	# The duplicate's fragments on one cream-glass slip (never white text over the bright dais).
	# v3.1: text sits on it, so the slip is glass at the text alpha with its 1 dpx line.
	# Fixer: the slip is painted at 0.97 (the kit banner let the night and the dais rim through and
	# read greige under the label): one 1 dpx gold line, the inner light, one quiet halo.
	var pnl := PanelContainer.new()
	var psb := StyleBoxEmpty.new()
	psb.content_margin_left = 20
	psb.content_margin_right = 20
	psb.content_margin_top = 10
	psb.content_margin_bottom = 12
	pnl.add_theme_stylebox_override("panel", psb)
	pnl.draw.connect(func():
		HeroV3.glass(pnl, Rect2(Vector2.ZERO, pnl.size), 10.0, 0.97, HeroV3.GOLD, 0.85, 0.7, 0.12))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pnl.add_child(pv)
	var fl := UIKit.label(HeroesText.t("SUMMON_FRAGS", [int(r["fragments"])]) if int(r["tomes"]) <= 0 else HeroesText.t("SUMMON_TOMES", [int(r["tomes"])]), 28, UITokens.INK, true)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(fl)
	_card_dup_bar = HeroEngravedBar.make(str(h["gem"]), float(h["frags"]), float(maxi(1, int(h["frags_need"]))), 300)
	_card_dup_bar.label = HeroesText.t("CUR_FRAGS")
	_card_dup_bar.label_color = UITokens.INK
	_card_dup_bar.value_text = _frags_value(int(h["frags"]), int(h["frags_need"]))
	pv.add_child(_card_dup_bar)
	_card_dup.add_child(pnl)
	add_child(_card_dup)


func _build_ribbon() -> void:
	# The name sits straight on the art (scene type + soft shadow over the bottom scrim), a gold
	# hairline under it, the title in GOLD_HI and the identity chips on one line - no cream card
	# over the cinematic (critic P1). The duplicate's fragments ride a slim cream-glass slip.
	_ribbon = VBoxContainer.new()
	_ribbon.add_theme_constant_override("separation", 6)
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ribbon)
	_name = UIKit.scene_label("", 72)
	_ribbon.add_child(_name)
	var hl := Control.new()
	hl.custom_minimum_size = Vector2(0, 14)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.draw.connect(func():
		var w := minf(hl.size.x, maxf(260.0, _name_w() + 40.0))
		# v3.1: one 1 dpx gold rule that fades out to the right (no end ticks).
		var py := GemDraw.pixel_y(hl, 7.0)
		var gh := UITokens.GOLD_HI
		hl.draw_polyline_colors(PackedVector2Array([Vector2(0, py), Vector2(w * 0.7, py), Vector2(w, py)]),
				PackedColorArray([Color(gh.r, gh.g, gh.b, 0.95), Color(gh.r, gh.g, gh.b, 0.8), Color(gh.r, gh.g, gh.b, 0.0)]), UIKit.line_px(1.0)))
	_ribbon.add_child(hl)
	_rtitle = UIKit.label("", 28, UITokens.GOLD_HI, true)
	UIKit.soft_shadow(_rtitle, 28, 1.8)
	UIKit.scene_halo(_rtitle, 2.0, 1.4)
	_ribbon.add_child(_rtitle)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 18)
	_ribbon.add_child(_chips)
	_rdup = UIKit.panel("banner", Vector2(18, 8))
	_rdup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rdup.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_rdup.add_child(row)
	_rdup_label = UIKit.label("", 24, UITokens.INK, true)
	_rdup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_rdup_label)
	_rdup_bar = HeroEngravedBar.make("L", 0, 1, 220)
	_rdup_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_rdup_bar)
	_ribbon.add_child(_rdup)
	# A soft slate halo behind the whole block so the name and title read on bright art too.
	UIKit.scene_halo(_ribbon, 1.5, 1.25)
	_rseal = HeroWaxSeal.make(96)
	add_child(_rseal)


func _name_w() -> float:
	if _name == null:
		return 0.0
	var fs := _name.get_theme_font_size("font_size")
	return _name.get_theme_font("font").get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## The stage content of result `i` (splash / bust / sigil, ribbon, emblem).
func _show_result(i: int) -> void:
	if i == _cur:
		return
	_cur = i
	var r := results[i]
	var id := str(r["id"])
	var g := str(r["gem"])
	var h := HeroesUIModel.hero(id) if str(r.get("kind", "hero")) == "hero" else HeroesUIModel.champion(id)
	var st := HeroArt.state(id)
	_splash.texture = null
	_splash_open.texture = null
	_splash_open.visible = false
	_sigil.visible = false
	match st:
		"splash":
			# Signature beat (Мейра): she steps out with her eyes closed; they open last.
			var closed := HeroArt.splash_variant(id, "eyes_closed")
			_splash.texture = closed if closed else HeroArt.splash(id)
			if closed:
				_splash_open.texture = HeroArt.splash(id)
		"card":
			_splash.texture = HeroArt.card_texture(id)
		"live3d":
			_splash.texture = HeroArt.cached_portrait(id, 512)
		"silhouette":
			_splash.texture = HeroArt.silhouette(id)
	if _splash.texture == null:
		_sigil.visible = true
		_sigil.cls = str(h.get("class", "warrior"))
		_sigil.gem = g
		_sigil.queue_redraw()
	_wipe.set_shader_parameter("gem", SummonFx.hex(g))
	if _splash.texture:
		var ts := _splash.texture.get_size()
		_wipe.set_shader_parameter("aspect", ts.x / maxf(ts.y, 1.0))
	_name.text = HeroesText.name_of(id)
	_rtitle.text = HeroesText.hero_title(id) if HeroData.HEROES.has(id) else HeroesText.champ_title(id)
	for c in _chips.get_children():
		c.queue_free()
	for tag: Array in [["cls_" + str(h.get("class", "")), HeroesText.class_label(str(h.get("class", ""))), false],
			["el_" + str(h.get("element", "")), HeroesText.element_label(str(h.get("element", ""))), true],
			["fac_" + str(h.get("faction", "")), HeroesText.faction_label(str(h.get("faction", ""))), false]]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var so := UIKit.socket(str(tag[0]), 40, bool(tag[2]))
		so.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(so)
		var l := UIKit.scene_label(str(tag[1]), 24)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(l)
		_chips.add_child(hb)
	var is_new := bool(r.get("is_new", false))
	_rseal.visible = is_new
	_rdup.visible = not is_new and not bool(r.get("replay", false))
	if _rdup.visible:
		_rdup_label.text = HeroesText.t("SUMMON_TOMES", [int(r["tomes"])]) if int(r["tomes"]) > 0 else HeroesText.t("SUMMON_FRAGS", [int(r["fragments"])])
		_rdup_bar.gem = str(h.get("gem", g))
		_rdup_bar.max_value = float(maxi(1, int(h.get("frags_need", 1))))
		_rdup_bar.value = float(h.get("frags", 0))
		_rdup_bar.value_text = _frags_value(int(h.get("frags", 0)), int(h.get("frags_need", 0)))
	_emblem.gem = str(h.get("gem", g))
	_emblem.native = str(h.get("native", g)) if bool(h.get("is_recut", false)) else ""
	_name.add_theme_font_size_override("font_size", UIKit.fit_size(_name.text, _W - 2.0 * UITokens.GUTTER - 120.0, 72, 48))
	_ribbon.reset_size()
	_layout_ribbon()


## The fragment bar's value: «18 / 30» while filling; once the next facet is paid for, «Грань
## готова» (never «68 / 30», which reads like a bug; the bar itself is full with its diamond).
static func _frags_value(frags: int, need: int) -> String:
	if need > 0 and frags < need:
		return "%d / %d" % [frags, need]
	if need > 0:
		return HeroesText.t("FRAGS_FACET_READY")
	return str(frags)


func _hero_target() -> String:
	var best := ""
	var bg := -1
	for r in results:
		if str(r.get("kind", "hero")) != "hero":
			continue
		var g := Ladder.gem_index(str(r["gem"])) + (10 if bool(r["is_new"]) else 0)
		if g > bg:
			bg = g
			best = str(r["id"])
	return best


# ================================================================== layout

func _layout() -> void:
	_W = size.x
	_H = size.y
	if _W < 10.0:
		return
	_ins = UIKit.safe_insets(get_viewport())
	_cc = Vector2(_W * 0.5, _H * 0.43)
	var D := minf(_W * 0.8, _H * 0.42)
	_ring.size = Vector2(D, D)
	_ring.position = _cc - _ring.size * 0.5
	_ring.pivot_offset = _ring.size * 0.5
	_pillar.size = Vector2(_W * 0.9, _H)
	_pillar.position = Vector2((_W - _pillar.size.x) * 0.5, 0)
	_pillar_mat.set_shader_parameter("base_y", _cc.y / _H)
	for f: Control in [_back, _fx, _fx_add, _art]:
		f.position = Vector2.ZERO
		f.size = Vector2(_W, _H)
	_sigil.size = Vector2(_W, _W * 1.0)
	_sigil.position = Vector2((_W - _sigil.size.x) * 0.5, _cc.y - _sigil.size.y * 0.5 - _H * 0.03)
	_skip.size = _skip.custom_minimum_size
	_skip.position = Vector2(_W - _skip.size.x - 16.0 - _ins.z, _ins.y + 18.0)
	_scrim.size = Vector2(_W, _H * 0.46)
	_scrim.position = Vector2(0, _H * 0.54)
	_tap.size = Vector2(_W, 40)
	_tap.position = Vector2(0, _H - _ins.w - 96.0)
	var dm := _dock.get_combined_minimum_size()
	_dock.size = Vector2(_W - 2.0 * UITokens.GUTTER, dm.y)
	_dock.position = Vector2(UITokens.GUTTER, _H - _ins.w - 52.0 - dm.y)
	if _card:
		_card.size = HeroCard.SIZES["L"]
		_card.pivot_offset = _card.size * 0.5
	if _card_dup:
		_card_dup.reset_size()
	_layout_ribbon()


func _layout_ribbon() -> void:
	if _ribbon == null:
		return
	var rs := _ribbon.get_combined_minimum_size()
	_ribbon.size = Vector2(_W - 2.0 * UITokens.GUTTER, rs.y)
	# Bottom-left on the art, clear of the end-state dock.
	_ribbon.position.y = _H - _ins.w - 52.0 - 88.0 - 34.0 - rs.y


## Splash rect (the art fills ~90 % of the height; its body sits on focus_x).
func _splash_rect() -> Rect2:
	if _splash.texture == null:
		return Rect2()
	var ts := _splash.texture.get_size()
	var id := str(results[maxi(_cur, 0)]["id"])
	if HeroArt.state(id) == "live3d":
		var s := _W * 0.9
		return Rect2(Vector2(_cc.x - s * 0.5, _cc.y - s * 0.56), Vector2(s, s))
	# Painted cut-outs bleed off their own canvas (Vesta's cape and legs touch its right and bottom
	# edges), so the art always runs past the screen's bottom edge and, when narrower than the
	# screen, is right-aligned so no cut edge shows.
	var h := _H * 1.06
	var w := h * ts.x / maxf(ts.y, 1.0)
	var fx := float(HeroArt.meta(id).get("focus_x", 0.5))
	var x := _W * 0.5 - fx * w + _W * 0.04
	if x + w < _W + 12.0:
		x = _W + 12.0 - w
	return Rect2(Vector2(x, _H * 0.01), Vector2(w, h))


# ================================================================== time

func _process(delta: float) -> void:
	if _frozen or results.is_empty():
		return
	if _press_t >= 0.0 and Time.get_ticks_msec() / 1000.0 - _press_t > 0.3 and _t >= CeremonyData.SKIP_FROM:
		_press_t = -1.0
		skip_to_end()
		return
	var nt := _t + delta
	# ×10: a finished walkout waits for a tap before the next one («Торкнись, щоб продовжити»).
	if mode == "x10":
		var s := _seg_at(_t)
		if str(s.get("kind", "")) == "walk":
			var e := float(s["a"]) + float(s["len"])
			var i := int(s["idx"])
			if nt >= e and not _released.has(i):
				nt = e - 0.0001
				_hold_wait = i
	_t_prev = _t
	_t = minf(nt, _total)
	_cues()
	_render()


## Dev shots: put the ceremony at `t` seconds and freeze there.
func gallery_seek(t: float) -> void:
	_frozen = true
	_t = clampf(t, 0.0, _total)
	_t_prev = _t
	if mode == "x10":
		for s in _segs:
			if str(s["kind"]) == "walk" and float(s["a"]) + float(s["len"]) <= _t:
				_released[int(s["idx"])] = true
	_render()


## A tap finishes the current beat: the current walkout / card jumps to its end (×10 then waits
## for the next tap); at a walkout that is waiting, the tap releases it.
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (e as InputEventMouseButton).pressed:
			_press_t = Time.get_ticks_msec() / 1000.0
		else:
			_press_t = -1.0
	if not UIJuice.is_tap(e) or _t < CeremonyData.SKIP_FROM or _t >= _total:
		return
	accept_event()
	var s := _seg_at(_t)
	if _hold_wait >= 0:
		_released[_hold_wait] = true
		_hold_wait = -1
		_t = minf(_t + 0.001, _total)
		return
	var e2 := float(s["a"]) + float(s["len"])
	if str(s["kind"]) == "prologue" or str(s["kind"]) == "sort" or str(s["kind"]) == "crack":
		# Jump to the first reveal.
		for x in _segs:
			if str(x["kind"]) in ["walk", "card", "summary"]:
				e2 = float(x["a"])
				break
	_t = minf(e2 - (0.0001 if mode == "x10" and str(s["kind"]) == "walk" else 0.0), _total)
	_t_prev = _t
	_render()


## «Пропустити» / Android back: straight to the end state (grants were applied in setup()).
func skip_to_end() -> void:
	if results.is_empty():
		return
	for s in _segs:
		if str(s["kind"]) == "walk":
			_released[int(s["idx"])] = true
	_hold_wait = -1
	_t = _total
	_t_prev = _t
	_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if _t < _total:
			skip_to_end()
		else:
			_close()


func _close() -> void:
	if _done_close:
		return
	_done_close = true
	# NEW stays marked in the Hall until the player opens the hero (the Showcase calls mark_seen).
	closed.emit()


func _open_hero(id: String) -> void:
	var h := hub
	_close()
	if HeroesNav.available("hero/" + id):
		HeroesNav.open(h, "hero/" + id)


# ================================================================== cues (sound + haptics)

func _cue_at(key: String, at: float) -> bool:
	if _fired.has(key) or _t_prev >= at or _t < at:
		return false
	_fired[key] = true
	return true


func _cues() -> void:
	var P := float(CeremonyData.CEREMONY["prologue"])
	if mode in ["x1", "x10"] and not _reduce:
		if _cue_at("spin", 0.0001):
			Audio.play("whoosh_gate", -8.0)
		if _cue_at("tell", P):
			Audio.chord(int(RING_STEP.get(_best, 5)), true, -6.0)
			if Ladder.gem_index(_best) >= 2:
				UIJuice.haptic_pattern("rarity_" + _best)
	for s in _segs:
		var a := float(s["a"])
		var kind := str(s["kind"])
		if kind == "crack" and _cue_at("crack%f" % a, a):
			Audio.play("geode_break", -6.0)
		elif kind == "card":
			var g := str(results[0]["gem"])
			var b: Dictionary = CARD.get(g, CARD["C"])
			var sc := float(s["len"]) / float(b["ref"])
			if _cue_at("cardcrack", a + float(b["crack"]) * sc):
				Audio.play("geode_break", -8.0)
			if bool(results[0]["is_new"]) and _cue_at("cardstamp", a + float(b["stamp"]) * sc):
				Audio.play("upgrade", -6.0)
				UIJuice.haptic("TICK", 0.4)
		elif kind == "walk":
			var i := int(s["idx"])
			var bt := _beats(s)
			if _cue_at("p%d" % i, a + 0.001):
				Audio.play("whoosh_gate", -4.0)
				UIJuice.haptic("THUD", 0.7)
			if bt.has("cls"):
				for k: String in ["cls", "el", "fac"]:
					if _cue_at(k + str(i), a + float(bt[k])):
						Audio.note(6 + ["cls", "el", "fac"].find(k) * 2, -10.0)
						UIJuice.haptic("TICK", 0.5)
			if _cue_at("sh%d" % i, a + float(bt["shatter"])):
				Audio.play("geode_break", 0.0)
				UIJuice.haptic_pattern("rarity_" + str(results[i]["gem"]))
			if _cue_at("nm%d" % i, a + float(bt["name"])):
				Audio.play("weapon_get", -4.0)
				UIJuice.haptic("THUD", 0.9)
			if bool(results[i].get("is_new", false)) and _cue_at("st%d" % i, a + float(bt["hold"])):
				Audio.play("upgrade", -6.0)
		elif kind == "summary" and _cue_at("sum", a + 0.05):
			for k in 3:
				Audio.note(5 + k * 3, -10.0 - k)


## The absolute beat offsets (seconds from the walk start) of walk segment `s`.
func _beats(s: Dictionary) -> Dictionary:
	var g := str(results[int(s["idx"])]["gem"])
	var kind := str(s["walk"])
	var L := float(s["len"])
	var src: Dictionary = SHORT
	match kind:
		"full": src = BEATS.get(g, BEATS["E"])
		"seal": src = SEAL
		"static": src = {"pillar": 0.0, "land": 0.0, "shatter": 0.0, "hit": 0.0, "step": 0.0, "wipe": 0.0, "emblem": 0.0, "name": 0.0, "hold": 0.2, "ref": 1.0}
	var k := L / float(src["ref"])
	var out := {}
	for key: String in src:
		out[key] = float(src[key]) * k
	return out


# ================================================================== render

func _render() -> void:
	if results.is_empty() or _sky == null:
		return
	var t := _t
	var seg := _seg_at(t)
	var kind := str(seg.get("kind", ""))
	var P := float(CeremonyData.CEREMONY["prologue"])
	var fw := _first_walk_a()
	_sky.t = t + 4.0
	# ---- the Portal stage (prologue / sort / crack / ×1 card)
	var stage_a := 1.0 - SummonFx.seg(t, fw, 0.25)
	if _reduce and mode == "x1":
		stage_a = 0.0 if kind == "walk" else 1.0
	_ring.visible = stage_a > 0.0 and mode in ["x1", "x10"]
	_ring.modulate.a = stage_a
	_ring.t = t + 3.0
	var told := SummonFx.seg(t, P, 0.12) if not _reduce else 1.0
	var push := SummonFx.inout(SummonFx.seg(t, 0.0, 0.4))
	_ring.scale = Vector2.ONE * (1.0 + 0.06 * push - 0.02 * SummonFx.seg(t, P, 0.3))
	_ring.charge = 0.2 + 0.5 * push + 0.3 * told
	_ring.pulse = SummonFx.seg(t, 0.4, 0.2) if t >= 0.4 and t < 0.6 else -1.0
	var lp := Ladder.gem_index(_best) >= 3
	_ring.crawl = SummonFx.seg(t, 0.35, 0.25) if lp and t < P + 0.05 else 0.0
	if told > 0.0:
		_ring.set_tint(SummonFx.hex(_best).lerp(Color("#A88CFF"), 1.0 - told), Color("#FFE6A3").lerp(SummonFx.hex(_best).lightened(0.5), told))
		_ring.lit = _best
		_ring.lit_k = told
		_ring.opal = told if _best == "M" else 0.0
	else:
		_ring.set_tint(Color("#A88CFF"), Color("#FFE6A3"))
		_ring.lit_k = 0.0
		_ring.opal = 0.0
	# Opal tell: the world greys (only the stones keep colour) until the opal steps out.
	var desat := 0.0
	if _best == "M" and mode in ["x1", "x10"] and not _reduce:
		desat = 0.85 * SummonFx.seg(t, P, 0.3)
	# ---- the tell column: from the tell the portal column takes the best gem's colour
	# (Topaz+: twin pillars), until the first walkout / summary takes over.
	var col_a := 0.0
	if mode in ["x1", "x10"] and not _reduce and t >= P:
		col_a = 0.38 * SummonFx.seg(t, P, 0.15) * stage_a
	# ---- defaults for the walk stage
	var dim := 0.0
	var burst_a := 0.0
	var burst_col := SummonFx.hex(_best)
	_art.visible = false
	_ribbon.visible = false
	_rseal.visible = false
	_emblem.visible = false
	_pillar.visible = col_a > 0.0
	if _pillar.visible:
		_pillar_mat.set_shader_parameter("t", t)
		_pillar_mat.set_shader_parameter("color", SummonFx.pillar_color(_best))
		_pillar_mat.set_shader_parameter("intensity", col_a)
		_pillar_mat.set_shader_parameter("twin", 1.0 if Ladder.gem_index(_best) >= 3 else 0.0)
		_pillar_mat.set_shader_parameter("opal", 1.0 if _best == "M" else 0.0)
		_pillar_mat.set_shader_parameter("width", 0.07)
	if _card:
		_card.visible = false
		_card_seal.visible = false
		_card_dup.visible = false
	_fx.state = {}
	_fx_add.state = {}
	_back.state = {}
	var st := {"t": t, "told": told, "stage_a": stage_a, "seg": kind}
	# ---- per segment
	match kind:
		"walk":
			var wi := int(seg["idx"])
			_show_result(wi)
			var u := t - float(seg["a"])
			var bt := _beats(seg)
			var g := str(results[wi]["gem"])
			var walk := str(seg["walk"])
			var r := _render_walk(u, bt, g, walk, float(seg["len"]))
			dim = float(r["dim"])
			burst_a = float(r["burst"])
			burst_col = SummonFx.hex(g)
			if g == "M" and desat > 0.0:
				desat *= 1.0 - SummonFx.seg(u, float(bt["step"]), 0.4)
			st["walk"] = r
			st["gem"] = g
			st["walk_kind"] = walk
		"card":
			_render_card(t - float(seg["a"]), float(seg["len"]), st)
		"summary":
			dim = 0.45
	if mode == "x10" and _summary:
		var sa := _first_summary_a()
		_summary.visible = t >= sa
		if _summary.visible:
			_summary.render(t - sa)
			dim = 0.45
			desat = 0.0
	_sky.dim = dim
	_sky.desat = desat
	_sky.set_burst(burst_col, burst_a, Vector2(0.5, _cc.y / maxf(_H, 1.0)))
	_fx.state = st
	_fx_add.state = st
	_back.state = st
	_fx.queue_redraw()
	_fx_add.queue_redraw()
	_back.queue_redraw()
	# ---- chrome
	var ended := t >= _total - 0.0001
	_skip.visible = t >= CeremonyData.SKIP_FROM and not ended
	_dock.visible = ended
	_dock.modulate.a = 1.0
	_scrim.visible = kind == "walk" or (kind == "card" and t >= _total - 0.0001)
	_scrim.modulate.a = 1.0 if ended else SummonFx.seg(t, float(seg.get("a", 0.0)) + float(seg.get("len", 0.0)) * 0.6, 0.4)
	_tap.visible = mode == "x10" and _hold_wait >= 0 and not ended
	if mode == "x10" and kind == "walk" and not ended:
		var e := float(seg["a"]) + float(seg["len"])
		_tap.visible = t >= e - 0.01
	if ended and mode != "x10" and _cur >= 0:
		_tap.visible = false


func _first_summary_a() -> float:
	for s in _segs:
		if str(s["kind"]) == "summary":
			return float(s["a"])
	return INF


## One walkout at `u` seconds (beats `bt`). Sets the nodes; returns {dim, burst, ...} for the FX.
func _render_walk(u: float, bt: Dictionary, g: String, walk: String, L: float) -> Dictionary:
	var out := {"u": u, "bt": bt, "len": L}
	var stat := walk == "static"
	var sh := float(bt["shatter"])
	var step := float(bt["step"])
	# Light pillar: up at once, holds until the shatter, then thins out behind the hero.
	var pa := SummonFx.seg(u, float(bt["pillar"]), 0.22) * (1.0 - 0.8 * SummonFx.seg(u, sh, 0.25))
	if stat:
		pa = 0.0
	_pillar.visible = pa > 0.0
	_pillar_mat.set_shader_parameter("t", _t)
	_pillar_mat.set_shader_parameter("color", SummonFx.pillar_color(g))
	_pillar_mat.set_shader_parameter("intensity", pa * {"C": 0.75, "M": 0.62}.get(g, 0.85))
	_pillar_mat.set_shader_parameter("twin", 1.0 if Ladder.gem_index(g) >= 3 else 0.0)
	_pillar_mat.set_shader_parameter("opal", 1.0 if g == "M" else 0.0)
	_pillar_mat.set_shader_parameter("width", 0.11 if walk == "full" else 0.08)
	out["dim"] = lerpf(0.0, 0.62, SummonFx.seg(u, 0.0, 0.25)) if not stat else 0.5
	out["burst"] = ((0.55 * SummonFx.seg(u, 0.0, 0.3) + 0.25 * SummonFx.seg(u, step, 0.4) - 0.3 * SummonFx.seg(u, step + 0.5, 0.8)) * (0.7 if g == "M" else 1.0)) if not stat else 0.3
	# Crystal (before the shatter), cracks in the last 0.6 s before it.
	# Hit-stop: the cracked crystal holds white-hot for `hit` seconds, then the shards fly.
	var hit := float(bt.get("hit", 0.0))
	out["crystal"] = SummonFx.seg(u, 0.0, maxf(float(bt["land"]), 0.05)) if u < sh + hit and not stat else 0.0
	out["crack"] = SummonFx.seg(u, maxf(0.0, sh - 0.6), minf(0.6, sh)) if not stat else 0.0
	out["hot"] = SummonFx.seg(u, sh, maxf(hit, 0.01)) if not stat else 0.0
	out["shard_u"] = u - sh - hit if not stat else -1.0
	# Flashes (one per shatter, opal two 300 ms apart), capped.
	var fl := 0.0 if stat else SummonFx.flash(u, sh + hit * 0.5, 0.45)
	if g == "M" and walk == "full":
		fl = maxf(fl, SummonFx.flash(u, sh + hit * 0.5 + 0.3, 0.36))
	out["flash"] = minf(fl, SummonFx.FLASH_PEAK)
	# Step-out: the splash appears through the facet wipe, scale up, parallax slide, rim light.
	var wk := SummonFx.seg(u, step, maxf(float(bt["wipe"]), 0.05)) if not stat else SummonFx.seg(u, 0.0, 0.3)
	var mv := SummonFx.seg(u, step, 0.6) if not stat else 1.0
	_art.visible = u >= step or stat
	var base_s := {"E": 0.92, "L": 0.9, "M": 0.88}.get(g, 0.94) as float
	var sc := lerpf(base_s, 1.0, SummonFx.back(mv, 1.2)) if not stat else 1.0
	var drift := -6.0 * maxf(0.0, u - step - 0.6)
	var px := 70.0 * (1.0 - SummonFx.out3(mv)) + drift
	if _splash.texture:
		var rr := _splash_rect()
		_splash.position = rr.position + Vector2(px, 0)
		_splash.size = rr.size
		_splash.pivot_offset = rr.size * Vector2(float(HeroArt.meta(str(results[_cur]["id"])).get("focus_x", 0.5)), 0.4)
		_splash.scale = Vector2(sc, sc)
		_wipe.set_shader_parameter("progress", wk if not stat else 1.0)
		_wipe.set_shader_parameter("rim", (1.0 - 0.65 * SummonFx.seg(u, step + 0.4, 0.8)) if not stat else 0.35)
		_splash.modulate.a = 1.0 if not stat else wk
		if _splash_open.texture:
			# The eyes open just after the name lands (Reduce Motion: open from the start).
			var eo := SummonFx.seg(u, float(bt["name"]) + 0.25, 0.35) if not stat else 1.0
			_splash_open.visible = eo > 0.0
			_splash_open.modulate.a = eo
	if _sigil.visible:
		_sigil.pivot_offset = _sigil.size * 0.5
		_sigil.scale = Vector2(sc, sc)
		_sigil.position = Vector2((_W - _sigil.size.x) * 0.5 + px, _cc.y - _sigil.size.y * 0.5 + _H * 0.015 + sin(_t * 1.4) * 4.0)
		# Reduce Motion: no white-hot cooling, a plain cross-fade.
		_sigil.reveal = wk if not stat else 1.0
		_sigil.modulate.a = 1.0 if not stat else wk
		_sigil.t = _t
		_sigil.queue_redraw()
	out["step_k"] = mv
	out["wipe"] = wk
	# Emblem: flies from the crystal to the top-left, overshoots, and rings.
	var em := SummonFx.seg(u, float(bt["emblem"]), 0.35) if not stat else 1.0
	_emblem.visible = em > 0.0
	if _emblem.visible:
		var dest := Vector2(UITokens.GUTTER + 6.0, _ins.y + 112.0)
		var from := _cc - _emblem.size * 0.5
		_emblem.position = from.lerp(dest, SummonFx.back(em, 1.1))
		var es := lerpf(2.2, 1.0, SummonFx.out3(em))
		_emblem.pivot_offset = _emblem.size * 0.5
		_emblem.scale = Vector2(es, es)
		_emblem.modulate.a = clampf(em * 4.0, 0.0, 1.0)
		_emblem.live = false
	out["emblem_ring"] = SummonFx.seg(u, float(bt["emblem"]) + 0.35, 0.5) if not stat else 0.0
	out["emblem_c"] = Vector2(UITokens.GUTTER + 6.0, _ins.y + 112.0) + _emblem.size * 0.5
	# Name ribbon: slides in, the name slams 1.3 -> 1.0, title +0.12 s, chips 60 ms apart.
	var nk := SummonFx.seg(u, float(bt["name"]), 0.18) if not stat else SummonFx.seg(u, 0.0, 0.3)
	_ribbon.visible = nk > 0.0
	if _ribbon.visible:
		_ribbon.position.x = lerpf(UITokens.GUTTER - 90.0, UITokens.GUTTER, SummonFx.out3(nk)) if not stat else UITokens.GUTTER
		_ribbon.modulate.a = clampf(nk * 2.0, 0.0, 1.0)
		var ns := lerpf(1.3, 1.0, SummonFx.out3(nk)) if not stat else 1.0
		_name.pivot_offset = Vector2(0, _name.size.y * 0.5)
		_name.scale = Vector2(ns, ns)
		_rtitle.modulate.a = SummonFx.seg(u, float(bt["name"]) + 0.12, 0.2) if not stat else 1.0
		var ci := 0
		for c in _chips.get_children():
			(c as Control).modulate.a = SummonFx.seg(u, float(bt["name"]) + 0.2 + 0.06 * ci, 0.16) if not stat else 1.0
			ci += 1
		_rdup.modulate.a = SummonFx.seg(u, float(bt["hold"]), 0.2) if not stat else 1.0
	# NEW tag: presses in at the hold beat (from 1.15, a soft 0.94 squash, settle), scaled about its
	# LEFT edge, so it never grows back over the name's last letter.
	var r := results[_cur]
	var sk := SummonFx.seg(u, float(bt["hold"]), 0.36) if not stat else 1.0
	_rseal.visible = bool(r.get("is_new", false)) and sk > 0.0 and _ribbon.visible
	if _rseal.visible:
		var tw := _rseal.drawn_size().x
		_rseal.pivot_offset = Vector2((_rseal.size.x - tw) * 0.5, _rseal.size.y * 0.5)
		var nx := minf(_ribbon.position.x + _name_w() + 22.0 + (tw - _rseal.size.x) * 0.5, _W - 12.0 - (_rseal.size.x + tw) * 0.5)
		_rseal.position = Vector2(nx, _ribbon.position.y + _name.size.y * 0.5 - _rseal.size.y * 0.5)
		var sq := 1.15 - 0.21 * SummonFx.in2(sk / 0.4) if sk < 0.4 else lerpf(0.94, 1.0, SummonFx.out3((sk - 0.4) / 0.6))
		_rseal.scale = Vector2.ONE * sq
		_rseal.modulate.a = clampf(sk * 5.0, 0.0, 1.0)
	out["motes"] = SummonFx.seg(u, float(bt["hold"]) - 0.3, 0.6) if not stat else 0.0
	out["rays"] = SummonFx.seg(u, float(bt.get("gather", step)), 0.4) * (1.0 if not stat else 0.0)
	out["seal_stream"] = SummonFx.seg(u, 0.0, 0.3) if walk == "seal" else -1.0
	out["sig"] = str(SIGNATURE.get(str(r["id"]), "")) if walk == "full" else ""
	return out


## ×1 Кварц / Сапфір: the seed cracks and the card flies to the centre (NEW: crystallise + stamp;
## duplicate: the fragments line and the bar).
func _render_card(u: float, L: float, st: Dictionary) -> void:
	var r := results[0]
	var g := str(r["gem"])
	if _card == null:
		return
	var b: Dictionary = CARD.get(g, CARD["C"])
	var k := L / float(b["ref"])
	var reduce := _reduce
	var ck := SummonFx.seg(u, float(b["card"]) * k, 0.3) if not reduce else SummonFx.seg(u, 0.0, L)
	st["crack_u"] = u - float(b["crack"]) * k if not reduce else -1.0
	st["card_gem"] = g
	_card.visible = ck > 0.0
	# The L card at 1.3x: the ×1 Кварц / Сапфір reveal fills the stage, not a thumbnail in the ring.
	var cs: Vector2 = HeroCard.SIZES["L"]
	var big := 1.3
	var vs := cs * big
	var dest := _cc - cs * 0.5 + Vector2(0, -10)
	var from := _cc - cs * 0.5
	_card.size = cs
	_card.pivot_offset = cs * 0.5
	_card.position = from.lerp(dest, SummonFx.out3(ck))
	var pop := 1.0 + 0.04 * sin(PI * clampf(ck, 0.0, 1.0)) if not reduce else 1.0
	_card.scale = Vector2.ONE * big * (lerpf(0.5, 1.0, SummonFx.out3(ck)) * pop if not reduce else 1.0)
	_card.modulate.a = clampf(ck * 3.0, 0.0, 1.0)
	var vis := Rect2(_card.position + cs * 0.5 - vs * 0.5, vs)
	st["card_rect"] = vis
	st["card_new"] = SummonFx.seg(u, float(b["new"]) * k, 0.3) if bool(r["is_new"]) and not reduce else (1.0 if bool(r["is_new"]) else 0.0)
	st["card_glint"] = SummonFx.seg(u, float(b.get("glint", 99.0)) * k, 0.4)
	var sk := SummonFx.seg(u, float(b["stamp"]) * k, 0.3) if not reduce else 1.0
	_card_seal.visible = bool(r["is_new"]) and sk > 0.0
	if _card_seal.visible:
		_card_seal.pivot_offset = _card_seal.size * 0.5
		var vd := Rect2(dest + cs * 0.5 - vs * 0.5, vs)
		# The «НОВИЙ» tag rides the card's top edge, inside its right corner.
		_card_seal.position = vd.position + Vector2(vs.x - 6.0 - _card_seal.drawn_size().x * 0.5 - _card_seal.size.x * 0.5, -_card_seal.size.y * 0.5)
		var sq := 1.15 - 0.21 * SummonFx.in2(sk / 0.4) if sk < 0.4 else lerpf(0.94, 1.0, SummonFx.out3((sk - 0.4) / 0.6))
		_card_seal.scale = Vector2.ONE * sq
		_card_seal.modulate.a = clampf(sk * 5.0, 0.0, 1.0)
	_card_dup.visible = not bool(r["is_new"]) and ck >= 1.0
	if _card_dup.visible:
		_card_dup.reset_size()
		_card_dup.position = Vector2((_W - _card_dup.size.x) * 0.5, dest.y + cs.y * 0.5 + vs.y * 0.5 + 30.0)
		# Fully opaque by the end of the beat (it used to stop at ~0.75 when the beat is short, so
		# the dais showed through the slip and the label fell to 3.8:1).
		var d0 := minf(float(b["card"]) * k + 0.25, L - 0.2)
		_card_dup.modulate.a = SummonFx.seg(u, d0, 0.2) if not reduce else 1.0


## A deterministic FX layer: "back" (additive light behind the art), "mid" (seeds, crystal, cracks,
## shards, identity glyphs) and "front" (additive motes, glints, the emblem ring).
class _Fx extends Control:
	var owner_c: SummonCeremony
	var layer := "mid"
	var additive := false
	var state: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		if additive:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = m

	func _draw() -> void:
		if owner_c == null or state.is_empty():
			return
		owner_c._draw_layer(self, layer, state)


func _draw_layer(ci: Control, layer: String, st: Dictionary) -> void:
	var t := float(st["t"])
	match layer:
		"back":
			if st.has("walk"):
				var w: Dictionary = st["walk"]
				var g := str(st["gem"])
				var col := SummonFx.hex(g)
				var u := float(w["u"])
				var bt: Dictionary = w["bt"]
				# Background fracture planes of the gem (parallax: they move slower than the hero).
				var fa := SummonFx.seg(u, 0.0, 0.3)
				if fa > 0.0 and str(st["walk_kind"]) != "static":
					var off := Vector2(24.0 * (1.0 - SummonFx.out3(float(w["step_k"]))), 0)
					ci.draw_set_transform(off, 0.0, Vector2.ONE)
					KitGemCard.draw_stage_fracture(ci, UITokens.gem_of(g), Rect2(Vector2.ZERO, ci.size))
					KitGemCard.draw_stage_fracture(ci, UITokens.gem_of(g), Rect2(Vector2(-_W * 0.3, _H * 0.2), ci.size))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				# The placeholder plate's rim light.
				if _sigil.visible and float(w["wipe"]) > 0.0:
					var sc2 := _sigil.position + _sigil.size * 0.5
					var sr := _sigil.stone_px() * 1.25
					var gl := col.lightened(0.3)
					ci.draw_texture_rect(UIKit.glow_texture(), Rect2(sc2 - Vector2(sr, sr), Vector2(sr, sr) * 2.0), false, Color(gl.r, gl.g, gl.b, 0.6 * float(w["wipe"])))
				# God rays behind the crystal / hero.
				var ra := 0.35 * SummonFx.seg(u, 0.0, 0.4) + 0.65 * float(w["rays"])
				SummonFx.draw_rays(ci, _cc, _H * 0.62, col.lightened(0.2), ra, t * 0.05, 11)
				SummonFx.draw_glow(ci, _cc, _W * (0.55 + 0.25 * float(w["step_k"])), col, 0.38 * fa * (1.0 - 0.45 * SummonFx.seg(u, float(bt["step"]) + 0.5, 0.8)))
				if g == "M":
					for i in 4:
						var hc := SummonFx.spectral(t * 0.08 + i * 0.25, 0.5, 1.0)
						SummonFx.draw_glow(ci, _cc + Vector2(cos(t * 0.4 + i * 1.6), sin(t * 0.3 + i * 1.6)) * _W * 0.24, _W * 0.3, hc, 0.1 * fa)
		"mid":
			_draw_stage(ci, st)
			if st.has("walk"):
				_draw_walk_mid(ci, st)
			if str(st["seg"]) == "card":
				_draw_card_fx(ci, st)
		"front":
			if st.has("walk"):
				var w: Dictionary = st["walk"]
				var g := str(st["gem"])
				var col := SummonFx.hex(g)
				var mc := col.lightened(0.45)
				SummonFx.draw_motes(ci, Rect2(0, _H * 0.1, _W, _H * 0.8), mc, t, 26, float(w["motes"]) * 0.9, hash(g))
				# The shatter flash: a radial white burst from the crystal (<= FLASH_PEAK white).
				var fla := float(w.get("flash", 0.0))
				if fla > 0.0:
					ci.draw_texture_rect(UIKit.glow_texture(), Rect2(_cc - Vector2(_W, _W) * 0.55, Vector2(_W, _W) * 1.1), false, Color(1, 1, 1, fla))
				# Shockwave ring from the shatter in the gem colour.
				var swu := float(w["shard_u"])
				if swu >= 0.0 and swu < 0.6:
					SummonFx.draw_ring_pulse(ci, _cc, 60.0, _W * 0.7, swu / 0.6, col.lightened(0.3), 10.0)
				var er := float(w["emblem_ring"])
				SummonFx.draw_ring_pulse(ci, w["emblem_c"], 40.0, 120.0, er, col.lightened(0.4), 4.0)
				# Shatter glints.
				var su := float(w["shard_u"])
				if su >= 0.0 and su < 0.5:
					var rng := RandomNumberGenerator.new()
					rng.seed = hash(g + "gl")
					for i in 8:
						var p := _cc + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 220.0 * (0.4 + su * 1.6)
						GemDraw.draw_glint(ci, p, 34.0 * (1.0 - su * 1.8), Color(1, 1, 1, 0.9 * (1.0 - su * 2.0)))
				# Topaz: a five-ray sunburst flares as Vesta steps out (her signature beat, ≤ 0.45 s).
				var bt: Dictionary = w["bt"]
				var sb := SummonFx.seg(float(w["u"]), float(bt["step"]) + 0.05, 0.45)
				if g == "L" and sb > 0.0 and sb < 1.0:
					for i in 5:
						var a := -PI / 2.0 + TAU * i / 5.0
						var d := Vector2(cos(a), sin(a))
						var n := Vector2(-d.y, d.x) * 18.0 * (1.0 - sb)
						var L := _W * 0.75 * SummonFx.out3(sb)
						var c0 := Color(1.0, 0.85, 0.45, 0.5 * (1.0 - sb))
						var c1 := Color(1.0, 0.85, 0.45, 0.0)
						ci.draw_polygon(PackedVector2Array([_cc + n, _cc + d * L, _cc - n]), PackedColorArray([c0, c1, c0]))
				# Opal: the spectrum splits across the planes as it descends.
				if g == "M" and sb > 0.0 and sb < 1.0:
					# Lumen's signature: a spectrum split by its prism falls across the planes.
					var apex := Vector2(_cc.x, _H * 0.08)
					for i in 7:
						var hc := SummonFx.spectral(float(i) / 7.0, 0.45, 1.0)
						var x0 := _W * (-0.1 + 1.2 * float(i) / 7.0)
						var x1 := _W * (-0.1 + 1.2 * float(i + 1) / 7.0)
						var y := _H * 0.95
						var ca := Color(hc.r, hc.g, hc.b, 0.16 * sin(PI * sb))
						var cz := Color(hc.r, hc.g, hc.b, 0.0)
						ci.draw_polygon(PackedVector2Array([apex, Vector2(x1, y), Vector2(x0, y)]), PackedColorArray([cz, ca, ca]))
			if str(st["seg"]) == "card" and float(st.get("card_glint", 0.0)) > 0.0:
				var gk := float(st["card_glint"])
				if gk < 1.0:
					var rr: Rect2 = st["card_rect"]
					var x := rr.position.x + rr.size.x * (gk * 1.4 - 0.2)
					ci.draw_polygon(PackedVector2Array([Vector2(x - 30, rr.position.y), Vector2(x + 10, rr.position.y), Vector2(x - 50, rr.end.y), Vector2(x - 90, rr.end.y)]),
							PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)]))
			if float(st["stage_a"]) > 0.0 and mode in ["x1", "x10"]:
				# Seed sparkle (additive) once told: a small glint, never a bloom over the cut.
				for sd in _seeds(t):
					var a2 := float(sd["a"]) * float(st["told"]) * float(st["stage_a"])
					if a2 > 0.0:
						var ss := float(sd["size"])
						GemDraw.draw_glint(ci, (sd["pos"] as Vector2) + Vector2(-ss * 0.18, -ss * 0.2), ss * 0.42, Color(1, 1, 1, 0.55 * a2 * (0.6 + 0.4 * sin(t * 5.0 + float(sd["i"])))))


## Seeds: positions, sizes and alphas at time t (the ring stage of ×1 / ×10).
func _seeds(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mode == "x1":
		var r := results[0]
		var rise := SummonFx.out3(SummonFx.seg(t, 0.0, 0.4))
		var bob := sin(t * 3.0) * 4.0
		var s := 92.0
		var pos := _cc + Vector2(0, lerpf(_ring.size.y * 0.55, 0.0, rise) + bob)
		var a := clampf(rise * 2.0, 0.0, 1.0)
		var seg := _seg_at(t)
		if str(seg.get("kind", "")) == "card":
			var b: Dictionary = CARD.get(str(r["gem"]), CARD["C"])
			var cu := t - float(seg["a"]) - float(b["crack"]) * float(seg["len"]) / float(b["ref"])
			if cu >= 0.0:
				a = 0.0
		out.append({"pos": pos, "size": s, "gem": str(r["gem"]), "a": a, "i": 0})
		return out
	# ×10: an arc across the ring; the sort glides them into ascending gem order.
	var n := results.size()
	var order: Array[int] = []
	for i in n:
		order.append(i)
	var sorted := order.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var ga := Ladder.gem_index(str(results[a]["gem"]))
		var gb := Ladder.gem_index(str(results[b]["gem"]))
		return ga < gb if ga != gb else a < b)
	var sort_k := SummonFx.inout(SummonFx.seg(t, float(CeremonyData.CEREMONY["prologue"]) + 0.25, 0.3))
	var R := _ring.size.x * 0.39 * 0.78
	var crack_a := INF
	for sgm in _segs:
		if str(sgm["kind"]) == "crack":
			crack_a = float(sgm["a"])
	for i in n:
		var slot0 := i
		var slot1 := sorted.find(i)
		var f0 := float(slot0) / maxf(n - 1, 1)
		var f1 := float(slot1) / maxf(n - 1, 1)
		var f := lerpf(f0, f1, sort_k)
		var ang := lerpf(PI * 1.12, PI * 1.88, f)
		var rise := SummonFx.out3(SummonFx.seg(t, 0.03 * i, 0.4))
		var target := _cc + Vector2(cos(ang) * R * 1.05, sin(ang) * R * 0.55 + R * 0.25)
		var pos := (_cc + Vector2(cos(ang) * R * 1.05, R * 1.4)).lerp(target, rise) + Vector2(0, sin(t * 3.0 + i) * 3.0)
		var g := str(results[i]["gem"])
		var a := clampf(rise * 2.0, 0.0, 1.0)
		if Ladder.gem_index(g) < 2 and t >= crack_a + 0.1:
			a = 0.0
		out.append({"pos": pos, "size": 44.0 + 8.0 * float(Ladder.gem_index(g) >= 2), "gem": g, "a": a, "i": i})
	return out


func _draw_stage(ci: Control, st: Dictionary) -> void:
	var t := float(st["t"])
	var sa := float(st["stage_a"])
	if sa <= 0.0 or not mode in ["x1", "x10"]:
		return
	var told := float(st["told"])
	var seeds := _seeds(t)
	# The gem-light halo goes UNDER the stones (normal blend, capped), so the cut stays readable.
	for sd in seeds:
		var a := float(sd["a"]) * sa * told
		if a > 0.0:
			var g2 := str(sd["gem"])
			var hc := SummonFx.hex(g2)
			ci.draw_texture_rect(UIKit.glow_texture(), Rect2((sd["pos"] as Vector2) - Vector2.ONE * float(sd["size"]) * 1.05, Vector2.ONE * float(sd["size"]) * 2.1), false, Color(hc.r, hc.g, hc.b, (0.45 if Ladder.gem_index(g2) >= 2 else 0.3) * a))
	for sd in seeds:
		var a := float(sd["a"]) * sa
		if a <= 0.0:
			continue
		SummonFx.draw_crystal(ci, str(sd["gem"]), sd["pos"], float(sd["size"]), told, a, t)
		if told > 0.5:
			# A light rim on top of everything so the cut reads against the ring's light.
			var rp := GemDraw.cut_points(SummonFx.cut(str(sd["gem"])), sd["pos"], float(sd["size"]) * 1.02)
			GemDraw.outline(ci, rp, Color(1, 1, 1, 0.75 * a), 1.6)
	# ×10 batch crack: the Кварц and Сапфір seeds crack together and burst into shards.
	for sgm in _segs:
		if str(sgm["kind"]) != "crack":
			continue
		var a0 := float(sgm["a"])
		if t < a0 or t > a0 + 0.8:
			continue
		var t_seeds := _seeds(a0 - 0.0001)
		for sd in t_seeds:
			var g := str(sd["gem"])
			if Ladder.gem_index(g) >= 2:
				continue
			var cu := t - a0
			if cu < 0.1:
				SummonFx.draw_crystal(ci, g, sd["pos"], float(sd["size"]), 1.0, sa, t)
				SummonFx.draw_cracks(ci, g, sd["pos"], float(sd["size"]) * 0.5, cu / 0.1, Color(1, 1, 1, 0.9))
			else:
				SummonFx.draw_shards(ci, g, sd["pos"], float(sd["size"]) * 0.5, cu - 0.1, 0.4, 7)


func _draw_card_fx(ci: Control, st: Dictionary) -> void:
	var cu := float(st.get("crack_u", -1.0))
	var g := str(st.get("card_gem", "C"))
	var sd: Dictionary = _seeds(float(st["t"]))[0]
	if cu >= -0.12 and cu < 0.0:
		SummonFx.draw_cracks(ci, g, _cc, 46.0, 1.0 + cu / 0.12, Color(1, 1, 1, 0.9))
	if cu >= 0.0:
		SummonFx.draw_shards(ci, g, sd["pos"], 46.0, cu, 0.4, 6 if g == "C" else 8)
	# NEW: the card crystallises from a frosted veil (facet wipe drawn over the card).
	var nk := float(st.get("card_new", 0.0))
	if bool(results[0]["is_new"]) and nk < 1.0 and st.has("card_rect"):
		var rr: Rect2 = st["card_rect"]
		var cols := 6
		var rows := 8
		var cw := rr.size.x / cols
		var chh := rr.size.y / rows
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var col := SummonFx.hex(g).lerp(Color(1, 1, 1), 0.55)
		for yy in rows:
			for xx in cols:
				var c := rr.position + Vector2((xx + 0.5) * cw, (yy + 0.5) * chh)
				var d := c.distance_to(rr.get_center()) / rr.size.length() * 2.0
				var p0 := c + Vector2(-cw, -chh) * 0.5
				var p1 := c + Vector2(cw, -chh) * 0.5
				var p2 := c + Vector2(cw, chh) * 0.5
				var p3 := c + Vector2(-cw, chh) * 0.5
				var flip := (xx + yy) % 2 == 0
				var tris := [PackedVector2Array([p0, p1, p2]), PackedVector2Array([p0, p2, p3])] if flip else [PackedVector2Array([p0, p1, p3]), PackedVector2Array([p1, p2, p3])]
				for tri: PackedVector2Array in tris:
					var thr := d * 0.75 + rng.randf() * 0.25
					var a := 1.0 - SummonFx.seg(nk, thr, 0.18)
					if a <= 0.0:
						continue
					ci.draw_colored_polygon(tri, Color(col.r, col.g, col.b, 0.9 * a))
					GemDraw.outline(ci, tri, Color(1, 1, 1, 0.5 * a), 1.0)


func _draw_walk_mid(ci: Control, st: Dictionary) -> void:
	var w: Dictionary = st["walk"]
	var g := str(st["gem"])
	var t := float(st["t"])
	var u := float(w["u"])
	var bt: Dictionary = w["bt"]
	var kind := str(st["walk_kind"])
	var size := {"E": 330.0, "L": 370.0, "M": 380.0}.get(g, 330.0) as float
	if kind == "short" or kind == "seal":
		size *= 0.82
	# Seal pick: the Seals stream from the bottom into the ring.
	var ss := float(w["seal_stream"])
	if ss >= 0.0 and ss < 1.0:
		for i in 8:
			var k := clampf(ss * 1.6 - float(i) * 0.08, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var p := Vector2(_W * 0.5 + (float(i) - 3.5) * 40.0, _H * 0.92).lerp(_cc, SummonFx.inout(k))
			HeroIcons.paint(ci, "seal", Rect2(p - Vector2(22, 22), Vector2(44, 44)), Color(1, 1, 1, 1.0 - k * 0.6))
	var ck := float(w["crystal"])
	if ck > 0.0:
		# The crystal grows in its cut and lands (ease-out-back), gathering pulses before the shatter.
		var land := SummonFx.back(ck, 1.6)
		var gather := 0.0
		if bt.has("gather"):
			var gu := u - float(bt["gather"])
			if gu > 0.0 and gu < float(bt["shatter"]) - float(bt["gather"]):
				gather = 0.05 * absf(sin(gu * TAU * 2.0))
		var s := size * lerpf(0.35, 1.0, land) * (1.0 + gather)
		var c := _cc + Vector2(0, -60.0 * (1.0 - SummonFx.out3(ck)))
		# Soft gem-light halo behind the stone, then the shaded crystal (light rim, facet
		# gradients, caustic band, inner glow swelling towards the shatter).
		var ik := float(w["crack"])
		var ca := clampf(ck * 3.0, 0.0, 1.0)
		var hl := SummonFx.hex(g).lightened(0.35)
		# (Topaz skips it: gold on the gold pillar would wash the stone out.)
		if g != "L":
			ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), false, Color(hl.r, hl.g, hl.b, 0.26 * ca))
		else:
			# A soft slate shade behind the star so the gold stone reads on the gold pillar.
			ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(s, s) * 0.62, Vector2(s, s) * 1.24), false, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.22 * ca))
		SummonFx.draw_crystal_lux(ci, g, c, s, ca, t, 0.25 + 0.6 * ik + 0.15 * sin(t * 3.0) * (1.0 - ik))
		SummonFx.draw_cracks(ci, g, c, s * 0.5, ik, Color(1.0, 0.98, 0.92, 0.95))
		var hot := float(w.get("hot", 0.0))
		if hot > 0.0:
			var hp := GemDraw.cut_points(SummonFx.cut(g), c, s * 1.02)
			ci.draw_colored_polygon(hp, Color(1.0, 0.97, 0.9, 0.55 * hot))
			SummonFx.draw_cracks(ci, g, c, s * 0.62, 1.0, Color(1, 1, 1, hot))
		# Identity beats: Class -> Element -> Faction light inside / around the crystal.
		if bt.has("cls") and kind == "full":
			var h := HeroesUIModel.hero(str(results[_cur]["id"]))
			var tags := [["cls_" + str(h.get("class", "")), HeroesText.class_label(str(h.get("class", "")))],
					["el_" + str(h.get("element", "")), HeroesText.element_label(str(h.get("element", "")))],
					["fac_" + str(h.get("faction", "")), HeroesText.faction_label(str(h.get("faction", "")))]]
			var keys := ["cls", "el", "fac"]
			# A symmetric arc under the stone: Class (left) -> Element (centre) -> Faction (right).
			var R := minf(size * 0.8, _W * 0.4)
			for i in 3:
				var bk := SummonFx.seg(u, float(bt[keys[i]]), 0.3)
				if bk <= 0.0:
					continue
				var ang := deg_to_rad([150.0, 90.0, 30.0][i])
				var p := _cc + Vector2(cos(ang) * R, sin(ang) * R * (0.62 if i != 1 else 0.86)) + Vector2(0, 12.0 * (1.0 - SummonFx.out3(bk)))
				var a := SummonFx.out3(bk) * clampf(ck * 3.0, 0.0, 1.0)
				_draw_identity(ci, p, str(tags[i][0]), str(tags[i][1]), g, a)
				# The glyph also lights inside the crystal (the current beat only).
				var nxt := float(bt[keys[i + 1]]) if i < 2 else float(bt["shatter"])
				var inside := SummonFx.window(u, float(bt[keys[i]]), nxt, 0.12)
				if inside > 0.0:
					var gs := s * 0.34
					KitIcons.line(ci, str(tags[i][0]), Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), Color(1, 1, 1, 0.85 * inside), maxf(2.0, gs * 0.06))
	var su := float(w["shard_u"])
	if su >= 0.0:
		SummonFx.draw_shards(ci, g, _cc, size * 0.5, su, 0.5 if g != "M" else 0.6, 18 if g == "E" else (22 if g == "L" else 24))
	if str(w.get("sig", "")) == "doves":
		_draw_doves_beat(ci, u, bt, t)


## Ольга's signature beat (§6.29): a blizzard of white (some ember-tipped) feathers blows in across the whole screen
## from just before the shatter, thickest as she steps out, and clears before the name lands; seven white doves burst
## out of it from the crystal at the step-out and fly off the screen. Pure function of the walk time `u`.
func _draw_doves_beat(ci: Control, u: float, bt: Dictionary, t: float) -> void:
	var step := float(bt["step"])
	var a_in := SummonFx.seg(u, float(bt.get("gather", step - 0.45)) - 0.7, 0.7)
	var a_out := 1.0 - SummonFx.seg(u, step + 0.1, minf(0.7, maxf(0.2, float(bt["name"]) - step - 0.25)))
	var fa := a_in * a_out
	if fa > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2701
		var span := Vector2(_W, _H)
		for i in 120:
			var p0 := Vector2(rng.randf_range(-0.2, 1.1), rng.randf_range(-0.15, 1.05)) * span
			var vel := Vector2(rng.randf_range(160.0, 320.0), rng.randf_range(70.0, 190.0))
			var ph := rng.randf() * TAU
			var ln := rng.randf_range(26.0, 62.0)
			var ember := rng.randf() < 0.22
			var depth := rng.randf_range(0.55, 1.0)
			# The feathers blow in from the upper left (the veil streams to the right) and flutter as they go.
			var p := p0 + vel * (u - step) * depth + Vector2(sin(t * 2.3 + ph) * 14.0, cos(t * 1.7 + ph) * 8.0)
			p = Vector2(fposmod(p.x + 0.2 * _W, 1.3 * _W) - 0.2 * _W, fposmod(p.y + 0.15 * _H, 1.2 * _H) - 0.15 * _H)
			var ang := 0.6 + 0.9 * sin(t * 3.1 * depth + ph)
			_draw_feather(ci, p, ang, ln * depth, fa * (0.55 + 0.45 * depth), ember)
	# The doves: out of the blizzard at the step-out, fanning to the left and up-left, away from her face (upper right
	# of the crystal on the splash), and off the screen before the name lands.
	var du := u - step + 0.1
	if du > 0.0 and du < 1.2:
		for j in 7:
			var dir := Vector2.from_angle(deg_to_rad([-105.0, -125.0, -145.0, -165.0, 175.0, 155.0, 138.0][j]))
			var k := clampf(du / 1.2, 0.0, 1.0)
			var p := _cc + Vector2(-30.0, 0.0) + dir * (30.0 + _W * 0.95 * (0.35 * k + 0.65 * k * k) * (0.8 + 0.08 * float(j % 3)))
			var da := clampf(du * 5.0, 0.0, 1.0) * (1.0 - SummonFx.seg(du, 0.9, 0.3))
			_draw_dove(ci, p, dir, 46.0 + 10.0 * float(j % 3), t * 13.0 + float(j) * 1.3, da)


## One feather: a white vane around a thin quill along `ang`, `len` px long; ember-tipped ones (Ольга's mantle) carry a
## warm tip (never the enemy's lava orange: a soft rose-gold).
func _draw_feather(ci: Control, p: Vector2, ang: float, len: float, a: float, ember: bool) -> void:
	if a <= 0.01:
		return
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array()
	for i in 9:
		var f := float(i) / 8.0
		pts.append(p + d * len * (f - 0.5) + n * len * 0.24 * sin(PI * f) * (1.0 - 0.3 * f))
	for i in range(8, -1, -1):
		var f := float(i) / 8.0
		pts.append(p + d * len * (f - 0.5) - n * len * 0.19 * sin(PI * f) * (1.0 - 0.3 * f))
	ci.draw_colored_polygon(pts, Color(0.99, 0.98, 0.95, 0.9 * a))
	if ember:
		var tip := PackedVector2Array([p + d * len * 0.5, p + d * len * 0.22 + n * len * 0.15, p + d * len * 0.22 - n * len * 0.12])
		ci.draw_colored_polygon(tip, Color(0.86, 0.45, 0.4, 0.85 * a))
	ci.draw_line(p - d * len * 0.62, p + d * len * 0.5, Color(0.78, 0.74, 0.68, 0.8 * a), 1.2)


## One white dove seen from the side, flying along `dir` (body length `s` px): a plump body, the head forward, a fanned
## tail, the near wing raised over the back and the far wing behind it, both flapping with `flap` (a bird silhouette,
## never a cross shape: the wings rise from the back, not across the body).
func _draw_dove(ci: Control, p: Vector2, dir: Vector2, s: float, flap: float, a: float) -> void:
	if a <= 0.01:
		return
	var d := dir.normalized()
	var up := Vector2(-d.y, d.x)
	if up.y > 0.0:
		up = -up
	var col := Color(1.0, 1.0, 0.98, a)
	var shade := Color(0.86, 0.87, 0.92, a)
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(s, s) * 1.1, Vector2(s, s) * 2.2), false, Color(1.0, 0.95, 0.85, 0.2 * a))
	var w := 0.2 + 0.4 * (1.0 + sin(flap))  # 1 = wings up, 0.2 = the down-stroke (never below the body)
	# The far wing (behind the body, a little smaller and shaded).
	ci.draw_colored_polygon(PackedVector2Array([p + d * s * 0.1, p + up * s * (0.15 + 0.55 * w) + d * s * 0.05,
			p + up * s * (0.1 + 0.5 * w) - d * s * 0.35, p - d * s * 0.2]), shade)
	# Tail fan.
	ci.draw_colored_polygon(PackedVector2Array([p - d * s * 0.32, p - d * s * 0.75 + up * s * 0.14, p - d * s * 0.8,
			p - d * s * 0.72 - up * s * 0.1]), col)
	# Body (a plump teardrop) and the head with a small dark beak and eye.
	var body := PackedVector2Array()
	for k in 14:
		var an := TAU * float(k) / 14.0
		var rx := s * (0.42 if cos(an) > 0.0 else 0.38)
		body.append(p + d * cos(an) * rx + up * sin(an) * s * (0.17 if sin(an) > 0.0 else 0.14))
	ci.draw_colored_polygon(body, col)
	var hp := p + d * s * 0.42 + up * s * 0.12
	ci.draw_circle(hp, s * 0.13, col)
	ci.draw_colored_polygon(PackedVector2Array([hp + d * s * 0.1 + up * s * 0.02, hp + d * s * 0.22, hp + d * s * 0.1 - up * s * 0.04]),
			Color(0.85, 0.55, 0.5, a))
	ci.draw_circle(hp + d * s * 0.04 + up * s * 0.03, maxf(1.0, s * 0.025), Color(0.15, 0.13, 0.2, a))
	# The near wing: rises from the back, the long primaries swept back, a curved trailing edge.
	var wing := PackedVector2Array([p + d * s * 0.18 + up * s * 0.08])
	wing.append(p + up * s * (0.25 + 0.75 * w) + d * s * 0.12)
	wing.append(p + up * s * (0.3 + 0.85 * w) - d * s * 0.18)
	wing.append(p + up * s * (0.22 + 0.62 * w) - d * s * 0.42)
	wing.append(p + up * s * (0.12 + 0.34 * w) - d * s * 0.36)
	wing.append(p + up * s * 0.06 - d * s * 0.24)
	ci.draw_colored_polygon(wing, col)
	GemDraw.outline(ci, wing, Color(0.78, 0.8, 0.88, 0.7 * a), 1.0)



## An identity glyph on a light pillar: a cream socket with a gem-light ring and an ink glyph,
## its label on a small cream slip under it (readable on any pillar colour; no dark holes).
func _draw_identity(ci: Control, p: Vector2, icon: String, label: String, g: String, a: float) -> void:
	var r := 34.0
	var col := SummonFx.hex(g)
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(r, r) * 1.7, Vector2(r, r) * 3.4), false, Color(col.r, col.g, col.b, 0.4 * a))
	var p0 := UITokens.PAPER_0
	ci.draw_circle(p, r, Color(p0.r, p0.g, p0.b, 0.97 * a), true, -1.0, true)
	var lc := col.lightened(0.25)
	# v3.1: one 1.5 dpx gem-light ring + a 1 dpx light line inside (no 3 px band).
	ci.draw_arc(p, r - UIKit.line_px(1.5) * 0.5, 0.0, TAU, 48, Color(lc.r, lc.g, lc.b, a), UIKit.line_px(1.5), true)
	ci.draw_arc(p, r - 3.0, PI * 1.05, PI * 1.95, 24, Color(1, 1, 1, 0.7 * a), UIKit.px(1.0), true)
	KitIcons.line(ci, icon, Rect2(p - Vector2(r, r) * 0.6, Vector2(r, r) * 1.2), Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, a), 2.0)
	var f := UIKit.font_w("medium")
	var fs := 22
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sr := Rect2(p + Vector2(-tw * 0.5 - 14.0, r + 10.0), Vector2(tw + 28.0, 36.0))
	sr.position.x = clampf(sr.position.x, 6.0, _W - sr.size.x - 6.0)
	HeroV3.glass(ci, sr, UITokens.CHAMFER_XS, 0.96 * a, HeroV3.GOLD, 0.85 * a, 0.6 * a)
	ci.draw_string(f, Vector2(sr.position.x + 14.0, sr.position.y + 26.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, a))


## The walkout art of a hero without a splash yet (§9.6; critic P0): the STONE itself is revealed -
## the hero's gem at ceremony scale in its cut, shaded facet by facet (SummonFx.draw_crystal_lux),
## held by gold claws, the class sigil raised in gold relief on its table, a double engraved cut
## halo behind it and the opal's play of colour. It cools from white-hot as it crystallises
## (`reveal` 0..1). No empty card: the rarest moment pays off with the gem. A real splash, card
## crop or silhouette replaces it automatically through HeroArt.
class _Sigil extends Control:
	var cls := "warrior"
	var gem := "L"
	var reveal := 1.0
	var t := 0.0

	func stone_px() -> float:
		# The marquise is long and low: it gets more width than the other cuts.
		return minf(size.x * 0.8, 540.0) if gem == "M" else minf(size.x * 0.62, 440.0)

	func _draw() -> void:
		var c := size * 0.5
		var S := stone_px()
		var a := clampf(reveal * 3.0, 0.0, 1.0)
		if a <= 0.0:
			return
		var g := gem
		var ct := SummonFx.cut(g)
		# Engraved cut halo (double stroke), the "soul gem" outline behind the stone.
		var gh := UITokens.GOLD_HI
		for k: Array in [[1.42, 0.34, 2.0], [1.5, 0.18, 1.2], [1.86, 0.1, 1.0]]:
			GemDraw.outline(self, GemDraw.cut_points(ct, c, S * float(k[0])), Color(gh.r, gh.g, gh.b, float(k[1]) * a), float(k[2]))
		# Small keystones on the halo's tips.
		for p in SummonFx.prong_points(g, c, S * 1.46):
			GemDraw.draw_keystone(self, p, 14.0, a, Color(1.0, 0.93, 0.75))
		# Gold bezel just outside the girdle.
		var bez := GemDraw.cut_points(ct, c, S * 1.05)
		var metal := Color("#E3C67E")
		var bc := PackedColorArray()
		for p in bez:
			var k2 := clampf((p.y - c.y + S * 0.55) / (S * 1.1), 0.0, 1.0)
			bc.append(Color(metal.lightened(0.3).lerp(metal.darkened(0.3), k2), a))
		draw_polygon(bez, bc)
		GemDraw.outline(self, bez, Color(1.0, 0.95, 0.8, 0.7 * a), 1.4)
		SummonFx.draw_crystal_lux(self, g, c, S, a, t, 0.35 + 0.25 * sin(t * 1.6))
		for p in SummonFx.prong_points(g, c, S * 1.0):
			SummonFx.draw_prong(self, c, p, S, a)
		# The class sigil raised in gold relief on the table.
		var outer := GemDraw.cut_points(ct, c, S)
		var cen := Vector2.ZERO
		for p in outer:
			cen += p
		cen /= float(outer.size())
		if ct == "star":
			cen = c + Vector2(0, S * 0.02)
		var gs := S * {"triangle": 0.3, "star": 0.3, "eye": 0.26}.get(ct, 0.36) as float
		var deep: Color = (SummonFx.BODY.get(g, SummonFx.BODY["L"]) as Array)[2]
		SummonFx.draw_relief_glyph(self, "cls_" + cls, Rect2(cen - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), a, deep.darkened(0.5))
		# White-hot while it crystallises, cooling into colour.
		var hot := 1.0 - SummonFx.out3(reveal)
		if hot > 0.0:
			draw_colored_polygon(GemDraw.cut_points(ct, c, S * 1.06), Color(1.0, 0.97, 0.9, 0.75 * hot))
