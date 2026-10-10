extends Node
## HUD lab (heroes design §10.2, §10.5, §12.6 #11). Two modes:
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
##   ult_anchor (arin), ult_rime (eira), ult_comet (iskar), ult_sunglaive (vesta), ult_forgewall (vartan),
##     ult_spectrum (lumen), ult_eyes (pava), ult_letter (sirko), ult_doves (olha): the nine new kinds the same
##     way, each on its v3 row with the ult at its TOP form (_top_form: the biggest version of every shape), drawn
##     by HeroFx; at every capture HeroFx's own alpha over the row's label rects is measured too (_fx_alpha: its
##     draw alone over black and over white), and a stack above its GATE_CAP (§10.2 rule 3) is printed as
##     HEROFX_STACK (information: HeroFx belongs to the Run; the labels' contrast is what is asserted);
##   champ_leap, champ_shot, champ_spell, champ_block, champ_down (team borko, alba, taya, ivo) and
##     champ_mend (team mila): the rules' champ_* fx event through Run._champ_fx, aimed at the gate row
##     (the leap lands 1.5 u before it, the arrows fly to 0.5 u past it, the spell ring sits on it, the
##     «БЛОК» pops at the nearest hazard ahead or the Guardian, the fallen champion lies at its slot).
## The run is started (RUNNING, as when an army meets a gate row) and the champions' start banner, which
## only lives 1.2 s during READY (§10.5), is closed first: a gate row is never met under it (--banner
## measures where it does show).
## Captures at CAPTURE_AT s after the trigger (and one baseline before it, on the quiet frame). A capture
## pauses the tree and renders the frame twice: as is, and with the row's label glyphs hidden (the big
## number and the forecast text: their fill and outline at alpha 0; their glow quad, drawn behind the
## glyphs as part of the backdrop, stays). Glyph mask: on the baseline frame, each label's text pixels
## (brighter than the glyph-less frame by TEXT_DIFF in luminance: the white fill), kept as offsets from the
## label's projected corner with their count. At every capture the label is measured on that mask: its text
## pixels = mask pixels still brighter than the glyph-less frame by TEXT_DIFF; fewer than COVER_SHARE of the
## baseline count = covered (ratio 1, a failure: half a washed-out label never passes on the half left; but a
## label covered on its baseline mask is measured again on its true mask of that frame, from the glyphs-only
## render: a camera shake moves small glyphs off their baseline mask, while a label an fx really covers stays
## covered on its true mask, "re-masked (moved)", as --compare does);
## else contrast = WCAG ratio of their median luminance and the 90th-percentile luminance of the glyph-less
## frame over the WHOLE mask (what is drawn right behind every glyph pixel, its bright end). A label whose
## text an ult changed (it hits the gate: "+45" -> "+52") gets its mask re-taken for the new text from a
## glyphs-only render (the row's labels alone on a black clear, the HUD hidden: fill brighter than ISO_LUM);
## the baseline self-check prints how well that render's masks agree with the baseline's. A baseline mask
## under MIN_TEXT pixels counts as covered. A case FAILS when any label at any capture is below 3 : 1 or
## covered. Self-check (once per run of the lab): the baseline of the plain gate row on the quiet frame must
## be >= 3 : 1 on every label (printed per label; if the game's own labels are below it, the numbers say so
## and the lab fails); beside it, for information, the same row restyled as every gate kind. Each case also
## prints the worst label's own baseline and the drop the fx took from it.
## (Before: the background was sampled only at the pixels still detected as text, so a half-washed label
## could pass on its other half; before that, the label-less frame hid the Label3D with its glow, the
## background was the 90th percentile of the whole rect, and the READY banner lay over the row in every
## champion case.)
##
## --banner: the champions' start banner (TeamBanner, 1.2 s from READY, ChampionHud places it) over a
## REAL level start, §10.2: for each of --levels (default BANNER_LEVELS) a fresh run (bolt, team borko,
## alba, taya, ivo: the widest ribbon) is left at READY as the game leaves it (nothing skipped, the army
## where the level starts it) until the banner and its cached picture are fully in; then every gate row
## ahead with a label on screen is projected and its label rects intersected with the ribbon (its glass
## plus the marquise ends, in viewport px), and the first row's labels are measured as above: baseline =
## the same paused frame with the banner's picture hidden, capture = with it. Then the worst case of a real
## start: the player taps at once (Run.start the moment the banner is in) and the run moves on under the
## banner for the rest of its life, every frame checked against the ribbon again. A level FAILS when the
## ribbon touches any gate label on screen (at READY or running under it) or a first-row label loses more
## than BANNER_DROP of its own banner-less ratio (or is newly covered). The first row's absolute ratio is
## printed, not asserted: at 30-85 u ahead its labels are small and below 3 : 1 with or without the
## banner (the game's far-row legibility, not the banner's). Last line: HUD_LAB_BANNER PASS|FAIL.
##
## --compare (owner decisions 10.10: see v2 before it ships, then v2 for everyone): the old gate labels (v1) beside
## the legible ones v2 (Models.gate_labels_v2, every run's default: an ink plate behind the number and the
## forecast, the labels above every ult VFX while an ult runs, the ult layers held back over gate panels; §10.2
## rules 2-3). --gate-legibility alone measures v2, or v1 when the run is started with --gate_labels=v1. Parts:
## A) the matrix: every COMPARE_KINDS gate kind x COMPARE_CASES case on the --level template (row AHEAD u ahead,
##    army ARMY), under v1 and then v2. Per cell a fresh play with the global RNG seeded (COMPARE_SEED: both
##    variants see the same frames), the row's gates set to the kind in the run's own data (_set_kind: the run
##    styles them and an ult hits them as in the game), then the --gate-legibility measure: the quiet baseline's
##    glyph masks, the trigger, the captures at CAPTURE_AT, a label covered on its baseline mask measured again on
##    its true mask of that frame (_capture `moved`: the quake's camera shake, both variants alike). v2's
##    glyph-less frame keeps the plate, so its ratio is the text against its own plate (and whatever the plate
##    lets through). A table of the worst ratio per cell (v1 -> v2; "!" below 3 : 1, "~" below the IDEAL 4.5 : 1),
##    HeroFx's worst alpha over the row per new-kind case, DIR/gate_compare.csv and
##    DIR/cells/<v1|v2>_<case>_<kind>.png (the worst capture around the row).
## B) the stills (STILLS: a plain row, a power / arm row, Руді's storm over a row, a W4 row, and a squad standing
##    in front of a gate outside an ult): the same frame under v1 and v2, DIR/<name>_v1.png, DIR/<name>_v2.png,
##    DIR/compare_<name>.png (v1 left, v2 right) and DIR/compare_<name>_zoom.png (the row, x2). The squad still
##    adds a third frame, v2 in its ult draw (Models.labels_over forced on, as while an ult runs), to its pair: the
##    calm v2 tablet sits behind the squad as v1's labels do, the ult one over it.
## Exit code = matrix cells where v2 reads below 3 : 1 (or is covered). Last line: HUD_LAB_COMPARE PASS|FAIL.
##   godot --fixed-fps 60 --path . --resolution 720x1280 res://scenes/dev/hud_lab.tscn -- --autotest --compare
##        --out=DIR [--level=45] [--cases=quiet,ult_storm] [--kinds=good,power] [--stills=storm_L12|none]
##        [--matrix=none]
##
## --fit (headless is fine): the gate number's size, v1 against v2, for FIT_GATES (typical faces on a 3-gate row's
## 1.7 u gate and a 2-gate row's 2.1 u one) in every world: each number's cap height under both, v2's share of v1's,
## and the tablet against the panel (inside the field: its width, its top under the crossbar, its bottom over the
## base rail). A face marked to check FAILS when its v2 number is off v1's by more than FIT_TOL or its tablet
## leaves the panel (a long word, a weapon's name, is printed only: the tablet's pads take width v1 never had).
## Exit code = the failing faces; last line HUD_LAB_FIT PASS|FAIL.
##   godot --headless --path . res://scenes/dev/hud_lab.tscn -- --autotest --fit
##
## Needs a real renderer (e.g. the hidden desktop):
##   godot --path . --resolution 720x1280 res://scenes/dev/hud_lab.tscn -- --autotest --gate-legibility --out=DIR
##        [--level=45] [--tag=720] [--cases=ult_storm,champ_shot]
##   godot --path . --resolution 720x1280 res://scenes/dev/hud_lab.tscn -- --autotest --banner --out=DIR
##        [--levels=1,12,45] [--tag=720]
## --gate-legibility writes DIR/gate_legibility_<case>_<tag>.png (the worst capture, label rects outlined:
## green >= 3 : 1, red below), DIR/gate_legibility_baseline_<tag>.png and DIR/gate_legibility.csv (case,
## capture time, label, contrast, text / background luminance, text pixels, glyph-mask pixels, covered, mask
## source, baseline); --banner writes DIR/banner_L<level>_<tag>.png (the ribbon outlined in gold, the label
## rects green / red) and DIR/banner_overlap.csv. Exit code = failing cases / levels (+1 when the baseline
## self-check fails). Last line: HUD_LAB_GATES | HUD_LAB_BANNER PASS|FAIL: ...
## Headless: prints SKIPPED and exits 77; with --setup-only --gate-legibility builds every case, finds the
## row, triggers the fx, runs its frames and checks the labels project into the screen (nothing measured),
## exit 0 when all set up:
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
## A label at a capture keeps at least this share of its baseline glyph-mask pixels as text, else covered.
const COVER_SHARE := 0.7
## Glyphs-only render (re-masking a label whose text changed): a glyph fill pixel is brighter than this.
const ISO_LUM := 0.2
## The visual layer the glyphs-only render puts the row's labels on (nothing else of the run uses it).
const ISO_LAYER := 1 << 19
## --banner: the level spread (early campaign, the world changes, the 4-member team's levels).
const BANNER_LEVELS: Array[int] = [1, 2, 3, 5, 8, 12, 16, 20, 25, 30, 35, 41, 45, 50, 60, 75, 90, 110]
## --banner: frames to wait for the banner to be fully in (it links within ~30 frames, fades in 0.15 s).
const BANNER_WAIT := 180
## The ribbon's marquise ends reach this far past its glass (TeamBanner._draw: 7 + 10 px).
const MARQUISE := 17.0
## --banner: a first-row label may read at most this much below its own banner-less ratio (render noise).
const BANNER_DROP := 0.05
const TEAM_A: Array[String] = ["borko", "alba", "taya", "ivo"]
const TEAM_B: Array[String] = ["mila"]
## name -> [hero, team, what]
const CASES := {
	# The control: nothing fired; what the gate row alone reads over the captures (its field animates).
	"quiet": ["bolt", [], "none"],
	"ult_storm": ["bolt", [], "ult"],
	"ult_quake": ["titan", [], "ult"],
	"ult_rift": ["seer", [], "ult"],
	# The nine new kinds (HeroKinds.KINDS), each at its top form, drawn by HeroFx.
	"ult_anchor": ["arin", [], "ult"],
	"ult_rime": ["eira", [], "ult"],
	"ult_comet": ["iskar", [], "ult"],
	"ult_sunglaive": ["vesta", [], "ult"],
	"ult_forgewall": ["vartan", [], "ult"],
	"ult_spectrum": ["lumen", [], "ult"],
	"ult_eyes": ["pava", [], "ult"],
	"ult_letter": ["sirko", [], "ult"],
	"ult_doves": ["olha", [], "ult"],
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
## --compare: the gate kinds and the cases of the legibility matrix.
const COMPARE_KINDS: Array[String] = ["good", "bad", "charge", "hidden", "power", "arm", "closed"]
const COMPARE_CASES: Array[String] = ["quiet", "ult_storm", "ult_quake", "ult_rift", "ult_anchor", "ult_rime",
		"ult_comet", "ult_sunglaive", "ult_forgewall", "ult_spectrum", "ult_eyes", "ult_letter", "ult_doves"]
## --compare: the ratio v2 aims at in every cell (the owner's target; 3 : 1 is the §10.2 rule).
const IDEAL_RATIO := 4.5
## HeroFx's alpha over a gate panel may reach its GATE_CAP (0.35) plus this (8-bit rounding and edge
## anti-aliasing) before a stack is reported; the alpha is the FX_PCT percentile over the label rects (the max too).
const FX_TOL := 0.03
const FX_PCT := 0.99
## --compare: the global RNG seed of every play, so v1 and v2 see the same frames (with --fixed-fps 60 the frame
## deltas match too).
const COMPARE_SEED := 1010
## --compare: the gate ops that make a power / arm row (Run._style_gate).
const OPS_POWER := ["rate", "dmg", "multi", "weapon", "ult", "rank", "arm"]
## --compare stills for the owner: name -> [level, hero, row (plain: the first plain row; power: the first row with
## a power or arm gate, searched from the level on), fire (none | ult | squad: no fire, an enemy squad moved to stand
## right in front of the row's middle gate, _squad_in_front), u ahead, army (0: the level's own), shot at s after
## the trigger (the storm ticks every 0.25 s: 0.52 s is just after a tick)].
const STILLS := {
	"plain_L5": [5, "bolt", "plain", "none", 7.0, 30, 0.5],
	"power_arm": [5, "bolt", "power", "none", 7.0, 30, 0.5],
	"storm_L12": [12, "bolt", "plain", "ult", 7.0, 60, 0.52],
	"w4_L28": [28, "bolt", "plain", "none", 7.0, 120, 0.5],
	"squad_front": [5, "bolt", "plain", "squad", 9.0, 30, 0.5],
}
## The squad still: its back rank this far before the gate row (its front further toward the army), its soldiers.
const SQUAD_GAP := 0.5
const SQUAD_HP := 24
## --fit: [gate width, number, forecast, kind, icon, checked]; the widths are LevelGen's ROW3_W and ROW2_W.
const FIT_GATES := [
	[1.7, "+8", "→ 38", "good", "", true],
	[1.7, "−11", "→ 19", "bad", "", true],
	[1.7, "×2", "→ 60", "good", "", true],
	[1.7, "÷2", "→ 15", "bad", "", true],
	[1.7, "+125", "→ 345", "good", "", true],
	[2.1, "+45", "→ 265", "good", "", true],
	[2.1, "−120", "→ 145", "bad", "", true],
	[1.7, "−12", "→ +20", "charge", "", true],
	[1.7, "+1", "шкода", "power", "dmg", true],
	[1.7, "+30%", "швидкість", "power", "rate", true],
	[1.7, "II", "Баліста", "power", "star", true],
	[1.7, "?", "", "hidden", "", true],
	[1.7, "+12", "", "closed", "", true],
	[2.1, "Арбалети", "", "power", "crossbow", false],
]
## --fit: a checked v2 number's cap height within this share of v1's.
const FIT_TOL := 0.05
## --compare stills: real milliseconds to block after parking, so the army counter (Juice.counter runs on the
## wall clock, not the frame clock) has finished counting in both variants' frames.
const COUNTER_MS := 900
## --compare stills: the zoomed pair's crop around the row (px of margin) and its scale.
const ZOOM_PAD := 40
const ZOOM := 2

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
	var banner := args.has("banner")
	var compare := args.has("compare")
	if args.has("fit"):
		_fit_lab()
		get_tree().quit(_fails)
		return
	if not args.has("gate-legibility") and not banner and not compare:
		print("hud_lab: pass --gate-legibility, --banner, --compare or --fit (see the header)")
		get_tree().quit(0)
		return
	var gate := "HUD_LAB_BANNER" if banner else ("HUD_LAB_COMPARE" if compare else "HUD_LAB_GATES")
	if not _render and (banner or compare or not args.has("setup-only")):
		print("%s SKIPPED: headless (no renderer); run windowed on a hidden desktop%s" % [gate,
				"" if banner or compare else ", or pass --setup-only"])
		get_tree().quit(SKIPPED)
		return
	var old_phase := EconData.phase_override
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	Juice.hitstop_enabled = false
	if out_dir != "" and _render:
		DirAccess.make_dir_recursive_absolute(out_dir)
	if banner:
		await _banner_lab()
	elif compare:
		await _compare_lab()
	else:
		await _gate_lab()
	EconData.phase_override = old_phase
	Juice.hitstop_enabled = true
	get_tree().quit(_fails)


func _gate_lab() -> void:
	var names: Array = CASES.keys()
	if args.has("cases"):
		names = []
		for c in str(args["cases"]).split(",", false):
			if CASES.has(c):
				names.append(c)
	var t0 := Time.get_ticks_msec()
	print("HUD_LAB gate legibility (gate labels %s): L%d, gate row %.0f u ahead, army %d, captures at %s s, rule >= %.0f : 1, covered below %.0f%% of the baseline glyph pixels%s" % [
			"v2" if Models.gate_labels_v2 else "v1", level, AHEAD, ARMY, str(CAPTURE_AT), MIN_RATIO,
			COVER_SHARE * 100.0, "" if _render else " (headless: setup check only)"])
	_csv.append("case,capture_t,label,contrast,text_lum,bg_lum,text_px,glyph_px,covered,mask,baseline")
	if not _render:
		_baseline_checked = true
	var passed := 0
	for name: String in names:
		var ok: bool = await _case(name)
		passed += 1 if ok else 0
		if not ok:
			_fails += 1
	_write_csv("gate_legibility.csv")
	print("HUD_LAB_GATES %s: %d of %d cases %s (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", passed, names.size(),
			"at >= 3 : 1, none covered" if _render else "set up (headless: nothing measured)",
			float(Time.get_ticks_msec() - t0) / 1000.0])


