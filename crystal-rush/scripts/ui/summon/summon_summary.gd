class_name SummonSummary
extends Control
## The ×10 summary frame (heroes_design.md §9.4 "×10: summary frame 1.2 s after the best walkout";
## part U §3.3; fusion §6.8 #4): ten gem cards fanned in two rows like a dealt hand - sorted gem
## high -> low, NEW first inside a gem - with the BEST card in the centre of the top row, larger
## and lit. NEW cards get the «НОВИЙ» wax seal; duplicates read «+15 фрагм.» in the footer. Under
## the cards one cream document: Seals gained (+10 · 47 / 100), the pity bar after the bundle, and
## the fragments each hero received. Every value comes from the results of HeroesUIModel.summon()
## and portal_state() before / after the bundle. No «Ще ×10» link, no offer (§9.3, §9.5 row 4).
## Deterministic: `render(u)` lays the frame out at u seconds into the arrival (seekable).

const ARRIVE := 0.55             ## part U §3.3: the summary arrives in 0.55 s
const STAGGER := 0.04            ## UITokens.CARD_STAGGER
const BEST_SCALE := 1.36

var results: Array[Dictionary] = []
var before: Dictionary = {}
var after: Dictionary = {}
var length := 1.2
var _order: Array[int] = []       ## result indices in display order
var _slots: Array[Dictionary] = [] ## per display slot: {pos, rot, scale}
var _cards: Array[HeroCard] = []
var _seals: Array[HeroWaxSeal] = []
var _glow: _Glow
var _title: Label
var _panel: PanelContainer
var _seal_row: Label
var _pity: HeroEngravedBar
var _frags: Label
var _laid := false


func setup(p_results: Array[Dictionary], p_before: Dictionary, p_after: Dictionary, p_length: float) -> void:
	results = p_results
	before = p_before
	after = p_after
	length = p_length


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = _Glow.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	_title = UIKit.scene_label(HeroesText.t("SUMMON_SUMMARY"), 40)
	add_child(_title)
	# Display order: gem high -> low, NEW first, then collector order.
	var idx: Array[int] = []
	for i in results.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ra: Dictionary = results[a]
		var rb: Dictionary = results[b]
		var ga := Ladder.gem_index(str(ra["gem"]))
		var gb := Ladder.gem_index(str(rb["gem"]))
		if ga != gb:
			return ga > gb
		if bool(ra["is_new"]) != bool(rb["is_new"]):
			return bool(ra["is_new"])
		return a < b)
	# Top row: [#4, #2, #1 best, #3, #5]; bottom row: [#9, #7, #6, #8, #10] (a fanned hand).
	var place := [3, 1, 0, 2, 4, 8, 6, 5, 7, 9]
	for k in mini(idx.size(), 10):
		_order.append(-1)
	for slot in _order.size():
		var rank: int = place[slot] if slot < place.size() else slot
		_order[slot] = idx[rank] if rank < idx.size() else idx[slot]
	for slot in _order.size():
		var r: Dictionary = results[_order[slot]]
		var d := HeroesUIModel.hero(str(r["id"])) if str(r["kind"]) == "hero" else HeroesUIModel.champion(str(r["id"]))
		d = d.duplicate()
		d["is_new"] = false
		d["owned"] = true
		var c := HeroCard.make(d, "S")
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var foot := ""
		if bool(r["is_new"]):
			foot = HeroesText.t("SUMMON_NEW")
		elif int(r["tomes"]) > 0:
			foot = HeroesText.t("SUMMON_TOMES", [int(r["tomes"])])
		else:
			foot = HeroesText.t("SUMMON_FRAGS", [int(r["fragments"])])
		SummonFx.card_footer(c, foot)
		add_child(c)
		_cards.append(c)
		var s: HeroWaxSeal = null
		if bool(r["is_new"]):
			s = HeroWaxSeal.make(64)
			add_child(s)
		_seals.append(s)
	# The document: Seals, pity after the bundle, fragments per hero.
	_panel = UIKit.panel("panel", Vector2(26, 18))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	col.add_child(srow)
	var sic := HeroIcons.make("seal", 40.0)
	sic.custom_minimum_size = Vector2(40, 40)
	srow.add_child(sic)
	var gained := int(after.get("seals", 0)) - int(before.get("seals", 0))
	var tgt: Dictionary = after.get("seal_target", {"gem": "E", "price": PortalData.seal_price("E")})
	_seal_row = UIKit.label(HeroesText.t("SUMMON_SEALS_ADD", [gained, int(after.get("seals", 0)), int(tgt["price"])]), 24, UITokens.INK, true)
	_seal_row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	srow.add_child(_seal_row)
	_pity = HeroEngravedBar.make("L", float(before.get("since_l", 0)), float(after.get("pity_l_hard", 30)), 600)
	_pity.tick_every = 1.0
	_pity.marker = float(after.get("pity_l_soft", 21)) - 1.0
	_pity.label = HeroesText.t("PORTAL_PITY_L", [int(after.get("pity_l_left", 30))])
	_pity.value_text = HeroesText.t("PORTAL_PITY_E", [int(after.get("pity_e_left", 10))])
	col.add_child(_pity)
	_frags = UIKit.label(_frag_line(), 22, UITokens.INK_DIM)
	_frags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frags.custom_minimum_size.x = 560
	col.add_child(_frags)
	_frags.visible = _frags.text != ""
	resized.connect(_layout)
	_layout()


