class_name HeroesTeamRoster
extends HeroesBottomSheet
## The roster sheet of the Team screen (heroes_design.md §5.5, §9.3; part U §2.7): the owned
## champions (4 columns, S cards) for a champion slot, or the owned heroes (3 columns) for the
## hero slot, each with synergy DELTA badges computed by diffing the team with the candidate in
## place («+Фракція» / «+Клас» / «+Стихія» gold, «−…» dim ink when it breaks an active tag).
## The card already in this slot reads «Тут зараз», another member «У строю» (placing it moves it).
## Tap a card = place it (the sheet closes); «Прибрати зі строю» empties a champion slot.
##   var r := HeroesTeamRoster.make(hub, 0)        # champion slot 0
##   r.placed.connect(func(id): ...)

signal placed(id: String)

var slot_index := 0               ## champion slot index; -1 = the hero
var slot_name: StringName = &""
var _team: Dictionary = {}


static func make(p_hub: Hub, p_slot: int, p_slot_name: StringName = &"") -> HeroesTeamRoster:
	var r := HeroesTeamRoster.new()
	r.hub = p_hub
	r.slot_index = p_slot
	r.slot_name = p_slot_name
	r.own_scrim = true
	r.height_frac = 0.72
	return r


func _ready() -> void:
	_team = HeroesUIModel.team()
	if slot_index < 0:
		title = HeroesText.t("TEAM_ROSTER_HERO")
	else:
		title = HeroesText.t("TEAM_ROSTER_CHAMP", [HeroesTeamLogic.slot_label(slot_name) if slot_name != &"" else ""])
	var hint := UIKit.label(HeroesText.t("TEAM_ROSTER_HINT"), 22, UITokens.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(620, 0)
	body.add_child(hint)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var grid := GridContainer.new()
	grid.columns = 3 if slot_index < 0 else 4
	grid.add_theme_constant_override("h_separation", 22 if slot_index < 0 else 18)
	grid.add_theme_constant_override("v_separation", 18)
	cc.add_child(grid)
	var cells: Array = []
	for d: Dictionary in _candidates():
		var cell := _cell(d)
		grid.add_child(cell)
		cells.append(cell)
	UIKit.scroll_fade(sc, UITokens.PAPER_1)
	if slot_index >= 0 and slot_index < (_team["champions"] as Array).size() and str(_team["champions"][slot_index]) != "":
		var rm := UIKit.text_button(HeroesText.t("TEAM_REMOVE"), Vector2(0, 88), 24)
		rm.pressed.connect(func(): _place(""))
		body.add_child(rm)
	super._ready()
	if not UITokens.reduce_motion():
		UIJuice.cards_in(cells, 0.12)


func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src: Array[Dictionary] = HeroesUIModel.heroes() if slot_index < 0 else HeroesUIModel.champions()
	for d in src:
		if bool(d["owned"]):
			var gain := 0
			for b: Dictionary in HeroesTeamLogic.delta(_team, str(d["id"]), slot_index):
				gain += 1 if bool(b["gain"]) else -1
			d["_gain"] = gain
			out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["_gain"]) != int(b["_gain"]):
			return int(a["_gain"]) > int(b["_gain"])
		var ga := Ladder.gem_index(str(a["gem"]))
		var gb := Ladder.gem_index(str(b["gem"]))
		if ga != gb:
			return ga > gb
		return int(a["no"]) < int(b["no"]))
	return out


func _cell(d: Dictionary) -> Control:
	var id := str(d["id"])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var card := HeroCard.make(d, "M" if slot_index < 0 else "S")
	card.pressed.connect(func(_i): _place(id))
	v.add_child(card)
	var here := false
	var member := false
	if slot_index < 0:
		here = str(_team["hero"]) == id
	else:
		var champs: Array = _team["champions"]
		here = slot_index < champs.size() and str(champs[slot_index]) == id
		member = not here and id in champs
	if here or member:
		v.add_child(_badge(HeroesText.t("TEAM_HERE" if here else "TEAM_IN_SLOT"), "here"))
	else:
		var ds := HeroesTeamLogic.delta(_team, id, slot_index)
		if ds.is_empty():
			v.add_child(_badge(HeroesText.t("TEAM_DELTA_NONE"), "none"))
		for b: Dictionary in ds.slice(0, 2):
			v.add_child(_badge(HeroesText.t(str(b["key"])), "gain" if bool(b["gain"]) else "loss"))
	return v


func _badge(text: String, kind: String) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := UITokens.PAPER_0
	var ink := UITokens.INK
	var line := 1
	match kind:
		"gain":
			fill = UITokens.CTA_HI
			ink = UIKit.BROWN
		"loss":
			fill = UITokens.PAPER_2
			ink = UITokens.INK_DIM
		"here":
			fill = UITokens.PAPER_0
			ink = UITokens.GOLD_TEXT
		_:
			fill = UITokens.PAPER_1
			ink = UITokens.INK_SOFT
			line = 0
	p.add_theme_stylebox_override("panel", UIKit.cbox(fill, int(UITokens.CHAMFER_XS), UITokens.HAIRLINE, line, Vector2(8, 2)))
	var l := UIKit.label(text, 22, ink, kind == "gain")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _place(id: String) -> void:
	placed.emit(id)
	close()
