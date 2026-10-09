extends Node
## Headless tests of the champion HUD (heroes design §10.5, §4.2): ChampionMedallions (setup for 1-4
## members in slot order, no input anywhere, refresh redraws only on a change, champ_down / revive,
## avoid-rect fades, the stack above the ult and the bottom-row fallback) and TeamBanner (<= 3 synergy
## icons, hides itself after its time).
##
## godot --headless --path . res://scenes/dev/test_champ_hud.tscn -- --autotest      Exit code = failures.

## Team order on purpose NOT slot order (the HUD sorts: front, left, right, rear).
const TEAM := [["dara", "L", &"rear"], ["brant", "E", &"front"], ["taya", "R", &"right"], ["mila", "C", &"left"]]
const W := 720.0
const H := 1280.0
## HudView._layout's ult rect at 720 x 1280 (no insets).
const ULT := Rect2(514, 1056, 180, 168)
## Longer than ChampionMedallions.PULSE_TIME.
const PULSE_WAIT := 0.5

var _fails := 0
var _passes := 0
var _root: Control


func _ready() -> void:
	Save.readonly = true
	var t0 := Time.get_ticks_msec()
	_root = Control.new()
	_root.size = Vector2(W, H)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_test_order()
	_test_setup_counts()
	_test_mouse_ignore()
	_test_refresh()
	await _test_fx()
	await _test_avoid()
	_test_place()
	_test_row()
	_test_scale()
	await _test_banner()
	print("TEST_CHAMP_HUD %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("  FAIL ", what)


func _team(n := 4) -> Array:
	var out: Array = []
	for t: Array in TEAM.slice(0, n):
		out.append(ChampionKinds.member(ChampionsMeta.stats_at(str(t[0]), str(t[1]), 0, 1), t[2]))
	return out


func _meds(members: Array) -> ChampionMedallions:
	var m := ChampionMedallions.new()
	_root.add_child(m)
	m.setup(members)
	m.place(ULT)
	return m


func _drop(n: Node) -> void:
	_root.remove_child(n)
	n.free()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


static func _all_ignore(n: Node) -> bool:
	if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for c in n.get_children(true):
		if not _all_ignore(c):
			return false
	return true


static func _inside(r: Rect2) -> bool:
	return r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= W and r.end.y <= H


# ------------------------------------------------------------------ medallions

func _test_order() -> void:
	print("== slot order")
	var ids: Array[String] = []
	for m: Dictionary in ChampionMedallions.ordered(_team()):
		ids.append(str(m["id"]))
	_ok(ids == ["brant", "mila", "taya", "dara"], "ordered = front, left, right, rear (%s)" % [ids])
	_ok(ChampionMedallions.ordered([]).is_empty(), "ordered([]) is empty")


func _test_setup_counts() -> void:
	print("== setup with 1-4 members")
	var want := {1: ["dara"], 2: ["brant", "dara"], 3: ["brant", "taya", "dara"], 4: ["brant", "mila", "taya", "dara"]}
	for n in [1, 2, 3, 4]:
		var m := _meds(_team(n))
		_ok(m.count() == n, "%d members -> %d medallions" % [n, m.count()])
		_ok(m.ids() == (want[n] as Array), "%d members in slot order (%s)" % [n, m.ids()])
		var rs := m.rects()
		var ok := true
		for i in rs.size():
			if not _inside(rs[i]) or not is_equal_approx(rs[i].size.x, ChampionMedallions.SIZE):
				ok = false
			for j in range(i + 1, rs.size()):
				if rs[i].intersects(rs[j]):
					ok = false
		_ok(ok, "%d medallions: 72 px, inside the viewport, no overlap" % n)
		_ok(m.visible, "%d members: visible" % n)
		_drop(m)
	var empty := _meds([])
	_ok(empty.count() == 0 and not empty.visible, "no members: nothing shown")
	empty.setup(_team(2))
	_ok(empty.count() == 2 and empty.visible, "setup again replaces the set")
	empty.setup(_team(1))
	_ok(empty.count() == 1 and empty.get_child_count() == 1, "a smaller set leaves no stale children")
	_drop(empty)
	# The owner may set up before adding it to the HUD: it lays out on entering the tree.
	var pre := ChampionMedallions.new()
	pre.setup(_team(2))
	_root.add_child(pre)
	var pr := pre.rects()
	_ok(pre.count() == 2 and pr[1].end.y <= ULT.position.y and _inside(pr[0]), "setup before add_child: laid out on entry")
	_drop(pre)


func _test_mouse_ignore() -> void:
	print("== no input anywhere")
	var m := _meds(_team(4))
	_ok(_all_ignore(m), "ChampionMedallions and every child: MOUSE_FILTER_IGNORE")
	m.on_fx(&"champ_down", {"id": "dara"})
	m.on_fx(&"champ_shot", {"id": "taya"})
	_ok(_all_ignore(m), "still IGNORE after state changes")
	var b := TeamBanner.new()
	_root.add_child(b)
	b.show_team(_team(4), ["fac_dawn_1"], 0.5)
	_ok(_all_ignore(b), "TeamBanner: MOUSE_FILTER_IGNORE")
	_drop(b)
	_drop(m)


func _test_refresh() -> void:
	print("== refresh redraws only on a change")
	var team := _team(4)
	var m := _meds(team)
	m.refresh(team)
	var r0 := m.redraws()
	for i in 5:
		m.refresh(team)
	_ok(m.redraws() == r0, "unchanged data: no redraw (%d -> %d)" % [r0, m.redraws()])
	_ok(is_equal_approx(m.ratio_of("taya"), 1.0), "full HP: ring 1.0")
	var taya: Dictionary = team[2]
	taya["hp"] = float(taya["hp_max"]) * 0.4
	m.refresh(team)
	_ok(m.redraws() == r0 + 1, "one HP change: exactly one redraw (%d)" % (m.redraws() - r0))
	_ok(is_equal_approx(m.ratio_of("taya"), 0.4), "ring follows HP (0.4, got %.3f)" % m.ratio_of("taya"))
	_ok(is_equal_approx(m.ratio_of("brant"), 1.0), "the others keep their ring")
	m.refresh(team)
	m.refresh(team)
	_ok(m.redraws() == r0 + 1, "no redraw while it stays")
	var shuffled := [team[3], team[2], team[1], team[0]]
	taya["hp"] = float(taya["hp_max"]) * 0.25
	m.refresh(shuffled)
	_ok(is_equal_approx(m.ratio_of("taya"), 0.25), "a reordered members array still maps by id")
	_drop(m)


func _test_fx() -> void:
	print("== fx: hit, down, revive, actions")
	var team := _team(4)
	var m := _meds(team)
	# Short frames first: the first frame after the synchronous tests runs ~150 ms, longer than the
	# whole 0.15 s nudge.
	for i in 3:
		await get_tree().process_frame
	m.on_fx(&"champ_hit", {"id": "brant", "hp": 28.0, "hp_max": 56.0})
	_ok(is_equal_approx(m.ratio_of("brant"), 0.5), "champ_hit sets the ring from its data (%.3f)" % m.ratio_of("brant"))
	var md := m.medallion_of("brant")
	var peak := 1.0
	var t := 0.0
	while t < 0.3:
		await get_tree().process_frame
		t += get_process_delta_time()
		peak = maxf(peak, md.scale.x)
	_ok(UITokens.reduce_motion() or (peak > 1.02 and peak <= ChampionMedallions.NUDGE + 0.001),
			"champ_hit nudges the scale (peak %.3f)" % peak)
	_ok(is_equal_approx(md.scale.x, 1.0), "the nudge settles back to 1 (%.3f)" % md.scale.x)
	m.on_fx(&"champ_down", {"id": "dara", "slot": &"rear", "x": 0.0, "d": 0.0})
	_ok(m.fallen_of("dara") and is_equal_approx(m.ratio_of("dara"), 0.0), "champ_down: fallen, ring empty")
	m.refresh(team)
	m.refresh(team)
	_ok(m.fallen_of("dara"), "fallen stays fallen through refresh (data unchanged)")
	m.on_fx(&"champ_shot", {"id": "dara"})
	_ok(float(m.medallion_of("dara").get("_pulse")) == 0.0, "a fallen medallion does not pulse")
	m.on_fx(&"champ_revive", {"id": "dara"})
	_ok(not m.fallen_of("dara"), "champ_revive restores it")
	var dara: Dictionary = team[0]
	dara["hp"] = float(dara["hp_max"]) * 0.5
	m.refresh(team)
	_ok(is_equal_approx(m.ratio_of("dara"), 0.5), "revived at 50 %: ring 0.5")
	# A fall the fx missed: the data flips alive -> false, then back.
	var mila: Dictionary = team[3]
	mila["alive"] = false
	mila["hp"] = 0.0
	m.refresh(team)
	_ok(m.fallen_of("mila"), "refresh follows alive = false")
	mila["alive"] = true
	mila["hp"] = float(mila["hp_max"]) * 0.5
	m.refresh(team)
	_ok(not m.fallen_of("mila") and is_equal_approx(m.ratio_of("mila"), 0.5), "refresh follows a revive in the data")
	for ev: StringName in [&"champ_block", &"champ_mend", &"champ_leap", &"champ_shot", &"champ_spell"]:
		m.on_fx(ev, {"id": "taya"})
		_ok(float(m.medallion_of("taya").get("_pulse")) > 0.0 or UITokens.reduce_motion(), "%s pulses the frame" % ev)
	m.on_fx(&"champ_heal", {"id": "mila", "target": "brant", "hp": 5.0})
	_ok(float(m.medallion_of("brant").get("_pulse")) > 0.0 or UITokens.reduce_motion(), "champ_heal pulses the healed one")
	await _wait(PULSE_WAIT)
	_ok(float(m.medallion_of("taya").get("_pulse")) == 0.0 and not m.medallion_of("taya").is_processing(),
			"the pulse ends and stops processing")
	var before := m.redraws()
	m.on_fx(&"champ_hit", {"id": "nobody", "hp": 1.0, "hp_max": 2.0})
	m.on_fx(&"not_an_event", {"id": "brant"})
	m.on_fx(&"champ_down", {})
	_ok(m.redraws() == before and not m.fallen_of("brant"), "unknown ids / events change nothing")
	_drop(m)



func _test_avoid() -> void:
	print("== avoid rects")
	var m := _meds(_team(4))
	var rs := m.rects()
	var gate := Rect2(rs[0].position - Vector2(120, 10), Vector2(150, 40))
	m.set_avoid_rects([gate])
	_ok(m.faded_of("brant") and not m.faded_of("mila"), "the medallion under the gate label fades, the others not")
	await _wait(0.3)
	var a := m.medallion_of("brant").modulate.a
	_ok(is_equal_approx(a, 0.5), "faded to 0.5 (%.3f)" % a)
	_ok(is_equal_approx(m.medallion_of("mila").modulate.a, 1.0), "the others stay at 1")
	for i in 3:
		m.set_avoid_rects([gate])
	_ok(m.faded_of("brant"), "repeated calls keep it faded")
	m.set_avoid_rects([])
	await _wait(0.3)
	_ok(not m.faded_of("brant") and is_equal_approx(m.medallion_of("brant").modulate.a, 1.0),
			"back to 1 when clear (%.3f)" % m.medallion_of("brant").modulate.a)
	var far := Rect2(Vector2(10, 10), Vector2(100, 40))
	m.set_avoid_rects([far, "not a rect"])
	_ok(not m.faded_of("brant") and not m.faded_of("dara"), "rects elsewhere (and junk entries) fade nothing")
	_drop(m)


func _test_place() -> void:
	print("== place: the stack above the ult")
	for ult: Rect2 in [ULT, Rect2(480, 900, 180, 168), Rect2(540, 1000, 160, 150)]:
		var m := _meds(_team(4))
		m.place(ult)
		var rs := m.rects()
		var above := true
		var inside := true
		var centred := true
		for r in rs:
			above = above and r.end.y <= ult.position.y - 1.0 and not r.intersects(ult)
			inside = inside and _inside(r)
			centred = centred and absf(r.get_center().x - ult.get_center().x) < 1.0
		_ok(above, "%s: every medallion above the ult rect" % ult)
		_ok(inside, "%s: inside the viewport" % ult)
		_ok(centred, "%s: centred on the ult" % ult)
		_ok(rs[0].position.y < rs[rs.size() - 1].position.y, "%s: front on top, rear nearest the ult" % ult)
		_ok(absf(rs[rs.size() - 1].end.y - (ult.position.y - ChampionMedallions.ULT_GAP)) < 0.5, "%s: ULT_GAP above it" % ult)
		_drop(m)


func _test_row() -> void:
	print("== use_bottom_row")
	var m := _meds(_team(4))
	m.use_bottom_row = true
	m.place(ULT)
	var rs := m.rects()
	var ok := true
	for i in rs.size():
		var r := rs[i]
		ok = ok and r.position.y >= H - ChampionMedallions.ROW_BAND and r.end.y <= H and _inside(r) and not r.intersects(ULT)
		if i > 0:
			ok = ok and r.position.x > rs[i - 1].end.x and is_equal_approx(r.position.y, rs[0].position.y)
	_ok(ok, "row: y >= H - 240, inside, left of the ult, one line (%s)" % [rs])
	m.use_bottom_row = false
	_ok(m.rects()[3].end.y <= ULT.position.y, "back to the stack when the flag clears")
	_drop(m)


func _test_scale() -> void:
	print("== size_px")
	var m := _meds(_team(3))
	m.size_px = 96.0
	var rs := m.rects()
	_ok(is_equal_approx(rs[0].size.x, 96.0) and rs[2].end.y <= ULT.position.y and _inside(rs[0]),
			"size_px 96 still stacks above the ult")
	_drop(m)


# ------------------------------------------------------------------ banner

func _test_banner() -> void:
	print("== TeamBanner")
	_ok(TeamBanner.synergy_icon("fac_dawn_2") == {"icon": "fac_dawn", "tier": 2}, "fac_dawn_2 -> fac_dawn tier 2")
	_ok(TeamBanner.synergy_icon("cls_guardian") == {"icon": "cls_guardian", "tier": 0}, "cls_guardian -> its class glyph")
	_ok(TeamBanner.synergy_icon("affinity") == {"icon": "odds", "tier": 0}, "affinity -> the Team screen's glyph")
	_ok(TeamBanner.synergy_icon("bogus").is_empty() and TeamBanner.synergy_icon("fac_nowhere_1").is_empty(),
			"unknown ids -> none")
	var b := TeamBanner.new()
	_root.add_child(b)
	_ok(not b.visible, "hidden until shown")
	var got := [false]
	b.done.connect(func(): got[0] = true)
	b.show_team(_team(4), ["fac_dawn_2", "bogus", "cls_guardian", "affinity", "fac_wildfang_1", "cls_mage"], 0.45)
	_ok(b.visible and b.champion_count() == 4, "shows the four champions")
	_ok(b.synergy_count() == 3, "at most 3 synergy icons (%d)" % b.synergy_count())
	var rr := b.ribbon_rect()
	_ok(_inside(rr) and absf(rr.get_center().y - H / 3.0) < 1.0 and absf(rr.get_center().x - W * 0.5) < 1.0,
			"the ribbon sits centred at the top third, inside the viewport (%s)" % rr)
	await _wait(0.2)
	_ok(b.visible and b.modulate.a > 0.9, "faded in after 0.15 s (%.2f)" % b.modulate.a)
	await _wait(0.6)
	_ok(not b.visible and got[0], "hid itself after its time and emitted done")
	b.show_team(_team(2), [], 0.3)
	_ok(b.visible and b.synergy_count() == 0 and b.champion_count() == 2, "shows again (no synergy)")
	b.hide_now()
	_ok(not b.visible, "hide_now hides it")
	b.show_team([], [], 1.0)
	_ok(not b.visible, "nothing to show: stays hidden")
	_drop(b)
