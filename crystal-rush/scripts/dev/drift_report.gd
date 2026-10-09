extends Node
## drift_report: the Meta-1 drift between the real Run and LevelSim, no team, phase 0 (heroes design
## §10.4 / §12.6 #9 follow-up; owner decision 09.10 #3: investigate and report only, nothing that moves
## LevelGen or a shipped level). The findings are in docs/design/sim_drift_report.md.
##
## For every campaign level x hero (the EXPECTED synthetic account, Meta.run_profile with the shipped flags)
## the planner's best path (LevelSim.best_path, the path level_check plays) is replayed:
## - in the Run, stepped by test_kind_parity's driver (Run.SUBSTEP steps, Run.steer_to a spring-lag ahead on
##   the path, the shared auto ult policy, its Effects on game time) as a DRun that books what every hazard
##   cost, the kills by source and the gate rows it crossed. The ult's "in a fight" test reads the Run itself
##   (RunKindView.in_fight): the bot's snapshot only sees a clash whose squad front stands within 0.6 u of
##   CONTACT, so a squad met from the side (armed, then swerved into) reads as no fight and the ult waits
##   (--ult=snapshot keeps test_kind_parity.step exactly);
## - in LevelSim, by this tool's copy of LevelSim.step (checked against LevelSim.simulate on every case:
##   SELF_CHECK), once as the planner sees it and once per toggle below. The toggles live here only: no game
##   rule changes.
## The fortress army of these LevelSim replays splits the gap (LevelSim own - Run) into mechanisms:
##   own     LevelSim on its own crate draws (what the planner, level_check and LevelGen see);
##   rc      with the crate contents the Run drew fixed in State.content (2a = own - rc);
##   +lag    the hero's x follows the path through the Run's steering (test_kind_parity.step's lead, then
##           Run._steer's STEER_HALFLIFE pull) instead of sitting on it: a swerve that ends at a gate row ends
##           short of the planned x in the Run;
##   +warm   machines warm up as in the Run: a crate's machine hops out for Weapons.ARRIVE_TIME and waits its
##           first cooldown (0.5 s; the railgun its charge + telegraph, the mortar + its shell's flight) (2b);
##   +amp    the hero's shots get the Prism amp only where the Run gives it (Run._hero_attack: never on a
##           gate, only at targets 2.5 u or more ahead, the squad splash inside the amp);
##   +mach   every machine's squad damage x (the Run's machine kills / this replay's, burn and chain kills
##           counted as machine kills; one factor per case, taken from the replay before it);
##   +bar    every barricade costs the soldiers it cost in the Run (1b: barricades met at full hp);
##   +blade  every rotor / sweeper costs the share of the army it took in the Run (1a);
##   +tur    every turret costs the soldiers it cost in the Run;
##   +gates  every gate the Run passed shows the op and value the Run passed it with;
## stacked in that order (sequential shares; residual = +gates - Run: clashes, the kills' timing) and each one
## alone on top of rc (single shares s_<toggle>; +mach's factor then from rc). An injected hazard costs its
## Run value once, when the army's front reaches its line (the band model's first contact), whatever
## LevelSim's own state of it. Per hazard the Run met, "model" is what LevelSim's band model says that very
## crossing costs from the Run's state at contact (army, armour, barricade hp, army x, hazard clock). The clash
## census books the squads only one side fought and how far inside the clash test the Run's hero was.
## Path p1 is the planner's path on LevelSim's own crate draws, so it picks crates the Run may fill with
## something else. Path p2 (unless --replan=0) is planned again knowing the crates the Run drew on p1 (a
## player reads the crate badges 30 u ahead) and replayed the same way: the drift a player who chooses meets.
##
##   godot --headless --fixed-fps 10 --path . res://scenes/dev/drift_report.tscn -- --autotest [--from=1]
##        [--to=112] [--levels=43,46] [--heroes=bolt,titan,seer] [--spf=4] [--seeds=1] [--candidates=13]
##        [--replan=1] [--ult=fight|snapshot] [--out=DIR] [--verbose]
##   godot --headless --path . res://scenes/dev/drift_report.tscn -- --autotest --merge=DIR
## --fixed-fps F with --spf = 40 / F keeps the engine clock on game time (SceneTreeTimers carry the rocket
## salvo and the mortar's bomblets; at test_kind_parity's 200 steps a frame they land seconds late).
## --seeds=N plays the Run N times per case on p1 as N attempts (other global seeds and run ids, so other
## crate draws; the Run on a fixed path and crates is otherwise deterministic).
## --out writes drift_<from>_<to>.csv (one row per case, path and seed) and drift_<from>_<to>_haz.csv (one row
## per hazard met); --merge reads every drift_*.csv of DIR but the _haz ones and prints the summary of them
## all. --verbose adds the kills by source, the gate rows, the hero's x at every row and the Run-only clashes.
## Exit code = SELF_CHECK failures. Last line: DRIFT_REPORT done: <rows>, <n> self-check fails, <time>. About
## 20 s per level and hero with both paths (the whole sweep: ~1 h in 8 shards of 14 levels).

const KP := preload("res://scripts/dev/test_kind_parity.gd")
const HEROES: Array[String] = ["bolt", "titan", "seer"]
const DT := Run.SUBSTEP
const MAX_T := 600.0
## A case "drifts" when the fortress armies differ by more than this share of LevelSim's (floor FLAG_FLOOR).
const FLAG_SHARE := 0.25
const FLAG_FLOOR := 10.0
const SEED0 := 4100
## +mach: a replay with fewer machine kills than this keeps its machines as they are.
const MACH_MIN := 5.0
## The toggles in chain order: replay c_<t> (on top of rc) has every toggle up to t, replay s_<t> only t.
const CHAIN: Array[String] = ["lag", "warm", "amp", "mach", "bar", "blade", "tur", "gates"]
## The sequential shares: [name, toggle].
const SHARES := [["steering lag", "lag"], ["machine warm-up (2b)", "warm"], ["Prism amp on hero shots", "amp"],
		["machine kill rate", "mach"], ["barricades (1b)", "bar"], ["rotors / sweepers (1a)", "blade"],
		["turrets", "tur"], ["gate values", "gates"]]
const COLS: Array[String] = ["level", "world", "boss", "hero", "path", "seed", "deck", "run_won", "own_won",
		"rc_won", "run_fort", "own_fort", "rc_fort", "c_lag_fort", "c_warm_fort", "c_amp_fort", "c_mach_fort",
		"c_bar_fort", "c_blade_fort", "c_tur_fort", "c_gates_fort", "s_warm_fort", "s_amp_fort", "s_mach_fort",
		"s_bar_fort", "s_blade_fort", "s_tur_fort", "s_gates_fort", "mach_k", "run_bar", "own_bar", "rc_bar",
		"run_rotor", "own_rotor", "rc_rotor", "run_sweeper", "own_sweeper", "rc_sweeper", "run_turret", "own_turret",
		"rc_turret", "run_clash", "own_clash", "rc_clash", "run_gate_gain", "own_gate_gain", "rc_gate_gain",
		"run_mach", "own_mach", "rc_mach", "run_first_d", "own_first_d", "run_first_k", "own_first_k",
		"run_first_hero", "own_first_hero", "run_first_mach", "own_first_mach", "run_first_ult", "own_first_ult",
		"crates", "crates_differ", "stale", "gates", "gates_differ", "gates_offpath", "clash_run_only",
		"clash_run_only_n", "clash_run_only_edge", "clash_own_only", "clash_own_only_n", "clash_both_run",
		"clash_both_own", "run_t", "own_t",
		"run_kills",
		"own_kills", "run_ults", "own_ults", "self_ok", "secs"]
const HAZ_COLS: Array[String] = ["level", "hero", "path", "seed", "kind", "d", "x", "run_lost", "run_model",
		"run_army", "run_armor", "run_hp", "run_w", "run_t", "run_ax", "own_lost", "own_army", "own_armor", "own_hp",
		"own_t", "own_ax", "rc_lost", "rc_army", "rc_armor", "rc_hp", "rc_t", "rc_ax"]


