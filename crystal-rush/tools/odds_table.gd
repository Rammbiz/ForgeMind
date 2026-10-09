extends SceneTree
## The Portal / Hero Chest odds the (i) sheets disclose (heroes_design.md §7.2, §7.5; WS-A), printed
## from the rule classes themselves (Summon, HeroChest) so the sheet, the roller and this table can
## never disagree.
##
##   godot --headless --path . --script res://tools/odds_table.gd [-- --portal] [--chest] [--check] [--diff] [--n=1000000]
##   --portal  consolidated gem odds, pity, best of a ×10, per-hero odds at the §7.2 stages A-D
##   --chest   card odds, best-card tables, per-champion odds (complete gems, a chest Focus)
##   --check   Monte Carlo per character through Summon.roll_gem / pick_hero and HeroChest.roll_gems /
##             pick_champion (--n rolls per pool state, default 1 000 000): exit 1 when any |z| > 4,
##             a pity gap exceeds its guarantee (Amethyst+ 10, Topaz+ 30, chest Topaz 15) or the
##             Focus share drifts from exactly 60%
##   --diff    exact tables vs the disclosed §7.2 / §7.5 rows (exit 1 on a difference > 0.005 pp), including
##             every champion's card odds; prints the odds changelog rows (ODDS_CHANGELOG, §9.3 «Змінено у»)
##             and fails when a chest gem's champion pool differs from LAUNCH_POOLS without a changelog row
##             whose `pool_after` equals the current pool, or when such a current row's `now` is not exact
## No flag = --portal --chest.

const DISCLOSED_GEMS := {"C": 52.09, "R": 26.52, "E": 14.35, "L": 5.63, "M": 1.41}
const DISCLOSED_X10 := {"welcome": {"L": 78.46, "M": 21.54}, "fresh": {"E": 59.87, "L": 30.56, "M": 9.56},
		"typical": {"E": 43.56, "L": 42.99, "M": 13.45}}
const DISCLOSED_CHEST := {"hero": {"C": 38.44, "R": 40.77, "E": 16.83, "L": 3.96}, "grand": {"E": 78.58, "L": 21.42}}
## §7.5 per-champion odds of one free chest card, every gem complete: champions per gem, each champion's % without a
## Focus, and with a chest Focus on that gem (the Focus champion / each other one).
const DISCLOSED_CHAMP := {
	"C": {"pool": 3, "each": 20.67, "focus": 37.20, "other": 12.40},
	"R": {"pool": 3, "each": 9.00, "focus": 16.20, "other": 5.40},
	"E": {"pool": 4, "each": 2.25, "focus": 5.40, "other": 1.20},
	"L": {"pool": 4, "each": 0.50, "focus": 1.20, "other": 0.27},
}
## Champions per chest gem at the launch of the Heroes system: a gem whose pool differs from this baseline must have an
## ODDS_CHANGELOG row recording the current pool (`pool_after`).
const LAUNCH_POOLS := {"C": 3, "R": 3, "E": 3, "L": 3}
## Odds changelog (§9.3: the (i) sheet marks changed rows «Змінено у %s» for one version; `version` is the release string
## the player sees). One row per disclosed number that a pool change moved; `was` is the row it replaces. Rows stay as
## history: only the rows whose `pool_after` equals the current pool are checked against the exact table.
const ODDS_CHANGELOG := [
	{"version": "2.4.0", "pool": "chest L", "pool_after": 4, "why": "C23 Тарас joins the Topaz champions (3 -> 4)", "row": "each", "was": 0.67, "now": 0.50},
	{"version": "2.4.0", "pool": "chest L", "pool_after": 4, "why": "C23 Тарас joins the Topaz champions (3 -> 4)", "row": "other", "was": 0.40, "now": 0.27},
	{"version": "2.4.0", "pool": "chest E", "pool_after": 4, "why": "C24 Снаряд joins the Amethyst champions (3 -> 4)", "row": "each", "was": 3.00, "now": 2.25},
	{"version": "2.4.0", "pool": "chest E", "pool_after": 4, "why": "C24 Снаряд joins the Amethyst champions (3 -> 4)", "row": "other", "was": 1.80, "now": 1.20},
]
const STAGES := {
	"A": {"own": ["bolt", "titan"], "focus": {}, "level": 21},
	"B": {"own": ["titan", "arin", "bolt", "eira", "seer", "iskar", "vesta", "lumen"], "focus": {}, "level": 25},
	"C": {"own": ["titan", "arin", "bolt", "eira", "seer", "iskar", "vesta", "vartan", "lumen", "pava"], "focus": {}, "level": 25},
	"D": {"own": ["titan", "arin", "bolt", "eira", "seer", "iskar", "vesta", "vartan", "lumen", "pava"],
			"focus": {"C": "titan", "R": "bolt", "E": "seer", "L": "vesta", "M": "lumen"}, "level": 25},
}

