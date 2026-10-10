class_name HeroKinds
extends RefCounted
## Hero behaviour as data + one rules implementation (heroes design §10.4, critique X32). Run and
## LevelSim never branch on hero ids: they look the hero up here (its run row def_for, the attack
## pattern, the ult kind) and drive the attack and the ult through the same static rules over a
## KindView (RunKindView: nodes, VFX and signals; SimKindView: LevelSim arrays).
##
## Phase 0 (shipped Meta-1): the three starters (Руді `bolt` = storm, Горан `titan` = quake, Мейра
## `seer` = rift) read Balance.HEROES and the rules reproduce Meta-1 exactly (level_check and the
## autotests stay identical). From V3_PHASE (H2) with a v3 hero block in the profile (Meta.run_profile
## in dev runs) every hero of §6 runs on its sheet: def_for builds the row from HeroData (the attack at
## its Attack rank, the ult at its form, x the v3 multipliers), the ult shapes drop / area / beam / fan /
## wall / ward / flock join timed and waves, attack() runs every v3 row's pattern and procs (the starters'
## too), hero_step() keeps the hero kind's timers, and ult_worth() fires in every clash and siege and
## otherwise reads the §10.4 policies (HeroData.ULTS policy, the POLICY_WHEN vocabulary).
##
## A v3 row (def.v3 = true) carries FINAL numbers: hp x hp_mult (x the Guardian's Bulwark), damage x
## dmg_mult (a float), ult.charge / ult_rate_mult, the ult's kills / breaks / heal / return / wall_hp
## (and its extra's kills / breaks) x ult_power (ult.power records it, and the rules then never
## multiply by view.ult_power()). An owner applies none of the hero block's multipliers on a v3 row
## again (Reinforcements dmg_add and team synergies still apply; damage gates add x dmg_mult, gate_damage).
## def.mults lists what was applied.
##
## FX (view.fx): timed and waves keep ult_cast, ult_step, ult_tick, ult_tick_done, ult_end, ult_wave,
## ult_waves_end; every other shape sends SHAPE_FX with one Dictionary {kind, form, shape, phase:
## &"start" | &"hit" | &"end", d, x, r, d0, d1, x0, x1, angle, reach, charges, s, targets} (unused keys
## left out) at its start, at each hit and at its end; a v3 attack volley sends ATTACK_FX {pattern, targets,
## d, x, proc} (the Run draws the starters' volleys with their own shot fx).

## The phase the heroes feature runs at: 0 = shipped Meta-1 (2.2.x), 1 = rules and data,
## 2 = champions in the run, 3 = meta UI on. The one flag is EconData.HEROES_PHASE (WS-B).
## The phase from which champions take part in runs (§13.2 H2).
const CHAMPIONS_PHASE := 2
## The phase from which def_for builds v3 rows from a profile's v3 hero block (§13.2 H2).
const V3_PHASE := 2

## Ult shapes (HeroData.ULT_SHAPES, the closed set): `timed` runs `duration` s and hits everything
## within `range` every `tick` s (gates in range take a hero hit per tick); `waves` sends `waves`
## bands `spacing` u deep, `gap` s apart, from the cast point (no gate hits); drop, area, beam, fan,
## wall, ward and flock are the H2 shapes (the rules below each say how they hit).
const TIMED := &"timed"
const WAVES := &"waves"
const DROP := &"drop"
const AREA := &"area"
const BEAM := &"beam"
const FAN := &"fan"
const WALL := &"wall"
const WARD := &"ward"
const FLOCK := &"flock"

## Attack patterns (HeroData.ATTACK_PATTERNS; the run's shot VFX). The starters' rules are data in
## their rows (targets, splash, reveal_row, charge_mult, aspect); the new heroes' run through attack().
const ATTACK_DART := &"dart"        ## Руді, Іскар, Пава, Ольга: fast straight shots
const ATTACK_BOULDER := &"boulder"  ## Горан, Вартан: a heavy throw with splash
const ATTACK_ORBS := &"orbs"        ## Мейра: twin homing orbs
const ATTACK_SWING := &"swing"      ## Арін, Веста, Сірко: melee swings in an arc
const ATTACK_BEAM := &"beam"        ## Ейра, Люмен: rays that ignore the Shielded pool

## The fx events of the H2 shapes and of a v3 attack volley (see the header).
const SHAPE_FX := &"ult_shape"
const ATTACK_FX := &"hero_attack"

## Hero id -> kind row (all 12 heroes of §6.0). Unknown ids fall back to DEFAULT_KIND (Meta-1's
## else-branch was Titan).
const KINDS := {
	"titan": {"attack": ATTACK_BOULDER, "ult": &"quake"},
	"arin": {"attack": ATTACK_SWING, "ult": &"anchor"},
	"bolt": {"attack": ATTACK_DART, "ult": &"storm"},
	"eira": {"attack": ATTACK_BEAM, "ult": &"rime"},
	"seer": {"attack": ATTACK_ORBS, "ult": &"rift"},
	"iskar": {"attack": ATTACK_DART, "ult": &"comet"},
	"vesta": {"attack": ATTACK_SWING, "ult": &"sunglaive"},
	"vartan": {"attack": ATTACK_BOULDER, "ult": &"forgewall"},
	"lumen": {"attack": ATTACK_BEAM, "ult": &"spectrum"},
	"pava": {"attack": ATTACK_DART, "ult": &"eyes"},
	"sirko": {"attack": ATTACK_SWING, "ult": &"letter"},
	"olha": {"attack": ATTACK_DART, "ult": &"doves"},
}
const DEFAULT_KIND := "titan"

## Ult kind -> run behaviour. `shape` = HeroData.ULTS[kind].shape. `first_tick`: the tick clock at
## the cast (a timed ult with 0 hits on its first step). `slows`: hazards, turrets and clashing
## squads run at (1 - ult.slow) while it lasts. `policy`: the Meta-1 auto-fire rule of a starter's
## Balance row (ult_worth): `reach` (u ahead; < 0 = the ult's range), `guard` = [min army, hazard
## ahead u]: also fire when a hazard is that close to a decent army (the quake's hazard immunity).
## A v3 row reads the §10.4 policy of HeroData.ULTS instead.
const ULTS := {
	&"storm": {"shape": TIMED, "first_tick": 0.0, "slows": false, "policy": {"reach": -1.0}},
	&"rift": {"shape": TIMED, "first_tick": 0.25, "slows": true, "policy": {"reach": -1.0}},
	&"quake": {"shape": WAVES, "first_tick": 0.43, "slows": false, "armor": true,
			"policy": {"reach": 13.0, "guard": [25.0, 6.0]}},
	&"anchor": {"shape": DROP, "slows": false},
	&"rime": {"shape": AREA, "slows": false},
	&"comet": {"shape": BEAM, "slows": false},
	&"sunglaive": {"shape": DROP, "slows": false},
	&"forgewall": {"shape": WALL, "slows": false},
	&"spectrum": {"shape": FAN, "slows": false},
	&"eyes": {"shape": WARD, "slows": false},
	&"letter": {"shape": AREA, "slows": false},
	&"doves": {"shape": FLOCK, "slows": false},
}

## The Forgewall's ward kinds (KindView.WARD_SPEND): they end with the wall (_wall_end clears them).
const WALL_WARDS: Array[StringName] = [&"wall_turret", &"wall_contact", &"clash"]
## The clock's `left` while an H2 shape's last step and its end parts run (_shape_step): still active, so
## their kills never charge the next ult.
const END_HOLD := 0.001

## Forked Fox (Руді's default Aspect): every FORK_EVERY-th cast chains to one more target.
const FORK_ASPECT := "forked_fox"
const FORK_EVERY := 3

## How long the cast pose of a `waves` ult plays (the hero model; timed ults pose for their
## duration).
const WAVES_CAST_POSE := 1.6

## The ult number keys def_for multiplies by ult power (HeroData.ULTS: "kills / breaks / heal / return / wall_hp
## (and an extra's kills / breaks) are x ult power"; lengths, radii, rates and counts never scale).
const POWER_KEYS: Array[String] = ["kills", "breaks", "heal", "return", "wall_hp"]
## u ahead "the screen" reaches (a part's target `all`, reveal -1, the 12 biggest hostiles): the run's camera
## shows about this much of the bridge ahead of the hero.
const SCREEN := 30.0
## A ward / hold "until their next clash" (clash_loss_s null): this long (a squad meets the army well inside it).
const NEXT_CLASH_S := 20.0
## Ward charges of an absorb count of -1 (every hit of that kind while it lasts).
const ALL_CHARGES := 9999
## Half width of a fan ray (thin rays, §10.2: <= 0.12 u drawn; this is the hit test) and of a flight path.
const RAY_HW := 0.3
const PATH_HW := 0.6
## A squad row without its half width (a view that does not send `hw`): the run's default squad (w 2.4).
const SQUAD_HW := 1.2
## Seconds of loss history the army_loss policy may look back (the longest POLICY_WHEN window, Пава's 3 s).
const LOSS_WINDOW := 3.0
## Seconds between two loss samples (the army_loss policy) and between two eye / field checks.
const SAMPLE_S := 0.25
## Healer-hero Awakenings that revive (§6.10 Пава «Пробуджені очі»): hero -> {after: s per Awakening rank 1..4,
## hp: the share they stand up with}, once per level. The other heroes' Awakenings are not run rules yet.
const AWAKEN_REVIVE := {"pava": {"after": [10.0, 9.0, 8.0, 7.0], "hp": 0.3}}


## The hero's run clock both Run and LevelSim keep (the views own it; the rules hand it back through
## store_clock): the ult (`left` s of the running ult, the `tick` countdown, the band index of a waves
## ult (99 = idle) and the distance it was cast at), the H2 shape's place and parts, and the hero
## kind's own counters (attack procs, the Healer revive pool, loss samples, cooldowns), which persist
## from ult to ult. A Meta-1 starter only ever uses the first four fields.
class Clock extends RefCounted:
	var left := 0.0
	var tick := 0.0
	var wave := 99
	var wave_d := 0.0
	# ---- the running H2 shape
	var t := 0.0                ## s since the cast
	var x := 0.0                ## the shape's x (the cast x; a `follow` beam tracks the hero)
	var d := 0.0                ## the shape's anchor distance (drop: the impact; area / flock: the cast)
	var n := 0                  ## pulses / ticks / waves done
	var hp := 0.0               ## wall hp at the cast
	var rec := 0.0              ## ward: soldiers recorded
	var lost0 := 0.0            ## ward: army()["lost"] at the last look
	var ids: Array = []         ## flock: the structures struck ([id, kind, d, x]); fixed at the cast
	var parts := {}             ## part -> its state ("hit" ids, "extra" fired, "field" / "afterburn" timers ...)
	# ---- the hero kind (persists from ult to ult)
	var casts := 0              ## attack volleys fired
	var procs := {}             ## proc / status id -> its counter
	var pool := 0.0             ## Healer hero revive pool (the Mend share of every soldier lost)
	var seen_lost := -1.0       ## army()["lost"] at the last hero_step (-1 = not looked yet)
	var losses := PackedVector2Array()  ## (time, lost) samples over the last LOSS_WINDOW s
	var now := 0.0              ## hero_step's clock (s)
	var cds := {}               ## cooldown -> s left (drones, guard, contact drone, eye and field checks)
	var eyes := {}              ## squad id -> [d, soldiers back when it is wiped] (Пава's Eyes)
	var grounded := {}          ## squad id -> hero clock when it may be grounded again (reground)
	var fallen := {}            ## champion id -> hero clock when it was first seen down (Пава's Awakening)
	var revived := false        ## Пава's Awakening revive used this level
	var ults := 0               ## ults cast (a v3 row's clock; dev tools count them)

	func active() -> bool:
		return left > 0.0 or wave < 99

	func copy() -> Clock:
		var c := Clock.new()
		c.left = left
		c.tick = tick
		c.wave = wave
		c.wave_d = wave_d
		c.t = t
		c.x = x
		c.d = d
		c.n = n
		c.hp = hp
		c.rec = rec
		c.lost0 = lost0
		c.ids = ids.duplicate(true)
		c.parts = parts.duplicate(true)
		c.casts = casts
		c.procs = procs.duplicate()
		c.pool = pool
		c.seen_lost = seen_lost
		c.losses = losses.duplicate()
		c.now = now
		c.cds = cds.duplicate()
		c.eyes = eyes.duplicate(true)
		c.grounded = grounded.duplicate()
		c.fallen = fallen.duplicate()
		c.revived = revived
		c.ults = ults
		return c

	## Forgets every target held by id (a copy whose ids mean other items: the bot's planner snapshot
	## re-indexes the Run's items). Timers, counters and the pool stay.
	func drop_refs() -> void:
		ids = []
		parts = {}
		eyes = {}
		grounded = {}
		left = 0.0
		wave = 99


