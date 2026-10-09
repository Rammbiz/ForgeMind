extends Node
## Champions in the run: the §10.6 bench and three stills (heroes design §4.2, §10.5, §10.6).
##
## --bench: a scripted W4 run (default L45, Bolt, the planner's path: LevelSim.best_path with the team,
## replayed by every pass, no re-planning) played through the real Run + run HUD with champions OFF (empty
## team) and ON (`--team`, default borko,taya,mila: Warrior front, Mage rear, Healer left), phase H2 forced,
## for --seconds game seconds (default 60) or until a second after the fortress falls (L45 takes ~45 s, so
## its whole level is recorded). Passes: a discarded warm-up (ON: every shader and pool the others need),
## then OFF, ON, OFF, ON interleaved (drift and heat hit both modes alike), then a split pass (ON, not
## timed). The game advances a fixed 1 / --fps s per frame (default 60, so every pass renders the very same
## frames whatever a frame costs), vsync off, the ult fired by the shared auto policy. Per pass, after
## --skip frames: frame wall time, the run's own CPU per frame (its step: logic + visuals),
## RENDER_TOTAL_DRAW_CALLS_IN_FRAME, RENDER_TOTAL_PRIMITIVES_IN_FRAME, RENDER_TEXTURE_MEM_USED,
## Champions.step per frame (Run.champ_perf), the scene's node count, ChampionView's and the medallions'
## node counts and ChampionView.budget(); TIME_PROCESS (Godot's max over the last second) goes to the CSV.
## Per mode the frames of its two warmed passes are pooled (p50 = the median frame, p95, max, means).
## The split pass stops the game every SPLIT_EVERY frames, pauses the tree (nothing animates on its own)
## and renders the same frame again part by part: as is, then with the champions' draws hidden one after
## another (ChampionHud.bench_parts: the medallions, the start banner's cached picture; ChampionView.
## bench_parts: the stamp's text, the marks with every VFX, the batched bodies with their shadow), then as is
## once more (the probe's noise); each state counts the fewest draws of SPLIT_RENDERS renders. Each step's
## fall in draw calls is that part's share: steady = bodies + marks + medallions, transient = stamp + banner
## (the VFX live inside the marks draw and add none); the rest of ON - OFF ("other": run.effects rings /
## popups the champions trigger, the soldiers Mend returns, the different fight) is the warmed delta less both.
## Prints
##   BENCH champions=off|on pass=N p50=.. p95=.. max=.. draws=.. prims=.. step_us=.. (one line per pass)
##   BENCH_MODE off|on (pooled) ...
##   BENCH_DELTA draws=+.. prims=+.. p95=+..ms (warmed, pooled)
##   BENCH_SPLIT added draws +.. = steady +.. (bodies .., marks + VFX .., medallions ..) + transient +..
##   (stamp .., banner ..) + other +..
##   BENCH_GATES (the §10.6 "added by 3 champions" rows, warmed passes only: draws <= +10 (+1 transient),
##   the split's steady part <= +10, tris <= +25k, Champions.step <= 0.25 ms; a split with 0 probes is
##   UNMEASURED, never PASS, and counts as a failed gate)
## and writes DIR/bench_champions.csv (one row per frame and pass) and DIR/bench_champions_summary.csv.
## Exit code: the number of failed (or unmeasured) gates.
## Needs a real renderer (the draw / primitive monitors read 0 headless), e.g. the hidden desktop:
##   godot --path . --resolution 720x1280 res://scenes/dev/gallery_champions.tscn -- --autotest --bench --out=DIR
##        [--seconds=60] [--level=45] [--hero=bolt] [--team=borko,taya,mila] [--fps=60] [--skip=30]
## Headless: prints SKIPPED and exits 77; --setup-only runs a few seconds of one OFF and one ON pass as a
## script check and exits 0:
##   godot --headless --path . res://scenes/dev/gallery_champions.tscn -- --autotest --bench --setup-only
##
## --shots[=clash,block,fallen]: the same level with four champions (borko front, taya, ivo, mila) and
## the real rules, three stills for a look: DIR/champions_clash_<tag>.png (a clash, the front champion
## just took a hit), champions_block_<tag>.png (the Guardian's Block and its «БЛОК» popup; the hero
## steers onto the next barricade / blade while this one is pending) and champions_fallen_<tag>.png
## (once the clash still is taken, the front champion is left at 1 HP in a clash: the rules make it
## fall, the still is taken once it lies). Same windowed command with --shots --out=DIR [--tag=720];
## headless it plays the run, reports when each still would be taken and saves nothing.
## Always pass --autotest: it makes Save read-only before Meta loads, so the real save is never touched.