var _fails := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := 1000000
	for a in args:
		if a.begins_with("--n="):
			n = maxi(1000, int(a.trim_prefix("--n=")))
	var any := false
	for f in ["--portal", "--chest", "--check", "--diff"]:
		any = any or f in args
	if "--portal" in args or not any:
		_portal()
	if "--chest" in args or not any:
		_chest()
	if "--diff" in args:
		_diff()
	if "--check" in args:
		_check(n)
	if "--check" in args or "--diff" in args:
		print("ODDS_TABLE %s (%d failure(s))" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


static func _pct(p: float) -> String:
	return "%.2f%%" % (100.0 * p)


func _stage(name: String) -> Dictionary:
	var s: Dictionary = STAGES[name]
	var acc := EconData.fresh_account()
	(acc["progress"] as Dictionary)["level"] = int(s["level"])
	for id: String in s["own"]:
		if not Roster.owned(acc, id):
			Roster.grant(acc, id, "start", 1)
	for g: String in s["focus"]:
		Summon.set_focus(acc, g, str(s["focus"][g]))
	return acc


func _portal() -> void:
	var cons := Summon.solve_consolidated()
	print("## Portal — consolidated odds (exact, stationary pity chain)")
	print("| Gem | Base | Consolidated | 1 in |")
	print("|---|---|---|---|")
	for g in Ladder.GEMS:
		print("| %s | %s | %s | %.1f |" % [Ladder.GEM_NAME_EN[Ladder.gem_index(g)], _pct(float(PortalData.BASE_ODDS[g])),
				_pct(float(cons[g])), 1.0 / float(cons[g])])
	var lp := float(cons["L"]) + float(cons["M"])
	print("| Topaz or better | | %s | %.2f |" % [_pct(lp), 1.0 / lp])
	print("| Amethyst or better | | %s | %.2f |" % [_pct(lp + float(cons["E"])), 1.0 / (lp + float(cons["E"]))])
	var row := []
	for k in range(1, int(PortalData.PITY_L["hard"]) + 1):
		row.append("%d: %s" % [k, _pct(PortalData.topaz_plus_chance(k - 1))])
	print("Topaz+ chance by summon count since the last Topaz+: " + " · ".join(row.slice(19)))
	print("\n## Best gem in one ×10")
	for k2: String in DISCLOSED_X10:
		var t := _x10(k2)
		var cells := []
		for g2 in ["E", "L", "M"]:
			cells.append("%s %s" % [g2, _pct(float(t.get(g2, 0.0)))])
		print("- %s: %s" % [k2, " · ".join(cells)])
	print("\n## Per-hero odds (§7.2 stages)")
	print("| Stage | " + " | ".join(HeroData.HERO_ORDER) + " |")
	for st: String in STAGES:
		var ho := Summon.hero_odds(_stage(st))
		var cells2 := []
		for id in HeroData.HERO_ORDER:
			cells2.append(_pct(float(ho[id])))
		print("| %s | %s |" % [st, " | ".join(cells2)])


func _x10(kind: String) -> Dictionary:
	match kind:
		"welcome":
			return Summon.x10_best(0, 0, true)
		"fresh":
			return Summon.x10_best(0, 0, false)
	return Summon.solve_x10_best_stationary()


func _chest() -> void:
	print("\n## Hero Chests — one card")
	var cells := []
	for g: String in PortalData.CHEST_ODDS:
		cells.append("%s %s" % [g, _pct(float(PortalData.CHEST_ODDS[g]))])
	print(" · ".join(cells) + " (Grand: the last card Amethyst+; a Topaz card by the %dth chest)" % PortalData.CHEST_PITY_L)
	for k: String in DISCLOSED_CHEST:
		var b := HeroChest.exact_best(k)
		var c2 := []
		for g2: String in b:
			if float(b[g2]) > 0.0:
				c2.append("%s %s" % [g2, _pct(float(b[g2]))])
		print("- best card, %s chest: %s" % [k, " · ".join(c2)])
	var acc := EconData.fresh_account()
	(acc["progress"] as Dictionary)["level"] = 31
	for cid in ChampionData.CHAMPION_ORDER:
		Roster.grant(acc, cid, "chest", 1)
	HeroChest.set_focus(acc, "C", "mila")
	var co := HeroChest.champion_odds(acc)
	var c3 := []
	for cid2 in ChampionData.CHAMPION_ORDER:
		c3.append("%s %s" % [cid2, _pct(float(co[cid2]))])
	print("- per champion card, every gem complete, chest Focus Quartz = mila: " + " · ".join(c3))
	print("\n## Per-champion odds of one free card (every gem complete; §7.5)")
	print("| Gem | Champions | Each, no Focus | Focus | Each other |")
	print("|---|---|---|---|---|")
	for g2: String in PortalData.CHEST_ODDS:
		var r := _champ_row(g2)
		if not r.is_empty():
			print("| %s | %d | %.2f%% | %.2f%% | %.2f%% |" % [g2, int(r["pool"]), float(r["each"]), float(r["focus"]), float(r["other"])])


## The exact per-champion odds of one free card of `gem` (every gem complete): {pool, each, focus, other} in %.
static func _champ_row(gem: String) -> Dictionary:
	var pool := HeroChest.pool(gem)
	if pool.is_empty():
		return {}
	var acc := EconData.fresh_account()
	(acc["progress"] as Dictionary)["level"] = 31
	for cid in ChampionData.CHAMPION_ORDER:
		Roster.grant(acc, cid, "chest", 1)
	var p := 100.0 * float(PortalData.CHEST_ODDS[gem])
	var even := HeroChest.champion_weights(acc, gem)
	HeroChest.set_focus(acc, gem, pool[pool.size() - 1])
	var fw := HeroChest.champion_weights(acc, gem)
	return {"pool": pool.size(), "each": p * float(even[pool[0]]), "focus": p * float(fw[pool[pool.size() - 1]]),
			"other": p * float(fw[pool[0]]) if pool.size() > 1 else 0.0}


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL ", what)


func _diff() -> void:
	print("\n## --diff: exact tables vs the disclosed rows")
	var cons := Summon.solve_consolidated()
	for g: String in DISCLOSED_GEMS:
		_ok(absf(100.0 * float(cons[g]) - float(DISCLOSED_GEMS[g])) <= 0.005, "consolidated %s" % g)
	for k: String in DISCLOSED_X10:
		var t := _x10(k)
		for g2: String in DISCLOSED_X10[k]:
			_ok(absf(100.0 * float(t.get(g2, 0.0)) - float(DISCLOSED_X10[k][g2])) <= 0.005, "x10 %s %s" % [k, g2])
	for k2: String in DISCLOSED_CHEST:
		var b := HeroChest.exact_best(k2)
		for g3: String in DISCLOSED_CHEST[k2]:
			_ok(absf(100.0 * float(b.get(g3, 0.0)) - float(DISCLOSED_CHEST[k2][g3])) <= 0.005, "chest %s %s" % [k2, g3])
	# Per-champion rows: the pool size and each disclosed % (rounded to 0.01 pp as printed).
	for g4: String in PortalData.CHEST_ODDS:
		var r := _champ_row(g4)
		var d: Dictionary = DISCLOSED_CHAMP.get(g4, {})
		if r.is_empty() or d.is_empty():
			_ok(r.is_empty() and d.is_empty(), "chest champion row %s disclosed" % g4)
			continue
		_ok(int(r["pool"]) == int(d["pool"]), "chest %s pool %d champions, disclosed %d (update DISCLOSED_CHAMP and add an ODDS_CHANGELOG row)" % [g4, int(r["pool"]), int(d["pool"])])
		for k3: String in ["each", "focus", "other"]:
			_ok(absf(snappedf(float(r[k3]), 0.01) - float(d[k3])) <= 0.005, "chest %s %s %.4f%% vs disclosed %.2f%%" % [g4, k3, float(r[k3]), float(d[k3])])
	print("\n## Odds changelog rows (§9.3 «Змінено у»)")
	for g6: String in PortalData.CHEST_ODDS:
		var pool_now := HeroChest.pool(g6).size()
		if pool_now == int(LAUNCH_POOLS.get(g6, 0)):
			continue
		var logged := false
		for row0: Dictionary in ODDS_CHANGELOG:
			logged = logged or (str(row0["pool"]) == "chest " + g6 and int(row0.get("pool_after", -1)) == pool_now)
		_ok(logged, "chest %s pool %d champions (launch %d) has no ODDS_CHANGELOG row with pool_after %d"
				% [g6, pool_now, int(LAUNCH_POOLS.get(g6, 0)), pool_now])
	for row: Dictionary in ODDS_CHANGELOG:
		var g5 := str(row["pool"]).trim_prefix("chest ")
		var current := int(row.get("pool_after", -1)) == HeroChest.pool(g5).size()
		if current:
			var now := snappedf(float(_champ_row(g5).get(str(row["row"]), -1.0)), 0.01)
			_ok(absf(now - float(row["now"])) <= 0.005, "changelog %s %s: now %.2f%% vs exact %.2f%%" % [row["version"], row["row"], float(row["now"]), now])
		print("- %s · %s (%d champions) · %s: %.2f%% -> %.2f%% (%s)%s" % [row["version"], row["pool"], int(row.get("pool_after", -1)),
				row["row"], float(row["was"]), float(row["now"]), row["why"], "" if current else " [history]"])


static func _z(k: int, n: int, p: float) -> float:
	if p <= 0.0:
		return 0.0 if k == 0 else 99.0
	if p >= 1.0:
		return 0.0 if k == n else 99.0
	return absf(float(k) - n * p) / sqrt(n * p * (1.0 - p))


func _check(n: int) -> void:
	print("\n## --check: %d rolls per pool state" % n)
	var rng := RandomNumberGenerator.new()
	for st: String in STAGES:
		rng.seed = 7000 + st.unicode_at(0)
		var acc := _stage(st)
		var ex := Summon.hero_odds(acc)
		var cnt := {}
		var by_gem := {}
		var ps := {"since_e": 0, "since_l": 0}
		var ge := 0
		var gl := 0
		var me := 0
		var ml := 0
		for i in n:
			var g := Summon.roll_gem(ps, rng)
			var id := Summon.pick_hero(acc, g, rng)
			cnt[id] = int(cnt.get(id, 0)) + 1
			by_gem[g] = int(by_gem.get(g, 0)) + 1
			ge += 1
			gl += 1
			if Ladder.gem_index(g) >= 2:
				me = maxi(me, ge)
				ge = 0
			if Ladder.gem_index(g) >= 3:
				ml = maxi(ml, gl)
				gl = 0
		var worst := 0.0
		for id2 in HeroData.HERO_ORDER:
			worst = maxf(worst, _z(int(cnt.get(id2, 0)), n, float(ex[id2])))
		print("  stage %s: max |z| %.2f · Amethyst+ gap max %d · Topaz+ gap max %d" % [st, worst, me, ml])
		_ok(worst <= 4.0, "stage %s per-hero |z| %.2f" % [st, worst])
		_ok(me <= int(PortalData.PITY_E["hard"]) and ml <= int(PortalData.PITY_L["hard"]), "stage %s pity gaps" % st)
		var fd: Dictionary = STAGES[st]["focus"]
		for fg: String in fd:
			var z := _z(int(cnt.get(fd[fg], 0)), int(by_gem.get(fg, 0)), PortalData.FOCUS_TOTAL)
			_ok(z <= 4.0, "stage %s Focus %s share |z| %.2f" % [st, fg, z])
	var pity := {"since_l": 0, "total": 0}
	var free := {}
	var nf := 0
	var gap := 0
	var mg := 0
	var chests := maxi(1000, n / 3)
	rng.seed = 7777
	for i2 in chests:
		var kind := "grand" if i2 % 6 == 5 else "hero"
		var gs := HeroChest.roll_gems(kind, pity, rng)
		var any_l := false
		for j in gs.size():
			any_l = any_l or gs[j] == "L"
			if j < gs.size() - 1:
				free[gs[j]] = int(free.get(gs[j], 0)) + 1
				nf += 1
		pity["since_l"] = 0 if any_l else int(pity["since_l"]) + 1
		gap += 1
		if any_l:
			mg = maxi(mg, gap)
			gap = 0
	var wz := 0.0
	for g4: String in PortalData.CHEST_ODDS:
		wz = maxf(wz, _z(int(free.get(g4, 0)), nf, float(PortalData.CHEST_ODDS[g4])))
	print("  chests: %d (5 Hero : 1 Grand) · free-card max |z| %.2f · Topaz card gap max %d" % [chests, wz, mg])
	_ok(wz <= 4.0, "chest card |z| %.2f" % wz)
	_ok(mg <= PortalData.CHEST_PITY_L, "chest Topaz pity gap %d" % mg)
	# Per champion: HeroChest.pick_champion inside every gem, every gem complete, without and with a chest Focus.
	var acc2 := EconData.fresh_account()
	(acc2["progress"] as Dictionary)["level"] = 31
	for cid in ChampionData.CHAMPION_ORDER:
		Roster.grant(acc2, cid, "chest", 1)
	rng.seed = 7900
	var cz := 0.0
	var per := maxi(1000, n / 10)
	for focus_on in [false, true]:
		for g6: String in PortalData.CHEST_ODDS:
			var pool := HeroChest.pool(g6)
			if pool.is_empty():
				continue
			HeroChest.set_focus(acc2, g6, pool[pool.size() - 1] if focus_on else "")
			var w := HeroChest.champion_weights(acc2, g6)
			var cc := {}
			for i5 in per:
				var id5 := HeroChest.pick_champion(acc2, g6, rng)
				cc[id5] = int(cc.get(id5, 0)) + 1
			for id6: String in pool:
				cz = maxf(cz, _z(int(cc.get(id6, 0)), per, float(w[id6])))
	print("  champions: %d picks per gem and Focus state · max |z| %.2f" % [per, cz])
	_ok(cz <= 4.0, "per-champion pick |z| %.2f" % cz)