# ------------------------------------------------------------------ phase flag

static func phase() -> int:
	return EconData.heroes_phase()


static func champions_live() -> bool:
	return phase() >= CHAMPIONS_PHASE


# ------------------------------------------------------------------ table

static func row(hero: String) -> Dictionary:
	return KINDS.get(hero, KINDS[DEFAULT_KIND])


static func attack_kind(hero: String) -> StringName:
	return row(hero)["attack"]


static func ult_kind(hero: String) -> StringName:
	return row(hero)["ult"]


static func ult_row(kind: StringName) -> Dictionary:
	return ULTS.get(kind, ULTS[&"quake"])


static func is_timed(kind: StringName) -> bool:
	return ult_row(kind)["shape"] == TIMED


## True for the Meta-1 starters (a Balance.HEROES row): the Run draws their volleys with their own shot fx at every
## phase; on a v3 row (from V3_PHASE) the volleys themselves run through attack(), as every hero's.
static func starter(hero: String) -> bool:
	return Balance.HEROES.has(hero)


## True when a run row is a v3 row (def_for from a v3 hero block: final numbers, see the header).
static func scaled(def: Dictionary) -> bool:
	return bool(def.get("v3", false))


## True when the profile hero block `b` is a v3 block (HeroesMeta.run_block keys).
static func is_v3(b: Dictionary) -> bool:
	return b.has("ult_form") and b.has("ult_power")


## True when a cast of a Forked Fox hero numbered `cast_no` (1 = the first cast) chains once more.
static func forks(aspect: String, cast_no: int) -> bool:
	return aspect == FORK_ASPECT and cast_no % FORK_EVERY == 0


# ------------------------------------------------------------------ the run row (§10.1)

## The hero's run row in the Balance.HEROES shape ({hp, damage, rate, range, targets, splash, corridor,
## charge_mult, reveal_row, aspect, color, ult {charge, ...}}). From V3_PHASE with a v3 block in
## `prof_hero` (Meta.run_profile().hero): built from HeroData (the attack at the block's Attack rank,
## HeroData.ult_numbers at its ult form) and scaled by the block (see the header: final numbers, v3 =
## true). Otherwise exactly Balance.HEROES[hero_id] (the starters at phase 0; the shared const row).
## A hero without a Balance row (dev tools fielding a new hero on a Meta-1 profile) gets its v3 row at
## the block's level (block_for). A block of another hero (a dev run fielding another hero than the
## account's) is rebased onto this one (block_for).
static func def_for(hero_id: String, prof_hero: Dictionary) -> Dictionary:
	var v3 := phase() >= V3_PHASE and is_v3(prof_hero)
	if not v3 and Balance.HEROES.has(hero_id):
		return Balance.HEROES[hero_id]
	if not HeroData.HEROES.has(hero_id):
		return Balance.HEROES[DEFAULT_KIND]
	return _v3_row(hero_id, block_for(hero_id, prof_hero))


## The v3 numbers def_for scales by: `b` itself when it is hero_id's v3 block; else a block for hero_id at
## b's level (and skill ranks, when b is a v3 block) on its native gem with no facets, as HeroesMeta.run_block
## would give an unowned hero (Lv1, rank 1 without a block).
static func block_for(hero_id: String, b: Dictionary) -> Dictionary:
	if is_v3(b) and str(b.get("id", hero_id)) == hero_id:
		return b
	var n := HeroData.native(hero_id)
	var lvl := maxi(1, int(b.get("lvl", 1)))
	var lm := float(lvl - 1)
	var lad := Ladder.mult(n, n, 0)
	# A Meta-1 block's ult_rank is the I-IV Ult Rank of a hero level, not a v3 skill rank: rank 1 then.
	var atk := clampi(int(b.get("attack_rank", 1)), 1, Ladder.skill_cap(n, n, 0)) if is_v3(b) else 1
	var ult := clampi(int(b.get("ult_rank", 1)), 1, Ladder.skill_cap(n, n, 0)) if is_v3(b) else 1
	return {"id": hero_id, "native": n, "gem": n, "facets": 0, "lvl": lvl, "mult": lad,
			"dmg_mult": lad * (1.0 + Ladder.LV_DMG * lm) * (1.0 + Ladder.ATK_RANK_STEP * (atk - 1)),
			"hp_mult": lad * (1.0 + Ladder.LV_HP * lm), "ult_rate_mult": 1.0 + Ladder.LV_RATE * lm,
			"ult_power": lad * (1.0 + Ladder.LV_ULT * lm) * (1.0 + Ladder.ULT_RANK_STEP * (ult - 1)),
			"ult_rank": ult, "ult_form": Ladder.ult_form(n, ult), "attack_rank": atk,
			"awakened": int(b.get("awakened", 1 if Ladder.born_awakened(n) else 0))}


## The v3 row of `hero_id` from block `b` (def_for). Class traits (HeroData.HERO_CLASS_RUN, §5.1) that are
## numbers of the row land here: Long sight (+range), Bulwark (hp: it only counts at army 0), Cleave (x on a
## hero hit on the squad in the clash, the attack rule), Mend (the revive pool share, hero_step).
static func _v3_row(hero_id: String, b: Dictionary) -> Dictionary:
	var h: Dictionary = HeroData.HEROES[hero_id]
	var kit: Dictionary = h["kit"]
	var cls := str(h["class"])
	var kind := StringName(str(h["ult"]))
	var top := HeroData.ult_top_form(String(kind))
	var form := clampi(int(b.get("ult_form", 1)), 1, maxi(top, 1))
	var atk := HeroData.attack_numbers(hero_id, int(b.get("attack_rank", 1)))
	var cr: Dictionary = HeroData.HERO_CLASS_RUN.get(cls, {})
	var meta1: Dictionary = Balance.HEROES.get(hero_id, {})
	var dm := float(b.get("dmg_mult", 1.0))
	var hm := float(b.get("hp_mult", 1.0))
	var rm := maxf(float(b.get("ult_rate_mult", 1.0)), 0.01)
	var pw := float(b.get("ult_power", 1.0))
	var pattern := attack_kind(hero_id)
	var out := {
		"name": "HERO_" + hero_id.to_upper(), "desc": "HERO_" + hero_id.to_upper() + "_DESC",
		"color": meta1.get("color", _element_color(str(h["element"]))),
		"hp": float(kit["hp"]) * hm * float(cr.get("bulwark_hp", 1.0)),
		"rate": float(atk.get("rate", kit["rate"])), "damage": float(atk.get("dmg", kit["dmg"])) * dm,
		"splash": float(atk.get("splash", kit["splash"])),
		"range": float(atk.get("range", kit["range"])) + float(cr.get("sight", 0.0)),
		"targets": int(atk.get("targets", kit["targets"])),
		"corridor": float(meta1.get("corridor", _corridor(pattern, atk))),
		"aspect": str(meta1.get("aspect", "")),
		"v3": true, "kind": hero_id, "class": cls, "element": str(h["element"]), "attack": pattern, "atk": atk,
		"attack_rank": int(b.get("attack_rank", 1)), "cleave": float(cr.get("cleave", 1.0)),
		"mend_share": float(atk.get("mend_share", cr.get("mend_share", 0.0))) if cls == "healer" else 0.0,
		"awakened": int(b.get("awakened", 0)),
		"mults": {"dmg_mult": dm, "hp_mult": hm, "ult_rate_mult": rm, "ult_power": pw},
	}
	if atk.has("charge_mult"):
		out["charge_mult"] = float(atk["charge_mult"])
	if int(atk.get("reveal_rows", 0)) > 0:
		out["reveal_row"] = true
	# hero_step's timers, read every step: cached here so the step reads plain numbers (no lookups, no
	# defaults to build). drones = Вартан's ward-drones (beat 6: the contact drone), guard = Пава's beat 9.
	out["drones"] = int(atk.get("drones", 0))
	out["drone_recharge"] = float(atk.get("drone_recharge", 6.0))
	out["drone_contact_cd"] = float(atk.get("drone_contact_cd", 0.0))
	var gp: Dictionary = (atk.get("procs", {}) as Dictionary).get("guard", {})
	var gk: Array = gp.get("kinds", ["turret"])
	out["guard_cd"] = float(gp.get("cd", 10.0)) if not gp.is_empty() else 0.0
	# One listed kind guards that kind; turret + blade (Пава §6.10 «a turret shot or blade contact») is the
	# shared &"fan" ward, spent by whichever comes first.
	out["guard_kind"] = StringName(str(gk[0])) if gk.size() == 1 else (&"fan" if gk.size() > 1 else &"turret")
	# A reviving Awakening (AWAKEN_REVIVE, Пава): the wait at the row's Awakening rank (0 = none) and the HP share.
	var aw: Dictionary = AWAKEN_REVIVE.get(hero_id, {})
	var awk := int(out["awakened"])
	var waits: Array = aw.get("after", [])
	out["awaken_wait"] = float(waits[clampi(awk, 1, waits.size()) - 1]) if awk > 0 and not waits.is_empty() else 0.0
	out["awaken_hp"] = float(aw.get("hp", 0.0))
	var u := HeroData.ult_numbers(String(kind), form)
	for k: String in POWER_KEYS:
		if u.has(k):
			u[k] = float(u[k]) * pw
	if u.get("extra") is Dictionary:
		var ex: Dictionary = u["extra"]
		for k2: String in POWER_KEYS:
			if ex.has(k2):
				ex[k2] = float(ex[k2]) * pw
	var mu: Dictionary = meta1.get("ult", {})
	var loc: Dictionary = (HeroData.ULTS[String(kind)] as Dictionary)["loc"]
	u["name"] = str(mu.get("name", loc["name"]))
	u["icon"] = str(mu.get("icon", String(kind)))
	u["charge"] = float(HeroData.ULTS[String(kind)]["charge"]) / rm
	u["kind"] = kind
	u["shape"] = StringName(str(HeroData.ULTS[String(kind)]["shape"]))
	u["form"] = form
	u["power"] = pw
	u["v3"] = true
	out["ult"] = u
	return out


## The targeting corridor of a pattern (the run's geometry, not on the sheets): a swing's arc widens it.
static func _corridor(pattern: StringName, atk: Dictionary) -> float:
	if pattern == ATTACK_SWING:
		if atk.has("arc_deg"):
			return 1.2
		return maxf(Balance.CORRIDOR, float(atk.get("arc", 1.5)) * 0.5 + 0.25)
	if pattern == ATTACK_BOULDER or pattern == ATTACK_ORBS:
		return 1.0
	return Balance.CORRIDOR


static func _element_color(el: String) -> Color:
	var f: Dictionary = ArsenalData.FAMILIES.get(el, {})
	return f.get("accent", Color(0.9, 0.9, 0.95))


## The ult power the rules multiply hits by: 1 for a v3 row (its numbers are final), else the view's Ult Rank
## power (Meta-1).
static func _pw(view: KindView, u: Dictionary) -> float:
	return 1.0 if u.has("power") else view.ult_power()


## Hero damage per hit of a v3 row with `gates` damage from "+1 шкода" gates (power.dmg), before Reinforcements
## and the Prism (both views apply those on top): the gates scale with the hero's power as in the shipped game
## (Meta-1: (damage + gates) x dmg_mult), so a v3 row's final damage + gates x its dmg_mult (owner, 10.10).
static func gate_damage(def: Dictionary, gates: float) -> float:
	var m: Dictionary = def.get("mults", {})
	return float(def["damage"]) + gates * float(m.get("dmg_mult", 1.0))


## The team part of bucket 2 a machine gets from Люмен V's &"machines" buff (`buff`) on top of the team's other
## bucket-2 adds (`team`: Affinity, Celestials, Rally; neither view applies those yet): never past
## TeamData.TEAM_B2_CAP. Both views add it into the machine's bucket-2 sum (Weapons._b2, LevelSim._machines).
static func machines_b2(buff: float, team := 0.0) -> float:
	return minf(TeamData.TEAM_B2_CAP, maxf(team, 0.0) + maxf(buff, 0.0))


# ------------------------------------------------------------------ ult rules

## Starts the ult of `kind` (numbers `u` = the run row's ult) on the view's clock. The caller has
## already spent the charge. timed / waves: fx(&"ult_cast") follows with the clock set; the H2 shapes
## send SHAPE_FX phase start.
static func ult_cast(view: KindView, kind: StringName, u: Dictionary) -> void:
	var k := ult_row(kind)
	var shape: StringName = k["shape"]
	if shape != TIMED and shape != WAVES:
		view.clock().ults += 1
		_shape_cast(view, kind, shape, u)
		return
	var c := view.clock()
	c.ults += 1
	if shape == TIMED:
		c.left = float(u["duration"])
		c.tick = float(k["first_tick"])
	else:
		c.wave_d = view.distance()
		c.wave = 0
		c.tick = float(k["first_tick"])
	view.store_clock(c)
	if bool(k.get("armor", false)):
		view.grant_armor(float(u.get("armor_time", 6.0)))
	view.fx(&"ult_cast")