## The Run with books: what each hazard cost, the kills by source and the gates it passed. Nothing here
## changes a rule (every override calls the Run's own method).
class DRun extends Run:
	## hazard key (item_key) -> new_rec: lost = the army's loss (after Scrape Guard), raw = the drawn units'
	## worth (hazard_deaths), touched = units hit; at the army's contact (contact) the army, armour, barricade
	## hp, soldiers per drawn unit w, run time t, hazard clock hz_t, hero x hx, blob centre x ax; model =
	## LevelSim's band model at that state (_model_losses).
	var haz := {}
	## Squad hp removed by source (hero, ult, volley, clash, siege, burn, chain, a machine id).
	var by_src := {}
	## Gate row -> "<op><int value>" passed (a row passed through a gap is never booked).
	var gates := {}
	## Gate key (item_key) -> [op, value] passed (the +gates toggle).
	var gate_out := {}
	## Soldiers the gates gave (or took).
	var gate_gain := 0.0
	## Gate row -> [d, hero x, run time] when the hero crossed it (gaps included).
	var rows_x := {}
	## Squad key (item_key) -> soldiers lost in the clash with it (every squad the army clashed with).
	var clash_by := {}
	## Squad key -> [hero d, hero x, blob radius, squad x, squad half span] when that clash began.
	var clash_at := {}

	func hurt(it: Dictionary, n: float, source := "") -> float:
		var dealt := super(it, n, source)
		if dealt > 0.0 and str(it.get("kind", "")) == "squad":
			by_src[source] = float(by_src.get(source, 0.0)) + dealt
		return dealt

	func hazard_kills(it: Dictionary, idxs: PackedInt32Array, push: Vector3) -> void:
		var before := army
		var raw := hazard_deaths
		contact(it)
		super(it, idxs, push)
		var r := rec(it)
		r["lost"] = float(r["lost"]) + float(before - army)
		r["raw"] = float(r["raw"]) + hazard_deaths - raw
		r["touched"] = int(r["touched"]) + idxs.size()

	func turret_hit(it: Dictionary, at: Vector3) -> void:
		var before := army
		var raw := hazard_deaths
		contact(it)
		super(it, at)
		var r := rec(it)
		r["lost"] = float(r["lost"]) + float(before - army)
		r["raw"] = float(r["raw"]) + hazard_deaths - raw

	func _begin_clash(it: Dictionary) -> void:
		clash_by[item_key(it)] = float(clash_by.get(item_key(it), 0.0))
		clash_at[item_key(it)] = [d, hx, blob_radius(), float(it["x"]), _hw(it)]
		super(it)

	func _clash(dt: float) -> void:
		var key := item_key(_foe) if not _foe.is_empty() else ""
		var c0 := float(stats["clash_losses"])
		super(dt)
		if key != "":
			clash_by[key] = float(clash_by.get(key, 0.0)) + float(stats["clash_losses"]) - c0

	func _gate_row(first: Dictionary) -> void:
		rows_x[int(first.get("row", -1))] = [float(first["d"]), hx, t]
		super(first)

	func _pass_gate(it: Dictionary, op: String, v: float) -> void:
		gates[int(it.get("row", -1))] = "%s%d" % [op, int(v)]
		gate_out[item_key(it)] = [op, v]
		var before := army
		super(it, op, v)
		gate_gain += float(army - before)

	## The army, armour, barricade hp and soldiers per drawn unit when the army meets hazard `it` (its front
	## on the line, or the first unit it touches if that comes first); booked once.
	func contact(it: Dictionary) -> void:
		var r := rec(it)
		if float(r["army"]) >= 0.0:
			return
		r["army"] = float(army)
		r["armor"] = _armor > 0.0
		r["hp"] = float(it.get("hp", 0.0)) if bool(it["alive"]) else 0.0
		r["w"] = maxf(float(army) / maxf(float(army_view.shown), 1.0), 1.0)
		r["t"] = t
		r["hz_t"] = hz_t
		r["hx"] = hx
		# The blob's real centre x: the mean of the drawn units (army_view.center rides on the hero's x).
		var cx := 0.0
		for k in army_view.shown:
			cx += army_view.position_of(k).x
		r["ax"] = cx / float(army_view.shown) if army_view.shown > 0 else hx

	## The book of hazard `it` (made on first use).
	func rec(it: Dictionary) -> Dictionary:
		var key := item_key(it)
		if not haz.has(key):
			haz[key] = new_rec(it)
		return haz[key]

	## "kind|d|x" of a level item (blades and moving gates by their base x0: the Run keeps the live x in x).
	static func item_key(it: Dictionary) -> String:
		return "%s|%.2f|%.2f" % [str(it["kind"]), float(it["d"]), float(it.get("x0", it.get("x", 0.0)))]

	## barricade, rotor, sweeper or turret.
	static func hz_kind(it: Dictionary) -> String:
		var k := str(it["kind"])
		return str(it.get("type", "rotor")) if k == "blade" else k

	static func new_rec(it: Dictionary) -> Dictionary:
		return {"kind": hz_kind(it), "d": float(it["d"]), "x": float(it.get("x0", it.get("x", 0.0))), "lost": 0.0,
				"raw": 0.0, "touched": 0, "army": -1.0, "armor": false, "hp": -1.0, "w": 1.0, "t": -1.0, "hz_t": 0.0,
				"hx": 0.0, "ax": 0.0, "model": -1.0}


## One LevelSim replay's toggles and books (see the header).
class Ctx extends RefCounted:
	## The Run's machine warm-up (Weapons.field: cd 0.5 after the 0.8 s hop out of the crate; the railgun
	## charges instead; the mortar's shell flies `telegraph` s more).
	const FIRST_CD := 0.5

	var lag := false
	var warm := false
	var amp := false
	var mach := false
	var bar := false
	var blade := false
	var tur := false
	var gates := false
	## Run values per hazard key: soldiers (barricades, turrets) or the share of the army (blades).
	var inj := {}
	## The Run's gates: key -> [op, value] (+gates).
	var gate_out := {}
	## +mach: the machines' squad damage factor.
	var mach_k := 1.0
	var keys := PackedStringArray()     ## item_key per item of the level
	var done := {}                      ## item index -> true once an injected hazard was paid
	var rec := {}                       ## hazard key -> DRun.new_rec shape (lost, army / armor / hp at contact)
	var src := {}                       ## kills by source (hero, ult, volley, clash, m:<machine>)
	var clash := 0.0                    ## soldiers lost in clashes (State.clash_deaths also counts the siege)
	var clash_by := {}                  ## squad key -> soldiers lost in the clash with it (as DRun.clash_by)
	var first := {}                     ## the first clash: {d, t, kills, army, src}
	var ready_at := {}                  ## machine id -> run time it may fire (warm)
	var prof := {}
	var contact := PackedInt32Array()   ## barricades, blades and turrets by d (contact_book)
	var ck := 0

	func setup(lv: LevelSim.Level, p_prof: Dictionary) -> void:
		prof = p_prof
		keys.resize(lv.items.size())
		var order: Array = []
		for i in lv.items.size():
			keys[i] = DRun.item_key(lv.items[i])
			if lv.kind[i] in [LevelSim.K.BARRICADE, LevelSim.K.BLADE, LevelSim.K.TURRET]:
				order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool: return lv.d[a] < lv.d[b])
		for i: int in order:
			contact.append(i)

	## The Run's value for hazard `i` when its kind is injected (0 when the Run met it for free), else -1.
	func inject_of(lv: LevelSim.Level, i: int) -> float:
		var k := lv.kind[i]
		if (k == LevelSim.K.BARRICADE and bar) or (k == LevelSim.K.BLADE and blade) or (k == LevelSim.K.TURRET and tur):
			return float(inj.get(keys[i], 0.0))
		return -1.0

	func book(lv: LevelSim.Level, i: int, lost: float) -> void:
		var r := _rec(lv, i)
		r["lost"] = float(r["lost"]) + lost

	func _rec(lv: LevelSim.Level, i: int) -> Dictionary:
		if not rec.has(keys[i]):
			rec[keys[i]] = DRun.new_rec(lv.items[i])
		return rec[keys[i]]

	func add_src(key: String, n: float) -> void:
		if n != 0.0:
			src[key] = float(src.get(key, 0.0)) + n

	## The machines' kills (m:<id> summed).
	func machine_kills() -> float:
		var n := 0.0
		for key: String in src:
			if key.begins_with("m:"):
				n += float(src[key])
		return n

	## Before the hazards of a step: the contact books of the hazards whose line the army's front reached
	## (the band model's first band), as DRun.contact.
	func contact_book(lv: LevelSim.Level, s: LevelSim.State) -> void:
		var front := s.d - Balance.HERO_GAP
		while ck < contact.size() and lv.d[contact[ck]] <= front:
			var i := contact[ck]
			ck += 1
			var r := _rec(lv, i)
			r["army"] = s.army
			r["armor"] = s.armor > 0.0
			r["hp"] = s.hp[i] if s.alive[i] == 1 else 0.0
			r["t"] = s.t
			r["hz_t"] = s.hz_t
			r["hx"] = s.hx
			r["ax"] = s.ax

	## After a step: the first clash.
	func after(s: LevelSim.State) -> void:
		if first.is_empty() and s.mode == LevelSim.Mode.CLASH:
			first = {"d": s.d, "t": s.t, "kills": s.kills, "army": s.army, "src": src.duplicate()}

	## +gates: the gates of the rows the hero crosses up to `nd` that the Run passed show the Run's op and
	## value (both faces of a blinking gate).
	func gate_override(lv: LevelSim.Level, s: LevelSim.State, nd: float) -> void:
		var k := s.pk
		while k < lv.pick.size():
			var i := lv.pick[k]
			if lv.d[i] > nd:
				break
			k += 1
			if lv.kind[i] != LevelSim.K.GATE:
				continue
			for g in lv.rows.get(int(lv.items[i].get("row", i)), PackedInt32Array([i])):
				var o: Array = gate_out.get(keys[g], [])
				if o.is_empty():
					continue
				s.op[g] = str(o[0])
				s.val[g] = float(o[1])
				s.op2[g] = str(o[0])
				s.val2[g] = float(o[1])

	## +lag: the hero's x after one Run steering step of `dt` from `hx` at distance `d` on `path` (the target a
	## spring-lag ahead, test_kind_parity.step; then Run._steer's half-life pull).
	static func steer(hx: float, path: PackedFloat32Array, d: float, dt: float) -> float:
		var target := clampf(LevelSim.path_x(path, d + Balance.RUN_SPEED * Balance.STEER_HALFLIFE / log(2.0)),
				-Balance.X_LIMIT, Balance.X_LIMIT)
		return hx + (target - hx) * (1.0 - pow(0.5, dt / Balance.STEER_HALFLIFE))

	## Machines fielded since the last look get their warm-up end (the Lead at t 0 skips the hop).
	func scan(s: LevelSim.State) -> void:
		for w: Array in s.weapons:
			var id := str(w[0])
			if ready_at.has(id):
				continue
			var st := _stats(id, int(w[1]))
			var wait := FIRST_CD
			match id:
				"railgun":
					wait = float(st.get("charge", 3.0)) + float(st.get("telegraph", 0.4))
				"mortar":
					wait = FIRST_CD + float(st.get("telegraph", 0.8))
			ready_at[id] = s.t + wait + (0.0 if s.t <= 0.0 else Weapons.ARRIVE_TIME)

	## The Run's stats of machine `id` at `rank` (Weapons._rank_stats: the profile's by_rank).
	func _stats(id: String, rank: int) -> Dictionary:
		var e: Dictionary = (prof.get("machines", {}) as Dictionary).get(id, {})
		if e.is_empty():
			e = LevelSim.entry(id, int(EconData.START_LEVEL[ArsenalData.rarity_of(id)]))
		var by: Array = e.get("by_rank", [])
		return by[clampi(rank, 1, 3) - 1] if by.size() >= clampi(rank, 1, 3) else e.get("stats", {})