func _write_csv(name: String) -> void:
	if out_dir == "" or not _render:
		return
	var f := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_csv) + "\n")
		f.close()
		print("HUD_LAB written ", out_dir.path_join(name))


# ------------------------------------------------------------------ one case

func _case(name: String) -> bool:
	var spec: Array = CASES[name]
	var hero := str(spec[0])
	var team: Array = spec[1]
	var holder := _new_play(level, hero, team)
	var run: Run = holder.get_meta("run")
	await get_tree().process_frame
	run.set_process(false)
	var row := _pick_row(run)
	if row.is_empty():
		print("  FAIL %s: no gate row on L%d" % [name, level])
		await _drop(holder)
		return false
	var parked: Array = _park(run, row, AHEAD, ARMY)
	var gd := float(parked[0])
	var gx := float(parked[1])
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
	var base: Dictionary = await _capture(labels, {}, true)
	if not _baseline_checked:
		_baseline_checked = true
		_baseline_check(base, name)
		await _kinds_check(run, row)
		labels = _labels(row)
		# The row is back in its own style: its glyph masks are taken again on the quiet frame.
		base = await _capture(labels)
	var base_min := _min_ratio(base)
	var what2 := _trigger(run, spec[2], row, gd, gx)
	var worst := {"ratio": INF}
	var worst_img: Image = null
	var worst_rects: Array = []
	var worst_t := 0.0
	var measured := 0
	var covered := 0
	var remasked := 0
	var moved := 0
	var fx := {}
	var t := 0.0
	for at in CAPTURE_AT:
		while t + DT * 0.5 < at:
			await _frame(run, str(spec[2]) == "ult")
			t += DT
		var cap: Dictionary = await _capture(labels, base, false, true)
		var fx_now: Dictionary = await _fx_alpha(run, labels)
		fx = _fx_worse(fx, fx_now, at)
		for r: Dictionary in cap["rows"]:
			measured += 1
			covered += 1 if r["covered"] else 0
			remasked += 1 if str(r["mask"]) == "re-masked" else 0
			moved += 1 if str(r["mask"]) == "re-masked (moved)" else 0
			_csv.append(_csv_row(name, at, r, float((base["by"] as Dictionary).get(str(r["key"]), 0.0))))
			if float(r["ratio"]) < float(worst["ratio"]):
				worst = r
				worst_img = cap["img"]
				worst_rects = cap["rects"]
				worst_t = at
	_fx_report(name, fx)
	# Nothing measured (no label on screen, no image) is a failure, never a vacuous pass; a covered label
	# measures ratio 1.
	var ok := measured > 0 and on_screen > 0 and float(worst["ratio"]) >= MIN_RATIO
	# What the fx itself took: the same label's quiet-frame ratio minus its worst under the fx.
	var same_base := float((base["by"] as Dictionary).get(str(worst.get("key", "")), 0.0))
	print("  %s %s (%s): worst %.2f : 1 on %s at %.2f s (%s); that label's baseline %.2f : 1 (fx drop %+.2f); baseline worst %.2f : 1; %d label measurements, %d covered, %d re-masked (text changed), %d re-masked (moved)" % [
			"PASS" if ok else "FAIL", name, what2, float(worst["ratio"]), str(worst.get("label", "?")), worst_t,
			_detail(worst), same_base, float(worst["ratio"]) - same_base, base_min, measured, covered, remasked, moved])
	if worst_img and out_dir != "":
		_outline(worst_img, worst_rects)
		worst_img.save_png(out_dir.path_join("gate_legibility_%s_%s.png" % [name, tag]))
	await _drop(holder)
	return ok