## Advances a running ult by `dt` (no-op when idle). timed / waves: hits go through view.area_hit
## with the ult's kills / breaks x the ult power (_pw: the view's Ult Rank for a Meta-1 row). fx
## events, in order: ult_step (every step of a timed ult), ult_tick before and ult_tick_done after
## each tick's hit, ult_end when a timed ult ends; ult_wave {near, spacing, wave} before each band's
## hit, ult_waves_end after the last band. A v3 timed row adds its form riders per tick (statuses,
## Flying x / grounding, reveal) and hits gates only with `gate_hits`. The H2 shapes: _shape_step.
static func ult_step(view: KindView, kind: StringName, u: Dictionary, dt: float) -> void:
	var shape: StringName = ult_row(kind)["shape"]
	if shape != TIMED and shape != WAVES:
		if view.clock().left > 0.0:
			_shape_step(view, kind, shape, u, dt)
		return
	var c := view.clock()
	if c.left > 0.0:
		c.left -= dt
		c.tick -= dt
		view.store_clock(c)
		view.fx(&"ult_step")
		var v3 := u.has("v3")
		while c.tick <= 0.0 and c.left > -dt:
			c.tick += float(u["tick"])
			view.store_clock(c)
			var d := view.distance()
			var pw := _pw(view, u)
			view.fx(&"ult_tick")
			var gates := float(u.get("gate_hits", 0.0)) > 0.0 if v3 else true
			view.area_hit(d - 0.5, d + float(u["range"]), float(u["kills"]) * pw, float(u["breaks"]) * pw, gates)
			if v3:
				_timed_riders(view, u, c, d)
			view.fx(&"ult_tick_done")
		if c.left <= 0.0:
			c.left = 0.0
			view.store_clock(c)
			view.fx(&"ult_end")
	elif c.wave < 99:
		c.tick -= dt
		var waves := int(u["waves"])
		var spacing := float(u["spacing"])
		while c.tick <= 0.0 and c.wave < waves:
			c.tick += float(u["gap"])
			var near := c.wave_d + float(u.get("from", 1.0)) + spacing * c.wave
			view.store_clock(c)
			view.fx(&"ult_wave", {"near": near, "spacing": spacing, "wave": c.wave})
			var pw2 := _pw(view, u)
			view.area_hit(near - 0.5, near + spacing, float(u["kills"]) * pw2, float(u["breaks"]) * pw2, false)
			c.wave += 1
		if c.wave >= waves:
			c.wave = 99
			view.store_clock(c)
			view.fx(&"ult_waves_end")
	view.store_clock(c)


## The form riders of a v3 timed ult's tick (storm II: Flying x flying_mult and grounded for the rest of the
## storm + ground_after s, a JOLT each tick; rift II: BRAND on every squad inside; rift III: hidden gates
## and Phantoms <= reveal u revealed while it is open).
static func _timed_riders(view: KindView, u: Dictionary, c: Clock, d: float) -> void:
	if u.has("reveal"):
		view.reveal(d, d + float(u["reveal"]), KindView.REVEAL_GATES)
		view.reveal(d, d + float(u["reveal"]), KindView.REVEAL_PHANTOMS)
	var fm := float(u.get("flying_mult", 1.0))
	if not u.has("statuses") and fm == 1.0 and not u.has("ground_after"):
		return
	var rows := view.squads_in(d - 0.5, d + float(u["range"]), -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0)
	for r: Dictionary in rows:
		var id := int(r["id"])
		if bool(r.get("flying", false)):
			if fm > 1.0:
				view.hit(id, float(u["kills"]) * (fm - 1.0), {"src": "hero", "kind": &"ult"})
			if u.has("ground_after"):
				view.ground(id, maxf(c.left, 0.0) + float(u["ground_after"]))
		_statuses(view, id, u.get("statuses", {}), u)


## Speed of hazards, turrets and clashing squads: 1, or 1 - ult.slow while a `slows` ult runs.
static func hazard_slow(kind: StringName, u: Dictionary, ult_left: float) -> float:
	if ult_left > 0.0 and bool(ult_row(kind)["slows"]):
		return 1.0 - float(u.get("slow", 0.0))
	return 1.0


# ------------------------------------------------------------------ H2 shapes

## The planned length of a shape with every part (the clock's `left` at the cast; a step that is done
## early ends it).
static func _span(shape: StringName, u: Dictionary) -> float:
	var ex: Dictionary = u.get("extra", {}) if u.get("extra") is Dictionary else {}
	var span := 0.0
	match shape:
		DROP:
			span = float(int(u.get("pulses", 1)) - 1) * float(u.get("gap", 0.0))
			if u.get("field") is Dictionary:
				span += float((u["field"] as Dictionary).get("duration", 0.0))
			span = maxf(span, float(ex.get("delay", 0.0)))
		AREA:
			span = maxf(maxf(float(u.get("sweep", 0.0)), float(u.get("duration", 0.0))), float(ex.get("delay", 0.0)))
		BEAM, FAN, WALL, WARD:
			span = float(u.get("duration", 0.0))
		FLOCK:
			span = float(int(u.get("waves", 1)) - 1) * float(u.get("gap", 0.0))
			if str(ex.get("at", "")) == "wave":
				span += float(u.get("gap", 0.0))
			if u.get("afterburn") is Dictionary:
				span += float((u["afterburn"] as Dictionary).get("duration", 0.0))
	return span + 0.05


## Data of a SHAPE_FX event: {kind, form, shape, phase} + `more`.
static func _fxd(u: Dictionary, phase: StringName, more: Dictionary) -> Dictionary:
	var out := {"kind": u.get("kind", &""), "form": int(u.get("form", 1)), "shape": u.get("shape", &""), "phase": phase}
	out.merge(more, true)
	return out


static func _shape_cast(view: KindView, _kind: StringName, shape: StringName, u: Dictionary) -> void:
	var c := view.clock()
	var a := view.army()
	var d := view.distance()
	var ax := float(a["x"])
	c.t = 0.0
	c.tick = 0.0
	c.n = 0
	c.wave = 99
	c.ids = []
	c.parts = {"hit": {}}
	c.rec = 0.0
	c.hp = 0.0
	c.x = ax if bool(u.get("at_x", false)) or shape == WALL or shape == AREA else 0.0
	c.d = d
	c.left = _span(shape, u)
	var more := {"d": d, "x": c.x}
	match shape:
		DROP:
			c.d = d + float(u.get("ahead", 0.0))
			more = {"d": c.d, "x": c.x, "r": float(u.get("radius", 1.0))}
		AREA:
			more = {"d0": d + float(u.get("from", 0.0)), "d1": d + float(u.get("to", 0.0)), "s": c.left}
		BEAM:
			var hw := float(u.get("width", 1.0)) * 0.5
			more = {"d0": d + float(u.get("from", 0.0)), "d1": d + float(u.get("to", 0.0)), "x0": c.x - hw,
					"x1": c.x + hw, "s": float(u.get("duration", 0.0))}
		FAN:
			more = {"d": d, "x": c.x, "angle": float(u.get("angle", 60.0)), "reach": float(u.get("length", 16.0)),
					"s": float(u.get("duration", 0.0))}
		WALL:
			c.hp = float(u.get("wall_hp", 0.0)) * float(u.get("wall_hp_mult", 1.0))
			var dur := float(u.get("duration", 0.0))
			var ab: Dictionary = u.get("absorb", {})
			# The wall's own ward kinds (WALL_WARDS): a new wall replaces what an older one left; they end with it.
			if ab.has("turret"):
				view.grant_ward(&"wall_turret", ALL_CHARGES if int(ab["turret"]) < 0 else int(ab["turret"]), dur, true)
			if c.hp > 0.0:
				# The wall's HP takes the clash losses of the squads that reach it first (ward kind "clash").
				view.grant_ward(&"clash", ceili(c.hp), dur, true)
			var hw2 := float(u.get("width", 6.0)) * 0.5
			more = {"d": d + float(u.get("ahead", 0.0)), "x0": c.x - hw2, "x1": c.x + hw2, "s": dur,
					"charges": ceili(c.hp)}
		WARD:
			c.lost0 = float(a.get("lost", 0.0))
			more = {"d": d, "x": ax, "s": float(u.get("duration", 0.0))}
		FLOCK:
			_flock_targets(view, u, c, d)
			var tg: Array[int] = []
			for e: Array in c.ids:
				tg.append(int(e[0]))
			more = {"d": d, "x": ax, "reach": float(u.get("reach", 0.0)), "targets": tg}
	_cast_parts(view, u, c, d)
	view.store_clock(c)
	view.fx(SHAPE_FX, _fxd(u, &"start", more))


## The parts every shape may carry at its cast: statuses at the cast (status_at.cast: target all = the
## screen, reach = <= reach u), champion revives (Healer form II / V), a timed team buff, the rime's heal.
static func _cast_parts(view: KindView, u: Dictionary, c: Clock, d: float) -> void:
	var sa: Dictionary = u.get("status_at", {}) if u.get("status_at") is Dictionary else {}
	if sa.get("cast") is Dictionary:
		var p: Dictionary = sa["cast"]
		var reach := SCREEN if str(p.get("target", "all")) == "all" else float(p.get("reach", SCREEN))
		for r: Dictionary in view.squads_in(d - 0.5, d + reach, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0):
			_statuses(view, int(r["id"]), p.get("statuses", {}), p)
	if int(u.get("revive", 0)) != 0:
		_revive(view, int(u["revive"]), float(u.get("revive_hp", 0.5)))
	if u.get("buff") is Dictionary:
		var b: Dictionary = u["buff"]
		match str(b.get("target", "")):
			"machines":
				view.buff(&"machines", float(b.get("b2", 0.0)), float(b.get("duration", 0.0)))
			"volleys":
				view.buff(&"volley_status", 0.0, float(b.get("duration", 0.0)), {"statuses": b.get("statuses", {})})
	if u.has("heal"):
		var share := float(u.get("heal_pool", 0.0)) * c.pool
		var back := floorf(float(u["heal"]) + share + 0.0001)
		c.pool = maxf(c.pool - share, 0.0)
		if back > 0.0:
			view.add_soldiers(back, &"heal")


## Revives fallen champions (`count` -1 = all, else the first `count` in team order) at `hp` of their max
## HP (§4.2: only Healer heroes revive; KindView.revive_champion -> ChampionKinds.revive).
static func _revive(view: KindView, count: int, hp: float) -> int:
	var done := 0
	for m: Dictionary in view.champions():
		if count >= 0 and done >= count:
			break
		if not bool(m.get("alive", true)) and view.revive_champion(StringName(str(m["id"])), hp):
			done += 1
	return done


## One step of a running H2 shape. The clock stays active (left >= END_HOLD) while this step's hits and, on
## the last step, _shape_end run: in the Run the view's clock IS the ult clock, so a kill there would otherwise
## charge the next ult (Люмен IV's Crown Shards, Вартан IV's Landslide, Пава IV's Eyes Wide); LevelSim's
## State.ult_left keeps its value until store_clock, so both views now refuse those points alike.
static func _shape_step(view: KindView, _kind: StringName, shape: StringName, u: Dictionary, dt: float) -> void:
	var c := view.clock()
	c.t += dt
	var left := c.left - dt
	c.left = maxf(left, END_HOLD)
	match shape:
		DROP:
			_drop_step(view, u, c, dt)
		AREA:
			_area_step(view, u, c)
		BEAM:
			_beam_step(view, u, c, dt)
		FAN:
			_fan_step(view, u, c, dt)
		WALL:
			_wall_step(view, u, c, dt)
		WARD:
			_ward_step(view, u, c)
		FLOCK:
			_flock_step(view, u, c, dt)
	if left <= 0.0:
		_shape_end(view, shape, u, c)
		c.left = 0.0
		view.fx(SHAPE_FX, _fxd(u, &"end", {"d": view.distance(), "x": c.x}))
	else:
		c.left = left
	view.store_clock(c)


## Whatever an ended shape still owes (a part due at its end that the last step did not reach).
static func _shape_end(view: KindView, shape: StringName, u: Dictionary, c: Clock) -> void:
	match shape:
		DROP:
			_extra_delay(view, u, c, true)
		AREA:
			_extra_delay(view, u, c, true)
		FAN:
			_fan_end(view, u, c)
		WALL:
			_wall_end(view, u, c)
		WARD:
			_ward_close(view, u, c)