const KP := preload("res://scripts/dev/test_kind_parity.gd")
const HUD_SCRIPT := "res://scripts/ui/run_hud.gd"
const BENCH_TEAM: Array[String] = ["borko", "taya", "mila"]
const SHOT_TEAM: Array[String] = ["borko", "taya", "ivo", "mila"]
const SHOTS: Array[String] = ["clash", "block", "fallen"]
## Planner candidates (the path is only an input).
const PLAN_CANDIDATES := 9
## §10.6 gates for what 3 champions add.
const GATE_DRAWS := 10.0
const GATE_TRIS := 25000
const GATE_STEP_MS := 0.25
## Stills: game seconds between the event and the shot.
const AFTER_HIT := 0.12
const AFTER_BLOCK := 0.25
const AFTER_FALL := 0.8
## Stills: the hero steers onto a hazard this far ahead while the Block still is pending.
const SEEK_AHEAD := 12.0
## Bench split pass: a probe every this many frames; the parts it hides, in this order (_probe).
const SPLIT_EVERY := 15
const SPLIT_PARTS: Array[String] = ["medallions", "banner", "stamp", "marks", "bodies"]
## Renders per probed state; the fewest draws count (_draws).
const SPLIT_RENDERS := 3
## Headless without --setup-only: nothing measured, exit code 77.
const SKIPPED := 77

var args := {}
var out_dir := ""
var tag := "720"
var level := 45
var hero := "bolt"
var _bot := Bot.new()
var _csv: PackedStringArray = PackedStringArray()
var _summary: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(args.get("out", ""))
	tag = str(args.get("tag", "720"))
	level = maxi(1, int(args.get("level", "45")))
	hero = str(args.get("hero", "bolt"))
	if not Balance.HEROES.has(hero):
		hero = "bolt"
	Save.readonly = true
	process_priority = -1000
	var old_phase := EconData.phase_override
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	Juice.hitstop_enabled = false
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var code := 0
	if args.has("bench"):
		code = await _bench()
	elif args.has("shots"):
		code = await _shots()
	else:
		print("gallery_champions: pass --bench or --shots (see the header)")
	EconData.phase_override = old_phase
	Juice.hitstop_enabled = true
	get_tree().quit(code)


## A run with the run HUD under a holder, as main.make_play builds it (the champion medallions link
## through the holder's "hud" meta). `ids` = the team; the account is the synthetic EXPECTED one.
func _make_play(ids: Array) -> Node:
	var acc := KP.account_with(level, hero, ids)
	var keep: Array = KP.swap_in(acc, hero)
	var holder := Node.new()
	holder.name = "Play"
	var run := Run.new()
	run.setup(level, hero)
	holder.add_child(run)
	var hud: CanvasLayer = (load(HUD_SCRIPT) as GDScript).new()
	hud.call("setup", run)
	holder.add_child(hud)
	holder.set_meta("run", run)
	holder.set_meta("hud", hud)
	KP.swap_out(keep)
	return holder


## The planner's path for `ids` (best_path with that team's profile).
func _plan(ids: Array) -> PackedFloat32Array:
	var prof := KP.profile_of(KP.account_with(level, hero, ids), level, hero)
	var bp: Dictionary = LevelSim.best_path(KP.level_of(level), hero, Balance.START_ARMY, {"profile": prof,
			"candidates": PLAN_CANDIDATES})
	return bp["path"]


func _team_arg(fallback: Array[String]) -> Array:
	if not args.has("team"):
		return fallback.duplicate()
	var ids: Array = []
	for id in str(args["team"]).split(",", false):
		if ChampionData.CHAMPIONS.has(id) and not ids.has(id) and ids.size() < 4:
			ids.append(id)
	return ids


static func _count(n: Node) -> int:
	if n == null or not is_instance_valid(n):
		return 0
	var c := 1
	for k in n.get_children(true):
		c += _count(k)
	return c


# ------------------------------------------------------------------ bench (§10.6)