## One CSV row of a label measurement (see _gate_lab's header line).
static func _csv_row(name: String, at: float, r: Dictionary, baseline: float) -> String:
	return "%s,%.2f,%s,%.2f,%.3f,%.3f,%d,%d,%s,%s,%.2f" % [name, at, str(r["label"]), float(r["ratio"]), float(r["text"]),
			float(r["bg"]), int(r["px"]), int(r["n"]), str(r["covered"]), str(r["mask"]), baseline]


## A measurement's numbers in words: text vs background luminance and the glyph pixels left.
static func _detail(r: Dictionary) -> String:
	if r.is_empty() or not r.has("n"):
		return "nothing measured"
	var px := "%d of %d glyph px still text" % [int(r["px"]), int(r["n"])]
	if r["covered"]:
		return "COVERED: %s, below %.0f%%; background %.2f" % [px, COVER_SHARE * 100.0, float(r["bg"])]
	return "text lum %.2f vs background %.2f over the glyph mask, %s; median background %.2f : 1%s" % [float(r["text"]),
			float(r["bg"]), px, float(r["ratio_med"]), ", re-masked" if str(r["mask"]) == "re-masked" else ""]


func _drop(holder: Node) -> void:
	get_tree().paused = false
	remove_child(holder)
	holder.free()
	await get_tree().process_frame


## A play at level `lvl` (`hero`, `team`) as main.make_play builds it (the real Run + run HUD), in the tree, at
## READY; a hero without a Meta-1 row (the nine new kinds) with its ult at its top form (_top_form). The lab runs
## while paused (captures); the play pauses with the tree.
func _new_play(lvl: int, hero: String, team: Array) -> Node:
	var acc := KP.account_with(lvl, hero, team)
	var keep: Array = KP.swap_in(acc, hero)
	var holder := Node.new()
	holder.name = "Play"
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	var run := Run.new()
	run.setup(lvl, hero)
	if not HeroKinds.starter(hero):
		_top_form(run, hero)
	holder.add_child(run)
	var hud: CanvasLayer = (load(HUD_SCRIPT) as GDScript).new()
	hud.call("setup", run)
	holder.add_child(hud)
	holder.set_meta("run", run)
	holder.set_meta("hud", hud)
	KP.swap_out(keep)
	add_child(holder)
	return holder


## The run's hero row rebuilt (before the run enters the tree) from its own v3 block with the ult at its top form
## (HeroData.ult_top_form; the attack, levels and multipliers as the profile gives them): the lab measures the
## biggest version of every ult shape.
static func _top_form(run: Run, hero: String) -> void:
	var ph: Variant = run.profile.get("hero")
	var b: Dictionary = HeroKinds.block_for(hero, ph if ph is Dictionary else {}).duplicate()
	b["ult_form"] = HeroData.ult_top_form(String(HeroKinds.ult_kind(hero)))
	run.def = HeroKinds.def_for(hero, b)
	run.ult = run.def["ult"]


## Parks the run `ahead` u before `row`: army `army` (0 keeps the level's own), the hero lined up on the gate
## nearest the middle, the champions at their slots, RUNNING with the start banner closed (a gate row is met
## while RUNNING, never under the READY start banner: 1.2 s, §10.5). Returns [row d, hero x].
static func _park(run: Run, row: Array, ahead: float, army: int) -> Array:
	var gd := float(row[0]["d"])
	var gx := float(row[0]["x"])
	for g: Dictionary in row:
		if absf(float(g["x"])) < absf(gx):
			gx = float(g["x"])
	run.skip_to(gd - ahead)
	if army > 0:
		run.set_army(army)
	run.hx = gx
	run.target_x = gx
	_place_champions(run)
	run.start()
	_close_banner(run)
	return [gd, gx]


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
		var form := " form %d" % int(run.ult["form"]) if run.ult.has("form") else ""
		return "ult %s%s" % [String(HeroKinds.ult_kind(run.hero_type)), form] if run.use_ult() else ""
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

## Pauses the tree, renders the frame as is and with the labels' glyphs hidden (fill and outline at alpha 0;
## the glow quad behind them stays), measures every label, restores the pause state. With no `base` this
## frame is the baseline: each label's glyph mask is taken here (its text pixels, as offsets from the
## label's projected corner) and returned in "masks"; with `iso` the glyphs-only render's mask sizes come
## too ("iso": the self-check's agreement). With a `base`, each label is measured on the base's mask for
## its key, re-taken from a glyphs-only render when its text changed. Returns {img, rows [{label, key,
## ratio, ratio_med, text, bg, px, n, covered, mask}], by {key: ratio}, rects [[Rect2i, ratio]], masks
## {key: mask}, iso {key: pixels}}; a label's key is its place in the label list and its kind ("l0 num",
## "l1 sub"), stable while an ult changes the number. With `moved` (--compare, both variants alike) a label
## covered on its baseline mask is measured again on a mask from the glyphs-only render of the same frame:
## a camera shake (the quake's trauma rolls the camera up to 2 degrees) shifts small glyphs off their baseline
## mask, while a label an fx really covers stays covered on its true mask ("re-masked (moved)").
func _capture(labels: Array, base := {}, iso := false, moved := false) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	var was := get_tree().paused
	get_tree().paused = true
	var a := await _grab()
	var keep: Array = []
	for l: Label3D in labels:
		keep.append([l.modulate, l.outline_modulate])
		l.modulate = Color(l.modulate, 0.0)
		l.outline_modulate = Color(l.outline_modulate, 0.0)
	var b := await _grab()
	for i in labels.size():
		(labels[i] as Label3D).modulate = keep[i][0]
		(labels[i] as Label3D).outline_modulate = keep[i][1]
	var masks: Dictionary = base.get("masks", {})
	var remask := iso or (moved and not base.is_empty())
	for i in labels.size():
		var g0: Dictionary = masks.get(_key(labels[i], i), {})
		if not base.is_empty() and (g0.is_empty() or str(g0["text"]) != (labels[i] as Label3D).text):
			remask = true
	var c: Image = null
	if remask:
		c = await _glyphs_only(labels)
	get_tree().paused = was
	var out := {"img": a, "rows": [], "by": {}, "rects": [], "masks": {}, "iso": {}}
	if a == null or b == null or a.is_empty():
		return out
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	if c:
		c.convert(Image.FORMAT_RGBA8)
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for i in labels.size():
		var l: Label3D = labels[i]
		var raw := _rect_raw(l, cam)
		var r := raw.intersection(vp)
		if not r.has_area():
			continue
		var key := _key(l, i)
		var anchor := Vector2i(raw.position.round())
		var g: Dictionary = masks.get(key, {})
		var src := "baseline"
		if base.is_empty():
			g = _mask_from(a, b, Rect2i(r), anchor, l.text)
			src = "own"
			(out["masks"] as Dictionary)[key] = g
			if c:
				(out["iso"] as Dictionary)[key] = int(_mask_from(c, null, Rect2i(r), anchor, l.text)["n"])
		elif g.is_empty() or str(g["text"]) != l.text:
			g = _mask_from(c, null, Rect2i(r), anchor, l.text)
			src = "re-masked"
		var m := _measure(a, b, g, anchor)
		if moved and c and bool(m["covered"]) and src == "baseline":
			var m2 := _measure(a, b, _mask_from(c, null, Rect2i(r), anchor, l.text), anchor)
			if not m2["covered"]:
				m = m2
				src = "re-masked (moved)"
		m["label"] = "%s '%s'" % [key, l.text.replace(",", " ").replace("\n", " ")]
		m["key"] = key
		m["mask"] = src
		(out["rows"] as Array).append(m)
		(out["by"] as Dictionary)[key] = float(m["ratio"])
		(out["rects"] as Array).append([Rect2i(r), float(m["ratio"])])
	return out