## One hit of a shape on the box [d0, d1] x [x0, x1]: living squads overlapping it lose `kills` (x
## flying_mult on a Flying one; `flying` false skips Flying squads), structures (structures_in: barricades,
## turrets, geodes, crates, the fortress) `breaks`. Returns the squad rows hit (the shape's riders follow).
static func _zone(view: KindView, u: Dictionary, d0: float, d1: float, x0: float, x1: float, kills: float,
		breaks: float, flying := true) -> Array:
	var rows: Array = []
	var fm := float(u.get("flying_mult", 1.0))
	for r: Dictionary in view.squads_in(d0, d1, x0, x1):
		var fl := bool(r.get("flying", false))
		if fl and not flying:
			continue
		if kills > 0.0:
			view.hit(int(r["id"]), kills * (fm if fl else 1.0), {"src": "hero", "kind": &"ult"})
		rows.append(r)
	if breaks > 0.0:
		for h: Dictionary in view.structures_in(d0, d1):
			var hw := float(h.get("hw", 0.5))
			if float(h["x"]) + hw < x0 or float(h["x"]) - hw > x1:
				continue
			view.hit(int(h["id"]), breaks, {"src": "hero", "kind": &"ult"})
	return rows


## The per-squad riders of an ult hit on squad rows `rows`: statuses (`statuses` = id -> stacks, lengths from
## `<status>_s`), the Warrior form's clash_loss (KindView.expose; clash_loss_s null = their next clash),
## strip_s (KindView.strip), Flying grounding (`ground` s).
static func _riders(view: KindView, u: Dictionary, rows: Array) -> void:
	var sts: Dictionary = u.get("statuses", {}) if u.get("statuses") is Dictionary else {}
	var cl := float(u.get("clash_loss", 0.0))
	var cl_s := NEXT_CLASH_S if u.get("clash_loss_s") == null else float(u["clash_loss_s"])
	var strip_s := float(u.get("strip_s", 0.0))
	var gr := float(u.get("ground", 0.0))
	for r: Dictionary in rows:
		var id := int(r["id"])
		_statuses(view, id, sts, u)
		if cl > 0.0:
			view.expose(id, cl, cl_s)
		if strip_s > 0.0:
			view.strip(id, strip_s)
		if gr > 0.0 and bool(r.get("flying", false)):
			view.ground(id, gr)


## Applies `sts` (status id -> stacks) on squad `id`, each kept at least `<status>_s` of `p` (0 = the status
## rule's own length).
static func _statuses(view: KindView, id: int, sts: Variant, p: Dictionary) -> void:
	if not sts is Dictionary:
		return
	for st: String in (sts as Dictionary):
		var stacks := maxi(1, int(round(float(sts[st]))))
		var len := float(p.get(st + "_s", 0.0))
		for k in stacks:
			view.status(id, StringName(st), len)


## Gate hits of a shape: every gate of gates_in(d0, d1) whose span overlaps [x0, x1] takes `hits` hero hits
## (KindView.hit on a gate id counts hero hits).
static func _gate_hits(view: KindView, d0: float, d1: float, x0: float, x1: float, hits: float) -> void:
	if hits <= 0.0:
		return
	for g: Dictionary in view.gates_in(d0, d1):
		var hw := float(g.get("hw", 1.0))
		if float(g["x"]) + hw >= x0 and float(g["x"]) - hw <= x1:
			view.hit(int(g["id"]), hits, {"src": "hero", "kind": &"gate"})


static func _ids(rows: Array) -> Array[int]:
	var out: Array[int] = []
	for r: Dictionary in rows:
		out.append(int(r["id"]))
	return out


## The biggest living hostiles within [d0, d1] across the bridge: up to `count` rows of squads (by n) and
## structures (by hp; blades never), the biggest first.
static func _biggest(view: KindView, d0: float, d1: float, count: int, squads_only := false) -> Array:
	var all: Array = []
	for r: Dictionary in view.squads_in(d0, d1, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0):
		all.append([float(r["n"]), r])
	if not squads_only:
		for h: Dictionary in view.structures_in(d0, d1):
			all.append([float(h.get("hp", 0.0)), h])
	all.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	var out: Array = []
	for k in mini(count, all.size()):
		out.append(all[k][1])
	return out


# ---- drop (Арін's anchor, Веста's sunrise)

## `pulses` hits (one when absent) `gap` s apart on the circle `radius` u around (x, d) fixed at the cast,
## `ahead` u in front (at the hero's x with `at_x`, else mid-bridge). Riders per pulse; anchor: the chain
## `hold_width` u wide holds the squads touching it `hold` s (strength 1, STAGGERed), gates under the impact
## take `gate_hits`. Sunrise forms: III the field after the burst, IV the extra at `delay`.
static func _drop_step(view: KindView, u: Dictionary, c: Clock, dt: float) -> void:
	var pulses := int(u.get("pulses", 1))
	var gap := float(u.get("gap", 0.0))
	var r := float(u.get("radius", 1.0))
	while c.n < pulses and c.t >= gap * float(c.n) - 0.0001:
		var rows := _zone(view, u, c.d - r, c.d + r, c.x - r, c.x + r, float(u.get("kills", 0.0)),
				float(u.get("breaks", 0.0)))
		_riders(view, u, rows)
		if u.has("hold"):
			var hw := float(u.get("hold_width", 2.0 * r)) * 0.5
			for sq: Dictionary in view.squads_in(c.d - r, c.d + r, c.x - hw, c.x + hw):
				view.hold(int(sq["id"]), float(u["hold"]), 1.0)
				view.status(int(sq["id"]), &"stagger", float(u["hold"]))
		_gate_hits(view, c.d - r, c.d + r, c.x - r, c.x + r, float(u.get("gate_hits", 0.0)))
		c.n += 1
		view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": c.d, "x": c.x, "r": r, "targets": _ids(rows)}))
	if c.n >= pulses and u.get("field") is Dictionary:
		_field_step(view, u["field"], c, dt)
	_extra_delay(view, u, c, false)


## Веста's Sun Field (form III): `duration` s, `radius` u around the burst: squads inside burn (refreshed every
## SAMPLE_S), army volleys + `volleys` (bucket 2) while the blob centre is inside.
static func _field_step(view: KindView, fd: Dictionary, c: Clock, dt: float) -> void:
	var f: Dictionary = c.parts.get("field", {})
	if f.is_empty():
		f = {"left": float(fd.get("duration", 0.0)), "cd": 0.0}
		c.parts["field"] = f
		view.fx(SHAPE_FX, {"kind": &"field", "phase": &"start", "d": c.d, "x": c.x, "r": float(fd.get("radius", 1.0)),
				"s": float(f["left"])})
	if float(f["left"]) <= 0.0:
		return
	f["left"] = float(f["left"]) - dt
	f["cd"] = float(f["cd"]) - dt
	if float(f["cd"]) > 0.0:
		return
	f["cd"] = SAMPLE_S
	var r := float(fd.get("radius", 1.0))
	for sq: Dictionary in view.squads_in(c.d - r, c.d + r, c.x - r, c.x + r):
		_statuses(view, int(sq["id"]), fd.get("statuses", {}), fd)
	var a := view.army()
	if float(fd.get("volleys", 0.0)) > 0.0 and absf(float(a["d"]) - c.d) <= r and absf(float(a["x"]) - c.x) <= r:
		view.buff(&"volleys", float(fd["volleys"]), SAMPLE_S + 0.01)


## A part with `at` = delay (Веста IV Sunstride, Сірко III Second Roar): `delay` s after the cast (or at the
## shape's end with `force`), once. Targets: `biggest` (the slam: the biggest hostile <= reach, `radius` u
## around it, every negative gate of the next row takes neg_gate_hits) or `area` (the ult's own area again).
static func _extra_delay(view: KindView, u: Dictionary, c: Clock, force: bool) -> void:
	if not u.get("extra") is Dictionary:
		return
	var ex: Dictionary = u["extra"]
	if str(ex.get("at", "")) != "delay" or c.parts.has("extra") or (not force and c.t < float(ex.get("delay", 0.0))):
		return
	c.parts["extra"] = true
	var d := view.distance()
	match str(ex.get("target", "")):
		"biggest":
			var big := _biggest(view, d, d + float(ex.get("reach", SCREEN)), 1)
			if big.is_empty():
				return
			var t: Dictionary = big[0]
			var td := float(t["d"])
			var tx := float(t["x"])
			var r := float(ex.get("radius", 1.0))
			var rows := _zone(view, ex, td - r, td + r, tx - r, tx + r, float(ex.get("kills", 0.0)),
					float(ex.get("breaks", 0.0)))
			_riders(view, ex, rows)
			var neg := float(ex.get("neg_gate_hits", 0.0))
			if neg > 0.0:
				_neg_gates(view, d, neg)
			view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": td, "x": tx, "r": r, "targets": _ids(rows),
					"s": float(ex.get("leap_s", 0.0))}))
		"area":
			var d0 := c.d + float(u.get("from", 0.0))
			var d1 := c.d + float(u.get("to", 0.0))
			var rows2 := _zone(view, ex, d0, d1, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0,
					float(ex.get("kills", 0.0)), float(ex.get("breaks", 0.0)))
			_riders(view, ex, rows2)
			view.fx(SHAPE_FX, _fxd(u, &"hit", {"d0": d0, "d1": d1, "targets": _ids(rows2)}))


## Every negative gate ("-" or an unfilled charge gate) of the next gate row ahead of `d` takes `hits` hero hits.
static func _neg_gates(view: KindView, d: float, hits: float) -> void:
	var gates := view.gates_in(d, d + SCREEN)
	if gates.is_empty():
		return
	var row0 := float((gates[0] as Dictionary)["d"])
	for g: Dictionary in gates:
		if float(g["d"]) > row0 + 0.01:
			break
		var op := str(g.get("kind", ""))
		if op == "-" or (op == "charge" and float(g.get("value", 0.0)) < 0.0):
			view.hit(int(g["id"]), hits, {"src": "hero", "kind": &"gate"})


# ---- area (Ейра's rime, Сірко's letter)

## A band from `from` to `to` u ahead of the cast point, `width` u at the hero's x (null = the full bridge):
## its front runs from `from` to `to` in `sweep` s (at once when absent) and every squad and structure it
## reaches is hit once (kills, breaks, riders); it stays `duration` s. With `fortress` at the siege the
## fortress takes the breaks. Сірко III: the extra pulse at `delay`.
static func _area_step(view: KindView, u: Dictionary, c: Clock) -> void:
	var d0 := c.d + float(u.get("from", 0.0))
	var d1 := c.d + float(u.get("to", 0.0))
	var x0 := -Balance.BRIDGE_HALF - 2.0
	var x1 := Balance.BRIDGE_HALF + 2.0
	if u.get("width") != null:
		x0 = c.x - float(u["width"]) * 0.5
		x1 = c.x + float(u["width"]) * 0.5
	var sweep := float(u.get("sweep", 0.0))
	var front := d1 if sweep <= 0.0 else lerpf(d0, d1, clampf(c.t / sweep, 0.0, 1.0))
	var done: Dictionary = c.parts["hit"]
	var kills := float(u.get("kills", 0.0))
	var breaks := float(u.get("breaks", 0.0))
	var fm := float(u.get("flying_mult", 1.0))
	var rows: Array = []
	for r: Dictionary in view.squads_in(d0, front, x0, x1):
		var id := int(r["id"])
		if done.has(id):
			continue
		done[id] = true
		if kills > 0.0:
			view.hit(id, kills * (fm if bool(r.get("flying", false)) else 1.0), {"src": "hero", "kind": &"ult"})
		rows.append(r)
	_riders(view, u, rows)
	if breaks > 0.0:
		for h: Dictionary in view.structures_in(d0, front):
			var hid := int(h["id"])
			var hw := float(h.get("hw", 0.5))
			if done.has(hid) or float(h["x"]) + hw < x0 or float(h["x"]) - hw > x1:
				continue
			done[hid] = true
			view.hit(hid, breaks, {"src": "hero", "kind": &"ult"})
		if bool(u.get("fortress", false)) and view.siege() and not c.parts.has("fortress"):
			c.parts["fortress"] = true
			var d := view.distance()
			for f: Dictionary in view.structures_in(d - 0.5, d + Balance.CONTACT + 1.0):
				if str(f["kind"]) == "fortress" and not done.has(int(f["id"])):
					done[int(f["id"])] = true
					view.hit(int(f["id"]), breaks, {"src": "hero", "kind": &"ult"})
	if not rows.is_empty() or c.n == 0:
		view.fx(SHAPE_FX, _fxd(u, &"hit", {"d0": d0, "d1": front, "x0": x0, "x1": x1, "targets": _ids(rows)}))
	c.n += 1
	_extra_delay(view, u, c, false)


# ---- beam (Іскар's comet)