var _bot := Bot.new()
var _verbose := false
var _spf := 4
var _ult_snapshot := false
var _rows: Array = []
var _haz_rows: Array = []
var _self_fails := 0
var _plan_checked := false


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Save.readonly = true
	var t0 := Time.get_ticks_msec()
	_verbose = args.has("verbose")
	if args.has("merge"):
		_merge(str(args["merge"]))
		_summary(_rows)
		print("DRIFT_REPORT done: %d rows (merged), %.0f s" % [_rows.size(),
				float(Time.get_ticks_msec() - t0) / 1000.0])
		get_tree().quit(0)
		return
	_spf = clampi(int(args.get("spf", "4")), 1, 400)
	_ult_snapshot = str(args.get("ult", "fight")) == "snapshot"
	var from := clampi(int(args.get("from", "1")), 1, 999)
	var to := clampi(int(args.get("to", "112")), from, 999)
	var levels: Array[int] = []
	if args.has("levels"):
		for v in str(args["levels"]).split(",", false):
			levels.append(int(v))
		from = int(levels.min())
		to = int(levels.max())
	else:
		for l in range(from, to + 1):
			levels.append(l)
	var heroes: Array[String] = []
	for h in str(args.get("heroes", ",".join(HEROES))).split(",", false):
		if Balance.HEROES.has(h):
			heroes.append(h)
	var seeds := clampi(int(args.get("seeds", "1")), 1, 9)
	var cands := clampi(int(args.get("candidates", "13")), 3, 21)
	var replan := str(args.get("replan", "1")) != "0"
	var old_hitstop := Juice.hitstop_enabled
	Juice.hitstop_enabled = false
	print("DRIFT_REPORT levels %d..%d (%d) x heroes %s x %d seed(s); heroes phase %d, EXPECTED profile, no team" % [
			from, to, levels.size(), ",".join(heroes), seeds, EconData.heroes_phase()])
	# The engine frame vs the game time a frame of _drive covers (--fixed-fps makes the frame fixed).
	await get_tree().process_frame
	await get_tree().process_frame
	var frame := get_process_delta_time()
	print("  %d Run steps (%.3f s) a frame, engine frame %.3f s: SceneTreeTimers %s; planner candidates %d" % [_spf,
			_spf * DT, frame, "on game time" if absf(frame - _spf * DT) < 0.0005 else
			"NOT on game time (use --fixed-fps %.1f)" % (1.0 / (_spf * DT)), cands])
	var head: PackedStringArray = PackedStringArray()
	for t in CHAIN:
		head.append("%6s" % ("+" + t))
	print("  %-4s %-5s %-2s %-2s | %-5s | %6s %6s %6s | %s %6s | %5s %5s %5s %5s | %s" % ["lvl", "hero", "pt", "sd",
			"W r/s", "run", "own", "rc", " ".join(head), "x mach", "bar", "rotor", "sweep", "turr", "flags"])
	for level in levels:
		var lv0 := KP.level_of(level)
		for hero in heroes:
			var t1 := Time.get_ticks_msec()
			var prof := KP.profile_of(KP.account(level, hero, "none"), level, hero)
			var bp: Dictionary = LevelSim.best_path(lv0, hero, Balance.START_ARMY, {"profile": prof,
					"candidates": cands})
			var path: PackedFloat32Array = bp["path"]
			if not _plan_checked:
				# Once: the re-planner with no crates known is LevelSim.best_path exactly.
				_plan_checked = true
				if _plan_knowing(lv0, hero, prof, cands, {}) != path:
					_self_fails += 1
					print("  SELF_CHECK FAIL the re-planner differs from LevelSim.best_path (L%d %s)" % [level, hero])
			for k in seeds:
				var row: Dictionary = await _case(level, hero, k, path, "p1")
				row["secs"] = float(Time.get_ticks_msec() - t1) / 1000.0
				t1 = Time.get_ticks_msec()
				_rows.append(row)
				_print_row(row)
				if k == 0 and replan:
					var p2 := _plan_knowing(lv0, hero, prof, cands, row["_crates"])
					var row2: Dictionary = await _case(level, hero, k, p2, "p2")
					row2["secs"] = float(Time.get_ticks_msec() - t1) / 1000.0
					t1 = Time.get_ticks_msec()
					# The crates the p2 Run drew otherwise than the p1 Run (what p2 was planned on).
					row2["stale"] = _stale(row["_crates"], row2["_crates"])
					_rows.append(row2)
					_print_row(row2)
	Juice.hitstop_enabled = old_hitstop
	_summary(_rows)
	if args.has("out"):
		_write(str(args["out"]), "drift_%d_%d" % [from, to])
	print("DRIFT_REPORT done: %d rows, %d self-check fails, %.0f s" % [_rows.size(), _self_fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_self_fails)


# ------------------------------------------------------------------ one case

## (level, hero, seed k) on `path` (path_id p1 / p2): the Run, then the LevelSim replays (header). Seed k is
## the k-th attempt: the global seed and the account's run counter (Run._pick_rng: the crate draws) move on.
func _case(level: int, hero: String, k: int, path: PackedFloat32Array, path_id: String) -> Dictionary:
	var acc := KP.account(level, hero, "none")
	(acc["meta"] as Dictionary)["run_seq"] = k
	var keep: Array = KP.swap_in(acc, hero)
	seed(SEED0 + level * 10 + HEROES.find(hero) + 1000 * k)
	var run := DRun.new()
	run.setup(level, hero)
	KP.swap_out(keep)
	# LevelSim gets the profile as the planner had it (the Run adds a NEW crate machine's entry to its own).
	var prof: Dictionary = run.profile.duplicate(true)
	add_child(run)
	var first := {}
	var res: Dictionary = await _drive(run, path, first)
	var crates := KP.run_crates(run)
	# LevelSim: its own draws (the self-check against LevelSim.simulate), then the Run's crates and the toggles.
	var lv_own := KP.level_of(level)
	var own_x := Ctx.new()
	var own := _sim(lv_own, hero, path, prof, {}, own_x)
	var ref := LevelSim.simulate(KP.level_of(level), hero, Balance.START_ARMY, path, {"profile": prof})
	var self_ok := ref.t == own.t and ref.d == own.d and ref.army == own.army and ref.kills == own.kills \
			and ref.hazard_deaths == own.hazard_deaths and ref.army_at_fortress == own.army_at_fortress \
			and ref.mode == own.mode
	if not self_ok:
		_self_fails += 1
		print("  SELF_CHECK FAIL L%d %s: the copied step differs from LevelSim.simulate" % [level, hero] +
				" (army %.3f vs %.3f, t %.2f vs %.2f)" % [own.army, ref.army, own.t, ref.t])
	var inj := _injections(run)
	var run_mach := _run_machine_kills(run)
	_model_losses(run, lv_own, own_x, hero, prof, path)
	var reps := {}
	for name: String in _plan():
		var togs: Array = _plan()[name]
		var x := Ctx.new()
		for tog: String in togs:
			x.set(tog, true)
		x.inj = inj
		x.gate_out = run.gate_out
		if x.mach:
			# +mach's factor: the Run's machine kills over the replay before it (rc for the single one).
			var before := "rc" if togs.size() == 1 else "c_" + CHAIN[CHAIN.find("mach") - 1]
			var mk := ((reps[before] as Array)[1] as Ctx).machine_kills()
			x.mach_k = clampf(run_mach / mk, 0.0, 3.0) if mk >= MACH_MIN else 1.0
		var lv := KP.level_of(level)
		reps[name] = [_sim(lv, hero, path, prof, crates, x), x]
	var rc_s: LevelSim.State = (reps["rc"] as Array)[0]
	var rc_x: Ctx = (reps["rc"] as Array)[1]
	var g_own := _gate_info(own)
	var g_rc := _gate_info(rc_s)
	var differ := 0
	var rows := {}
	for r: int in (g_own[0] as Dictionary):
		rows[r] = true
	for r: int in run.gates:
		rows[r] = true
	for r: int in rows:
		if str(run.gates.get(r, "gap")) != str((g_own[0] as Dictionary).get(r, "gap")):
			differ += 1
	var row := {"level": level, "world": ArsenalData.world_of(level), "boss": 1 if ArsenalData.is_boss(level) else 0,
			"hero": hero, "path": path_id, "seed": k, "deck": "/".join(prof.get("deck", [])), "_crates": crates,
			"stale": 0, "run_won": 1 if run.state != Run.State.LOST and bool(res["ended"]) else 0,
			"own_won": 1 if own.mode == LevelSim.Mode.WON else 0, "rc_won": 1 if rc_s.mode == LevelSim.Mode.WON else 0,
			"run_fort": _fort(float(run._army_at_fortress)), "own_fort": _fort(own.army_at_fortress),
			"mach_k": ((reps["c_mach"] as Array)[1] as Ctx).mach_k,
			"run_clash": float(run.stats["clash_losses"]), "own_clash": own_x.clash, "rc_clash": rc_x.clash,
			"clash_run_only": 0.0, "clash_run_only_n": 0, "clash_run_only_edge": 0.0, "clash_own_only": 0.0,
			"clash_own_only_n": 0,
			"clash_both_run": 0.0, "clash_both_own": 0.0,
			"run_gate_gain": run.gate_gain, "own_gate_gain": g_own[1], "rc_gate_gain": g_rc[1],
			"run_mach": run_mach, "own_mach": own_x.machine_kills(), "rc_mach": rc_x.machine_kills(),
			"run_first_d": float(first.get("d", -1.0)), "own_first_d": float(own_x.first.get("d", -1.0)),
			"run_first_k": float(first.get("kills", 0.0)), "own_first_k": float(own_x.first.get("kills", 0.0)),
			"crates": crates.size(), "crates_differ": KP._crates_differ(lv_own, own, crates),
			"gates": rows.size(), "gates_differ": differ, "gates_offpath": _off_path(run, path), "run_t": run.t,
			"own_t": own.t,
			"run_kills": float(run.stats["kills_total"]), "own_kills": own.kills, "run_ults": int(res["ults"]),
			"own_ults": _ults(own), "self_ok": 1 if self_ok else 0}
	for name: String in reps:
		row[name + "_fort"] = _fort(((reps[name] as Array)[0] as LevelSim.State).army_at_fortress)
	# The clash census: squads only one side fought (the planner's path slips past a squad LevelSim never meets
	# while the Run, a little off the line or later, clashes with it, or the reverse) and the shared ones.
	for key: String in run.clash_by:
		if own_x.clash_by.has(key):
			row["clash_both_run"] = float(row["clash_both_run"]) + float(run.clash_by[key])
			row["clash_both_own"] = float(row["clash_both_own"]) + float(own_x.clash_by[key])
		else:
			row["clash_run_only"] = float(row["clash_run_only"]) + float(run.clash_by[key])
			row["clash_run_only_n"] = int(row["clash_run_only_n"]) + 1
			# How far inside the clash test the Run's hero was (blob radius + half span - |dx|; LevelSim's planner
			# keeps the blob just clear of a squad it slips past, so a hair of steering lag starts the clash).
			var c: Array = run.clash_at[key]
			var edge := float(c[2]) + float(c[4]) - absf(float(c[1]) - float(c[3]))
			row["clash_run_only_edge"] = maxf(float(row["clash_run_only_edge"]), edge)
	for key: String in own_x.clash_by:
		if not run.clash_by.has(key):
			row["clash_own_only"] = float(row["clash_own_only"]) + float(own_x.clash_by[key])
			row["clash_own_only_n"] = int(row["clash_own_only_n"]) + 1
	var by_kind := {"run": _by_kind(run.haz), "own": _by_kind(own_x.rec), "rc": _by_kind(rc_x.rec)}
	for side: String in by_kind:
		for kind: String in ["bar", "rotor", "sweeper", "turret"]:
			row["%s_%s" % [side, kind]] = float((by_kind[side] as Dictionary).get(kind, 0.0))
	# The kills before the first clash by source (the Run's machines by id with burn and chain, LevelSim's m:<id>).
	var rsrc: Dictionary = first.get("src", run.by_src)
	var osrc: Dictionary = own_x.first.get("src", own_x.src)
	row["run_first_hero"] = float(rsrc.get("hero", 0.0))
	row["own_first_hero"] = float(osrc.get("hero", 0.0))
	row["run_first_ult"] = float(rsrc.get("ult", 0.0))
	row["own_first_ult"] = float(osrc.get("ult", 0.0))
	row["run_first_mach"] = _machine_share(rsrc)
	var om := 0.0
	for key: String in osrc:
		if key.begins_with("m:"):
			om += float(osrc[key])
	row["own_first_mach"] = om
	_hazard_rows(row, run.haz, own_x.rec, rc_x.rec)
	if _verbose:
		print("       run src %s | own src %s" % [str(run.by_src), str(own_x.src)])
		print("       gates run %s | sim %s" % [str(run.gates), str(g_own[0])])
		for key: String in run.clash_by:
			if not own_x.clash_by.has(key):
				var c: Array = run.clash_at[key]
				print("       Run-only clash %s at d %.1f: hero x %.4f, path x %.4f, blob r %.2f," % [key, float(c[0]),
						float(c[1]), LevelSim.path_x(path, float(c[0])), float(c[2])] +
						" squad x %.2f +- %.2f, lost %.0f" % [float(c[3]), float(c[4]), float(run.clash_by[key])])
		for rw: int in run.rows_x:
			var e: Array = run.rows_x[rw]
			print("       row %d at d %.1f t %.2f: hero x %.2f, path x %.2f" % [rw, float(e[0]), float(e[2]),
					float(e[1]), LevelSim.path_x(path, float(e[0]))])
	remove_child(run)
	run.free()
	return row


## The LevelSim replays after own, in order: name -> toggles (rc, the chain c_<t>, the singles s_<t>).
static func _plan() -> Dictionary:
	var out := {"rc": []}
	for k in CHAIN.size():
		out["c_" + CHAIN[k]] = CHAIN.slice(0, k + 1)
	for t in CHAIN.slice(1):
		out["s_" + t] = [t]
	return out


## The Run's values per hazard key for the injections: soldiers lost (barricades, turrets) or the share of
## the army at contact (blades).
static func _injections(run: DRun) -> Dictionary:
	var out := {}
	for key: String in run.haz:
		var r: Dictionary = run.haz[key]
		if str(r["kind"]) in ["rotor", "sweeper"]:
			out[key] = float(r["lost"]) / float(r["army"]) if float(r["army"]) > 0.0 else 0.0
		else:
			out[key] = float(r["lost"])
	return out


## Every barricade and blade the Run met, crossed once more by LevelSim's band model from the Run's state
## at contact (army, armour, barricade hp, army centre x, hazard clock), the hero running on along `path` at
## RUN_SPEED and the army centre following it at ARMY_FOLLOW: what the model says that crossing costs at the
## Run's own timing (record "model"). The items come from `lv` (LevelGen's, unmutated), matched by `x`'s keys.
static func _model_losses(run: DRun, lv: LevelSim.Level, x: Ctx, hero: String, prof: Dictionary,
		path: PackedFloat32Array) -> void:
	for key: String in run.haz:
		var r: Dictionary = run.haz[key]
		var i := x.keys.find(key)
		if i < 0 or str(r["kind"]) == "turret" or float(r["army"]) < 0.5:
			continue
		if bool(r["armor"]):
			r["model"] = 0.0
			continue
		var one := LevelSim.level_from_items([lv.items[i]], lv.level, lv.d[i] + 60.0)
		var s := LevelSim.start_state(one, hero, 0, {"profile": prof})
		s.army = float(r["army"])
		s.weapons = []
		if lv.kind[i] == LevelSim.K.BARRICADE:
			s.hp[0] = float(r["hp"])
			s.alive[0] = 1 if float(r["hp"]) > 0.001 else 0
		s.d = lv.d[i] + Balance.HERO_GAP
		s.hz_t = float(r["hz_t"])
		s.t = float(r["t"])
		s.hx = float(r["hx"])
		s.ax = float(r["ax"])
		var end := lv.d[i] + Balance.HERO_GAP + 2.0 * Balance.blob_radius(s.army) * Balance.BLOB_STRETCH + 0.5
		var lost0 := s.hazard_deaths
		while s.d < end and s.army >= 0.5:
			s.d_prev = s.d
			s.d += Balance.RUN_SPEED * LevelSim.DT
			s.t += LevelSim.DT
			s.hz_t += LevelSim.DT
			s.hx = LevelSim.path_x(path, s.d)
			s.ax += (s.hx - s.ax) * (1.0 - exp(-LevelSim.ARMY_FOLLOW * LevelSim.DT))
			LevelSim._hazards(one, s)
		r["model"] = s.hazard_deaths - lost0


## The machines' kills in a by-source book of the Run: the machine ids, burn and chain (statuses the
## machines set; LevelSim's cannon row carries its burn).
static func _machine_share(src: Dictionary) -> float:
	var n := 0.0
	for key: String in src:
		if ArsenalData.MACHINES.has(key) or key == "burn" or key == "chain":
			n += float(src[key])
	return n


static func _run_machine_kills(run: DRun) -> float:
	return _machine_share(run.by_src)


## LevelSim's gate rows from its trace: [row -> "<op><int value>" or "gap", soldiers the gates gave].
static func _gate_info(s: LevelSim.State) -> Array:
	var rows := {}
	var gain := 0.0
	var re := RegEx.create_from_string("row (-?\\d+): (\\S+)(?:\\s+(-?\\d+) -> (-?\\d+))?")
	for line in s.trace:
		var m := re.search(line)
		if m == null:
			continue
		rows[int(m.get_string(1))] = m.get_string(2)
		if m.get_string(3) != "":
			gain += float(int(m.get_string(4)) - int(m.get_string(3)))
	return [rows, gain]


## LevelSim.best_path (the same candidates, horizon 22, re-plans every PLAN_STEP) from a state whose crates
## already hold `crates` (Vector2(d, x) -> content, as the Run drew them): the planner reading the crate
## badges. With no crates it is best_path's path exactly (checked once). Returns the path.
static func _plan_knowing(lv: LevelSim.Level, hero: String, prof: Dictionary, cands: int,
		crates: Dictionary) -> PackedFloat32Array:
	var s := LevelSim.start_state(lv, hero, Balance.START_ARMY, {"profile": prof})
	for key: Vector2 in crates:
		var ci := KP._crate_index(lv, key)
		if ci >= 0:
			s.content[ci] = str(crates[key])
	var cs := LevelSim.candidates(cands)
	var path := PackedFloat32Array([0.0, 0.0])
	var guard := 0
	while s.mode != LevelSim.Mode.WON and s.mode != LevelSim.Mode.LOST and s.d < lv.length + 50.0 and guard < 2000:
		guard += 1
		var pick := LevelSim.plan(lv, s, cs, 22.0, LevelSim.DT_COARSE, s.hx, 0.05, PackedFloat32Array(LevelSim.PAIRS))
		var seg := LevelSim.hold_path(s.d, s.hx, float(pick["x"]))
		path.append_array(seg)
		LevelSim.advance(lv, s, seg, s.d + LevelSim.PLAN_STEP, LevelSim.DT, 30.0)
	return path


## Gate rows the Run's hero crossed more than LevelSim.PLAN_GATE_MARGIN off the planned path's x (the planner
## keeps that far inside a gate's span, so such a row may land in another gate or a gap).
static func _off_path(run: DRun, path: PackedFloat32Array) -> int:
	var n := 0
	for rw: int in run.rows_x:
		var e: Array = run.rows_x[rw]
		if absf(float(e[1]) - LevelSim.path_x(path, float(e[0]))) > LevelSim.PLAN_GATE_MARGIN:
			n += 1
	return n


## Crates of `b` holding something else than in `a` (both Vector2(d, x) -> content).
static func _stale(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	for key: Vector2 in b:
		if a.has(key) and str(a[key]) != str(b[key]):
			n += 1
	return n


static func _by_kind(recs: Dictionary) -> Dictionary:
	var out := {}
	for key: String in recs:
		var r: Dictionary = recs[key]
		var k := "bar" if str(r["kind"]) == "barricade" else str(r["kind"])
		out[k] = float(out.get(k, 0.0)) + float(r["lost"])
	return out


static func _fort(v: float) -> float:
	return maxf(v, 0.0)


# ------------------------------------------------------------------ the Run

## test_kind_parity.drive with books: `_spf` fixed Run steps a frame, the Effects on game time, the ult by
## the shared auto policy; the contact book of every hazard as the army's front reaches its line (DRun.contact)
## and the first clash {d, t, kills, army, src} into `first`. Returns {ended, ults}.
func _drive(run: DRun, path: PackedFloat32Array, first: Dictionary) -> Dictionary:
	KP.begin(run, path)
	run.effects.set_process(false)
	var haz: Array[Dictionary] = []
	for it: Dictionary in run.items:
		if str(it["kind"]) in ["barricade", "blade", "turret"]:
			haz.append(it)
	haz.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	var hk := 0
	var steps := 0
	var ults := 0
	var tree := get_tree()
	while true:
		for k in _spf:
			if KP.over(run) or run.t > MAX_T:
				return {"ended": KP.over(run), "ults": ults}
			if _step(run, path, steps % 2 == 0):
				ults += 1
			run.effects._process(DT)
			steps += 1
			var front := run.d - Balance.HERO_GAP
			while hk < haz.size() and float(haz[hk]["d"]) <= front:
				run.contact(haz[hk])
				hk += 1
			if first.is_empty() and run.state == Run.State.CLASH:
				first.merge({"d": run.d, "t": run.t, "kills": float(run.stats["kills_total"]), "army": float(run.army),
						"src": run.by_src.duplicate()})
		await tree.process_frame
	return {}


## test_kind_parity.step (steer a spring-lag ahead on the path, the ult, Run._process(DT)) with the ult's first
## rule read from the Run: a ready ult fires in a clash or the siege (RunKindView.in_fight, as LevelSim's own
## SimKindView answers), else when the shared policy on the bot's snapshot says so. True when it fired.
func _step(run: DRun, path: PackedFloat32Array, ult_check: bool) -> bool:
	if _ult_snapshot:
		return KP.step(run, path, _bot, DT, ult_check)
	run.steer_to(LevelSim.path_x(path, run.d + Balance.RUN_SPEED * Balance.STEER_HALFLIFE / log(2.0)))
	var fired := false
	if ult_check and run.ult_ready():
		var worth := run.kind_view.in_fight()
		if not worth:
			var snap := _bot.snapshot(run, false)
			worth = LevelSim.ult_worth(snap[0], snap[1])
		fired = worth and run.use_ult()
	run._process(DT)
	return fired


## The ults LevelSim fired (its trace's "ult at" lines).
static func _ults(s: LevelSim.State) -> int:
	var n := 0
	for line in s.trace:
		if line.contains("ult at"):
			n += 1
	return n


# ------------------------------------------------------------------ LevelSim (a copy of its step with the toggles)

## LevelSim.simulate (start_state, the path's first x, advance to length + 50 at LevelSim.DT for at most
## MAX_T s) through step() below; `crates` (Vector2(d, x) -> content, KP.run_crates) fixes those crates'
## contents. Traced (the gate rows); tracing only appends text.
static func _sim(lv: LevelSim.Level, hero: String, path: PackedFloat32Array, prof: Dictionary, crates: Dictionary,
		x: Ctx) -> LevelSim.State:
	var s := LevelSim.start_state(lv, hero, Balance.START_ARMY, {"profile": prof, "trace": true})
	for key: Vector2 in crates:
		var ci := KP._crate_index(lv, key)
		if ci >= 0:
			s.content[ci] = str(crates[key])
	s.hx = LevelSim.path_x(path, 0.0)
	s.ax = s.hx
	x.setup(lv, prof)
	x.scan(s)
	var d_end := lv.length + 50.0
	while s.mode != LevelSim.Mode.WON and s.mode != LevelSim.Mode.LOST and s.d < d_end and s.t < MAX_T:
		step(lv, s, path, LevelSim.DT, x)
		x.after(s)
	return s


## LevelSim.step in its order, with the kills booked by source and _machines / _hazards / _turrets taken from
## this file (the toggles). With every toggle off it is LevelSim.step float for float (SELF_CHECK).
static func step(lv: LevelSim.Level, s: LevelSim.State, path: PackedFloat32Array, dt: float, x: Ctx) -> void:
	s.t += dt
	s.hz_t += dt * LevelSim.hazard_slow(s)
	var def: Dictionary = Balance.HEROES[s.hero]
	var k0 := s.kills
	if s.auto_ult and s.ult >= float((def["ult"] as Dictionary)["charge"]) - 0.001 and LevelSim.ult_ready(s) \
			and LevelSim.ult_worth(lv, s):
		LevelSim.use_ult(lv, s)
	x.add_src("ult", s.kills - k0)
	s.d_prev = s.d
	if s.mode == LevelSim.Mode.RUN:
		var nd := s.d + Balance.RUN_SPEED * dt
		var hx_n := LevelSim.path_x(path, nd)
		if x.lag:
			hx_n = Ctx.steer(s.hx, path, s.d, dt)
		nd = LevelSim._blocks(lv, s, nd, hx_n)
		s.hx = hx_n if x.lag else LevelSim.path_x(path, nd)
		if x.gates:
			x.gate_override(lv, s, nd)
		LevelSim._picks(lv, s, nd)
		s.d = nd
		LevelSim._crate_contact(lv, s)
	s.ax += (s.hx - s.ax) * (1.0 - exp(-LevelSim.ARMY_FOLLOW * dt))
	if lv.ult_ready_at >= 0.0 and not s.script_done and s.d >= lv.ult_ready_at:
		s.script_done = true
		s.ult = float((def["ult"] as Dictionary)["charge"])
	k0 = s.kills
	if x.amp:
		_hero_attack(lv, s, def, dt)
	else:
		LevelSim._hero_attack(lv, s, def, dt)
	x.add_src("hero", s.kills - k0)
	_machines(lv, s, dt, x)
	if not s.kv_live.is_empty():
		LevelSim._statuses(lv, s, dt)
	k0 = s.kills
	LevelSim._volleys(lv, s, dt)
	x.add_src("volley", s.kills - k0)
	k0 = s.kills
	LevelSim._ult_step(lv, s, def, dt)
	x.add_src("ult", s.kills - k0)
	if s.champs.active():
		s.champs.step(LevelSim._view(lv, s), dt)
	x.contact_book(lv, s)
	_hazards(lv, s, x)
	_turrets(lv, s, dt, x)
	k0 = s.kills
	match s.mode:
		LevelSim.Mode.CLASH:
			var c0 := s.clash_deaths
			var foe := x.keys[s.foe] if s.foe >= 0 else ""
			LevelSim._clash(lv, s, dt)
			x.clash += s.clash_deaths - c0
			if foe != "":
				x.clash_by[foe] = float(x.clash_by.get(foe, 0.0)) + s.clash_deaths - c0
		LevelSim.Mode.SIEGE:
			LevelSim._siege(lv, s, dt)
	x.add_src("clash", s.kills - k0)
	s.armor = maxf(s.armor - dt, 0.0)
	s.peak = maxf(s.peak, s.army)


## LevelSim._hero_attack with the Prism amp where the Run gives it (+amp): Run._hero_attack multiplies a shot
## by 1 + amp only when the Prism crosses it (Weapons.prism_crosses: the target 2.5 u or more ahead in the
## hero's lane) and never on a gate; the squad splash rides inside the amp. Used only with +amp (LevelSim's
## own is called otherwise, so the self-check never depends on this copy).
static func _hero_attack(lv: LevelSim.Level, s: LevelSim.State, def: Dictionary, dt: float) -> void:
	s.atk_cd -= dt
	if s.atk_cd > 0.0:
		return
	var corridor := float(def.get("corridor", Balance.CORRIDOR))
	var base := int(def.get("targets", 1)) + s.p_multi
	var shots := base
	if HeroKinds.forks(s.aspect, s.casts + 1):
		shots += 1
	var targets := LevelSim._targets(lv, s, s.hx, corridor, float(def["range"]), shots, true)
	for j in range(targets.size() - 1, 0, -1):
		var a := lv.items[targets[0]]
		var b := lv.items[targets[j]]
		if lv.kind[targets[j]] == LevelSim.K.CRATE and a.has("pair") and b.has("pair") \
				and int(a["pair"]) == int(b["pair"]):
			targets.remove_at(j)
	if targets.is_empty():
		s.atk_cd = 0.0
		return
	s.atk_cd += 1.0 / LevelSim.hero_rate(s)
	s.atk_cd = maxf(s.atk_cd, 0.02)
	s.casts += 1
	var raw := float(int(Balance.HEROES[s.hero]["damage"]) + s.p_dmg) * s.hero_dmg
	var amp := 1.0 + LevelSim.prism_amp(s)
	for k in shots:
		if k >= base and k >= targets.size():
			continue
		var i: int = targets[mini(k, targets.size() - 1)]
		if s.alive[i] == 0:
			continue
		var crosses := lv.d[i] >= s.d + 2.5
		if lv.kind[i] == LevelSim.K.GATE:
			if bool(def.get("reveal_row", false)):
				for g in lv.rows.get(int(lv.items[i].get("row", i)), PackedInt32Array([i])):
					s.rev[g] = 1
			var gk := float(def.get("charge_mult", 1.0)) if str(LevelSim.gate_view(lv, s, i)[0]) == "charge" else 1.0
			LevelSim._hit_gate(lv, s, i, raw * gk)
		elif lv.kind[i] == LevelSim.K.SQUAD:
			s.hit_t[i] = s.t
			var n := (raw + float(def["splash"])) * (amp if crosses else 1.0)
			if s.kv.is_empty():
				LevelSim._hurt(lv, s, i, n)
			else:
				LevelSim._hurt_vs(lv, s, i, n)
		else:
			LevelSim._hurt(lv, s, i, raw * (amp if crosses else 1.0))


## LevelSim._machines, the kills booked per machine; +warm: a machine waits for its Run warm-up; +mach: its
## squad damage x mach_k.
static func _machines(lv: LevelSim.Level, s: LevelSim.State, dt: float, x: Ctx) -> void:
	if x.warm:
		x.scan(s)
	var amp := LevelSim.prism_amp(s)
	for w: Array in s.weapons:
		w[2] = float(w[2]) + dt
		if float(w[2]) < LevelSim.MACHINE_TICK:
			continue
		if x.warm and s.t < float(x.ready_at.get(str(w[0]), 0.0)):
			w[2] = LevelSim.MACHINE_TICK
			continue
		var row := LevelSim.machine_row(s, w)
		var lane := bool(row["lane"])
		var lateral := Balance.CORRIDOR if lane else Balance.WEAPON_LATERAL
		if float(row["place"]) > 0.0:
			lateral = float(row["radius"])
		var tg := LevelSim._targets(lv, s, s.hx, lateral, float(row["range"]) + float(row["radius"]), 1, false, false)
		if tg.is_empty():
			w[2] = LevelSim.MACHINE_TICK
			continue
		var tick := float(w[2])
		w[2] = 0.0
		var i: int = tg[0]
		if float(row["place"]) > 0.0 and lv.d[i] < s.d + float(row["place"]) * 0.5:
			continue
		var over := 0.0
		for k in int(w[3]) if w.size() > 3 else 0:
			over += ArsenalData.overflow_bonus(k + 1)
		var mult := (1.0 + over) * (1.0 + (amp if lane and str(w[0]) != "prism" else 0.0))
		var k0 := s.kills
		if lv.kind[i] == LevelSim.K.SQUAD:
			var n := (float(row["crowd"]) + float(row.get("burn", 0.0))) * tick * mult
			if x.mach:
				n *= x.mach_k
			if s.kv.is_empty():
				LevelSim._hurt(lv, s, i, n)
			else:
				LevelSim._hurt_vs(lv, s, i, n)
		else:
			LevelSim._hurt(lv, s, i, float(row["struct"]) * tick * mult)
		x.add_src("m:" + str(w[0]), s.kills - k0)


## LevelSim._hazards with the books; an injected kind costs its Run value once, at the first band of the army
## crossing the hazard's line, whatever LevelSim's own state of it (alive, armour, Scrape Guard).
static func _hazards(lv: LevelSim.Level, s: LevelSim.State, x: Ctx) -> void:
	var d0 := s.d_prev
	var d1 := s.d
	if d1 <= d0 + 0.00001:
		return
	var r := Balance.blob_radius(s.army)
	var rz := r * Balance.BLOB_STRETCH
	var gap := Balance.HERO_GAP
	while s.hz < lv.haz.size() and lv.d[lv.haz[s.hz]] + gap + 2.0 * rz < d0 - 0.0001:
		s.hz += 1
	var k := s.hz
	while k < lv.haz.size():
		var i := lv.haz[k]
		k += 1
		var hd := lv.d[i]
		if hd + gap > d1:
			break
		var inj := x.inject_of(lv, i)
		if inj < 0.0:
			if s.alive[i] == 0 or s.army < 0.5 or s.armor > 0.0:
				continue
		elif x.done.has(i) or s.army < 0.5:
			continue
		var v0 := maxf((d0 - hd - gap) / maxf(rz, 0.001) - 1.0, -1.0)
		var v1 := minf((d1 - hd - gap) / maxf(rz, 0.001) - 1.0, 1.0)
		if v1 <= v0:
			continue
		var mass := LevelSim._disk_cdf(v1) - LevelSim._disk_cdf(v0)
		if mass <= 0.0:
			continue
		var lost := 0.0
		if inj >= 0.0:
			x.done[i] = true
			if lv.kind[i] == LevelSim.K.BARRICADE:
				lost = minf(inj, s.army)
				s.hp[i] = maxf(s.hp[i] - lost, 0.0)
				if s.hp[i] <= 0.001:
					s.alive[i] = 0
			else:
				lost = minf(inj * s.army, s.army)
		else:
			var vm := (v0 + v1) * 0.5
			var half_w := r * sqrt(maxf(1.0 - vm * vm, 0.0))
			if lv.kind[i] == LevelSim.K.BARRICADE:
				var half := lv.hw[i] * Balance.HAZARD_SHRINK + Balance.UNIT_R
				var share := LevelSim._chord_share(s.ax, half_w, lv.x[i] - half, lv.x[i] + half)
				lost = minf(mass * share * s.army, s.hp[i])
				s.hp[i] -= lost
				if s.hp[i] <= 0.001:
					s.alive[i] = 0
			else:
				lost = mass * LevelSim._blade_band(lv, s, i, half_w) * s.army
			if lost > 0.0 and s.scrape_guard > 0.0:
				var left := s.guard[i] if s.guard[i] >= 0.0 else s.scrape_guard
				var spare := minf(left, lost)
				s.guard[i] = left - spare
				lost -= spare
				if lv.kind[i] == LevelSim.K.BARRICADE:
					s.hp[i] += spare
					s.alive[i] = 1 if s.hp[i] > 0.001 else 0
			if lost > 0.0 and not s.wards.is_empty():
				lost -= LevelSim.ward_spend(s, &"contact" if lv.kind[i] == LevelSim.K.BARRICADE else &"blade", lost)
			if lost > 0.0 and s.champs.active():
				lost = LevelSim._champ_hazard(lv, s, i, lost)
		if lost > 0.0:
			s.army = maxf(s.army - lost, 0.0)
			s.hazard_deaths += lost
			LevelSim._log(s, "%s -%d" % [str(lv.items[i]["kind"]), int(round(lost))])
			x.book(lv, i, lost)


## LevelSim._turrets with the books; an injected turret costs its Run value once, the first step the army
## is in its range.
static func _turrets(lv: LevelSim.Level, s: LevelSim.State, dt: float, x: Ctx) -> void:
	if lv.tur.is_empty() or s.army < 0.5 or (s.armor > 0.0 and not x.tur):
		return
	var c := LevelSim.army_center_d(s)
	var r := Balance.blob_radius(s.army)
	for i in lv.tur:
		var inj := x.inject_of(lv, i)
		if inj < 0.0 and s.alive[i] == 0:
			continue
		if inj >= 0.0 and x.done.has(i):
			continue
		var it := lv.items[i]
		var reach := float(it.get("range", 7.0))
		var dz := lv.d[i] - c
		if absf(dz) > reach + r:
			continue
		if Vector2(lv.x[i] - s.hx, dz).length() - r > reach:
			continue
		var lost := 0.0
		if inj >= 0.0:
			x.done[i] = true
			lost = minf(inj, s.army)
		else:
			lost = minf(float(it.get("rate", 2.0)) * dt * LevelSim.hazard_slow(s), s.army)
			if not s.wards.is_empty():
				lost -= LevelSim.ward_spend(s, &"turret", lost)
			if s.champs.active():
				lost = ChampionKinds.absorb_turret(LevelSim._view(lv, s), s.champs.members, i, lost)
				lost *= ChampionKinds.hazard_loss_mult(s.champs.members)
				LevelSim._fed(s, lost)
		s.army -= lost
		s.hazard_deaths += lost
		x.book(lv, i, lost)


# ------------------------------------------------------------------ report

func _print_row(r: Dictionary) -> void:
	var flags: PackedStringArray = PackedStringArray()
	if int(r["run_won"]) != int(r["own_won"]):
		flags.append("FLIP")
	if _drifts(r):
		var off := (float(r["run_fort"]) - float(r["own_fort"])) / maxf(float(r["own_fort"]), FLAG_FLOOR)
		flags.append("DRIFT %+.0f%%" % (100.0 * off))
	if int(r["self_ok"]) == 0:
		flags.append("SELF_CHECK")
	var chain: PackedStringArray = PackedStringArray()
	for t in CHAIN:
		chain.append("%6.0f" % float(r["c_%s_fort" % t]))
	print("  %-4d %-5s %-2s %-2d | %s/%s   | %6.0f %6.0f %6.0f | %s %6.2f | %5.0f %5.0f %5.0f %5.0f | %s" % [
			int(r["level"]), str(r["hero"]), str(r["path"]), int(r["seed"]), "W" if int(r["run_won"]) == 1 else "L",
			"W" if int(r["own_won"]) == 1 else "L", float(r["run_fort"]), float(r["own_fort"]), float(r["rc_fort"]),
			" ".join(chain), float(r["mach_k"]), float(r["run_bar"]) - float(r["own_bar"]),
			float(r["run_rotor"]) - float(r["own_rotor"]), float(r["run_sweeper"]) - float(r["own_sweeper"]),
			float(r["run_turret"]) - float(r["own_turret"]), " ".join(flags)])


## The fortress armies differ by more than FLAG_SHARE of LevelSim's (at least FLAG_FLOOR).
static func _drifts(r: Dictionary) -> bool:
	return absf(float(r["run_fort"]) - float(r["own_fort"])) > FLAG_SHARE * maxf(float(r["own_fort"]), FLAG_FLOOR)


## The headline numbers over `rows`: the p1 decomposition (seed 0), flips and drifting cases per world, the
## p2 (chooser) comparison and the Run's noise over the seeds.
func _summary(rows: Array) -> void:
	var p1: Array = rows.filter(func(r: Dictionary) -> bool: return int(r["seed"]) == 0 and str(r["path"]) == "p1")
	var p2: Array = rows.filter(func(r: Dictionary) -> bool: return int(r["seed"]) == 0 and str(r["path"]) == "p2")
	if p1.is_empty():
		return
	var sum := _sums(p1)
	print("DRIFT_SUMMARY p1, %d cases: army at the fortress Run %.0f, LevelSim %.0f (%+.1f%%)," % [p1.size(),
			float(sum["run_fort"]), float(sum["own_fort"]), _pct(float(sum["run_fort"]), float(sum["own_fort"]))] +
			" LevelSim with the Run's crates %.0f" % float(sum["rc_fort"]))
	_shares("p1", sum, true)
	print("DRIFT_HAZARDS p1 losses Run / LevelSim / LevelSim with the Run's crates: barricades %s, rotors %s," % [
			_trio(sum, "bar"), _trio(sum, "rotor")] + " sweepers %s, turrets %s; clashes %s" % [_trio(sum, "sweeper"),
			_trio(sum, "turret"), _trio(sum, "clash")])
	print("DRIFT_KILLS p1 Run / LevelSim / with the Run's crates: machine kills %s; soldiers from gates %s" % [
			_trio(sum, "mach"), _trio(sum, "gate_gain")])
	print("DRIFT_FIRST_CLASH p1 kills before it Run / LevelSim %.0f / %.0f (hero %.0f / %.0f," % [
			float(sum["run_first_k"]), float(sum["own_first_k"]), float(sum["run_first_hero"]),
			float(sum["own_first_hero"])] + " machines %.0f / %.0f, ult %.0f / %.0f)" % [float(sum["run_first_mach"]),
			float(sum["own_first_mach"]), float(sum["run_first_ult"]), float(sum["own_first_ult"])])
	print("DRIFT_CLASHES p1 squads only the Run fought %d (%.0f soldiers lost), only LevelSim %d (%.0f);" % [
			int(sum["clash_run_only_n"]), float(sum["clash_run_only"]), int(sum["clash_own_only_n"]),
			float(sum["clash_own_only"])] + " shared clashes cost Run / LevelSim %.0f / %.0f" % [
			float(sum["clash_both_run"]), float(sum["clash_both_own"])])
	print("DRIFT_INPUTS p1 crates drawn differently %d of %d; gate rows passed differently %d of %d, %d crossed" % [
			int(sum["crates_differ"]), int(sum["crates"]), int(sum["gates_differ"]), int(sum["gates"]),
			int(sum["gates_offpath"])] + " more than PLAN_GATE_MARGIN off the planned x")
	_flags("p1", p1, p1)
	if not p2.is_empty():
		# The chooser: the Run on p2 against the planner's own estimate (p1, LevelSim on its draws).
		var sum2 := _sums(p2)
		var est := 0.0
		for r: Dictionary in p1:
			for q: Dictionary in p2:
				if int(q["level"]) == int(r["level"]) and str(q["hero"]) == str(r["hero"]):
					est += float(r["own_fort"])
		print("DRIFT_CHOICE p2 (planned on the Run's crates), %d cases: army at the fortress Run %.0f" % [p2.size(),
				float(sum2["run_fort"])] + " vs the planner's estimate (p1 LevelSim) %.0f (%+.1f%%);" % [est,
				_pct(float(sum2["run_fort"]), est)] + " LevelSim on p2 with the Run's crates %.0f;" % float(
				sum2["rc_fort"]) + " p2 crates drawn otherwise than planned %d" % int(sum2["stale"]))
		_shares("p2", sum2, false)
		_flags("p2", p2, p1)
	# The attempts (--seeds): the spread of the Run's fortress army over the crate draws of a case (p1), and
	# their mean against LevelSim's one draw.
	var groups := {}
	for r: Dictionary in rows:
		if str(r["path"]) != "p1":
			continue
		var key := "%d|%s" % [int(r["level"]), str(r["hero"])]
		var g: Array = groups.get(key, [])
		g.append([float(r["run_fort"]), float(r["own_fort"]), int(r["run_won"])])
		groups[key] = g
	var spread := 0.0
	var n := 0
	var sums := [0.0, 0.0, 0, 0]
	for key: String in groups:
		var g2: Array = groups[key]
		if g2.size() < 2:
			continue
		var lo := INF
		var hi := -INF
		var mean := 0.0
		for v: Array in g2:
			mean += float(v[0])
			lo = minf(lo, float(v[0]))
			hi = maxf(hi, float(v[0]))
			sums[2] = int(sums[2]) + int(v[2])
			sums[3] = int(sums[3]) + 1
		mean /= g2.size()
		spread += (hi - lo) / maxf(mean, FLAG_FLOOR)
		sums[0] = float(sums[0]) + mean
		sums[1] = float(sums[1]) + float((g2[0] as Array)[1])
		n += 1
	if n > 0:
		print("DRIFT_ATTEMPTS the Run on p1 over its attempts (crate draws), %d cases: mean spread of the" % n +
				" fortress army (max - min) / mean %.1f%%;" % (100.0 * spread / n) +
				" mean army %.0f vs LevelSim's one draw %.0f (%+.1f%%); won %d of %d" % [float(sums[0]), float(sums[1]),
				_pct(float(sums[0]), float(sums[1])), int(sums[2]), int(sums[3])])


## Column sums over `rows` (every numeric column the summary reads).
static func _sums(rows: Array) -> Dictionary:
	var sum := {}
	for col: String in COLS:
		if col in ["level", "world", "boss", "hero", "path", "seed", "deck", "secs"]:
			continue
		sum[col] = 0.0
		for r: Dictionary in rows:
			sum[col] = float(sum[col]) + float(r.get(col, 0.0))
	sum["run"] = sum["run_fort"]
	sum["own"] = sum["own_fort"]
	for name: String in _plan():
		sum[name] = sum[name + "_fort"]
	return sum


## "Run / LevelSim / LevelSim with the Run's crates" of a booked quantity.
static func _trio(sum: Dictionary, key: String) -> String:
	return "%.0f / %.0f / %.0f" % [float(sum["run_" + key]), float(sum["own_" + key]), float(sum["rc_" + key])]


static func _pct(a: float, b: float) -> float:
	return 100.0 * (a - b) / maxf(b, 1.0)


## The sequential shares (from LevelSim own when `crates`, else from rc) and the single ones.
static func _shares(tag: String, sum: Dictionary, crates: bool) -> void:
	var top := "own" if crates else "rc"
	var gap := float(sum[top]) - float(sum["run"])
	print("DRIFT_GAP %s %s - Run = %+.0f soldiers" % [tag, "LevelSim" if crates else "LevelSim with the Run's crates",
			gap])
	var steps: Array = [["crates (2a)", "own", "rc"]] if crates else []
	var prev := "rc"
	for st: Array in SHARES:
		steps.append([st[0], prev, "c_" + str(st[1])])
		prev = "c_" + str(st[1])
	steps.append(["residual (clashes, timing)", prev, "run"])
	for st: Array in steps:
		var part := float(sum[st[1]]) - float(sum[st[2]])
		print("DRIFT_SHARE %s %-28s %+8.0f soldiers = %6.1f%% of the gap (sequential)" % [tag, str(st[0]), part,
				100.0 * part / gap if absf(gap) > 0.5 else 0.0])
	for st: Array in SHARES:
		var name := "c_" + CHAIN[0] if str(st[1]) == CHAIN[0] else "s_" + str(st[1])
		print("DRIFT_SINGLE %s %-28s alone on top of the Run's crates: %+8.0f soldiers" % [tag, str(st[0]),
				float(sum["rc"]) - float(sum[name])])


## Outcome flips and drifting cases of `rows` against the planner's estimate in `ref` (p1 rows, LevelSim own),
## overall and per world.
func _flags(tag: String, rows: Array, ref: Array) -> void:
	var est := {}
	for r: Dictionary in ref:
		est["%d|%s" % [int(r["level"]), str(r["hero"])]] = r
	var worlds := {}
	var flips := [0, 0]
	var drift := 0
	var listed: PackedStringArray = PackedStringArray()
	for r: Dictionary in rows:
		var e0: Dictionary = est.get("%d|%s" % [int(r["level"]), str(r["hero"])], r)
		var cmp := {"run_fort": r["run_fort"], "own_fort": e0["own_fort"]}
		var w := int(r["world"])
		var e: Array = worlds.get(w, [0, 0, 0, 0.0, 0.0])
		e[0] = int(e[0]) + 1
		var flip := int(r["run_won"]) != int(e0["own_won"])
		if flip:
			e[1] = int(e[1]) + 1
			flips[0 if int(r["run_won"]) == 0 else 1] = int(flips[0 if int(r["run_won"]) == 0 else 1]) + 1
		if _drifts(cmp):
			e[2] = int(e[2]) + 1
			drift += 1
		if flip or _drifts(cmp):
			listed.append("L%d %s %.0f/%.0f%s" % [int(r["level"]), str(r["hero"]), float(r["run_fort"]),
					float(e0["own_fort"]), (" " + ("W" if int(r["run_won"]) == 1 else "L") + "/" +
					("W" if int(e0["own_won"]) == 1 else "L")) if flip else ""])
		e[3] = float(e[3]) + float(r["run_fort"])
		e[4] = float(e[4]) + float(e0["own_fort"])
		worlds[w] = e
	print("DRIFT_FLAGS %s outcome flips %d (Run loses / LevelSim wins %d, the reverse %d);" % [tag, flips[0] + flips[1],
			flips[0], flips[1]] + " fortress army off by > %d%% %d of %d cases" % [int(FLAG_SHARE * 100.0), drift,
			rows.size()])
	var keys := worlds.keys()
	keys.sort()
	for w: int in keys:
		var e2: Array = worlds[w]
		print("DRIFT_WORLD %s %d: %d cases, flips %d, off by > %d%% %d," % [tag, w, int(e2[0]), int(e2[1]),
				int(FLAG_SHARE * 100.0), int(e2[2])] + " fortress army Run / LevelSim %.0f / %.0f (%+.1f%%)" % [
				float(e2[3]), float(e2[4]), _pct(float(e2[3]), float(e2[4]))])
	print("DRIFT_LIST %s (Run / LevelSim fortress army; W/L on a flip): %s" % [tag, ", ".join(listed)])


func _hazard_rows(row: Dictionary, run_h: Dictionary, own_h: Dictionary, rc_h: Dictionary) -> void:
	var keys := {}
	for src: Dictionary in [run_h, own_h, rc_h]:
		for key: String in src:
			keys[key] = src[key]
	var none := DRun.new_rec({"kind": "x", "d": 0.0})
	for key: String in keys:
		var base: Dictionary = keys[key]
		var a: Dictionary = run_h.get(key, none)
		var b: Dictionary = own_h.get(key, none)
		var c: Dictionary = rc_h.get(key, none)
		_haz_rows.append({"level": row["level"], "hero": row["hero"], "path": row["path"], "seed": row["seed"],
				"kind": base["kind"], "d": base["d"], "x": base["x"], "run_lost": a["lost"], "run_model": a["model"],
				"run_army": a["army"], "run_armor": 1 if a["armor"] else 0, "run_hp": a["hp"], "run_w": a["w"],
				"run_t": a["t"], "run_ax": a["ax"], "own_lost": b["lost"], "own_army": b["army"],
				"own_armor": 1 if b["armor"] else 0, "own_hp": b["hp"], "own_t": b["t"], "own_ax": b["ax"],
				"rc_lost": c["lost"], "rc_army": c["army"], "rc_armor": 1 if c["armor"] else 0, "rc_hp": c["hp"],
				"rc_t": c["t"], "rc_ax": c["ax"]})


func _write(dir: String, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for pair: Array in [[name + ".csv", COLS, _rows], [name + "_haz.csv", HAZ_COLS, _haz_rows]]:
		var lines: PackedStringArray = PackedStringArray([",".join(pair[1])])
		for r: Dictionary in pair[2]:
			var vals: PackedStringArray = PackedStringArray()
			for col: String in pair[1]:
				var v: Variant = r.get(col, "")
				vals.append(("%.3f" % v) if v is float else str(v))
			lines.append(",".join(vals))
		var path := dir.path_join(str(pair[0]))
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_warning("drift_report: cannot write " + path)
			continue
		f.store_string("\n".join(lines) + "\n")
		f.close()
		print("DRIFT_REPORT written ", path)


## Reads every drift_*.csv of `dir` (not the _haz ones) into _rows.
func _merge(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		push_warning("drift_report: cannot open " + dir)
		return
	for fn in da.get_files():
		if not fn.begins_with("drift_") or not fn.ends_with(".csv") or fn.ends_with("_haz.csv"):
			continue
		var lines := FileAccess.get_file_as_string(dir.path_join(fn)).split("\n", false)
		if lines.is_empty():
			continue
		var head := lines[0].split(",")
		for k in range(1, lines.size()):
			var vals := lines[k].split(",")
			var r := {}
			for c in mini(head.size(), vals.size()):
				r[head[c]] = vals[c]
			_rows.append(r)