## The next rendered frame of the viewport (two post-draws: a frame with the latest changes in it).
func _grab() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## A label's stable key: its place in the label list and its kind.
static func _key(l: Label3D, i: int) -> String:
	return "l%d %s" % [i, "num" if l.font_size > 150 else "sub"]


## The labels alone (on their own visual layer, the only one the camera sees) over a black clear with a
## linear tonemap and no glow or fog, every CanvasLayer (the HUD) hidden: where their glyphs are now,
## whatever the fx draws over them. Everything is put back.
func _glyphs_only(labels: Array) -> Image:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var keep_mask := cam.cull_mask
	var keep_env := cam.environment
	var layers: Array = []
	for l: Label3D in labels:
		layers.append(l.layers)
		l.layers = ISO_LAYER
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	cam.cull_mask = ISO_LAYER
	cam.environment = env
	var hidden := _hide_canvas()
	var img := await _grab()
	_show_canvas(hidden)
	cam.cull_mask = keep_mask
	cam.environment = keep_env
	for i in labels.size():
		(labels[i] as Label3D).layers = layers[i]
	return img


## Hides every visible CanvasLayer (the HUD); returns them for _show_canvas.
func _hide_canvas() -> Array:
	var hidden: Array = []
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl.visible:
			cl.visible = false
			hidden.append(cl)
	return hidden


static func _show_canvas(hidden: Array) -> void:
	for cl: CanvasLayer in hidden:
		cl.visible = true


## HeroFx's draw alone (its MultiMesh on ISO_LAYER, the only layer the camera sees; no HUD, a linear tonemap, no glow
## or fog) over a black clear and over a white one, the tree paused: a stack of blend_mix layers lets 1 - A of what
## is behind it through, so per pixel A = 1 - (white - black) (the channels' mean). Over the screen rects of
## `labels` (the row's numbers and forecasts: where the tablets are): {a (the FX_PCT percentile), max, label (the
## rect with the highest a)}; {} when the run has no HeroFx or it draws nothing this frame.
func _fx_alpha(run: Run, labels: Array) -> Dictionary:
	var draw: MultiMeshInstance3D = run.hero_fx.get_node_or_null("HeroFxDraw") if run.hero_fx else null
	var cam := get_viewport().get_camera_3d()
	if draw == null or not draw.visible or cam == null:
		return {}
	var was := get_tree().paused
	get_tree().paused = true
	var keep_mask := cam.cull_mask
	var keep_env := cam.environment
	var keep_layers := draw.layers
	draw.layers = ISO_LAYER
	cam.cull_mask = ISO_LAYER
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	cam.environment = env
	var hidden := _hide_canvas()
	var on_black := await _grab()
	env.background_color = Color.WHITE
	var on_white := await _grab()
	_show_canvas(hidden)
	cam.cull_mask = keep_mask
	cam.environment = keep_env
	draw.layers = keep_layers
	get_tree().paused = was
	if on_black == null or on_white == null:
		return {}
	on_black.convert(Image.FORMAT_RGBA8)
	on_white.convert(Image.FORMAT_RGBA8)
	var out := {"a": 0.0, "max": 0.0, "label": "-", "img": on_black, "rects": []}
	for i in labels.size():
		var l: Label3D = labels[i]
		var r := Rect2i(_rect(l, cam))
		if not r.has_area():
			continue
		(out["rects"] as Array).append([r, MIN_RATIO])
		var al := PackedFloat32Array()
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var b := on_black.get_pixel(x, y)
				var wt := on_white.get_pixel(x, y)
				al.append(clampf(1.0 - ((wt.r - b.r) + (wt.g - b.g) + (wt.b - b.b)) / 3.0, 0.0, 1.0))
		al.sort()
		var a := al[clampi(int(FX_PCT * float(al.size() - 1)), 0, al.size() - 1)]
		out["max"] = maxf(float(out["max"]), al[al.size() - 1])
		if a > float(out["a"]):
			out["a"] = a
			out["label"] = "%s '%s'" % [_key(l, i), l.text.replace("\n", " ")]
	return out


## The worse of two _fx_alpha results (`cur` taken at `at` s).
static func _fx_worse(acc: Dictionary, cur: Dictionary, at: float) -> Dictionary:
	if cur.is_empty() or (not acc.is_empty() and float(acc["a"]) >= float(cur["a"])):
		if not acc.is_empty() and not cur.is_empty():
			acc["max"] = maxf(float(acc["max"]), float(cur["max"]))
		return acc
	var out := cur.duplicate()
	out["at"] = at
	if not acc.is_empty():
		out["max"] = maxf(float(out["max"]), float(acc["max"]))
	return out


## Prints a case's worst HeroFx alpha over its row's labels (nothing for a run without HeroFx): HEROFX_STACK when
## the layers stack past GATE_CAP + FX_TOL (information; HeroFx is the Run's), and then DIR/herofx_<name>.png: that
## frame's HeroFx draw alone over black around the row, x2, the label rects outlined.
func _fx_report(name: String, fx: Dictionary) -> void:
	if fx.is_empty():
		return
	var over := float(fx["a"]) > HeroFx.GATE_CAP + FX_TOL
	if over and out_dir != "" and fx.get("img") is Image:
		var img: Image = (fx["img"] as Image).duplicate()
		_outline(img, fx["rects"])
		var z := _crop_rows(img, fx["rects"], ZOOM_PAD * 3)
		z.resize(z.get_width() * ZOOM, z.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
		z.save_png(out_dir.path_join("herofx_%s.png" % name.validate_filename()))
	print("    %s %s: HeroFx alpha over the row's label rects %.2f (p%.0f; max %.2f) on %s at %.2f s, cap %.2f%s" % [
			"HEROFX_STACK" if over else "HeroFx within the cap,", name, float(fx["a"]), FX_PCT * 100.0,
			float(fx["max"]), str(fx["label"]), float(fx.get("at", 0.0)), HeroFx.GATE_CAP,
			": its layers stack past the cap over the panel" if over else ""])


## A label's glyph mask in rect `r`: with `b`, the pixels of `a` brighter than `b` by TEXT_DIFF (the
## baseline's text pixels); without, the pixels of the glyphs-only render `a` brighter than ISO_LUM. Kept
## as offsets from `anchor` (the label's projected corner): {text, mask [dx, dy, ...], n}.
static func _mask_from(a: Image, b: Image, r: Rect2i, anchor: Vector2i, text: String) -> Dictionary:
	var mask := PackedInt32Array()
	if a != null:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var la := lum(a.get_pixel(x, y))
				var on: bool = (la - lum(b.get_pixel(x, y)) > TEXT_DIFF) if b != null else la > ISO_LUM
				if on:
					mask.append(x - anchor.x)
					mask.append(y - anchor.y)
	return {"text": text, "mask": mask, "n": mask.size() / 2}


## Info beside the self-check: the same quiet row restyled as every gate kind (Models.gate_style, the
## row's own number and forecast; "?" for hidden), each label's ratio printed (on its own glyphs), then
## the row's own style back (Run._style_gate). Not asserted: the game shows these kinds where its levels
## put them.
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
		var cap: Dictionary = await _capture(_labels(row))
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
## label, else the lab's own reference frame is illegible (printed with the numbers; the lab fails). Beside
## it (info): each label's baseline glyph mask against the glyphs-only render's (the re-mask path).
func _baseline_check(base: Dictionary, name: String) -> void:
	var rows: Array = base["rows"]
	var low: PackedStringArray = PackedStringArray()
	var parts: PackedStringArray = PackedStringArray()
	var agree: PackedStringArray = PackedStringArray()
	for r: Dictionary in rows:
		parts.append("%s %.2f (text %.2f / bg %.2f, %d glyph px; median bg %.2f)" % [str(r["label"]), float(r["ratio"]),
				float(r["text"]), float(r["bg"]), int(r["n"]), float(r["ratio_med"])])
		agree.append("%s %d / %d" % [str(r["key"]), int(r["n"]), int((base["iso"] as Dictionary).get(str(r["key"]), 0))])
		if float(r["ratio"]) < MIN_RATIO:
			low.append(str(r["label"]))
	var ok := not rows.is_empty() and low.is_empty()
	if not ok:
		_fails += 1
	print("  %s baseline self-check (%s's quiet frame, no fx): every label >= %.0f : 1: %s" % ["PASS" if ok else "FAIL",
			name, MIN_RATIO, "; ".join(parts) if not parts.is_empty() else "no label measured"])
	print("    glyph masks (info), baseline / glyphs-only render pixels: %s" % ", ".join(agree))
	if out_dir != "" and base.get("img") is Image:
		var img: Image = (base["img"] as Image).duplicate()
		_outline(img, base["rects"])
		img.save_png(out_dir.path_join("gate_legibility_baseline_%s.png" % tag))


static func _min_ratio(cap: Dictionary) -> float:
	var v := INF
	for r: Dictionary in cap["rows"]:
		v = minf(v, float(r["ratio"]))
	return v


## The label's screen rect: its mesh AABB corners projected, clipped to the viewport (empty when behind the
## camera or off screen).
func _rect(l: Label3D, cam: Camera3D) -> Rect2:
	return _rect_raw(l, cam).intersection(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))