## A corridor `width` u wide down the hero's x (fixed at the cast; `follow`: his live x) from `from` to `to`
## u ahead of the hero for `duration` s, hitting every `tick` s (the first at the cast): kills / breaks, riders
## (form II: Flying x flying_mult, grounded `ground` s; the biggest squad hit is PAINTED: the fx carries it),
## form III: gates in the corridor take gate_hits per tick.
static func _beam_step(view: KindView, u: Dictionary, c: Clock, dt: float) -> void:
	c.tick -= dt
	var tick := maxf(float(u.get("tick", 0.25)), 0.02)
	var ticks := int(round(float(u.get("duration", 0.0)) / tick))
	while c.tick <= 0.0 and c.n < ticks:
		c.tick += tick
		var d := view.distance()
		var x := float(view.army()["x"]) if bool(u.get("follow", false)) else c.x
		var hw := float(u.get("width", 1.0)) * 0.5
		var d0 := d + float(u.get("from", 0.0))
		var d1 := d + float(u.get("to", 0.0))
		var rows := _zone(view, u, d0, d1, x - hw, x + hw, float(u.get("kills", 0.0)), float(u.get("breaks", 0.0)),
				bool(u.get("flying", true)))
		_riders(view, u, rows)
		_gate_hits(view, d0, d1, x - hw, x + hw, float(u.get("gate_hits", 0.0)))
		var more := {"d0": d0, "d1": d1, "x0": x - hw, "x1": x + hw, "targets": _ids(rows)}
		if float(u.get("paint_s", 0.0)) > 0.0 and not rows.is_empty():
			var best: Dictionary = rows[0]
			for r: Dictionary in rows:
				if float(r["n"]) > float(best["n"]):
					best = r
			more["paint"] = int(best["id"])
			more["s"] = float(u["paint_s"])
		c.n += 1
		view.fx(SHAPE_FX, _fxd(u, &"hit", more))


# ---- fan (Люмен's spectrum)

## How many rays of a fan from (x0, d) hit each target: {id: [row, rays]} for squads (at most per_squad_max)
## and structures (`structures` true). Ray k leaves at angle -angle/2 + k angle / (rays - 1) off the run
## axis and reaches `length` u; a target is hit when its span (x +- hw) holds the ray's x at its distance.
static func _fan_hits(view: KindView, u: Dictionary, x0: float, d: float, structures: bool) -> Dictionary:
	var rays := maxi(int(u.get("rays", 1)), 1)
	var half := deg_to_rad(float(u.get("angle", 60.0))) * 0.5
	var length := float(u.get("length", 16.0))
	var cap := int(u.get("per_squad_max", rays))
	var tans: Array[float] = []
	for k in rays:
		var th := 0.0 if rays == 1 else -half + 2.0 * half * float(k) / float(rays - 1)
		tans.append(tan(th))
	var out := {}
	var rows: Array = view.squads_in(d, d + length, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0)
	if structures:
		rows = rows + view.structures_in(d, d + length)
	for r: Dictionary in rows:
		var dd := float(r["d"]) - d
		if dd < 0.0:
			continue
		var sq := r.has("n")
		var hw := float(r.get("hw", SQUAD_HW if sq else 0.5)) + RAY_HW
		var n := 0
		for k in rays:
			var cos_k := 1.0 / sqrt(1.0 + tans[k] * tans[k])
			if dd > length * cos_k:
				continue
			if absf(float(r["x"]) - (x0 + dd * tans[k])) <= hw:
				n += 1
		if sq:
			n = mini(n, cap)
		if n > 0:
			out[int(r["id"])] = [r, n]
	return out


## `rays` rays over `angle` degrees from the cast x and the hero's live distance, `length` u long, for
## `duration` s: every `tick` s (the first at the cast) each ray kills / breaks (a squad takes <= per_squad_max
## rays per tick; Flying x flying_mult); riders on the squads hit (form II BURN); form III: every gate inside
## the fan takes gate_hits. Form IV at the end (_fan_end).
static func _fan_step(view: KindView, u: Dictionary, c: Clock, dt: float) -> void:
	c.tick -= dt
	var tick := maxf(float(u.get("tick", 0.25)), 0.02)
	var ticks := int(round(float(u.get("duration", 0.0)) / tick))
	var kills := float(u.get("kills", 0.0))
	var breaks := float(u.get("breaks", 0.0))
	var fm := float(u.get("flying_mult", 1.0))
	while c.tick <= 0.0 and c.n < ticks:
		c.tick += tick
		var d := view.distance()
		var hits := _fan_hits(view, u, c.x, d, breaks > 0.0)
		var rows: Array = []
		for id: int in hits:
			var e: Array = hits[id]
			var r: Dictionary = e[0]
			if r.has("n"):
				view.hit(id, kills * float(e[1]) * (fm if bool(r.get("flying", false)) else 1.0), {"src": "hero", "kind": &"ult"})
				rows.append(r)
			else:
				view.hit(id, breaks * float(e[1]), {"src": "hero", "kind": &"ult"})
		_riders(view, u, rows)
		var gh := float(u.get("gate_hits", 0.0))
		if gh > 0.0:
			var half := deg_to_rad(float(u.get("angle", 60.0))) * 0.5
			for g: Dictionary in view.gates_in(d, d + float(u.get("length", 16.0))):
				var reach_x := (float(g["d"]) - d) * tan(half) + float(g.get("hw", 1.0))
				if absf(float(g["x"]) - c.x) <= reach_x:
					view.hit(int(g["id"]), gh, {"src": "hero", "kind": &"gate"})
		c.n += 1
		view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": d, "x": c.x, "angle": float(u.get("angle", 60.0)),
				"reach": float(u.get("length", 16.0)), "targets": _ids(rows)}))


## Люмен IV Crown Shards (extra at end, target biggest): the `count` biggest hostiles on the screen take
## kills / breaks each.
static func _fan_end(view: KindView, u: Dictionary, c: Clock) -> void:
	if not u.get("extra") is Dictionary or c.parts.has("extra"):
		return
	var ex: Dictionary = u["extra"]
	if str(ex.get("at", "")) != "end":
		return
	c.parts["extra"] = true
	var d := view.distance()
	var tg: Array[int] = []
	for t: Dictionary in _biggest(view, d, d + SCREEN, int(ex.get("count", 1))):
		var sq := t.has("n")
		view.hit(int(t["id"]), float(ex.get("kills", 0.0)) if sq else float(ex.get("breaks", 0.0)),
				{"src": "hero", "kind": &"ult"})
		tg.append(int(t["id"]))
	view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": d, "x": c.x, "reach": SCREEN, "targets": tg}))


# ---- wall (Вартан's forgewall)

## A knee-high wall `width` u wide, `ahead` u in front, travelling with the army for `duration` s. At the cast
## (_shape_cast) it takes every turret shot at the army (a `wall_turret` ward) and its HP (wall_hp x
## wall_hp_mult) takes the clash losses of the squads that reach it (a `clash` ward). Each squad reaching it
## (not Flying) is hit once: kills + riders (STAGGER). The first barricade or blade it reaches
## (absorb.contact): a barricade takes contact_breaks and the army's contact with it is warded (a
## `wall_contact` ward for every soldier until the army has passed it). Every wall ward ends with the wall
## (_wall_end). Form III: rivet turrets (_rivets). Form IV at the end (_wall_end).
static func _wall_step(view: KindView, u: Dictionary, c: Clock, dt: float) -> void:
	var d := view.distance()
	var a := view.army()
	var ax := float(a["x"])
	var wd := d + float(u.get("ahead", 0.0))
	var hw := float(u.get("width", 6.0)) * 0.5
	var done: Dictionary = c.parts["hit"]
	var rows: Array = []
	for sq: Dictionary in view.squads_in(wd - 0.6, wd + 0.6, ax - hw, ax + hw):
		var id := int(sq["id"])
		if done.has(id) or bool(sq.get("flying", false)):
			continue
		done[id] = true
		view.hit(id, float(u.get("kills", 0.0)), {"src": "hero", "kind": &"ult"})
		rows.append(sq)
	_riders(view, u, rows)
	var ab: Dictionary = u.get("absorb", {}) if u.get("absorb") is Dictionary else {}
	if int(ab.get("contact", 0)) != 0 and not c.parts.has("contact"):
		for h: Dictionary in view.hazards_in(wd - 0.6, wd + 0.6):
			var kind := str(h["kind"])
			if kind != "barricade" and kind != "blade":
				continue
			var hh := float(h.get("hw", 0.5))
			if float(h["x"]) + hh < ax - hw or float(h["x"]) - hh > ax + hw:
				continue
			c.parts["contact"] = int(h["id"])
			if kind == "barricade" and float(u.get("contact_breaks", 0.0)) > 0.0:
				view.hit(int(h["id"]), float(u["contact_breaks"]), {"src": "hero", "kind": &"ult"})
			# The army's rear passes the hazard in about this long (it runs at RUN_SPEED); the wall's end cuts it.
			var rear := float(a["d"]) - float(a["radius"]) * Balance.BLOB_STRETCH
			var pass_s := maxf(float(h["d"]) - rear, 0.0) / Balance.RUN_SPEED + 0.3
			view.grant_ward(&"wall_contact", maxi(ceili(float(a["n"])), 1), pass_s, true)
			rows.append(h)
			break
	if u.get("turrets") is Dictionary:
		_rivets(view, u["turrets"], c, dt, d, ax)
	if not rows.is_empty():
		view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": wd, "x0": ax - hw, "x1": ax + hw, "targets": _ids(rows)}))


## Вартан III Rivet Turrets: every `period` s, `count` homing rivets of `dmg` at the nearest hostiles ahead
## within the hero's attack reach (squads first, Flying too with `flying`; else structures), each with its
## statuses (MARK).
static func _rivets(view: KindView, t: Dictionary, c: Clock, dt: float, d: float, ax: float) -> void:
	var cd := float(c.parts.get("rivet_cd", 0.0)) - dt
	if cd > 0.0:
		c.parts["rivet_cd"] = cd
		return
	c.parts["rivet_cd"] = cd + float(t.get("period", 0.5))
	var reach := 12.0
	var targets: Array = []
	for sq: Dictionary in view.squads_in(d, d + reach, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0):
		if bool(sq.get("flying", false)) and not bool(t.get("flying", false)):
			continue
		targets.append(sq)
	if targets.is_empty():
		for h: Dictionary in view.structures_in(d, d + reach):
			targets.append(h)
	if targets.is_empty():
		return
	targets.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		return absf(float(p["d"]) - d) + absf(float(p["x"]) - ax) < absf(float(q["d"]) - d) + absf(float(q["x"]) - ax))
	var tg: Array[int] = []
	for k in int(t.get("count", 1)):
		var r: Dictionary = targets[k % targets.size()]
		view.hit(int(r["id"]), float(t.get("dmg", 1.0)), {"src": "hero", "kind": &"ult"})
		if r.has("n"):
			_statuses(view, int(r["id"]), t.get("statuses", {}), t)
		tg.append(int(r["id"]))
	view.fx(SHAPE_FX, {"kind": &"rivets", "phase": &"hit", "d": d, "x": ax, "targets": tg})


## The wall's end: its wards end with it (WALL_WARDS cleared: the turret ward, the contact ward of a barricade
## the army is still passing, what is left of its HP). Вартан IV Landslide (extra at end, target strip): the
## wall topples forward, a strip `width` u wide from the wall to `to` u ahead of the hero: kills / breaks.
static func _wall_end(view: KindView, u: Dictionary, c: Clock) -> void:
	if not c.parts.has("wards_off"):
		c.parts["wards_off"] = true
		for wk: StringName in WALL_WARDS:
			view.grant_ward(wk, 0, 0.0, true)
	if not u.get("extra") is Dictionary or c.parts.has("extra"):
		return
	var ex: Dictionary = u["extra"]
	if str(ex.get("at", "")) != "end":
		return
	c.parts["extra"] = true
	var d := view.distance()
	var ax := float(view.army()["x"])
	var hw := float(ex.get("width", u.get("width", 6.0))) * 0.5
	var d0 := d + float(u.get("ahead", 0.0))
	var d1 := d + float(ex.get("to", 10.0))
	var rows := _zone(view, ex, d0, d1, ax - hw, ax + hw, float(ex.get("kills", 0.0)), float(ex.get("breaks", 0.0)))
	_riders(view, ex, rows)
	view.fx(SHAPE_FX, _fxd(u, &"hit", {"d0": d0, "d1": d1, "x0": ax - hw, "x1": ax + hw, "targets": _ids(rows)}))


# ---- ward (Пава's eyes)

## A window of `duration` s on the army: soldiers lost meanwhile (army()["lost"]) are recorded x `record`.
## The cast part (status_at.cast) BRANDs the squads <= reach (form V adds CHILL to FREEZE); forms II / V
## revive champions at the cast. The close: _ward_close.
static func _ward_step(view: KindView, u: Dictionary, c: Clock) -> void:
	var lost := float(view.army().get("lost", 0.0))
	c.rec += maxf(lost - c.lost0, 0.0) * float(u.get("record", 1.0))
	c.lost0 = lost
	if c.t >= float(u.get("duration", 0.0)):
		_ward_close(view, u, c)


