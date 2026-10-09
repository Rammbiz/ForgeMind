extends Node
## HUD lab (heroes design §10.2, §10.5, §12.6 #11). One mode so far:
##
## --gate-legibility: the gate-legibility rule (§10.2.1: no ult or champion VFX may drop the next gate
## row's label contrast below 3 : 1, measured on the label rect against what is drawn behind it). For
## every case a fresh run (the real Run + run HUD, phase H2, --level default 45) is put 6 u before its
## first row of plain army gates (+ - x /, all revealed; else its first row), the army at 220 (the §10.6
## steady W4 army), the hero lined up on the nearer gate. The run's logic is frozen there (no Run._step:
## the row stays 6 u ahead) while its visuals keep drawing (Run._visuals each frame), and the case is
## triggered:
##   quiet (bolt): nothing fired, the control (the row's field animates, so its ratio moves by itself);
##   ult_storm (bolt), ult_quake (titan), ult_rift (seer): Run.use_ult with a full charge, the ult clock
##     stepped every frame (Run._ult_step: ticks, waves, the rift);
##   champ_leap, champ_shot, champ_spell, champ_block, champ_down (team borko, alba, taya, ivo) and
##     champ_mend (team mila): the rules' champ_* fx event through Run._champ_fx, aimed at the gate row
##     (the leap lands 1.5 u before it, the arrows fly to 0.5 u past it, the spell ring sits on it, the
##     «БЛОК» pops at the nearest hazard ahead or the Guardian, the fallen champion lies at its slot).
## The run is started (RUNNING, as when an army meets a gate row) and the champions' start banner, which
## only lives 1.2 s during READY (§10.5), is closed first: a gate row is never met under it.
## Captures at CAPTURE_AT s after the trigger (and one baseline before it, on the quiet frame). A capture
## pauses the tree and renders the frame twice: as is, and with the row's label glyphs hidden (the big
## number and the forecast text: their fill and outline at alpha 0; their glow quad, drawn behind the
## glyphs as part of the backdrop, stays). Text pixels = brighter than the glyph-less frame by TEXT_DIFF in
## luminance (the white fill); contrast = WCAG ratio of their median luminance and the 90th-percentile
## luminance of the glyph-less frame AT those pixels (what is drawn right behind the glyphs, its bright end).
## A rect with fewer than MIN_TEXT text pixels counts as covered (ratio 1). A case FAILS when any label at
## any capture is below 3 : 1. Self-check (once per run of the lab): the baseline of the plain gate row on
## the quiet frame must be >= 3 : 1 on every label (printed per label; if the game's own labels are below
## it, the numbers say so and the lab fails); beside it, for information, the same row restyled as every
## gate kind. Each case also prints the worst label's own baseline and the drop the fx took from it.
## (Before: the label-less frame hid the Label3D with its glow, the background was the 90th percentile of
## the whole rect, and the READY banner lay over the row in every champion case, so even the baseline read
## 1.01 : 1: the "background" was the banner's white.)
##
## Needs a real renderer (e.g. the hidden desktop):
##   godot --path . --resolution 720x1280 res://scenes/dev/hud_lab.tscn -- --autotest --gate-legibility --out=DIR
##        [--level=45] [--tag=720] [--cases=ult_storm,champ_shot]
## writes DIR/gate_legibility_<case>_<tag>.png (the worst capture, label rects outlined: green >= 3 : 1,
## red below), DIR/gate_legibility_baseline_<tag>.png and DIR/gate_legibility.csv (case, capture time,
## label, contrast, text / background luminance, text pixels, baseline). Exit code = failing cases (+1 when
## the baseline self-check fails). Last line: HUD_LAB_GATES PASS|FAIL: ...
## Headless: prints SKIPPED and exits 77; with --setup-only it builds every case, finds the row, triggers
## the fx, runs its frames and checks the labels project into the screen (nothing measured), exit 0 when
## all set up:
##   godot --headless --path . res://scenes/dev/hud_lab.tscn -- --autotest --gate-legibility [--setup-only]
## Always pass --autotest: it makes Save read-only before Meta loads, so the real save is never touched.

