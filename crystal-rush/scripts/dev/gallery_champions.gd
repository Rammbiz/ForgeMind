extends Node
## Champions in the run: the §10.6 bench and three stills (heroes design §4.2, §10.5, §10.6).
##
## --bench: a scripted W4 run (default L45, Bolt, the planner's path: LevelSim.best_path with the team,
## replayed by both runs, no re-planning) played twice through the real Run + run HUD, champions OFF
## (empty team) then ON (`--team`, default borko,taya,mila: Warrior front, Mage rear, Healer left),
## phase H2 forced for both, for --seconds game seconds (default 60) or until a second after the fortress
## falls (L45 takes ~45 s, so its whole level is recorded). The game advances a fixed 1 / --fps s per
## frame (default 60, so both runs render the very same frames whatever a frame costs), vsync off, the
## ult fired by the shared auto policy. Per run, after --skip warm-up frames:
## frame wall time p50 / p95 / max, the run's own CPU per frame (its step: logic + visuals),
## RENDER_TOTAL_DRAW_CALLS_IN_FRAME, RENDER_TOTAL_PRIMITIVES_IN_FRAME, RENDER_TEXTURE_MEM_USED,
## Champions.step per frame (Run.champ_perf), the scene's node count, ChampionView's and the medallions'
## node counts and ChampionView.budget(); TIME_PROCESS (Godot's max over the last second) goes to the CSV.
## Prints
##   BENCH champions=off|on p50=.. p95=.. max=.. draws=.. prims=.. step_us=.. (+ cpu, tex, nodes)
##   BENCH_DELTA draws=+.. prims=+.. p95=+..ms
##   BENCH_GATES (the §10.6 "added by 3 champions" rows: draws <= +10 (+1 transient), tris <= +25k,
##   Champions.step <= 0.25 ms)
## and writes DIR/bench_champions.csv (one row per frame and run) and DIR/bench_champions_summary.csv.
## Needs a real renderer (the draw / primitive monitors read 0 headless):
##   godot --path . --resolution 720x1280 res://scenes/dev/gallery_champions.tscn -- --autotest --bench --out=DIR
##        [--seconds=60] [--level=45] [--hero=bolt] [--team=borko,taya,mila] [--fps=60] [--skip=30]
## Headless (a script check: starts, runs a few seconds of both runs, exits 0):
##   godot --headless --path . res://scenes/dev/gallery_champions.tscn -- --autotest --bench --seconds=5
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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("BENCH_RUN L%d %s team %s, %.0f s at a fixed 1/%.0f s per frame, skip %d frames%s" % [level, hero,
			",".join(team), secs, fps, skip, " (headless: no renderer, draw / primitive / frame numbers are not real)" if headless else ""])
	var path := _plan(team)
	_csv.append("champions,frame,t,wall_ms,run_cpu_ms,draws,prims,tex_mb,champ_step_us,nodes,time_process_1s_ms")
	_summary.append("champions,frames,p50_ms,p95_ms,max_ms,cpu_p50_ms,cpu_p95_ms,time_process_1s_max_ms,draws_mean," +
			"draws_max,prims_mean,prims_max,tex_mb_max,step_us_mean,step_us_p95,step_us_max,nodes_mean,champ_nodes," +
			"medallion_nodes,champ_tris,champ_draws_steady")
	var off: Dictionary = await _bench_run("off", [], path, secs, fps, skip)
	var on: Dictionary = await _bench_run("on", team, path, secs, fps, skip)
	print("BENCH_DELTA draws=%+.1f prims=%+.0f p95=%+.2fms p50=%+.2fms max=%+.2fms cpu_p95=%+.2fms nodes=%+.0f tex=%+.1fMB" % [
			float(on["draws"]) - float(off["draws"]), float(on["prims"]) - float(off["prims"]),
			float(on["p95"]) - float(off["p95"]), float(on["p50"]) - float(off["p50"]), float(on["max"]) - float(off["max"]),
			float(on["cpu_p95"]) - float(off["cpu_p95"]), float(on["nodes"]) - float(off["nodes"]),
			float(on["tex_mb"]) - float(off["tex_mb"])])
	var dd := float(on["draws"]) - float(off["draws"])
	var ddm := float(on["draws_max"]) - float(off["draws_max"])
	var step_ms := float(on["step_us_p95"]) / 1000.0
	print("BENCH_GATES draws %+.1f mean / %+.0f max (<= +%d, +1 transient): %s; champion tris %d (<= %d): %s; Champions.step p95 %.3f ms (<= %.2f): %s%s" % [
			dd, ddm, int(GATE_DRAWS), _ok(dd <= GATE_DRAWS and ddm <= GATE_DRAWS + 1.0), int(on["champ_tris"]),
			GATE_TRIS, _ok(int(on["champ_tris"]) <= GATE_TRIS), step_ms, GATE_STEP_MS, _ok(step_ms <= GATE_STEP_MS),
			" (headless: draw calls not measured)" if headless else ""])
	if out_dir != "":
		_write("bench_champions.csv", _csv)
		_write("bench_champions_summary.csv", _summary)
	return 0