## The same, not clipped (a glyph mask is anchored at its corner).
static func _rect_raw(l: Label3D, cam: Camera3D) -> Rect2:
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
	return Rect2(lo, hi - lo)


## WCAG relative luminance of an sRGB colour.
static func lum(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	for i in 3:
		var v: float = ch[i]
		ch[i] = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func ratio(l1: float, l2: float) -> float:
	return (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05)


## A label on its glyph mask `g` (anchored at `anchor`): its text pixels = mask pixels of `a` still brighter
## than the glyph-less `b` by TEXT_DIFF; fewer than COVER_SHARE of the mask (or a mask under MIN_TEXT) =
## covered, ratio 1; else the WCAG ratio of their median luminance and the BG_PCT luminance of `b` over the
## WHOLE mask (what is drawn right behind every glyph pixel, its bright end): {ratio, ratio_med, text, bg,
## px, n, covered}.
static func _measure(a: Image, b: Image, g: Dictionary, anchor: Vector2i) -> Dictionary:
	var mask: PackedInt32Array = g.get("mask", PackedInt32Array())
	var n := int(g.get("n", 0))
	var text := PackedFloat32Array()
	var bg := PackedFloat32Array()
	var w := a.get_width()
	var h := a.get_height()
	for k in range(0, mask.size(), 2):
		var x := anchor.x + mask[k]
		var y := anchor.y + mask[k + 1]
		if x < 0 or y < 0 or x >= w or y >= h:
			continue
		var la := lum(a.get_pixel(x, y))
		var lb := lum(b.get_pixel(x, y))
		bg.append(lb)
		if la - lb > TEXT_DIFF:
			text.append(la)
	bg.sort()
	var lbk := bg[clampi(int(BG_PCT * float(bg.size() - 1)), 0, bg.size() - 1)] if not bg.is_empty() else 0.0
	var res := {"ratio": 1.0, "ratio_med": 1.0, "text": 0.0, "bg": lbk, "px": text.size(), "n": n, "covered": true}
	if n < MIN_TEXT or text.is_empty() or float(text.size()) < COVER_SHARE * float(n):
		return res
	text.sort()
	var lt := text[text.size() / 2]
	# ratio_med (info): against the median background behind the glyphs instead of its bright end.
	res.merge({"ratio": ratio(lt, lbk), "ratio_med": ratio(lt, bg[bg.size() / 2]), "text": lt, "covered": false}, true)
	return res


## Outlines each [rect, ratio] on `img` (2 px; green at >= MIN_RATIO, red below).
static func _outline(img: Image, rects: Array) -> void:
	for e: Array in rects:
		_box(img, e[0], Color(0.2, 1.0, 0.3) if float(e[1]) >= MIN_RATIO else Color(1.0, 0.15, 0.15))


static func _box(img: Image, r: Rect2i, col: Color) -> void:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if not r.has_area():
		return
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 2), col)
	img.fill_rect(Rect2i(r.position.x, r.end.y - 2, r.size.x, 2), col)
	img.fill_rect(Rect2i(r.position.x, r.position.y, 2, r.size.y), col)
	img.fill_rect(Rect2i(r.end.x - 2, r.position.y, 2, r.size.y), col)


# ------------------------------------------------------------------ the start banner over a level start (--banner)

func _banner_lab() -> void:
	var levels: Array[int] = []
	if args.has("levels"):
		for v in str(args["levels"]).split(",", false):
			levels.append(maxi(1, int(v)))
	else:
		levels = BANNER_LEVELS.duplicate()
	var t0 := Time.get_ticks_msec()
	print("HUD_LAB start banner over a real level start (READY, nothing skipped): levels %s, hero bolt, team %s; the ribbon (glass + marquise ends) must touch no gate label on screen at READY nor while the run is tapped into motion under it, and the first row's labels must lose no contrast to it (> %.2f : 1 or covered; their own far-row ratio is printed, not asserted)" % [
			str(levels), ",".join(PackedStringArray(TEAM_A)), BANNER_DROP])
	_csv.append("level,phase,t,champions,ribbon_x0,ribbon_y0,ribbon_x1,ribbon_y1,row_ahead,label,label_x0,label_y0," +
			"label_x1,label_y1,overlap_px")
	var clear := 0
	var gap := INF
	for lvl in levels:
		var res: Dictionary = await _banner_level(lvl)
		clear += 1 if res["ok"] else 0
		gap = minf(gap, float(res["gap"]))
	_fails += levels.size() - clear
	_write_csv("banner_overlap.csv")
	print("HUD_LAB_BANNER %s: %d of %d level starts with the ribbon clear of every gate label on screen and no contrast lost; closest any gate label came to the ribbon: %.0f px (%.1f s)" % [
			"PASS" if clear == levels.size() else "FAIL", clear, levels.size(), gap,
			float(Time.get_ticks_msec() - t0) / 1000.0])


## One level start (see the header), two fresh plays. READY: the run left at READY until its banner and
## its picture are fully in; the ribbon against every gate label on screen; the first row's labels under
## the banner's picture (if any) measured with the picture hidden (baseline) and shown. A tap at once: the
## run started on the very frame the banner appears (it then lives its whole 1.2 s over a moving run) and
## every frame checked again until the banner is gone. {ok, gap: the fewest px between the ribbon and any
## gate label seen}.
func _banner_level(lvl: int) -> Dictionary:
	var holder := _banner_play(lvl)
	var run: Run = holder.get_meta("run")
	var ch: ChampionHud = run.champ_view.hud if run.champ_view else null
	var frames := 0
	while frames < BANNER_WAIT and not _banner_in(ch):
		await get_tree().process_frame
		frames += 1
	if not _banner_in(ch):
		print("  FAIL L%d: no start banner fully in after %d frames (champions %d, state %s)" % [lvl, BANNER_WAIT,
				run.champions.members.size(), Run.State.keys()[run.state]])
		await _drop(holder)
		return {"ok": false, "gap": INF}
	get_tree().paused = true
	var cam := get_viewport().get_camera_3d()
	var ribbon := _ribbon_px(ch)
	var pic: Control = (ch.bench_parts()["banner"] as Array)[0]
	var pic_px := ch.layer_transform() * Rect2(pic.position, pic.size)
	var seen := _banner_seen(lvl, "ready", 0.0, run, cam, ribbon)
	var hits: PackedStringArray = seen["hits"]
	# The first row's labels the banner's picture lies over (none: it cannot change them).
	var under: Array = []
	for l: Label3D in seen["first"]:
		if _rect(l, cam).intersects(pic_px):
			under.append(l)
	var drop := {}
	var lost_any := false
	if not under.is_empty():
		pic.visible = false
		var base: Dictionary = await _capture(under)
		pic.visible = true
		var cap: Dictionary = await _capture(under, base)
		for r2: Dictionary in cap["rows"]:
			var b0 := float((base["by"] as Dictionary).get(str(r2["key"]), 0.0))
			var was_covered := true
			for rb: Dictionary in base["rows"]:
				if str(rb["key"]) == str(r2["key"]):
					was_covered = bool(rb["covered"])
			# Lost to the banner: below its own banner-less ratio by more than BANNER_DROP, or newly covered.
			lost_any = lost_any or b0 - float(r2["ratio"]) > BANNER_DROP or (bool(r2["covered"]) and not was_covered)
			if drop.is_empty() or float(r2["ratio"]) - b0 < float(drop["d"]):
				drop = {"d": float(r2["ratio"]) - b0, "row": r2, "base": b0}
	var img := await _grab()
	var champs := run.champions.members.size()
	get_tree().paused = false
	await _drop(holder)
	# A tap at once: a fresh play started the frame its banner appears.
	holder = _banner_play(lvl)
	run = holder.get_meta("run")
	ch = run.champ_view.hud if run.champ_view else null
	frames = 0
	while frames < BANNER_WAIT and not (ch and is_instance_valid(ch.banner) and ch.banner.visible):
		await get_tree().process_frame
		frames += 1
	run.start()
	cam = get_viewport().get_camera_3d()
	var t := 0.0
	var run_hits: PackedStringArray = PackedStringArray()
	var gap := float(seen["gap"])
	var nearest := INF
	var d0 := run.d
	while ch and ch.banner.visible and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var s2 := _banner_seen(lvl, "running", t, run, cam, ribbon)
		run_hits.append_array(s2["hits"])
		gap = minf(gap, float(s2["gap"]))
		nearest = minf(nearest, float(s2["nearest"]))
	var ran := run.d - d0
	await _drop(holder)
	var ok := hits.is_empty() and run_hits.is_empty() and not lost_any and int(seen["on_screen"]) > 0 and t > 0.5
	var r3: Dictionary = drop.get("row", {})
	print("  %s L%d: ribbon y %.0f-%.0f x %.0f-%.0f (%d champions); at READY %d gate labels on screen in %d rows, first row %.1f u ahead, overlap %s; tapped at once the run went %.1f u in the %.2f s the banner showed, nearest row %.1f u ahead, overlap %s; closest label edge %.0f px from the ribbon; the banner's picture over the first row: %s" % [
			"PASS" if ok else "FAIL", lvl, ribbon.position.y, ribbon.end.y, ribbon.position.x, ribbon.end.x,
			champs, int(seen["on_screen"]), int(seen["rows"]), float(seen["first_d"]),
			"none" if hits.is_empty() else "; ".join(hits), ran, t, nearest,
			"none" if run_hits.is_empty() else "; ".join(run_hits.slice(0, 3)), gap,
			"over none of its labels" if drop.is_empty() else "%s %+.2f vs hidden (%.2f -> %.2f : 1 on %s; %s)" % [
				"LOST" if lost_any else "no loss,", float(drop["d"]), float(drop["base"]), float(r3["ratio"]), str(r3["label"]),
				_detail(r3)]])
	if img and out_dir != "":
		img.convert(Image.FORMAT_RGBA8)
		_outline(img, seen["rects"])
		_box(img, Rect2i(ribbon), Color(1.0, 0.85, 0.3))
		img.save_png(out_dir.path_join("banner_L%d_%s.png" % [lvl, tag]))
	return {"ok": ok, "gap": gap}