const HUD_SCRIPT := "res://scripts/ui/run_hud.gd"
const KP := preload("res://scripts/dev/test_kind_parity.gd")
const MIN_RATIO := 3.0
const AHEAD := 6.0
const ARMY := 220
const DT := 1.0 / 60.0
const CAPTURE_AT: Array[float] = [0.1, 0.25, 0.5, 0.8, 1.2, 1.8, 2.5]
## Text pixels: luminance above the label-less frame by this much (white glyph fill).
const TEXT_DIFF := 0.1
const MIN_TEXT := 12
const BG_PCT := 0.9
const TEAM_A: Array[String] = ["borko", "alba", "taya", "ivo"]
const TEAM_B: Array[String] = ["mila"]
## name -> [hero, team, what]
const CASES := {
	# The control: nothing fired; what the gate row alone reads over the captures (its field animates).
	"quiet": ["bolt", [], "none"],
	"ult_storm": ["bolt", [], "ult"],
	"ult_quake": ["titan", [], "ult"],
	"ult_rift": ["seer", [], "ult"],
	"champ_leap": ["bolt", TEAM_A, &"champ_leap"],
	"champ_shot": ["bolt", TEAM_A, &"champ_shot"],
	"champ_spell": ["bolt", TEAM_A, &"champ_spell"],
	"champ_block": ["bolt", TEAM_A, &"champ_block"],
	"champ_mend": ["bolt", TEAM_B, &"champ_mend"],
	"champ_down": ["bolt", TEAM_A, &"champ_down"],
}
const OPS_PLAIN := ["+", "-", "x", "/"]
## Headless without --setup-only: nothing measured, exit code 77.
const SKIPPED := 77