## At the close min(recorded, return + return_pool x the revive pool) soldiers come back (the pool pays the
## part above `return`); form IV Eyes Wide: every squad on the screen loses kills, the screen's Phantoms are
## revealed (KindView.REVEAL_PHANTOMS; hidden gates stay hidden) and MARKed.
static func _ward_close(view: KindView, u: Dictionary, c: Clock) -> void:
	if c.parts.has("closed"):
		return
	c.parts["closed"] = true
	var base := float(u.get("return", 0.0))
	var cap := base + float(u.get("return_pool", 0.0)) * c.pool
	var back := floorf(minf(c.rec, cap) + 0.0001)
	c.pool = maxf(c.pool - maxf(back - base, 0.0), 0.0)
	if back > 0.0:
		view.add_soldiers(back, &"ward")
	var d := view.distance()
	var tg: Array[int] = []
	if u.get("extra") is Dictionary and str((u["extra"] as Dictionary).get("at", "")) == "end":
		var ex: Dictionary = u["extra"]
		var reach := SCREEN if float(ex.get("reveal", -1.0)) < 0.0 else float(ex["reveal"])
		for r: Dictionary in view.squads_in(d - 0.5, d + SCREEN, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0):
			var id := int(r["id"])
			if float(ex.get("kills", 0.0)) > 0.0:
				view.hit(id, float(ex["kills"]), {"src": "hero", "kind": &"ult"})
			if bool(ex.get("mark_phantoms", false)) and bool(r.get("phantom", false)):
				view.status(id, &"mark", 0.0)
			tg.append(id)
		if ex.has("reveal"):
			# Eyes Wide reveals the Phantoms only (§6.10), never a hidden gate.
			view.reveal(d - 0.5, d + reach, KindView.REVEAL_PHANTOMS)
	view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": d, "x": float(view.army()["x"]), "charges": int(back), "targets": tg}))


# ---- flock (Ольга's doves)

## The flock's targets, fixed at the cast: every structure of `targets` within `reach` u ahead (barricades,
## turrets; the fortress gate with `fortress` at the siege) and, with "gate" in `targets`, every gate in reach.
static func _flock_targets(view: KindView, u: Dictionary, c: Clock, d: float) -> void:
	var kinds: Array = u.get("targets", [])
	var reach := float(u.get("reach", SCREEN))
	var siege := bool(u.get("fortress", false)) and view.siege()
	for h: Dictionary in view.structures_in(d - 0.5, d + reach):
		var k := str(h["kind"])
		if kinds.has(k) or (k == "fortress" and siege):
			c.ids.append([int(h["id"]), StringName(k), float(h["d"]), float(h["x"])])
	if kinds.has("gate"):
		for g: Dictionary in view.gates_in(d, d + reach):
			c.ids.append([int(g["id"]), &"gate", float(g["d"]), float(g["x"])])


## `waves` waves `gap` s apart (the first at the cast) fly from the hero to every target: a structure takes
## breaks / waves per wave, a gate one hero hit per wave (R8: a gate has a value, not hp); every squad under a
## flight path (PATH_HW u of the line, once per wave) loses kills / waves (R4: kills in total) and BURNs
## burn_s (form II: Flying x flying_mult and grounded `ground` s). The first wave: form IV silences the turrets
## struck silence_s, form V staggers the squads <= status_at.land.radius of every struck structure. Form III:
## one more wave at the biggest squad <= reach. Form V: the afterburn on the fortress gate at the siege, else
## the farthest structure struck.
static func _flock_step(view: KindView, u: Dictionary, c: Clock, dt: float) -> void:
	var waves := maxi(int(u.get("waves", 1)), 1)
	var gap := float(u.get("gap", 0.0))
	var share := 1.0 / float(waves)
	while c.n < waves and c.t >= gap * float(c.n) - 0.0001:
		var d := view.distance()
		var ax := float(view.army()["x"])
		var under := {}
		var tg: Array[int] = []
		for e: Array in c.ids:
			var id := int(e[0])
			var td := float(e[2])
			var tx := float(e[3])
			if e[1] == &"gate":
				view.hit(id, 1.0, {"src": "hero", "kind": &"gate"})
			else:
				view.hit(id, float(u.get("breaks", 0.0)) * share, {"src": "hero", "kind": &"ult"})
			tg.append(id)
			if td <= d:
				continue
			for sq: Dictionary in view.squads_in(d, td, minf(ax, tx) - PATH_HW - SQUAD_HW, maxf(ax, tx) + PATH_HW + SQUAD_HW):
				var lx := lerpf(ax, tx, clampf((float(sq["d"]) - d) / (td - d), 0.0, 1.0))
				if absf(float(sq["x"]) - lx) <= PATH_HW + float(sq.get("hw", SQUAD_HW)):
					under[int(sq["id"])] = sq
		var fm := float(u.get("flying_mult", 1.0))
		var rows: Array = []
		for sid: int in under:
			var sq2: Dictionary = under[sid]
			var fl := bool(sq2.get("flying", false))
			view.hit(sid, float(u.get("kills", 0.0)) * share * (fm if fl else 1.0), {"src": "hero", "kind": &"ult"})
			rows.append(sq2)
		_riders(view, u, rows)
		if c.n == 0:
			_flock_land(view, u, c)
		c.n += 1
		view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": d, "x": ax, "reach": float(u.get("reach", 0.0)), "targets": tg}))
	var ex: Dictionary = u.get("extra", {}) if u.get("extra") is Dictionary else {}
	if c.n >= waves and str(ex.get("at", "")) == "wave" and not c.parts.has("extra") \
			and c.t >= gap * float(waves) - 0.0001:
		c.parts["extra"] = true
		var d2 := view.distance()
		var big := _biggest(view, d2, d2 + float(u.get("reach", SCREEN)), 1, true)
		if not big.is_empty():
			var b: Dictionary = big[0]
			view.hit(int(b["id"]), float(ex.get("kills", 0.0)), {"src": "hero", "kind": &"ult"})
			_statuses(view, int(b["id"]), ex.get("statuses", {}), u)
			view.fx(SHAPE_FX, _fxd(u, &"hit", {"d": float(b["d"]), "x": float(b["x"]), "targets": [int(b["id"])]}))
	if c.n >= waves and u.get("afterburn") is Dictionary:
		_afterburn(view, u["afterburn"], c, dt)


## The first wave's landing parts: form IV silences every struck turret silence_s; form V staggers the
## squads <= radius of every struck structure (status_at.land).
static func _flock_land(view: KindView, u: Dictionary, c: Clock) -> void:
	var sil := float(u.get("silence_s", 0.0))
	var sa: Dictionary = u.get("status_at", {}) if u.get("status_at") is Dictionary else {}
	var land: Dictionary = sa.get("land", {}) if sa.get("land") is Dictionary else {}
	for e: Array in c.ids:
		if sil > 0.0 and e[1] == &"turret":
			view.silence(int(e[0]), sil)
		if not land.is_empty() and e[1] != &"gate":
			var r := float(land.get("radius", 1.0))
			for sq: Dictionary in view.squads_in(float(e[2]) - r, float(e[2]) + r, float(e[3]) - r, float(e[3]) + r):
				_statuses(view, int(sq["id"]), land.get("statuses", {}), land)


## Ольга V Iskorosten: the fortress gate at the siege, else the farthest structure struck, keeps burning
## `duration` s at breaks_per_s.
static func _afterburn(view: KindView, ab: Dictionary, c: Clock, dt: float) -> void:
	var st: Dictionary = c.parts.get("afterburn", {})
	if st.is_empty():
		var best := -1
		var far := -INF
		for e: Array in c.ids:
			if e[1] == &"gate":
				continue
			if e[1] == &"fortress":
				best = int(e[0])
				break
			if float(e[2]) > far:
				far = float(e[2])
				best = int(e[0])
		st = {"id": best, "left": float(ab.get("duration", 0.0)) if best >= 0 else 0.0}
		c.parts["afterburn"] = st
	if float(st["left"]) <= 0.0:
		return
	var step := minf(dt, float(st["left"]))
	st["left"] = float(st["left"]) - dt
	view.hit(int(st["id"]), float(ab.get("breaks_per_s", 0.0)) * step, {"src": "hero", "kind": &"ult"})


# ------------------------------------------------------------------ the attack of a v3 hero (§6 Run lines)

## Shots of the next volley of a v3 row: `targets` + the `ray` proc's extra on its every-Nth cast (Люмен
## beat 3). Read-only (attack() counts the cast); the owner adds its power-gate shots.
static func volley_shots(view: KindView, def: Dictionary) -> int:
	var atk: Dictionary = def.get("atk", {})
	var n := int(def.get("targets", 1))
	var ray: Dictionary = (atk.get("procs", {}) as Dictionary).get("ray", {})
	if not ray.is_empty() and (view.clock().casts + 1) % maxi(int(ray.get("every", 1)), 1) == 0:
		n += int(ray.get("targets", 1))
	return n


## True when proc `p` (every-Nth by casts; `on` triggers are handled where they happen) fires on cast `no`.
static func _due(p: Dictionary, no: int) -> bool:
	return not p.has("on") and p.has("every") and no % maxi(int(p["every"]), 1) == 0


## True when the attack status `st` at proc `p` (1.0 = every hit, 0.5 = every 2nd ...) lands on this hit
## (a deterministic counter per status: both views count the same hits).
static func _proc_hit(c: Clock, st: String, p: float) -> bool:
	if p <= 0.0:
		return false
	var key := "st_" + st
	var n := int(c.procs.get(key, 0)) + 1
	c.procs[key] = n
	return n % maxi(int(round(1.0 / minf(p, 1.0))), 1) == 0