static func _ok(c: bool) -> String:
	return "PASS" if c else "FAIL"


## One bench run: builds the play, steps it a fixed 1 / fps per frame for `secs` game seconds (or until
## a second after it ended), records every frame after `skip`, frees it. Per frame: the wall time
## between two frames (vsync off: what the frame cost), the CPU time of the run's step (logic + visuals,
## KP.step), the render monitors of that frame, Champions.step (Run.champ_perf) and the node count.
## TIME_PROCESS is Godot's max process time over the last second (it updates once a second): kept in
## the CSV, not used for the percentiles. Returns the summary.
func _bench_run(mode: String, team: Array, path: PackedFloat32Array, secs: float, fps: float, skip: int) -> Dictionary:
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
			_csv.append("%s,%d,%.3f,%.3f,%.3f,%.0f,%.0f,%.2f,%.0f,%.0f,%.2f" % [mode, frame, game_t, w, last_cpu, dc, pr,
					tex, su, nc, tp])
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
	var n := wall.size()
	var res := {"frames": n, "p50": _pct(wall, 0.5), "p95": _pct(wall, 0.95), "max": _pct(wall, 1.0),
			"cpu_p50": _pct(cpu, 0.5), "cpu_p95": _pct(cpu, 0.95), "draws": _mean(draws), "draws_max": _pct(draws, 1.0),
			"prims": _mean(prims), "prims_max": _pct(prims, 1.0), "tex_mb": tex_max, "step_us": _mean(steps),
			"step_us_p95": _pct(steps, 0.95), "step_us_max": _pct(steps, 1.0), "nodes": nodes / maxf(float(n), 1.0),
			"champ_nodes": champ_nodes, "med_nodes": med_nodes, "champ_tris": int(bud.get("tris", 0)),
			"champ_draws": int(bud.get("draws_steady", 0))}
	print("BENCH champions=%s p50=%.2f p95=%.2f max=%.2f draws=%.1f prims=%.0f step_us=%.1f (p95 %.0f, max %.0f) cpu_p50=%.2f cpu_p95=%.2f tex=%.1fMB nodes=%.0f champ_nodes=%d medallion_nodes=%d champ_tris=%d frames=%d end=%s" % [
			mode, float(res["p50"]), float(res["p95"]), float(res["max"]), float(res["draws"]), float(res["prims"]),
			float(res["step_us"]), float(res["step_us_p95"]), float(res["step_us_max"]), float(res["cpu_p50"]),
			float(res["cpu_p95"]), tex_max, float(res["nodes"]), champ_nodes, med_nodes, int(res["champ_tris"]), n,
			("%.1fs" % end_t) if end_t >= 0.0 else "running"])
	_summary.append("%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.2f,%.0f,%.0f,%.0f,%.2f,%.2f,%.0f,%.0f,%.0f,%d,%d,%d,%d" % [mode, n,
			float(res["p50"]), float(res["p95"]), float(res["max"]), float(res["cpu_p50"]), float(res["cpu_p95"]), tp_max,
			float(res["draws"]), float(res["draws_max"]), float(res["prims"]), float(res["prims_max"]), tex_max,
			float(res["step_us"]), float(res["step_us_p95"]), float(res["step_us_max"]), float(res["nodes"]),
			champ_nodes, med_nodes, int(res["champ_tris"]), int(res["champ_draws"])])
	remove_child(holder)
	holder.free()
	await get_tree().process_frame
	return res


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