## A play at level `lvl` (bolt, TEAM_A) as main.make_play builds it, in the tree, left at READY.
func _banner_play(lvl: int) -> Node:
	return _new_play(lvl, "bolt", TEAM_A)


## Every gate label on screen now against the ribbon: CSV rows, {hits, first (the nearest row's labels on
## screen), first_d, on_screen, rows, rects [[Rect2i, ratio-ish]] (red when it touches), gap (fewest px
## between the ribbon and a label), nearest (u ahead of the nearest row with a label on screen)}.
func _banner_seen(lvl: int, phase: String, t: float, run: Run, cam: Camera3D, ribbon: Rect2) -> Dictionary:
	var rows := _rows_ahead(run)
	var out := {"hits": PackedStringArray(), "first": [], "first_d": -1.0, "on_screen": 0, "rows": 0, "rects": [],
			"gap": INF, "nearest": INF}
	for row: Array in rows:
		var labels := _labels(row)
		var ahead := float(row[0]["d"]) - run.d
		var shown: Array = []
		for i in labels.size():
			var l: Label3D = labels[i]
			var r := _rect(l, cam)
			if not r.has_area():
				continue
			shown.append(l)
			var ov := r.intersection(ribbon).get_area() if r.intersects(ribbon) else 0.0
			if ov > 0.0:
				(out["hits"] as PackedStringArray).append("%s row %.1f u ahead %s '%s' (%.0f px²)" % [phase, ahead, _key(l, i),
						l.text.replace("\n", " "), ov])
			out["gap"] = minf(float(out["gap"]), _rect_gap(r, ribbon))
			if phase == "ready" or ov > 0.0:
				_csv.append("%d,%s,%.2f,%d,%.0f,%.0f,%.0f,%.0f,%.1f,%s,%.0f,%.0f,%.0f,%.0f,%.0f" % [lvl, phase, t,
						run.champions.members.size(), ribbon.position.x, ribbon.position.y, ribbon.end.x, ribbon.end.y,
						ahead, _key(l, i), r.position.x, r.position.y, r.end.x, r.end.y, ov])
			(out["rects"] as Array).append([Rect2i(r), MIN_RATIO if ov <= 0.0 else 0.0])
		if shown.is_empty():
			continue
		out["on_screen"] = int(out["on_screen"]) + shown.size()
		out["rows"] = int(out["rows"]) + 1
		out["nearest"] = minf(float(out["nearest"]), ahead)
		if (out["first"] as Array).is_empty():
			out["first"] = shown
			out["first_d"] = ahead
	return out


## Pixels between two rects (0 when they touch or overlap).
static func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), 0.0)
	var dy := maxf(maxf(b.position.y - a.end.y, a.position.y - b.end.y), 0.0)
	return sqrt(dx * dx + dy * dy)


## The banner is in: linked, visible at full opacity and its cached picture drawn and shown at full opacity.
static func _banner_in(ch: ChampionHud) -> bool:
	if ch == null or not is_instance_valid(ch.banner) or not ch.banner.visible or ch.banner.modulate.a < 0.999:
		return false
	var pic: Array = ch.bench_parts().get("banner", [])
	return not pic.is_empty() and (pic[0] as CanvasItem).visible and (pic[0] as CanvasItem).modulate.a >= 0.999


## The ribbon on screen (viewport px): TeamBanner.ribbon_rect (in the champion layer: the banner fills it
## from its corner) with the marquise ends, through the layer's canvas transform.
static func _ribbon_px(ch: ChampionHud) -> Rect2:
	var rr: Rect2 = (ch.banner.call("ribbon_rect") as Rect2).grow_individual(MARQUISE, 0.0, MARQUISE, 0.0)
	rr.position += ch.banner.position
	return ch.layer_transform() * rr


## The gate rows ahead of the run (d > run.d), nearest first: [[gate items], ...].
static func _rows_ahead(run: Run) -> Array:
	var rows := {}
	var order: Array = []
	for it: Dictionary in run.items:
		if str(it["kind"]) != "gate" or float(it["d"]) <= run.d:
			continue
		var r := int(it.get("row", -1))
		if not rows.has(r):
			rows[r] = []
			order.append(r)
		(rows[r] as Array).append(it)
	var out: Array = []
	for r in order:
		out.append(rows[r])
	out.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]["d"]) < float(q[0]["d"]))
	return out


# ------------------------------------------------------------------ today's gate labels beside v2 (--compare)

func _compare_lab() -> void:
	var t0 := Time.get_ticks_msec()
	var keep := Models.gate_labels_v2
	var cases: Array[String] = _list_arg("cases", COMPARE_CASES)
	var kinds: Array[String] = _list_arg("kinds", COMPARE_KINDS)
	if str(args.get("matrix", "")) != "none":
		await _compare_matrix(cases, kinds)
	if str(args.get("stills", "")) != "none":
		await _compare_stills()
	Models.gate_labels_v2 = keep
	print("HUD_LAB_COMPARE %s: %d v2 cells below %.0f : 1 or covered (%.1f s)" % ["PASS" if _fails == 0 else "FAIL",
			_fails, MIN_RATIO, float(Time.get_ticks_msec() - t0) / 1000.0])


## The comma list in args[`key`] filtered to `all` (all of it when absent).
func _list_arg(key: String, all: Array[String]) -> Array[String]:
	if not args.has(key):
		return all.duplicate()
	var out: Array[String] = []
	for v in str(args[key]).split(",", false):
		if v in all:
			out.append(v)
	return out