## One volley of a v3 hero's attack (HeroData.ATTACKS at the row's Attack rank). `targets` = the owner's
## targeting for this volley, nearest first, unique ({id, kind: squad | gate | barricade | turret | geode | crate
## | fortress, d, x, op (a gate's face), flying}); `shots` = the shots of the volley (volley_shots + power
## gates: spare shots hit the last target again, a beam's spare rays converge on the first for x focus_mult);
## `dmg` = hero damage per hit (every multiplier the owner applies: damage gates, Reinforcements, the Prism).
## Squad hits: dmg + splash, x Cleave on the squad in the clash, the attack's statuses by proc, `pierce` more
## squads behind in the corridor; structures x structure_mult; gates take hero hits (x charge_mult on a charge
## face; the row reveal with reveal_row). Every-Nth procs by cast:
## throw (the shot goes to the farthest hostile <= reach for x mult), comet / lance (the corridor, x mult),
## dove (the farthest structure <= reach, else the biggest squad), fork (a plain volley chains on, _fork), mend
## (soldiers from the revive pool), eye, double, burst, mark, strip; on-event procs: echo (structure), burst
## (break / structure), bounce (kill), flinch (wipe). Sends ATTACK_FX. From V3_PHASE the starters attack through
## it too (their §6 rules: Горан structure_mult / STAGGER / echo / burst, Руді grounding / fork / lance, Мейра
## BRAND / bounce / mark, the row reveal and charge gates x1.5); at phase 0 they keep their Meta-1 path.
static func attack(view: KindView, def: Dictionary, targets: Array, shots: int, dmg: float) -> void:
	if targets.is_empty():
		return
	var c := view.clock()
	var atk: Dictionary = def.get("atk", {})
	var procs: Dictionary = atk.get("procs", {})
	c.casts += 1
	var no := c.casts
	var pattern: StringName = def.get("attack", ATTACK_DART)
	var proc := &""
	var shot_targets: Array = targets.duplicate()
	var mult := 1.0
	var d := view.distance()
	var hx := float(view.army()["x"])
	var reach := float(def.get("range", 12.0))
	var corridor := float(def.get("corridor", Balance.CORRIDOR))
	# Every-Nth procs that redirect the volley.
	if procs.has("throw") and _due(procs["throw"], no):
		var tp: Dictionary = procs["throw"]
		var far := _farthest(view, d, d + float(tp.get("reach", reach)), false)
		if not far.is_empty():
			shot_targets = [far]
			mult = float(tp.get("mult", 1.0))
			proc = &"throw"
	elif procs.has("dove") and _due(procs["dove"], no):
		var dp: Dictionary = procs["dove"]
		var to := _farthest(view, d, d + float(dp.get("reach", reach)), true)
		if to.is_empty() and str(dp.get("fallback", "")) == "biggest_squad":
			var big := _biggest(view, d, d + float(dp.get("reach", reach)), 1, true)
			to = _as_target(big[0]) if not big.is_empty() else {}
		if not to.is_empty():
			shot_targets = [to]
			proc = &"dove"
	var lance := ""
	for lk: String in ["comet", "lance"]:
		if procs.has(lk) and _due(procs[lk], no):
			lance = lk
	if lance != "":
		proc = StringName(lance)
	var hit_ids: Array[int] = []
	var base := shot_targets.size()
	var n_shots := maxi(shots, 1) if proc == &"" else 1
	if lance != "":
		var lp: Dictionary = procs[lance]
		var rails := maxi(int(lp.get("rails", 1)), 1)
		for rk in rails:
			var rx := hx + (0.0 if rails == 1 else (float(rk) - 0.5 * float(rails - 1)) * 2.0 * float(lp.get("rail_dx", 0.0)))
			for sq: Dictionary in view.squads_in(d - 0.5, d + reach, rx - corridor, rx + corridor):
				var got := view.hit(int(sq["id"]), (dmg + float(def.get("splash", 0.0))) * float(lp.get("mult", 1.0)),
						{"src": "hero", "kind": &"attack"})
				_attack_statuses(view, c, def, int(sq["id"]), lp)
				_on_kill(view, def, c, sq, got)
				hit_ids.append(int(sq["id"]))
			for h: Dictionary in view.structures_in(d - 0.5, d + reach):
				if absf(float(h["x"]) - rx) <= corridor + float(h.get("hw", 0.5)):
					view.hit(int(h["id"]), dmg * float(lp.get("mult", 1.0)) * float(atk.get("structure_mult", 1.0)),
							{"src": "hero", "kind": &"attack"})
					hit_ids.append(int(h["id"]))
	else:
		# A throw or a dove is not a swing: no splash.
		var plain := proc == &""
		# Every shot of the volley lands, the power gates' too (the Meta-1 rule: shots beyond the targets in reach
		# hit the last one again; only Meta-1's chained Forked Fox shot needed another target, and on a v3 row the
		# fork is a proc).
		for k in n_shots:
			if k >= base and pattern == ATTACK_BEAM and float(atk.get("focus_mult", 1.0)) > 1.0:
				# Spare rays converge on the first target (x focus_mult instead of one more ray): damage only.
				_hit_one(view, def, c, shot_targets[0], dmg * (float(atk["focus_mult"]) - 1.0), d, false, false)
				continue
			var t: Dictionary = shot_targets[mini(k, base - 1)]
			_hit_one(view, def, c, t, dmg * mult, d, plain)
			hit_ids.append(int(t["id"]))
			if procs.has("double") and _due(procs["double"], no) and str(t["kind"]) == "squad":
				_hit_one(view, def, c, t, dmg * mult, d)
				proc = &"double"
			if str(t["kind"]) == "squad" and int(atk.get("pierce", 0)) != 0:
				_pierce(view, def, c, t, int(atk["pierce"]), dmg * mult, d, hx)
		var first: Dictionary = shot_targets[0]
		if proc == &"throw" and str(first["kind"]) == "squad":
			var tp2: Dictionary = procs["throw"]
			if float(tp2.get("weaken", 0.0)) > 0.0:
				view.hold(int(first["id"]), float(tp2.get("weaken_s", 3.0)), float(tp2["weaken"]))
		if proc == &"dove":
			_statuses(view, int(first["id"]), (procs["dove"] as Dictionary).get("statuses", {}), procs["dove"])
		if plain and procs.has("fork") and _due(procs["fork"], no) \
				and _fork(view, def, c, procs["fork"], first, dmg, d, hit_ids):
			proc = &"fork"
	_volley_procs(view, c, procs, no, shot_targets[0])
	view.fx(ATTACK_FX, {"pattern": pattern, "targets": hit_ids, "d": float((shot_targets[0] as Dictionary)["d"]),
			"x": float((shot_targets[0] as Dictionary)["x"]), "proc": proc})


## Руді's Forked Fox (the `fork` proc on its every-Nth cast, §6.3): the dart chains from squad `t` to `targets`
## more squads within `r` u (nearest first, none struck this volley), `chains` jumps, each from the last squad
## it struck. A forked hit is a hero hit of `n` (its riders: grounding, the attack's statuses) and carries the
## fork's own statuses by proc (beat 9 Stormcaller: JOLT). Adds the squads struck to `hit_ids`; true when one
## was. On a v3 row it replaces the Meta-1 Forked Fox aspect's extra shot.
static func _fork(view: KindView, def: Dictionary, c: Clock, fp: Dictionary, t: Dictionary, n: float, d: float,
		hit_ids: Array[int]) -> bool:
	if str(t["kind"]) != "squad":
		return false
	var r := float(fp.get("r", 4.0))
	var fd := float(t["d"])
	var fx := float(t["x"])
	var struck := false
	for j in maxi(int(fp.get("chains", 1)), 1):
		var near: Array = []
		for sq: Dictionary in view.squads_in(fd - r, fd + r, fx - r, fx + r):
			if not hit_ids.has(int(sq["id"])):
				near.append([absf(float(sq["d"]) - fd) + absf(float(sq["x"]) - fx), sq])
		if near.is_empty():
			break
		near.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		for k in mini(maxi(int(fp.get("targets", 1)), 1), near.size()):
			var row := _as_target(near[k][1])
			_hit_one(view, def, c, row, n, d)
			_attack_statuses(view, c, def, int(row["id"]), fp)
			hit_ids.append(int(row["id"]))
			struck = true
			fd = float(row["d"])
			fx = float(row["x"])
	return struck


## A row of squads_in (no "kind") as an attack target row.
static func _as_target(r: Dictionary) -> Dictionary:
	if r.has("kind") and not r.has("n"):
		return r
	var out := r.duplicate()
	out["kind"] = "squad"
	return out


## One hit of the volley on target row `t` (`splash`: + the row's splash on a squad; `riders`: the attack's
## statuses, grounding and on-event procs).
static func _hit_one(view: KindView, def: Dictionary, c: Clock, t: Dictionary, n: float, d: float, splash := true,
		riders := true) -> void:
	var atk: Dictionary = def.get("atk", {})
	var id := int(t["id"])
	match str(t["kind"]):
		"gate":
			var hits := float(def.get("charge_mult", 1.0)) if str(t.get("op", "")) == "charge" else 1.0
			view.hit(id, hits, {"src": "hero", "kind": &"gate"})
			if bool(def.get("reveal_row", false)):
				view.reveal(float(t["d"]) - 0.01, float(t["d"]) + 0.01, KindView.REVEAL_GATES)
				if int(atk.get("reveal_rows", 1)) > 1:
					var next := view.gates_in(float(t["d"]) + 0.1, float(t["d"]) + SCREEN)
					if not next.is_empty():
						var nd := float((next[0] as Dictionary)["d"])
						view.reveal(nd - 0.01, nd + 0.01, KindView.REVEAL_GATES)
		"squad":
			var cleave := float(def.get("cleave", 1.0))
			var k := n + (float(def.get("splash", 0.0)) if splash else 0.0)
			if cleave > 1.0 and view.in_fight() and float(t["d"]) <= d + Balance.CONTACT + 0.6:
				k *= cleave
			var got := view.hit(id, k, {"src": "hero", "kind": &"attack"})
			if not riders:
				return
			_attack_statuses(view, c, def, id, atk)
			if float(atk.get("ground", 0.0)) > 0.0 and bool(t.get("flying", false)):
				var at := float(c.grounded.get(id, -1.0))
				if c.now >= at:
					view.ground(id, float(atk["ground"]))
					c.grounded[id] = c.now + float(atk.get("reground", 0.0))
			_on_kill(view, def, c, t, got)
		_:
			# Горан's structures x1.5: the echo repeats a share of, and a break is weighed by, what landed.
			var hit_n := n * float(atk.get("structure_mult", 1.0))
			view.hit(id, hit_n, {"src": "hero", "kind": &"attack"})
			if riders:
				_on_structure(view, def, c, t, hit_n)


## The attack's statuses (`statuses` of `p`: id -> proc per hit; lengths `<status>_s`) on squad `id`.
static func _attack_statuses(view: KindView, c: Clock, def: Dictionary, id: int, p: Dictionary) -> void:
	var sts: Dictionary = p.get("statuses", {}) if p.get("statuses") is Dictionary else {}
	for st: String in sts:
		if _proc_hit(c, st, float(sts[st])):
			view.status(id, StringName(st), float(p.get(st + "_s", p.get("mark_s", 0.0) if st == "mark" else 0.0)))


## `pierce` more squads behind squad `t` in the hero's corridor take the hit too (-1 = every squad in range).
static func _pierce(view: KindView, def: Dictionary, c: Clock, t: Dictionary, pierce: int, n: float, d: float,
		hx: float) -> void:
	var corridor := float(def.get("corridor", Balance.CORRIDOR))
	# A view may answer with a shared read-only empty array: sort a copy.
	var rows := view.squads_in(float(t["d"]) + 0.01, d + float(def.get("range", 12.0)), hx - corridor, hx + corridor)
	if rows.is_empty():
		return
	rows = rows.duplicate()
	rows.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	var left := pierce
	for r: Dictionary in rows:
		if int(r["id"]) == int(t["id"]):
			continue
		if left == 0:
			break
		left -= 1
		var got := view.hit(int(r["id"]), n + float(def.get("splash", 0.0)), {"src": "hero", "kind": &"attack"})
		_attack_statuses(view, c, def, int(r["id"]), def.get("atk", {}))
		_on_kill(view, def, c, r, got)


## On-event procs of a squad hit that killed: bounce (on kill: one more squad <= r takes 1), flinch (on a wipe:
## the next squad in the lane is STAGGERed; its `needs` (the wiped squad was Branded) is not checked: the views
## answer no statuses, and every hit of Сірко Brands anyway).
static func _on_kill(view: KindView, def: Dictionary, _c: Clock, t: Dictionary, got: int) -> void:
	if got <= 0:
		return
	var procs: Dictionary = (def.get("atk", {}) as Dictionary).get("procs", {})
	var wiped := float(t.get("n", 0.0)) - float(got) <= 0.001
	if procs.has("bounce") and str((procs["bounce"] as Dictionary).get("on", "")) == "kill":
		var bp: Dictionary = procs["bounce"]
		var r := float(bp.get("r", 3.0))
		var td := float(t["d"])
		var tx := float(t["x"])
		var left := int(bp.get("targets", 1))
		for sq: Dictionary in view.squads_in(td - r, td + r, tx - r, tx + r):
			if left <= 0:
				break
			if int(sq["id"]) == int(t["id"]):
				continue
			left -= 1
			view.hit(int(sq["id"]), 1.0, {"src": "hero", "kind": &"attack"})
	if wiped and procs.has("flinch"):
		var fp: Dictionary = procs["flinch"]
		var d := view.distance()
		var cor := float(def.get("corridor", Balance.CORRIDOR))
		var hx := float(view.army()["x"])
		var far := d + float(def.get("range", 12.0))
		for sq2: Dictionary in view.squads_in(float(t["d"]) + 0.01, far, hx - cor, hx + cor):
			if int(sq2["id"]) != int(t["id"]):
				_statuses(view, int(sq2["id"]), fp.get("statuses", {}), fp)
				break


## On-event procs of a structure hit: echo (every Nth structure hit repeats `share` on the next structure
## <= reach behind), burst (on a break / a structure hit: `breaks` or `dmg` on the structures <= r).
static func _on_structure(view: KindView, def: Dictionary, c: Clock, t: Dictionary, n: float) -> void:
	var procs: Dictionary = (def.get("atk", {}) as Dictionary).get("procs", {})
	if procs.is_empty():
		return
	var td := float(t["d"])
	if procs.has("echo"):
		var ep: Dictionary = procs["echo"]
		var k := int(c.procs.get("echo", 0)) + 1
		c.procs["echo"] = k
		if k % maxi(int(ep.get("every", 1)), 1) == 0:
			for h: Dictionary in view.structures_in(td + 0.01, td + float(ep.get("reach", 4.0))):
				view.hit(int(h["id"]), n * float(ep.get("share", 0.5)), {"src": "hero", "kind": &"attack"})
				break
	if procs.has("burst") and str((procs["burst"] as Dictionary).get("on", "")) in ["structure", "break"]:
		var bp: Dictionary = procs["burst"]
		var r := float(bp.get("r", 1.5))
		var v := float(bp.get("breaks", bp.get("dmg", 0.0)))
		if str(bp["on"]) == "break" and float(t.get("hp", 1.0)) > n:
			return
		for h2: Dictionary in view.structures_in(td - r, td + r):
			if int(h2["id"]) != int(t["id"]) and absf(float(h2["x"]) - float(t["x"])) <= r + float(h2.get("hw", 0.5)):
				view.hit(int(h2["id"]), v, {"src": "hero", "kind": &"attack"})