var args := {}
var out_dir := ""
var tag := "720"
var level := 45
var _render := true
var _fails := 0
var _csv: PackedStringArray = PackedStringArray()
## The baseline self-check runs on the first rendered case.
var _baseline_checked := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(args.get("out", ""))
	tag = str(args.get("tag", "720"))
	level = maxi(1, int(args.get("level", "45")))
	_render = DisplayServer.get_name() != "headless"
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.readonly = true
	if not args.has("gate-legibility"):
		print("hud_lab: pass --gate-legibility (see the header)")
		get_tree().quit(0)
		return
	if not _render and not args.has("setup-only"):
		print("HUD_LAB_GATES SKIPPED: headless (no renderer); run windowed on a hidden desktop, or pass --setup-only")
		get_tree().quit(SKIPPED)
		return
	var old_phase := EconData.phase_override
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	Juice.hitstop_enabled = false
	if out_dir != "" and _render:
		DirAccess.make_dir_recursive_absolute(out_dir)
	var names: Array = CASES.keys()
	if args.has("cases"):
		names = []
		for c in str(args["cases"]).split(",", false):
			if CASES.has(c):
				names.append(c)
	var t0 := Time.get_ticks_msec()
	print("HUD_LAB gate legibility: L%d, gate row %.0f u ahead, army %d, captures at %s s, rule >= %.0f : 1%s" % [level,
			AHEAD, ARMY, str(CAPTURE_AT), MIN_RATIO, "" if _render else " (headless: setup check only)"])
	_csv.append("case,capture_t,label,contrast,text_lum,bg_lum,text_px,baseline")
	if not _render:
		_baseline_checked = true
	var passed := 0
	for name: String in names:
		var ok: bool = await _case(name)
		passed += 1 if ok else 0
		if not ok:
			_fails += 1
	if out_dir != "" and _render:
		var f := FileAccess.open(out_dir.path_join("gate_legibility.csv"), FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_csv) + "\n")
			f.close()
			print("HUD_LAB written ", out_dir.path_join("gate_legibility.csv"))
	EconData.phase_override = old_phase
	Juice.hitstop_enabled = true
	print("HUD_LAB_GATES %s: %d of %d cases %s (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", passed, names.size(),
			"at >= 3 : 1" if _render else "set up (headless: nothing measured)", float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


# ------------------------------------------------------------------ one case

func _case(name: String) -> bool:
	var spec: Array = CASES[name]
	var hero := str(spec[0])
	var team: Array = spec[1]
	var acc := KP.account_with(level, hero, team)
	var keep: Array = KP.swap_in(acc, hero)
	var holder := Node.new()
	holder.name = "Play"
	# The lab runs while paused (captures); the play pauses with the tree.
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	var run := Run.new()
	run.setup(level, hero)
	holder.add_child(run)
	var hud: CanvasLayer = (load(HUD_SCRIPT) as GDScript).new()
	hud.call("setup", run)
	holder.add_child(hud)
	holder.set_meta("run", run)
	holder.set_meta("hud", hud)
	KP.swap_out(keep)
	add_child(holder)
	await get_tree().process_frame
	run.set_process(false)
	var row := _pick_row(run)
	if row.is_empty():
		print("  FAIL %s: no gate row on L%d" % [name, level])
		await _drop(holder)
		return false
	var gd := float(row[0]["d"])
	var gx := float(row[0]["x"])
	for g: Dictionary in row:
		if absf(float(g["x"])) < absf(gx):
			gx = float(g["x"])
	run.skip_to(gd - AHEAD)
	run.set_army(ARMY)
	run.hx = gx
	run.target_x = gx
	_place_champions(run)
	# A gate row is met while RUNNING, never under the READY start banner (1.2 s, §10.5).
	run.start()
	_close_banner(run)
	for k in 20:
		await _frame(run, false)
	var labels := _labels(row)
	var cam := get_viewport().get_camera_3d()
	var on_screen := 0
	for l: Label3D in labels:
		if not _rect(l, cam).has_area():
			continue
		on_screen += 1
	if not _render:
		var what := _trigger(run, spec[2], row, gd, gx)
		for k in int(CAPTURE_AT[CAPTURE_AT.size() - 1] / DT) + 2:
			await _frame(run, str(spec[2]) == "ult")
		var ok_setup := on_screen > 0 and what != ""
		print("  %s %s: hero %s, team %s, row at d %.1f (%d gates, %d labels with text, %d on screen), fired %s" % [
				"SETUP" if ok_setup else "FAIL", name, hero, ",".join(PackedStringArray(team)), gd, row.size(), labels.size(),
				on_screen, what])
		await _drop(holder)
		return ok_setup
	var base: Dictionary = await _capture(run, row, labels)
	var base_min := _min_ratio(base)
	if not _baseline_checked:
		_baseline_checked = true
		_baseline_check(base, name)
		await _kinds_check(run, row)
		labels = _labels(row)
	var what2 := _trigger(run, spec[2], row, gd, gx)
	var worst := {"ratio": INF}
	var worst_img: Image = null
	var worst_rects: Array = []
	var worst_t := 0.0
	var measured := 0
	var t := 0.0
	for at in CAPTURE_AT:
		while t + DT * 0.5 < at:
			await _frame(run, str(spec[2]) == "ult")
			t += DT
		var cap: Dictionary = await _capture(run, row, labels)
		for r: Dictionary in cap["rows"]:
			measured += 1
			_csv.append("%s,%.2f,%s,%.2f,%.3f,%.3f,%d,%.2f" % [name, at, str(r["label"]), float(r["ratio"]),
					float(r["text"]), float(r["bg"]), int(r["px"]), float((base["by"] as Dictionary).get(str(r["key"]), 0.0))])
			if float(r["ratio"]) < float(worst["ratio"]):
				worst = r
				worst_img = cap["img"]
				worst_rects = cap["rects"]
				worst_t = at
	# Nothing measured (no label on screen, no image) is a failure, never a vacuous pass.
	var ok := measured > 0 and on_screen > 0 and float(worst["ratio"]) >= MIN_RATIO
	# What the fx itself took: the same label's quiet-frame ratio minus its worst under the fx.
	var same_base := float((base["by"] as Dictionary).get(str(worst.get("key", "")), 0.0))
	print("  %s %s (%s): worst %.2f : 1 on %s at %.2f s (text lum %.2f vs background %.2f, %d text px; median background %.2f : 1); that label's baseline %.2f : 1 (fx drop %+.2f); baseline worst %.2f : 1; %d label measurements" % [
			"PASS" if ok else "FAIL", name, what2, float(worst["ratio"]), str(worst.get("label", "?")), worst_t,
			float(worst.get("text", 0.0)), float(worst.get("bg", 0.0)), int(worst.get("px", 0)),
			float(worst.get("ratio_med", 0.0)), same_base, float(worst["ratio"]) - same_base, base_min, measured])
	if worst_img and out_dir != "":
		_outline(worst_img, worst_rects)
		worst_img.save_png(out_dir.path_join("gate_legibility_%s_%s.png" % [name, tag]))
	await _drop(holder)
	return ok


func _drop(holder: Node) -> void:
	get_tree().paused = false
	remove_child(holder)
	holder.free()
	await get_tree().process_frame


## The first row of revealed plain army gates (+ - x /) at d >= 20, else the first row: [gate items].
static func _pick_row(run: Run) -> Array:
	var rows := {}
	var order: Array = []
	for it: Dictionary in run.items:
		if str(it["kind"]) != "gate" or float(it["d"]) < 20.0:
			continue
		var r := int(it.get("row", -1))
		if not rows.has(r):
			rows[r] = []
			order.append(r)
		(rows[r] as Array).append(it)
	for r in order:
		var plain := true
		for g: Dictionary in rows[r]:
			if not (str(g["op"]) in OPS_PLAIN) or not bool(g.get("revealed", true)):
				plain = false
		if plain:
			return rows[r]
	return rows[order[0]] if not order.is_empty() else []


## The champions at their slots around the blob (ChampionKinds.step's placement, without acting).
static func _place_champions(run: Run) -> void:
	if not run.champions.active():
		return
	var a := run.kind_view.army()
	for m: Dictionary in run.champions.members:
		var off := ChampionKinds.slot_offset(m["slot"], float(a["radius"]))
		m["x"] = float(a["x"]) + off.x
		m["d"] = float(a["d"]) - off.y
	if run.champ_view:
		run.champ_view._place(0.0, true)


## The row's labels with text: the big numbers and the forecast texts.
static func _labels(row: Array) -> Array:
	var out: Array = []
	for g: Dictionary in row:
		var node := g["node"] as Node3D
		for key in ["label", "sub"]:
			var l: Label3D = node.get_meta(key) if node.has_meta(key) else null
			if l and l.text.strip_edges() != "" and l.is_visible_in_tree():
				out.append(l)
	return out


## One frame: the run's visuals (and the ult clock when `ult`), never its logic step.
func _frame(run: Run, ult: bool) -> void:
	if ult:
		run._ult_step(DT)
	run._visuals(DT)
	await get_tree().process_frame


## Fires the case. Returns what was fired ("" when it could not be).
static func _trigger(run: Run, what: Variant, row: Array, gd: float, gx: float) -> String:
	if str(what) == "none":
		return "nothing (control)"
	if str(what) == "ult":
		run.ult_points = float(run.ult["charge"])
		return "ult %s" % String(HeroKinds.ult_kind(run.hero_type)) if run.use_ult() else ""
	var ev := StringName(str(what))
	var ms := run.champions.members
	var pick := {}
	var want := {&"champ_leap": "warrior", &"champ_shot": "ranger", &"champ_spell": "mage", &"champ_block": "guardian",
			&"champ_mend": "healer", &"champ_down": ""}
	for m: Dictionary in ms:
		if str(want.get(ev, "")) == "" or str(m["class"]) == str(want[ev]):
			pick = m
			break
	if pick.is_empty() or run.champ_view == null:
		return ""
	var id := str(pick["id"])
	var data := {"id": id}
	match ev:
		&"champ_leap":
			data.merge({"target": -1, "d": gd - 1.5, "x": gx})
		&"champ_shot":
			data.merge({"target": -1, "d": gd + 0.5, "x": gx, "arrows": 3, "pierce": 0})
		&"champ_spell":
			data.merge({"d": gd - 0.5, "x": gx, "r": 2.0})
		&"champ_block":
			data.merge({"hazard": _hazard_near(run, gd), "kind": &"barricade"})
		&"champ_mend":
			data.merge({"n": 4, "front": true})
		&"champ_down":
			pick["alive"] = false
			pick["hp"] = 0.0
			data.merge({"slot": pick["slot"], "x": float(pick["x"]), "d": float(pick["d"])})
	run._champ_fx(ev, data)
	return "%s by %s" % [String(ev), id]


## The KindView id of the nearest live barricade / turret ahead of the hero within the gate row, else -1.
static func _hazard_near(run: Run, gd: float) -> int:
	for it: Dictionary in run.items:
		var k := str(it["kind"])
		if (k == "barricade" or k == "turret") and it["alive"] and float(it["d"]) > run.d and float(it["d"]) <= gd:
			return int(it["kid"])
	return -1


# ------------------------------------------------------------------ measuring

## Pauses the tree, renders the frame as is and with the row's label glyphs hidden (fill and outline at
## alpha 0; the glow quad behind them stays), measures every label rect, resumes. Returns {img, rows
## [{label, key, ratio, text, bg, px}], by {key: ratio}, rects [[Rect2i, ratio]]}; a label's key is its
## place in the row's label list and kind ("l0 num", "l1 sub"), stable while an ult changes the number.
func _capture(run: Run, row: Array, labels: Array) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var a := get_viewport().get_texture().get_image()
	var keep: Array = []
	for l: Label3D in labels:
		keep.append([l.modulate, l.outline_modulate])
		l.modulate = Color(l.modulate, 0.0)
		l.outline_modulate = Color(l.outline_modulate, 0.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var b := get_viewport().get_texture().get_image()
	for i in labels.size():
		(labels[i] as Label3D).modulate = keep[i][0]
		(labels[i] as Label3D).outline_modulate = keep[i][1]
	get_tree().paused = false
	var out := {"img": a, "rows": [], "by": {}, "rects": []}
	if a == null or b == null or a.is_empty():
		return out
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	for i in labels.size():
		var l: Label3D = labels[i]
		var r := _rect(l, cam)
		if not r.has_area():
			continue
		var key := "l%d %s" % [i, "num" if l.font_size > 150 else "sub"]
		var m := _measure(a, b, Rect2i(r))
		m["label"] = "%s '%s'" % [key, l.text.replace(",", " ").replace("\n", " ")]
		m["key"] = key
		(out["rows"] as Array).append(m)
		(out["by"] as Dictionary)[key] = float(m["ratio"])
		(out["rects"] as Array).append([Rect2i(r), float(m["ratio"])])
	return out


## Info beside the self-check: the same quiet row restyled as every gate kind (Models.gate_style, the
## row's own number and forecast; "?" for hidden), each label's ratio printed, then the row's own style
## back (Run._style_gate). Not asserted: the game shows these kinds where its levels put them.
func _kinds_check(run: Run, row: Array) -> void:
	var texts: Array = []
	for g: Dictionary in row:
		var n0 := g["node"] as Node3D
		var l0: Label3D = n0.get_meta("label") if n0.has_meta("label") else null
		var s0: Label3D = n0.get_meta("sub") if n0.has_meta("sub") else null
		texts.append([l0.text if l0 else "+10", s0.text if s0 else "", str(n0.get_meta("kind", "good"))])
	for kind: String in ["good", "bad", "charge", "hidden", "power", "arm"]:
		for i in row.size():
			var t: Array = texts[i]
			Models.gate_style(row[i]["node"] as Node3D, "?" if kind == "hidden" else str(t[0]), str(t[1]), kind)
		for k in 3:
			await _frame(run, false)
		var cap: Dictionary = await _capture(run, row, _labels(row))
		var parts: PackedStringArray = PackedStringArray()
		for r: Dictionary in cap["rows"]:
			parts.append("%s %.2f (median bg %.2f)" % [str(r["label"]), float(r["ratio"]), float(r["ratio_med"])])
		print("    gate kind %-6s on the quiet frame: %s" % [kind, "; ".join(parts)])
		if out_dir != "" and cap.get("img") is Image:
			var img: Image = cap["img"]
			_outline(img, cap["rects"])
			img.save_png(out_dir.path_join("gate_legibility_kind_%s_%s.png" % [kind, tag]))
	for i in row.size():
		var t2: Array = texts[i]
		Models.gate_style(row[i]["node"] as Node3D, str(t2[0]), str(t2[1]), str(t2[2]))
		run._style_gate(row[i])
	for k in 3:
		await _frame(run, false)


## The start banner (READY only, 1.2 s) closed at once, so the quiet frame is a running one.
static func _close_banner(run: Run) -> void:
	if run.champ_view and run.champ_view.hud and is_instance_valid(run.champ_view.hud.banner):
		run.champ_view.hud.banner.call("hide_now")


## Self-check: the plain gate row on the quiet frame (before any fx) must read >= MIN_RATIO on every
## label, else the lab's own reference frame is illegible (printed with the numbers; the lab fails).
func _baseline_check(base: Dictionary, name: String) -> void:
	var rows: Array = base["rows"]
	var low: PackedStringArray = PackedStringArray()
	var parts: PackedStringArray = PackedStringArray()
	for r: Dictionary in rows:
		parts.append("%s %.2f (text %.2f / bg %.2f, %d px; median bg %.2f)" % [str(r["label"]), float(r["ratio"]),
				float(r["text"]), float(r["bg"]), int(r["px"]), float(r["ratio_med"])])
		if float(r["ratio"]) < MIN_RATIO:
			low.append(str(r["label"]))
	var ok := not rows.is_empty() and low.is_empty()
	if not ok:
		_fails += 1
	print("  %s baseline self-check (%s's quiet frame, no fx): every label >= %.0f : 1: %s" % ["PASS" if ok else "FAIL",
			name, MIN_RATIO, "; ".join(parts) if not parts.is_empty() else "no label measured"])
	if out_dir != "" and base.get("img") is Image:
		var img: Image = (base["img"] as Image).duplicate()
		_outline(img, base["rects"])
		img.save_png(out_dir.path_join("gate_legibility_baseline_%s.png" % tag))


static func _min_ratio(cap: Dictionary) -> float:
	var v := INF
	for r: Dictionary in cap["rows"]:
		v = minf(v, float(r["ratio"]))
	return v


## The label's screen rect: its mesh AABB corners projected (clipped to the viewport; empty when behind
## the camera or off screen).
func _rect(l: Label3D, cam: Camera3D) -> Rect2:
	if cam == null:
		return Rect2()
	var box := l.get_aabb()
	var xf := l.global_transform
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in 8:
		var p := xf * box.get_endpoint(k)
		if cam.is_position_behind(p):
			return Rect2()
		var s := cam.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return Rect2(lo, hi - lo).intersection(vp)


## WCAG relative luminance of an sRGB colour.
static func lum(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	for i in 3:
		var v: float = ch[i]
		ch[i] = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func ratio(l1: float, l2: float) -> float:
	return (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05)


## Text pixels of `a` (brighter than the glyph-less `b` by TEXT_DIFF) in `r` against `b` at those very
## pixels (what is drawn right behind the glyphs): {ratio, text, bg, px}.
static func _measure(a: Image, b: Image, r: Rect2i) -> Dictionary:
	var text := PackedFloat32Array()
	var bg := PackedFloat32Array()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var la := lum(a.get_pixel(x, y))
			var lb := lum(b.get_pixel(x, y))
			if la - lb > TEXT_DIFF:
				text.append(la)
				bg.append(lb)
	if text.size() < MIN_TEXT or bg.is_empty():
		return {"ratio": 1.0, "ratio_med": 1.0, "text": 0.0, "bg": 0.0, "px": text.size()}
	text.sort()
	bg.sort()
	var lt := text[text.size() / 2]
	var lbk := bg[clampi(int(BG_PCT * float(bg.size() - 1)), 0, bg.size() - 1)]
	# ratio_med (info): against the median background behind the glyphs instead of its bright end.
	return {"ratio": ratio(lt, lbk), "ratio_med": ratio(lt, bg[bg.size() / 2]), "text": lt, "bg": lbk,
			"px": text.size()}


## Outlines each [rect, ratio] on `img` (2 px; green at >= MIN_RATIO, red below).
static func _outline(img: Image, rects: Array) -> void:
	for e: Array in rects:
		var r: Rect2i = e[0]
		var col := Color(0.2, 1.0, 0.3) if float(e[1]) >= MIN_RATIO else Color(1.0, 0.15, 0.15)
		img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 2), col)
		img.fill_rect(Rect2i(r.position.x, r.end.y - 2, r.size.x, 2), col)
		img.fill_rect(Rect2i(r.position.x, r.position.y, 2, r.size.y), col)
		img.fill_rect(Rect2i(r.end.x - 2, r.position.y, 2, r.size.y), col)