## Part A of --compare (see the header): every kind x case under v1 then v2, a table, the CSV and the cell crops.
func _compare_matrix(cases: Array[String], kinds: Array[String]) -> void:
	print("HUD_LAB compare matrix: L%d, gate row %.0f u ahead, army %d, captures at %s s; worst label ratio per cell, v1 (the old labels) -> v2 (the default: ink plate; measured against its own plate), rule >= %.0f : 1 (ideal %.1f)" % [
			level, AHEAD, ARMY, str(CAPTURE_AT), MIN_RATIO, IDEAL_RATIO])
	_csv.append("case,kind,variant,worst,label,capture_t,text_lum,bg_lum,text_px,glyph_px,covered,mask,measurements," +
			"moved_remasks,herofx_alpha")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir.path_join("cells"))
	var res := {}
	for v2: bool in [false, true]:
		Models.gate_labels_v2 = v2
		for c: String in cases:
			for k: String in kinds:
				res["%s|%s|%s" % [c, k, v2]] = await _cell(c, k, v2)
	# One table per case group of up to 5 columns (13 cases do not fit one line).
	var low: PackedStringArray = PackedStringArray()
	var under: PackedStringArray = PackedStringArray()
	for c0 in range(0, cases.size(), 5):
		var group := cases.slice(c0, c0 + 5)
		var head := "  %-7s" % "kind"
		for c: String in group:
			head += " | %-15s" % c
		print(head)
		for k: String in kinds:
			var line := "  %-7s" % k
			for c: String in group:
				var a: Dictionary = res["%s|%s|false" % [c, k]]
				var b: Dictionary = res["%s|%s|true" % [c, k]]
				var low2 := float(b["ratio"]) < MIN_RATIO
				var under2 := float(b["ratio"]) < IDEAL_RATIO
				line += " | %5.2f -> %5.2f%s" % [float(a["ratio"]), float(b["ratio"]),
						"!" if low2 else ("~" if under2 else " ")]
				if low2:
					_fails += 1
					low.append("%s %s: %s" % [c, k, _cell_note(b)])
				elif under2:
					under.append("%s %s: %s" % [c, k, _cell_note(b)])
			print(line)
	var worst2 := INF
	for key: String in res:
		if key.ends_with("|true"):
			worst2 = minf(worst2, float((res[key] as Dictionary)["ratio"]))
	print("  v2 worst cell %.2f : 1%s" % [worst2, "" if low.is_empty() else "; below %.0f : 1: %s" % [MIN_RATIO,
			"; ".join(low)]])
	print("  v2 cells below the ideal %.1f : 1: %d%s" % [IDEAL_RATIO, under.size() + low.size(),
			"" if under.is_empty() else " (%s)" % "; ".join(under)])
	# HeroFx (the new kinds' ult shapes) over the row, worst over the kinds, per variant; not over a closed row: HeroFx
	# caps over the live gates ahead only (a closed row is one the army has passed; the matrix puts it ahead).
	for c: String in cases:
		for v2: bool in [false, true]:
			var fx := {}
			var at_kind := ""
			for k: String in kinds:
				if k == "closed":
					continue
				var f: Dictionary = (res["%s|%s|%s" % [c, k, v2]] as Dictionary).get("fx", {})
				if not f.is_empty() and (fx.is_empty() or float(f["a"]) > float(fx["a"])):
					fx = f
					at_kind = k
			if not fx.is_empty():
				_fx_report("%s (%s row, %s)" % [c, at_kind, "v2" if v2 else "v1"], fx)
	_write_csv("gate_compare.csv")


## One matrix cell: a fresh seeded play of `name` (CASES) on --level, the row set to `kind`, the --gate-legibility
## measure (quiet baseline masks, the trigger, the captures). {ratio (worst; 1 when covered or nothing measured),
## label, at, row (the worst measurement), measured}.
func _cell(name: String, kind: String, v2: bool) -> Dictionary:
	var spec: Array = CASES[name]
	seed(COMPARE_SEED)
	var holder := _new_play(level, str(spec[0]), spec[1])
	var run: Run = holder.get_meta("run")
	await get_tree().process_frame
	run.set_process(false)
	var row := _pick_row(run)
	if row.is_empty():
		await _drop(holder)
		return {"ratio": 1.0, "label": "no gate row", "at": 0.0, "row": {}, "measured": 0}
	var at0: Array = _park(run, row, AHEAD, ARMY)
	_set_kind(run, row, kind)
	for k in 20:
		await _frame(run, false)
	var labels := _labels(row)
	var base: Dictionary = await _capture(labels)
	var ult := str(spec[2]) == "ult"
	_trigger(run, spec[2], row, float(at0[0]), float(at0[1]))
	var worst := {"ratio": INF}
	var worst_img: Image = null
	var worst_rects: Array = []
	var worst_t := 0.0
	var measured := 0
	var moved := 0
	var fx := {}
	var t := 0.0
	for at in CAPTURE_AT:
		while t + DT * 0.5 < at:
			await _frame(run, ult)
			t += DT
		var cap: Dictionary = await _capture(labels, base, false, true)
		var fx_now: Dictionary = await _fx_alpha(run, labels)
		fx = _fx_worse(fx, fx_now, at)
		for r: Dictionary in cap["rows"]:
			measured += 1
			moved += 1 if str(r["mask"]) == "re-masked (moved)" else 0
			if float(r["ratio"]) < float(worst["ratio"]):
				worst = r
				worst_img = cap["img"]
				worst_rects = cap["rects"]
				worst_t = at
	await _drop(holder)
	var ratio := float(worst["ratio"]) if measured > 0 else 1.0
	var vname := "v2" if v2 else "v1"
	_csv.append("%s,%s,%s,%.2f,%s,%.2f,%.3f,%.3f,%d,%d,%s,%s,%d,%d,%s" % [name, kind, vname, ratio,
			str(worst.get("label", "-")).replace(",", " "), worst_t, float(worst.get("text", 0.0)),
			float(worst.get("bg", 0.0)), int(worst.get("px", 0)), int(worst.get("n", 0)), str(worst.get("covered", true)),
			str(worst.get("mask", "-")), measured, moved, "-" if fx.is_empty() else "%.2f" % float(fx["a"])])
	if worst_img and out_dir != "":
		var img: Image = worst_img.duplicate()
		_outline(img, worst_rects)
		var crop := _crop_rows(img, worst_rects, ZOOM_PAD)
		crop.save_png(out_dir.path_join("cells").path_join("%s_%s_%s.png" % [vname, name, kind]))
	# The matrix keeps HeroFx's numbers only (its frames are saved by --gate-legibility).
	fx.erase("img")
	return {"ratio": ratio, "label": str(worst.get("label", "-")), "at": worst_t, "row": worst, "measured": measured,
			"fx": fx}


static func _cell_note(c: Dictionary) -> String:
	return "%.2f on %s at %.2f s (%s)" % [float(c["ratio"]), str(c["label"]), float(c["at"]), _detail(c["row"])]


## Sets the row's gates to gate `kind` in the run's own data, so Run._style_gate draws them and an ult hits them as
## in the game: good as generated; bad the same numbers as − / ÷; charge −12 that fills to +20; hidden unrevealed;
## power +25 % rate / +30 % damage; arm crossbows / blasters; closed (the row passed: not alive).
static func _set_kind(run: Run, row: Array, kind: String) -> void:
	for i in row.size():
		var it: Dictionary = row[i]
		var f: Array = run._gate_face(it)
		match kind:
			"bad":
				f[0] = "-" if str(f[0]) == "+" else "/"
			"charge":
				f[0] = "charge"
				f[1] = -12.0
				it["value0"] = -12.0
				it["reward"] = {"op": "+", "value": 20}
			"hidden":
				it["revealed"] = false
			"power":
				f[0] = "rate" if i % 2 == 0 else "dmg"
				f[1] = 25.0 if i % 2 == 0 else 30.0
			"arm":
				f[0] = "arm"
				f[1] = 1.0 if i % 2 == 0 else 2.0
			"closed":
				it["alive"] = false
		run._sync_face(it)
		it.erase("_style")
		run._style_gate(it)


## The crop of `img` around the union of `rects` ([[Rect2i, ratio]]) grown by `pad` px (the whole image when none).
static func _crop_rows(img: Image, rects: Array, pad: int) -> Image:
	if rects.is_empty():
		return img
	var u: Rect2i = rects[0][0]
	for e: Array in rects:
		u = u.merge(e[0])
	u = u.grow(pad).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(u)