## The volley's every-Nth side procs: mend (soldiers from the revive pool), eye (planted on the squad hit; beat 6
## reveals a Phantom), burst (`kills` on the squads <= r of the target + statuses), mark (MARK the target, the
## Phantoms <= reveal u revealed), strip (a burning strip across the bridge `depth` u at the target).
static func _volley_procs(view: KindView, c: Clock, procs: Dictionary, no: int, t: Dictionary) -> void:
	if procs.has("mend") and _due(procs["mend"], no):
		var want := float((procs["mend"] as Dictionary).get("soldiers", 1))
		if c.pool >= want:
			c.pool -= want
			view.add_soldiers(want, &"mend")
	if procs.has("eye") and _due(procs["eye"], no) and str(t["kind"]) == "squad":
		var ep: Dictionary = procs["eye"]
		c.eyes[int(t["id"])] = [float(t["d"]), float(ep.get("soldiers", 1))]
		_statuses(view, int(t["id"]), ep.get("statuses", {}), ep)
		if bool(ep.get("reveals", false)):
			# Пава beat 6 Watchful: the Eye shows a Phantom for what it is.
			view.reveal(float(t["d"]) - 0.5, float(t["d"]) + 0.5, KindView.REVEAL_PHANTOMS)
	if procs.has("burst") and _due(procs["burst"], no):
		var bp: Dictionary = procs["burst"]
		var r := float(bp.get("r", 1.5))
		var td := float(t["d"])
		var tx := float(t["x"])
		for sq: Dictionary in view.squads_in(td - r, td + r, tx - r, tx + r):
			view.hit(int(sq["id"]), float(bp.get("kills", 0.0)), {"src": "hero", "kind": &"attack"})
			_statuses(view, int(sq["id"]), bp.get("statuses", {}), bp)
	if procs.has("mark") and _due(procs["mark"], no) and str(t["kind"]) == "squad":
		var mp: Dictionary = procs["mark"]
		view.status(int(t["id"]), &"mark", float(mp.get("mark_s", 3.0)))
		if float(mp.get("reveal", 0.0)) > 0.0:
			var rv := float(mp["reveal"])
			view.reveal(float(t["d"]) - rv, float(t["d"]) + rv, KindView.REVEAL_PHANTOMS)
	if procs.has("strip") and _due(procs["strip"], no):
		var sp: Dictionary = procs["strip"]
		var td2 := float(t["d"])
		for sq2: Dictionary in view.squads_in(td2, td2 + float(sp.get("depth", 3.0)), -Balance.BRIDGE_HALF - 2.0,
				Balance.BRIDGE_HALF + 2.0):
			_statuses(view, int(sq2["id"]), sp.get("statuses", {}), sp)


## The farthest hostile within [d0, d1] across the bridge (`structures_only`: structures and gates; the dove
## flies to walls, gates and the fortress gate), {} when none.
static func _farthest(view: KindView, d0: float, d1: float, structures_only: bool) -> Dictionary:
	var best: Dictionary = {}
	var rows: Array = view.structures_in(d0, d1).duplicate()
	if structures_only:
		for g: Dictionary in view.gates_in(d0, d1):
			var gr := g.duplicate()
			gr["kind"] = "gate"
			gr["op"] = str(g.get("kind", ""))
			rows.append(gr)
	else:
		rows = rows + view.squads_in(d0, d1, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0)
	for r: Dictionary in rows:
		if best.is_empty() or float(r["d"]) > float(best["d"]):
			best = r
	if best.is_empty():
		return {}
	var out := best.duplicate()
	if best.has("n"):
		out["kind"] = "squad"
	return out


# ------------------------------------------------------------------ the hero kind's timers (v3 rows)

## One step of a v3 hero's own state (owners call it every step after the ult): the Healer revive pool
## (mend_share of every soldier lost), the loss samples of the army_loss policy, Pava's Eyes (a wiped squad
## gives its soldiers back from the pool), Вартан's ward-drones (`drones` drone wards every drone_recharge
## s, each recharge replacing the last; beat 6: a contact ward every drone_contact_cd s), Pava's beat 9 guard,
## Пава's Awakening (a fallen champion stands up again after 11 - rank s at 30% HP, once per level). No-op on a
## Meta-1 row.
static func hero_step(view: KindView, def: Dictionary, dt: float) -> void:
	if not scaled(def):
		return
	var c := view.clock()
	c.now += dt
	var lost := float(view.army().get("lost", 0.0))
	if c.seen_lost < 0.0:
		c.seen_lost = lost
	var dl := maxf(lost - c.seen_lost, 0.0)
	c.seen_lost = lost
	if dl > 0.0 and float(def.get("mend_share", 0.0)) > 0.0:
		c.pool += dl * float(def["mend_share"])
	var cd := float(c.cds.get("sample", 0.0)) - dt
	if cd <= 0.0:
		cd += SAMPLE_S
		c.losses.append(Vector2(c.now, lost))
		while c.losses.size() > 1 and c.losses[0].x < c.now - LOSS_WINDOW - SAMPLE_S:
			c.losses.remove_at(0)
		_eyes(view, c)
		_awakening(view, def, c)
	c.cds["sample"] = cd
	# The row's cached timers (_v3_row: drones, drone_recharge, drone_contact_cd, guard_cd, guard_kind).
	var drones := int(def.get("drones", 0))
	if drones > 0:
		# Вартан's ward-drones: `drone` wards (a turret shot spends the wall's first, then these).
		_every(view, c, "drones", float(def["drone_recharge"]), dt, &"drone", drones)
		if float(def["drone_contact_cd"]) > 0.0:
			_every(view, c, "drone_contact", float(def["drone_contact_cd"]), dt, &"contact", 1)
	if float(def.get("guard_cd", 0.0)) > 0.0:
		_every(view, c, "guard", float(def["guard_cd"]), dt, def["guard_kind"], 1)
	view.store_clock(c)


## Grants `charges` wards of `kind` every `period` s, each grant replacing what the last one left (an unspent
## charge lapses at the next recharge: drones and guards never bank).
static func _every(view: KindView, c: Clock, key: String, period: float, dt: float, kind: StringName,
		charges: int) -> void:
	var left := float(c.cds.get(key, 0.0)) - dt
	if left <= 0.0:
		left += period
		view.grant_ward(kind, charges, period, true)
	c.cds[key] = left


## Pava's Eyes: a squad that carried one and is gone (wiped) gives its soldiers back from the revive pool.
static func _eyes(view: KindView, c: Clock) -> void:
	if c.eyes.is_empty():
		return
	for id: int in c.eyes.keys():
		var e: Array = c.eyes[id]
		var ed := float(e[0])
		var alive := false
		for sq: Dictionary in view.squads_in(ed - 0.05, ed + 0.05, -Balance.BRIDGE_HALF - 2.0, Balance.BRIDGE_HALF + 2.0):
			if int(sq["id"]) == id:
				alive = true
				break
		if alive:
			if view.distance() > ed + SCREEN:
				c.eyes.erase(id)
			continue
		c.eyes.erase(id)
		var n := minf(float(e[1]), floorf(c.pool + 0.0001))
		if n > 0.0:
			c.pool -= n
			view.add_soldiers(n, &"eye")


## Пава's Awakening «Пробуджені очі» (AWAKEN_REVIVE; born, rank 1..4): a fallen champion stands up again after
## 10 / 9 / 8 / 7 s at 30% HP, once per level (a Healer-hero revive, §6.10).
static func _awakening(view: KindView, def: Dictionary, c: Clock) -> void:
	# The row's cached wait and HP share (_v3_row: awaken_wait 0 = no reviving Awakening).
	var wait := float(def.get("awaken_wait", 0.0))
	if wait <= 0.0 or c.revived:
		return
	for m: Dictionary in view.champions():
		var id := str(m["id"])
		if bool(m.get("alive", true)):
			c.fallen.erase(id)
			continue
		if not c.fallen.has(id):
			c.fallen[id] = c.now
		elif c.now - float(c.fallen[id]) >= wait and view.revive_champion(StringName(id), float(def["awaken_hp"])):
			c.revived = true
			return


# ------------------------------------------------------------------ auto-fire policy (§10.4)

## The auto-fire policy (bot, level_check, LevelSim): 1.0 = fire now, 0.0 = hold. A v3 row: always in a
## clash or the fortress siege (the owner's rule, 10.10: no kind sits on a full charge through a fight), else
## the §10.4 policy of HeroData.ULTS[kind] (fire when ANY of its POLICY_WHEN conditions holds). A Meta-1 row
## (phase 0): always in a clash or the siege; else when the squads overlapping the blob's lane within
## `reach` hold >= max(8, 35% of the army) hp (the fortress counts 99); a `guard` kind also fires for
## its armour when a hazard is close ahead of a decent army.
static func ult_worth(kind: StringName, view: KindView, u: Dictionary) -> float:
	if u.has("v3"):
		if view.in_fight():
			return 1.0
		var pol: Dictionary = (HeroData.ULTS.get(String(kind), {}) as Dictionary).get("policy", {})
		for cond: Dictionary in pol.get("any", []):
			if _policy_fires(view, cond, u):
				return 1.0
		return 0.0
	if view.in_fight():
		return 1.0
	var mp: Dictionary = ult_row(kind).get("policy", {"reach": -1.0})
	var reach := float(mp["reach"])
	if reach < 0.0:
		reach = float(u.get("range", 13.0))
	var n := float(view.army()["n"])
	if mp.has("guard"):
		var g: Array = mp["guard"]
		if n >= float(g[0]) and view.hazard_near(float(g[1])):
			return 1.0
	return 1.0 if view.threat_ahead(reach) >= maxf(8.0, n * 0.35) else 0.0


## One POLICY_WHEN condition (HeroData.POLICY_WHEN) through the view.
static func _policy_fires(view: KindView, cond: Dictionary, u: Dictionary) -> bool:
	var d := view.distance()
	var a := view.army()
	var wide := Balance.BRIDGE_HALF + 2.0
	match str(cond.get("when", "")):
		"squads":
			var rows := view.squads_in(d + float(cond.get("from", 0.0)), d + float(cond["reach"]), -wide, wide)
			return rows.size() >= int(cond.get("count", 1))
		"flying", "armored":
			var key := str(cond["when"])
			for r: Dictionary in view.squads_in(d, d + float(cond["reach"]), -wide, wide):
				if bool(r.get(key, false)):
					return true
			return false
		"lane":
			var hx := float(a["x"])
			var lane := float(u.get("width", Balance.CORRIDOR * 2.0)) * 0.5
			var n := view.squads_in(d, d + float(cond["reach"]), hx - lane, hx + lane).size()
			for h: Dictionary in view.structures_in(d, d + float(cond["reach"])):
				if absf(float(h["x"]) - hx) <= lane + float(h.get("hw", 0.5)):
					n += 1
			return n >= int(cond.get("count", 1))
		"fan":
			var n2 := 0
			for id: int in _fan_hits(view, u, float(a["x"]), d, false):
				n2 += 1
			return n2 >= int(cond.get("count", 1))
		"structures":
			var kinds: Array = cond.get("kinds", [])
			var n3 := 0
			for h2: Dictionary in view.structures_in(d, d + float(cond["reach"])):
				if kinds.is_empty() or kinds.has(str(h2["kind"])):
					n3 += 1
			return n3 >= int(cond.get("count", 1))
		"hazards":
			var kinds2: Array = cond.get("kinds", [])
			for h3: Dictionary in view.hazards_in(d, d + float(cond["reach"])):
				var hk := str(h3["kind"])
				# A geode is a reward, not a hazard.
				if (kinds2.is_empty() and hk != "geode") or kinds2.has(hk):
					return true
			return false
		"gate_row":
			var gates := view.gates_in(d, d + float(cond["reach"]))
			if gates.is_empty():
				return false
			if not bool(cond.get("hidden", false)):
				return true
			var row0 := float((gates[0] as Dictionary)["d"])
			for g: Dictionary in gates:
				if float(g["d"]) <= row0 + 0.01 and bool(g.get("hidden", false)):
					return true
			return false
		"clash":
			if view.in_fight():
				return true
			var r := float(a["radius"])
			var ahead := Balance.CONTACT + float(cond.get("within", 1.0)) * Balance.RUN_SPEED
			return not view.squads_in(d, d + ahead, float(a["x"]) - r, float(a["x"]) + r).is_empty()
		"siege":
			return view.siege()
		"army_loss":
			var c := view.clock()
			if c.losses.is_empty():
				return false
			var lost := float(a.get("lost", 0.0))
			var win := float(cond.get("window", LOSS_WINDOW))
			var then := lost
			for p: Vector2 in c.losses:
				if p.x >= c.now - win - 0.001:
					then = p.y
					break
			var gone := lost - then
			return gone > 0.0 and gone >= float(cond.get("share", 0.25)) * (float(a["n"]) + gone)
		"champion_down":
			for m: Dictionary in view.champions():
				if not bool(m.get("alive", true)):
					return true
			return false
	return false