func _bench() -> int:
	var team := _team_arg(BENCH_TEAM)
	var secs := maxf(float(args.get("seconds", "60")), 1.0)
	var fps := clampf(float(args.get("fps", "60")), 10.0, 240.0)
	var skip := maxi(int(args.get("skip", "30")), 0)
	var headless := DisplayServer.get_name() == "headless"
	var setup_only := args.has("setup-only")
	if headless and not setup_only:
		print("BENCH SKIPPED: headless (no renderer: draw calls, primitives and frame times are not real); run windowed on a hidden desktop, or pass --setup-only")
		return SKIPPED
	if setup_only:
		secs = minf(secs, 5.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("BENCH_RUN L%d %s team %s, %.0f s at a fixed 1/%.0f s per frame, skip %d frames; passes %s" % [level, hero,
			",".join(team), secs, fps, skip, "off, on (setup only)" if setup_only else "warm-up (discarded), off, on, off, on, split"])
	var path := _plan(team)
	_csv.append("champions,pass,frame,t,wall_ms,run_cpu_ms,draws,prims,tex_mb,champ_step_us,nodes,time_process_1s_ms")
	_summary.append("champions,pass,frames,p50_ms,p95_ms,max_ms,cpu_p50_ms,cpu_p95_ms,time_process_1s_max_ms,draws_mean," +
			"draws_max,prims_mean,prims_max,tex_mb_max,step_us_mean,step_us_p95,step_us_max,nodes_mean,champ_nodes," +
			"medallion_nodes,champ_tris,champ_draws_steady")
	if setup_only:
		await _bench_run("off", 1, [], path, secs, fps, skip, 0)
		await _bench_run("on", 1, team, path, secs, fps, skip, 0)
		print("BENCH setup only: both modes ran %.0f s (headless numbers are not real; nothing gated)" % secs)
		return 0
	await _bench_run("warmup", 0, team, path, secs, fps, skip, 0)
	var runs := {"off": [], "on": []}
	for k in 2:
		for mode: String in ["off", "on"]:
			(runs[mode] as Array).append(await _bench_run(mode, k + 1, [] if mode == "off" else team, path, secs, fps,
					skip, 0))
	var off := _pool("off", runs["off"])
	var on := _pool("on", runs["on"])
	var split: Dictionary = await _bench_run("split", 0, team, path, secs, fps, skip, SPLIT_EVERY)
	var dd := float(on["draws"]) - float(off["draws"])
	var ddm := float(on["draws_max"]) - float(off["draws_max"])
	print("BENCH_DELTA draws=%+.1f prims=%+.0f p95=%+.2fms p50=%+.2fms max=%+.2fms cpu_p95=%+.2fms nodes=%+.0f tex=%+.1fMB (warmed passes, pooled)" % [
			dd, float(on["prims"]) - float(off["prims"]), float(on["p95"]) - float(off["p95"]),
			float(on["p50"]) - float(off["p50"]), float(on["max"]) - float(off["max"]),
			float(on["cpu_p95"]) - float(off["cpu_p95"]), float(on["nodes"]) - float(off["nodes"]),
			float(on["tex_mb"]) - float(off["tex_mb"])])
	var sp: Dictionary = split.get("split", {})
	var n_probes := int(sp.get("n", 0))
	var probes := maxi(n_probes, 1)
	var share := {}
	for k: String in SPLIT_PARTS:
		share[k] = float(sp.get(k, 0.0)) / probes
	var steady := float(share["bodies"]) + float(share["marks"]) + float(share["medallions"])
	var transient := float(share["stamp"]) + float(share["banner"])
	print("BENCH_SPLIT added draws %+.1f = steady %+.1f (bodies with shadow %+.1f, marks + VFX %+.1f, medallions %+.1f; canvas draws of the medallions %+.1f) + transient %+.2f (stamp text %+.2f, showing in %.0f%% of probes, %+.1f when showing; banner picture %+.2f) + other %+.1f (run.effects the champions trigger, Mend's soldiers, the different fight); VFX alive in %.0f%% of probes (inside the marks draw: +0 of their own); %d probes every %d frames, each state the fewest draws of %d renders, probe noise %.2f draws (the same frame rendered again)%s" % [
			dd, steady, share["bodies"], share["marks"], share["medallions"], float(sp.get("canvas", 0.0)) / probes,
			transient, share["stamp"], 100.0 * float(sp.get("stamp_live", 0)) / probes,
			float(sp.get("stamp", 0.0)) / maxf(float(sp.get("stamp_live", 0)), 1.0), share["banner"], dd - steady - transient,
			100.0 * float(sp.get("fx_live", 0)) / probes, n_probes, SPLIT_EVERY, SPLIT_RENDERS, float(sp.get("noise", 0.0)) / probes,
			"" if n_probes > 0 else " - NO PROBE RAN: the split is unmeasured"])
	var step_ms := float(on["step_us_p95"]) / 1000.0
	# The max-minus-max draw count flips on identical runs (+6 / +12 / +6: the OFF run's own peak
	# moves), so it is printed for information only; the mean and the split steady part gate.
	var gates := [_gate(dd <= GATE_DRAWS), _gate(steady <= GATE_DRAWS, n_probes > 0),
			_gate(int(on["champ_tris"]) <= GATE_TRIS), _gate(step_ms <= GATE_STEP_MS)]
	print("BENCH_GATES (warmed) draws %+.1f mean (<= +%d): %s, max %+.0f (info, +1 transient allowed) [split steady %+.1f (<= +%d) over %d probes: %s]; champion tris %d (<= %d): %s; Champions.step p95 %.3f ms (<= %.2f): %s" % [
			dd, int(GATE_DRAWS), gates[0], ddm, steady, int(GATE_DRAWS), n_probes, gates[1], int(on["champ_tris"]), GATE_TRIS,
			gates[2], step_ms, GATE_STEP_MS, gates[3]])
	if out_dir != "":
		_write("bench_champions.csv", _csv)
		_write("bench_champions_summary.csv", _summary)
	return gates.count("FAIL") + gates.count("UNMEASURED")


## A gate's verdict: PASS / FAIL, or UNMEASURED when nothing was measured (never a vacuous PASS).
static func _gate(c: bool, measured := true) -> String:
	if not measured:
		return "UNMEASURED"
	return "PASS" if c else "FAIL"


## One bench pass: builds the play, steps it a fixed 1 / fps per frame for `secs` game seconds (or until
## a second after it ended), records every frame after `skip`, frees it. Per frame: the wall time
## between two frames (vsync off: what the frame cost), the CPU time of the run's step (logic + visuals,
## KP.step), the render monitors of that frame, Champions.step (Run.champ_perf) and the node count.
## TIME_PROCESS is Godot's max process time over the last second (it updates once a second): kept in
## the CSV, not used for the percentiles. With `probe_every` > 0 (the split pass) every probe_every-th
## frame is rendered again, frozen, part by part (_probe) and the frame times mean nothing. Returns the
## summary plus the raw per-frame arrays (pooling) and, for the split pass, "split".
func _bench_run(mode: String, pass_k: int, team: Array, path: PackedFloat32Array, secs: float, fps: float, skip: int,
		probe_every: int) -> Dictionary:
	seed(7)
	var holder := _make_play(team)
	add_child(holder)
	var run: Run = holder.get_meta("run")
	await get_tree().process_frame
	KP.begin(run, path)
	var dt := 1.0 / fps
	var wall := PackedFloat32Array()
	var cpu := PackedFloat32Array()
	var draws := PackedFloat32Array()
	var prims := PackedFloat32Array()
	var steps := PackedFloat32Array()
	var tex_max := 0.0
	var tp_max := 0.0
	var nodes := 0.0
	var champ_nodes := 0
	var med_nodes := 0
	var last_us := Time.get_ticks_usec()
	var last_champ := 0
	var last_cpu := 0.0
	var frame := 0
	var game_t := 0.0
	var end_t := -1.0
	var split := {"n": 0, "canvas": 0.0, "noise": 0.0, "fx_live": 0, "stamp_live": 0}
	for part: String in SPLIT_PARTS:
		split[part] = 0.0
	while game_t < secs and (end_t < 0.0 or game_t < end_t + 1.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var w := float(now - last_us) / 1000.0
		last_us = now
		frame += 1
		var cu := int(run.champ_perf["us"])
		if frame > skip + 1:
			# The monitors describe the frame that just ended: the one stepped last time round.
			var dc := float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var pr := float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var tex := float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0
			var nc := float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var tp := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
			var su := float(cu - last_champ)
			wall.append(w)
			cpu.append(last_cpu)
			draws.append(dc)
			prims.append(pr)
			steps.append(su)
			tex_max = maxf(tex_max, tex)
			tp_max = maxf(tp_max, tp)
			nodes += nc
			_csv.append("%s,%d,%d,%.3f,%.3f,%.3f,%.0f,%.0f,%.2f,%.0f,%.0f,%.2f" % [mode, pass_k, frame, game_t, w, last_cpu, dc,
					pr, tex, su, nc, tp])
			if probe_every > 0 and frame % probe_every == 0 and run.champ_view and not KP.over(run):
				await _probe(run, split)
				last_us = Time.get_ticks_usec()
		last_champ = cu
		if run.champ_view:
			champ_nodes = maxi(champ_nodes, _count(run.champ_view))
			var hud: ChampionHud = run.champ_view.hud
			if hud:
				med_nodes = maxi(med_nodes, _count(hud.medallions) + _count(hud.banner))
		if end_t < 0.0 and KP.over(run):
			end_t = game_t
		var c0 := Time.get_ticks_usec()
		KP.step(run, path, _bot, dt)
		last_cpu = float(Time.get_ticks_usec() - c0) / 1000.0
		game_t += dt
	var bud: Dictionary = run.champ_view.budget() if run.champ_view else {"tris": 0, "draws_steady": 0}
	var res := _stats(wall, cpu, draws, prims, steps)
	res.merge({"tex_mb": tex_max, "tp_max": tp_max, "nodes": nodes / maxf(float(wall.size()), 1.0),
			"champ_nodes": champ_nodes, "med_nodes": med_nodes, "champ_tris": int(bud.get("tris", 0)),
			"champ_draws": int(bud.get("draws_steady", 0)), "wall": wall, "cpu": cpu, "draws_a": draws, "prims_a": prims,
			"steps_a": steps, "split": split, "end": end_t})
	if probe_every <= 0:
		_line("BENCH champions=%s pass=%d" % [mode, pass_k], res)
	else:
		print("BENCH champions=on pass=split: %d probes (frame times of this pass are not used)" % int(split["n"]))
	remove_child(holder)
	holder.free()
	await get_tree().process_frame
	return res


## Percentiles and means of one pass (or of pooled passes).
static func _stats(wall: PackedFloat32Array, cpu: PackedFloat32Array, draws: PackedFloat32Array,
		prims: PackedFloat32Array, steps: PackedFloat32Array) -> Dictionary:
	return {"frames": wall.size(), "p50": _pct(wall, 0.5), "p95": _pct(wall, 0.95), "max": _pct(wall, 1.0),
			"cpu_p50": _pct(cpu, 0.5), "cpu_p95": _pct(cpu, 0.95), "draws": _mean(draws), "draws_max": _pct(draws, 1.0),
			"prims": _mean(prims), "prims_max": _pct(prims, 1.0), "step_us": _mean(steps),
			"step_us_p95": _pct(steps, 0.95), "step_us_max": _pct(steps, 1.0)}


## The warmed passes of one mode pooled frame by frame (p50 = the median frame of both passes).
func _pool(mode: String, passes: Array) -> Dictionary:
	var keys := {"wall": PackedFloat32Array(), "cpu": PackedFloat32Array(), "draws_a": PackedFloat32Array(),
			"prims_a": PackedFloat32Array(), "steps_a": PackedFloat32Array()}
	var out := {"tex_mb": 0.0, "tp_max": 0.0, "nodes": 0.0, "champ_nodes": 0, "med_nodes": 0, "champ_tris": 0,
			"champ_draws": 0}
	for p: Dictionary in passes:
		for k: String in keys:
			# Packed arrays are values: append to the copy, store it back.
			var a: PackedFloat32Array = keys[k]
			a.append_array(p[k])
			keys[k] = a
		out["tex_mb"] = maxf(float(out["tex_mb"]), float(p["tex_mb"]))
		out["tp_max"] = maxf(float(out["tp_max"]), float(p["tp_max"]))
		out["nodes"] = float(out["nodes"]) + float(p["nodes"]) / float(passes.size())
		for k2: String in ["champ_nodes", "med_nodes", "champ_tris", "champ_draws"]:
			out[k2] = maxi(int(out[k2]), int(p[k2]))
	out.merge(_stats(keys["wall"], keys["cpu"], keys["draws_a"], keys["prims_a"], keys["steps_a"]))
	_line("BENCH_MODE %s (%d warmed passes pooled)" % [mode, passes.size()], out)
	return out


## Prints one summary line and books its CSV row.
func _line(head: String, res: Dictionary) -> void:
	print("%s p50=%.2f p95=%.2f max=%.2f draws=%.1f prims=%.0f step_us=%.1f (p95 %.0f, max %.0f) cpu_p50=%.2f cpu_p95=%.2f tex=%.1fMB nodes=%.0f champ_nodes=%d medallion_nodes=%d champ_tris=%d frames=%d" % [
			head, float(res["p50"]), float(res["p95"]), float(res["max"]), float(res["draws"]), float(res["prims"]),
			float(res["step_us"]), float(res["step_us_p95"]), float(res["step_us_max"]), float(res["cpu_p50"]),
			float(res["cpu_p95"]), float(res["tex_mb"]), float(res["nodes"]), int(res["champ_nodes"]), int(res["med_nodes"]),
			int(res["champ_tris"]), int(res["frames"])])
	_summary.append("%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.2f,%.0f,%.0f,%.0f,%.2f,%.2f,%.0f,%.0f,%.0f,%d,%d,%d,%d" % [
			head.replace(",", ";"), int(res["frames"]), float(res["p50"]), float(res["p95"]), float(res["max"]),
			float(res["cpu_p50"]), float(res["cpu_p95"]), float(res["tp_max"]), float(res["draws"]), float(res["draws_max"]),
			float(res["prims"]), float(res["prims_max"]), float(res["tex_mb"]), float(res["step_us"]), float(res["step_us_p95"]),
			float(res["step_us_max"]), float(res["nodes"]), int(res["champ_nodes"]), int(res["med_nodes"]),
			int(res["champ_tris"]), int(res["champ_draws"])])


## The split probe: the game frozen, the same frame rendered as is, then with the champions' draws hidden
## one after another (SPLIT_PARTS: ChampionHud.bench_parts' medallions and banner picture, ChampionView.
## bench_parts' stamp text, marks + VFX and bodies); each step's fall in draw calls is that part's share.
## Visibility restored after. Adds into `acc`.
func _probe(run: Run, acc: Dictionary) -> void:
	var cv := run.champ_view
	var have: Dictionary = cv.bench_parts()
	if cv.hud:
		have.merge(cv.hud.bench_parts())
	var keep: Array = []
	# Paused: nothing animates on its own while the same frame is rendered part by part (the run is stepped
	# by this bench only; the popups, effects and medallions process with the tree).
	var was := get_tree().paused
	get_tree().paused = true
	var before := await _draws()
	var first := before
	acc["fx_live"] = int(acc["fx_live"]) + (1 if int(have.get("fx_live", 0)) > 0 else 0)
	var stamp: Array = have.get("stamp", [])
	acc["stamp_live"] = int(acc["stamp_live"]) + (1 if not stamp.is_empty() and (stamp[0] as Node3D).visible else 0)
	for part: String in SPLIT_PARTS:
		var nodes: Array = have.get(part, [])
		for n: Variant in nodes:
			if not is_instance_valid(n):
				continue
			keep.append([n, (n as Node).get("visible")])
			(n as Node).set("visible", false)
		var after := await _draws()
		acc[part] = float(acc[part]) + float(before.x - after.x)
		if part == "medallions":
			acc["canvas"] = float(acc["canvas"]) + float(before.y - after.y)
		before = after
	for e: Array in keep:
		(e[0] as Node).set("visible", e[1])
	# The same frame again with everything back: what moved by itself between the renders (fx nodes that
	# animate on their own) is the probe's noise.
	var again := await _draws()
	get_tree().paused = was
	acc["noise"] = float(acc.get("noise", 0.0)) + absf(again.x - first.x)
	acc["n"] = int(acc["n"]) + 1


## Draw calls of the frozen frame once the last change is in: x = RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME (the
## monitor the gate reads), y = the viewport's canvas draws (Viewport.RENDER_INFO_TYPE_CANVAS); each the
## fewest over SPLIT_RENDERS renders (the shadow atlas re-renders a light now and then on its own, a
## one-frame extra that is not the part's).
func _draws() -> Vector2:
	await RenderingServer.frame_post_draw
	var best := Vector2(INF, INF)
	for k in SPLIT_RENDERS:
		await RenderingServer.frame_post_draw
		var total := float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var canvas := float(get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS,
				Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		best = best.min(Vector2(total, canvas))
	return best


static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(floor(q * float(s.size() - 1))), 0, s.size() - 1)]


static func _mean(a: PackedFloat32Array) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxf(float(a.size()), 1.0)


func _write(name: String, lines: PackedStringArray) -> void:
	var path := out_dir.path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("gallery_champions: cannot write " + path)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("BENCH written ", path)


# ------------------------------------------------------------------ stills

func _shots() -> int:
	var want: Array[String] = []
	var list := str(args["shots"])
	for s in (SHOTS if list == "1" else Array(list.split(",", false))):
		if s in SHOTS:
			want.append(s)
	var team := _team_arg(SHOT_TEAM)
	var path := _plan(team)
	var holder := _make_play(team)
	add_child(holder)
	var run: Run = holder.get_meta("run")
	await get_tree().process_frame
	KP.begin(run, path)
	var dt := 1.0 / 60.0
	var front := ChampionKinds.in_slot(run.champions.members, ChampionKinds.FRONT)
	var taken := {}
	var due := {}            # shot -> game time to take it
	var last_hit := float(front.get("dmg_taken", 0.0)) if not front.is_empty() else 0.0
	var blocks := _blocks(run)
	var doomed := false
	var game_t := 0.0
	while game_t < 300.0 and taken.size() < want.size():
		await get_tree().process_frame
		# Events of the step that just ran.
		if not front.is_empty():
			var hit := float(front["dmg_taken"])
			if "clash" in want and not due.has("clash") and run.state == Run.State.CLASH and hit > last_hit \
					and bool(front["alive"]):
				due["clash"] = game_t + AFTER_HIT
			last_hit = hit
			if "fallen" in want and not doomed and taken.has("clash") == ("clash" in want) \
					and run.state == Run.State.CLASH and bool(front["alive"]):
				# The front is left at 1 HP: the rules make it fall in this clash.
				front["hp"] = minf(float(front["hp"]), 1.0)
				doomed = true
			if doomed and not due.has("fallen") and not bool(front["alive"]):
				due["fallen"] = game_t + AFTER_FALL
		var b := _blocks(run)
		if "block" in want and not due.has("block") and b > blocks:
			due["block"] = game_t + AFTER_BLOCK
		blocks = b
		for s: String in due:
			if not taken.has(s) and game_t >= float(due[s]):
				taken[s] = true
				await _save(s, run, game_t)
		if KP.over(run) and run.state != Run.State.STAIRS:
			break
		KP.step(run, path, _bot, dt, true, _seek_hazard(run, "block" in want and not due.has("block")))
		game_t += dt
	var missing: PackedStringArray = PackedStringArray()
	for s in want:
		if not taken.has(s):
			missing.append(s)
	print("SHOTS taken %d of %d%s" % [taken.size(), want.size(), (", missing: " + ", ".join(missing)) if not missing.is_empty() else ""])
	remove_child(holder)
	holder.free()
	return 0 if missing.is_empty() else 1


## While the Block still is pending: the x of the nearest live barricade or blade within SEEK_AHEAD
## (the army runs into it, a ready Guardian Blocks), else INF (follow the path).
static func _seek_hazard(run: Run, on: bool) -> float:
	if not on:
		return INF
	var best := {}
	for list: Array[Dictionary] in [run.hazards.spikes, run.hazards.blades]:
		for it: Dictionary in list:
			var ahead := float(it["d"]) - run.d
			if ahead < -0.5 or ahead > SEEK_AHEAD or not (it["alive"] or str(it["kind"]) == "blade"):
				continue
			if best.is_empty() or float(it["d"]) < float(best["d"]):
				best = it
	return INF if best.is_empty() else float(best.get("x0", best["x"]))


static func _blocks(run: Run) -> int:
	var n := 0
	for m: Dictionary in run.champions.members:
		n += int(m["blocks"])
	return n


func _save(name: String, run: Run, game_t: float) -> void:
	var file := "champions_%s_%s.png" % [name, tag]
	var ctx := "t %.1f s, d %.1f, state %s, army %d, team %s" % [game_t, run.d, Run.State.keys()[run.state], run.army,
			_team_line(run)]
	if DisplayServer.get_name() == "headless" or out_dir == "":
		print("SHOT ", file, " (not saved: headless or no --out) ", ctx)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("SHOT ", out_dir.path_join(file), " ", ctx)


static func _team_line(run: Run) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for m: Dictionary in run.champions.members:
		parts.append("%s:%s %.0f/%.0f%s" % [str(m["id"]), str(m["slot"]), float(m["hp"]), float(m["hp_max"]),
				"" if bool(m["alive"]) else " down"])
	return " ".join(parts)