## «Фрагменти: Горан +10 · Руді +15» (totals per character, gem high -> low).
func _frag_line() -> String:
	var tot := {}
	var order: Array[String] = []
	for r in results:
		var f := int(r["fragments"])
		if f <= 0:
			continue
		var id := str(r["id"])
		if not tot.has(id):
			order.append(id)
			tot[id] = 0
		tot[id] = int(tot[id]) + f
	if order.is_empty():
		return ""
	var parts: Array[String] = []
	for id in order:
		parts.append(HeroesText.t("SUMMON_FRAG_ITEM", [HeroesText.name_of(id), int(tot[id])]))
	return HeroesText.t("SUMMON_FRAGS_TOTAL", [" · ".join(parts)])


func _layout() -> void:
	var W := size.x
	var H := size.y
	if W < 10.0:
		return
	var ins := UIKit.safe_insets(get_viewport()) if is_inside_tree() else Vector4.ZERO
	var cs := HeroCard.SIZES["S"] as Vector2
	var pitch := 134.0
	# Centre the whole frame (title, two rows, the document) between the top bar and the dock.
	_panel.size = Vector2(W - 2.0 * UITokens.GUTTER, 0)
	_panel.reset_size()
	var ph := _panel.get_combined_minimum_size().y
	# The rows sit a little apart (the larger best card needs the room) and the frame sits low,
	# close to the dock, instead of floating with a quarter of the screen empty under it.
	var gap_rows := 84.0
	var block := 120.0 + cs.y * 2.0 + gap_rows + 44.0 + ph
	var room_top := ins.y + 96.0
	var room_bot := H - ins.w - 150.0
	var top := room_top + maxf(0.0, (room_bot - room_top - block) * 0.72)
	_title.position = Vector2((W - _title.get_combined_minimum_size().x) * 0.5, top)
	var row_y := [top + 120.0 + cs.y * 0.5 + 18.0, top + 120.0 + cs.y * 1.5 + gap_rows]
	_slots.clear()
	for slot in _order.size():
		var row := slot / 5
		var i := slot % 5
		var off := float(i - 2)
		var is_best := slot == 2
		var sc := BEST_SCALE if is_best else 1.0
		var pos := Vector2(W * 0.5 + off * pitch, float(row_y[row]) + absf(off) * absf(off) * 7.0 + (-14.0 if is_best else 0.0))
		_slots.append({"pos": pos, "rot": deg_to_rad(off * 3.2), "scale": sc})
	_panel.size = Vector2(W - 2.0 * UITokens.GUTTER, 0)
	_panel.reset_size()
	_panel.size.x = W - 2.0 * UITokens.GUTTER
	_panel.position = Vector2(UITokens.GUTTER, float(row_y[1]) + cs.y * 0.5 + 44.0)
	_glow.size = Vector2(W, H)
	_laid = true


## Lays out the frame at `u` seconds into the arrival (0 = nothing yet, >= length = final).
func render(u: float) -> void:
	if not _laid:
		_layout()
	var cs := HeroCard.SIZES["S"] as Vector2
	var reduce := UITokens.reduce_motion()
	for slot in _cards.size():
		var c := _cards[slot]
		var sl: Dictionary = _slots[slot]
		var d := float(slot) * STAGGER
		var k := SummonFx.seg(u, d, ARRIVE * 0.6) if not reduce else SummonFx.seg(u, 0.0, 0.25)
		var e := SummonFx.back(k, 1.2) if not reduce else k
		var sc := float(sl["scale"]) * lerpf(0.7, 1.0, e)
		c.pivot_offset = cs * 0.5
		c.size = cs
		c.scale = Vector2(sc, sc)
		c.rotation = float(sl["rot"]) * e
		var start := Vector2(size.x * 0.5, size.y * 0.42) - cs * 0.5
		c.position = start.lerp((sl["pos"] as Vector2) - cs * 0.5, SummonFx.out3(k))
		c.modulate.a = clampf(k * 3.0, 0.0, 1.0)
		var s := _seals[slot]
		if s:
			# The seal presses in after the cards land (0.14 s squash, then settle).
			var sk := SummonFx.seg(u, ARRIVE + 0.1 + float(slot) * 0.06, 0.32)
			# Seals sit 8 px further inside the card so they never cover the neighbour's top.
			var p := (sl["pos"] as Vector2) + Vector2(cs.x * 0.5 * sc - 30.0, -cs.y * 0.5 * sc + 10.0)
			s.position = p - s.size * 0.5
			s.pivot_offset = s.size * 0.5
			var sq := 1.5 - 0.6 * SummonFx.in2(sk / 0.45) if sk < 0.45 else lerpf(0.9, 1.0, SummonFx.out3((sk - 0.45) / 0.55))
			s.scale = Vector2.ONE * (1.0 if reduce else sq)
			s.modulate.a = clampf(sk * 5.0, 0.0, 1.0)
	_glow.best = _slots[2]["pos"] if _slots.size() > 2 else Vector2.ZERO
	_glow.gem = str(results[_order[2]]["gem"]) if _order.size() > 2 else "C"
	_glow.k = SummonFx.seg(u, 0.1, 0.5)
	_glow.t = u
	_glow.queue_redraw()
	_title.modulate.a = SummonFx.seg(u, 0.0, 0.3)
	var pk := SummonFx.seg(u, ARRIVE * 0.8, 0.3)
	_panel.modulate.a = pk
	_panel.position.y = _panel.position.y
	_pity.value = lerpf(float(before.get("since_l", 0)), float(after.get("since_l", 0)), SummonFx.seg(u, ARRIVE, 0.4))


## The light behind the best card (soft rays + glow in its gem colour).
class _Glow extends Control:
	var best := Vector2.ZERO
	var gem := "L"
	var k := 0.0
	var t := 0.0

	func _init() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _draw() -> void:
		if k <= 0.0:
			return
		var col := SummonFx.hex(gem)
		SummonFx.draw_rays(self, best, 300.0, col, k * 0.9, t * 0.08, 10)
		SummonFx.draw_glow(self, best, 230.0, col, 0.5 * k)