## Part B of --compare: each still under v1 then v2 (same seed; the squad still also v2 in its ult draw), saved alone
## and side by side (v1 left, v2 right, the ult draw last), plus a zoomed set around the row.
func _compare_stills() -> void:
	var names: Array = STILLS.keys()
	if args.has("stills"):
		names = []
		for v in str(args["stills"]).split(",", false):
			if STILLS.has(v):
				names.append(v)
	for name: String in names:
		var spec: Array = STILLS[name]
		var lvl := int(spec[0])
		if str(spec[2]) == "power":
			lvl = await _level_with_power_row(lvl, str(spec[1]))
		# [file suffix, v2, labels in their ult draw]
		var variants: Array = [["v1", false, false], ["v2", true, false]]
		if str(spec[3]) == "squad":
			variants.append(["v2_ult_draw", true, true])
		var shots: Array[Image] = []
		var rects: Array = []
		for va: Array in variants:
			Models.gate_labels_v2 = bool(va[1])
			var got: Dictionary = await _still(lvl, spec, bool(va[2]))
			if got.get("img") == null:
				break
			shots.append(got["img"])
			rects.append_array(got.get("rects", []))
			print("  still %s %s: L%d, %s" % [name, str(va[0]), lvl, str(got.get("note", ""))])
		if shots.size() < variants.size() or out_dir == "":
			continue
		var all: Image = null
		var zoom: Image = null
		for i in shots.size():
			shots[i].save_png(out_dir.path_join("%s_%s.png" % [name, str(variants[i][0])]))
			all = shots[i] if all == null else _pair(all, shots[i])
			if not rects.is_empty():
				var z := _crop_rows(shots[i], rects, ZOOM_PAD)
				z.resize(z.get_width() * ZOOM, z.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
				zoom = z if zoom == null else _pair(zoom, z)
		all.save_png(out_dir.path_join("compare_%s.png" % name))
		if zoom:
			zoom.save_png(out_dir.path_join("compare_%s_zoom.png" % name))
		print("HUD_LAB written ", out_dir.path_join("compare_%s.png" % name))


# ------------------------------------------------------------------ the number's size, v1 against v2 (--fit)

## --fit (see the header): every FIT_GATES face built and styled under v1 and v2 in every world (Models.gate, the
## world's gate model or the procedural frame), its number's cap height compared and its tablet checked inside the
## panel. Sets _fails.
func _fit_lab() -> void:
	var keep_v2 := Models.gate_labels_v2
	var keep_world := Models.world
	print("HUD_LAB fit: the gate number's cap height (font size x pixel size x %.2f) under v1 and v2, the v2 tablet inside the panel (field width, crossbar, base rail); checked faces within %.0f%% of v1" % [
			Models.PLATE_CAP, FIT_TOL * 100.0])
	var checked := 0
	var ratios := PackedFloat32Array()
	for wk: String in Worlds.ORDER:
		Models.use_world(Worlds.LIST[wk])
		print("  world %s" % wk)
		for f: Array in FIT_GATES:
			var caps: Array[float] = []
			var info := ""
			var inside := true
			for v2: bool in [false, true]:
				Models.gate_labels_v2 = v2
				var g := Models.gate(float(f[0]))
				Models.gate_style(g, str(f[1]), str(f[2]), str(f[3]), str(f[4]))
				var l := g.get_meta("label") as Label3D
				caps.append(float(l.font_size) * Models.PLATE_CAP * l.pixel_size)
				if v2:
					var tab := _fit_tablet(g)
					inside = bool(tab["inside"])
					info = str(tab["note"])
				g.free()
			var r := caps[1] / maxf(caps[0], 1e-6)
			var check := bool(f[5])
			var ok := not check or (absf(r - 1.0) <= FIT_TOL and inside)
			if check:
				checked += 1
				ratios.append(r)
				_fails += 0 if ok else 1
			print("    %s w %.1f %-8s %-5s %-6s: cap v1 %.3f m, v2 %.3f m (%3.0f%% of v1); %s" % [
					("PASS" if ok else "FAIL") if check else "info", float(f[0]), "'%s'" % f[1], str(f[3]),
					"'%s'" % f[2] if str(f[2]) != "" else "-", caps[0], caps[1], r * 100.0, info])
	Models.gate_labels_v2 = keep_v2
	Models.use_world(keep_world)
	ratios.sort()
	print("HUD_LAB_FIT %s: %d of %d checked faces with the v2 number within %.0f%% of v1's and the tablet inside the panel; v2 / v1 from %.0f%% to %.0f%%" % [
			"PASS" if _fails == 0 else "FAIL", checked - _fails, checked, FIT_TOL * 100.0,
			ratios[0] * 100.0 if not ratios.is_empty() else 0.0,
			ratios[ratios.size() - 1] * 100.0 if not ratios.is_empty() else 0.0])


## A styled v2 gate's tablet against its panel (gate space, the plane's lean ignored): {inside, note}. Inside = no
## wider than the field (plus Models' 0.02 m) or v1's label (w - Models.LABEL_MARGIN), whichever is wider, its top
## under the field's top (the crossbar's underside) and its bottom over the base rail (0.06 m).
static func _fit_tablet(g: Node3D) -> Dictionary:
	var l := g.get_meta("label") as Label3D
	var plate: MeshInstance3D = l.get_meta("plate") if l.has_meta("plate") else null
	var fh := float(g.get_meta("field_h", Models.GATE_H))
	var fw := ((g.get_meta("field") as MeshInstance3D).mesh as QuadMesh).size.x
	var max_w := maxf(fw + 0.02, float(g.get_meta("width", 2.0)) - Models.LABEL_MARGIN)
	if plate == null or not plate.visible:
		return {"inside": true, "note": "no tablet (no text); panel %.2f x %.2f m" % [fw, fh]}
	var cy := l.position.y + plate.position.y
	var top := cy + plate.scale.y * 0.5
	var bot := cy - plate.scale.y * 0.5
	var inside := plate.scale.x <= max_w + 0.001 and top <= fh + 0.02 and bot >= 0.06
	var note := "tablet %.2f x %.2f m, y %.2f-%.2f; panel: field %.2f x %.2f m, width allowed %.2f" % [plate.scale.x,
			plate.scale.y, bot, top, fw, fh, max_w]
	return {"inside": inside, "note": note + ("" if inside else " (OUT OF THE PANEL)")}


## The first level from `lvl` on (up to 40 more) whose run has a row with a power or arm gate at d >= 20.
func _level_with_power_row(lvl: int, hero: String) -> int:
	for l in range(lvl, lvl + 41):
		var holder := _new_play(l, hero, [])
		var run: Run = holder.get_meta("run")
		await get_tree().process_frame
		var found := not _pick_ops_row(run, OPS_POWER).is_empty()
		await _drop(holder)
		if found:
			return l
	return lvl


## The first row at d >= 20 with any gate whose op is in `ops`: [gate items], or [].
static func _pick_ops_row(run: Run, ops: Array) -> Array:
	var rows := _rows_ahead(run)
	for row: Array in rows:
		if float(row[0]["d"]) < 20.0:
			continue
		for g: Dictionary in row:
			if str(g["op"]) in ops:
				return row
	return []


## One still (spec as STILLS) under the current variant: a fresh seeded play parked before its row (a squad moved in
## front of it for a squad still), fired, played (visuals and the ult clock) to the shot time, then the frame; with
## `over` the gate labels are put in their ult draw for it (Models.labels_over, as while an ult runs). {img, rects
## (the row's label rects), note}.
func _still(lvl: int, spec: Array, over := false) -> Dictionary:
	seed(COMPARE_SEED)
	var holder := _new_play(lvl, str(spec[1]), [])
	var run: Run = holder.get_meta("run")
	await get_tree().process_frame
	run.set_process(false)
	var row := _pick_ops_row(run, OPS_POWER) if str(spec[2]) == "power" else _pick_row(run)
	if row.is_empty():
		await _drop(holder)
		return {"note": "no row"}
	var at0: Array = _park(run, row, float(spec[4]), int(spec[5]))
	var squad := _squad_in_front(run, row) if str(spec[3]) == "squad" else ""
	OS.delay_msec(COUNTER_MS)
	for k in 20:
		await _frame(run, false)
	var ult := str(spec[3]) == "ult"
	var what := _trigger(run, "ult" if ult else "none", row, float(at0[0]), float(at0[1]))
	if squad != "":
		what = squad
	var t := 0.0
	while t + DT * 0.5 < float(spec[6]):
		await _frame(run, ult)
		t += DT
	if over:
		# The ult draw without an ult: the plates switch on their next frame (Effects writes the flag only when the
		# ult clock starts or stops, and it stays idle here).
		Models.labels_over = true
		await _frame(run, false)
		what += ", gate labels in their ult draw"
	var cam := get_viewport().get_camera_3d()
	get_tree().paused = true
	var img := await _grab()
	Models.labels_over = false
	var rects: Array = []
	var texts: PackedStringArray = PackedStringArray()
	for l: Label3D in _labels(row):
		var r := _rect(l, cam)
		if r.has_area():
			rects.append([Rect2i(r), MIN_RATIO])
		texts.append(l.text)
	var ops: PackedStringArray = PackedStringArray()
	for g: Dictionary in row:
		ops.append(str(g["op"]))
	var note := "row %s (%s), %.0f u ahead, army %d, fired %s, shot %.2f s after" % [" ".join(texts), ",".join(ops),
			float(spec[4]), run.army, what, t]
	get_tree().paused = false
	await _drop(holder)
	if img:
		img.convert(Image.FORMAT_RGBA8)
	return {"img": img, "rects": rects, "note": note}


## The squad still: the level's first live enemy squad moved in front of the row's gate nearest the middle (the one
## the hero is lined up on), SQUAD_HP soldiers whose back rank stands SQUAD_GAP u before the gate. Returns what was
## done ("" when the level has no squad).
static func _squad_in_front(run: Run, row: Array) -> String:
	var mid: Dictionary = row[0]
	for g: Dictionary in row:
		if absf(float(g["x"])) < absf(float(mid["x"])):
			mid = g
	var gd := float(mid["d"])
	var n := mini(SQUAD_HP, Hazards.SQUAD_SHOWN)
	for it: Dictionary in run.items:
		if str(it["kind"]) != "squad" or not it["alive"]:
			continue
		it["x"] = float(mid["x"])
		it["hp"] = float(SQUAD_HP)
		# Laid out once at the gate to learn its depth (the ranks stand behind its front, away from the army).
		it["d"] = gd
		var sq: Variant = run.hazards.squad_state(it)
		run.hazards._layout(it, sq, n)
		var depth := 0.0
		for p: Vector3 in (sq as Hazards.Squad).pos:
			depth = maxf(depth, -p.z - gd)
		it["d"] = gd - SQUAD_GAP - depth
		run.hazards._layout(it, sq, n)
		return "nothing; a squad of %d before the gate at x %.2f (its front %.1f u, its back rank %.1f u away)" % [
				n, float(mid["x"]), SQUAD_GAP + depth, SQUAD_GAP]
	return ""


## Two images side by side (a left, b right) on an ink gap.
static func _pair(a: Image, b: Image) -> Image:
	var gap := 12
	var out := Image.create(a.get_width() + gap + b.get_width(), maxi(a.get_height(), b.get_height()), false,
			Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.09, 0.14))
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + gap, 0))
	return out
