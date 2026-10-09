class_name HeroKinds
extends RefCounted
## Hero behaviour as data + one rules implementation (heroes design §10.4, critique X32). Run and
## LevelSim no longer branch on hero ids: they look the hero up here (attack pattern, ult kind)
## and drive the ult through the same static rules over a KindView (RunKindView: nodes, VFX and
## signals; SimKindView: LevelSim arrays). The numbers stay where they were (Balance.HEROES[id]
## and its `ult` block) until WS-A's HeroData replaces that table; this file holds only the
## behaviour shape of each kind.
##
## Phase H0: only the three starters exist (Руді `bolt` = storm, Горан `titan` = quake, Мейра
## `seer` = rift) and the rules reproduce Meta-1 exactly (level_check and autotests identical).
## The new hero kinds of §6 (anchor, rime, comet, sunglaive, forgewall, spectrum, eyes) and the
## §10.4 bot policy table arrive in H2 behind the phase flag (phase()).

## The phase the heroes feature runs at: 0 = shipped Meta-1 (2.2.x), 1 = rules and data,
## 2 = champions in the run, 3 = meta UI on. The one flag is EconData.HEROES_PHASE (WS-B).
## The phase from which champions take part in runs (§13.2 H2).
const CHAMPIONS_PHASE := 2

## Ult shapes: `timed` runs `duration` s and hits everything within `range` every `tick` s
## (gates in range take a hero hit per tick); `waves` sends `waves` bands `spacing` u deep,
## `gap` s apart, from the cast point (no gate hits).
const TIMED := &"timed"
const WAVES := &"waves"

## Attack patterns (the run's shot VFX; the rules themselves are data in Balance.HEROES:
## targets, splash, reveal_row, charge_mult, aspect).
const ATTACK_DART := &"dart"        ## Руді: lightning darts
const ATTACK_BOULDER := &"boulder"  ## Горан: a heavy throw with splash
const ATTACK_ORBS := &"orbs"        ## Мейра: twin homing orbs

## Hero id -> kind row. Unknown ids fall back to DEFAULT_KIND (Meta-1's else-branch was Titan).
const KINDS := {
	"bolt": {"attack": ATTACK_DART, "ult": &"storm"},
	"titan": {"attack": ATTACK_BOULDER, "ult": &"quake"},
	"seer": {"attack": ATTACK_ORBS, "ult": &"rift"},
}
const DEFAULT_KIND := "titan"

## Ult kind -> behaviour. `first_tick`: the tick clock at the cast (a timed ult with 0 hits on
## its first step). `slows`: hazards, turrets and clashing squads run at (1 - ult.slow) while it
## lasts. `policy`: the auto-fire rule (ult_worth): `reach` (u ahead; < 0 = the ult's range),
## `guard` = [min army, hazard ahead u]: also fire when a hazard is that close to a decent army
## (the quake's hazard immunity).
const ULTS := {
	&"storm": {"shape": TIMED, "first_tick": 0.0, "slows": false, "policy": {"reach": -1.0}},
	&"rift": {"shape": TIMED, "first_tick": 0.25, "slows": true, "policy": {"reach": -1.0}},
	&"quake": {"shape": WAVES, "first_tick": 0.43, "slows": false, "armor": true,
			"policy": {"reach": 13.0, "guard": [25.0, 6.0]}},
}

## Forked Fox (Руді's default Aspect): every FORK_EVERY-th cast chains to one more target.
const FORK_ASPECT := "forked_fox"
const FORK_EVERY := 3

## How long the cast pose of a `waves` ult plays (the hero model; timed ults pose for their
## duration).
const WAVES_CAST_POSE := 1.6


## The ult clock both Run and LevelSim keep: `left` s of a timed ult, the `tick` countdown,
## the band index of a waves ult (99 = idle) and the distance it was cast at.
class Clock extends RefCounted:
	var left := 0.0
	var tick := 0.0
	var wave := 99
	var wave_d := 0.0

	func active() -> bool:
		return left > 0.0 or wave < 99


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


## True when a cast of a Forked Fox hero numbered `cast_no` (1 = the first cast) chains once more.
static func forks(aspect: String, cast_no: int) -> bool:
	return aspect == FORK_ASPECT and cast_no % FORK_EVERY == 0


# ------------------------------------------------------------------ ult rules

## Starts the ult of `kind` (numbers `u` = Balance.HEROES[id].ult) on the view's clock. The
## caller has already spent the charge; fx(&"ult_cast") follows with the clock set.
static func ult_cast(view: KindView, kind: StringName, u: Dictionary) -> void:
	var k := ult_row(kind)
	var c := view.clock()
	if k["shape"] == TIMED:
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


## Advances a running ult by `dt` (no-op when idle). Hits go through view.area_hit with the ult's
## kills / breaks x view.ult_power() (Ult Rank). fx events, in order: ult_step (every step of a
## timed ult), ult_tick before and ult_tick_done after each tick's hit, ult_end when a timed ult
## ends; ult_wave {near, spacing, wave} before each band's hit, ult_waves_end after the last band.
static func ult_step(view: KindView, kind: StringName, u: Dictionary, dt: float) -> void:
	var c := view.clock()
	if c.left > 0.0:
		c.left -= dt
		c.tick -= dt
		view.store_clock(c)
		view.fx(&"ult_step")
		while c.tick <= 0.0 and c.left > -dt:
			c.tick += float(u["tick"])
			view.store_clock(c)
			var d := view.distance()
			var pw := view.ult_power()
			view.fx(&"ult_tick")
			view.area_hit(d - 0.5, d + float(u["range"]), float(u["kills"]) * pw, float(u["breaks"]) * pw, true)
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
			var near := c.wave_d + 1.0 + spacing * c.wave
			view.store_clock(c)
			view.fx(&"ult_wave", {"near": near, "spacing": spacing, "wave": c.wave})
			var pw2 := view.ult_power()
			view.area_hit(near - 0.5, near + spacing, float(u["kills"]) * pw2, float(u["breaks"]) * pw2, false)
			c.wave += 1
		if c.wave >= waves:
			c.wave = 99
			view.store_clock(c)
			view.fx(&"ult_waves_end")
	view.store_clock(c)


## Speed of hazards, turrets and clashing squads: 1, or 1 - ult.slow while a `slows` ult runs.
static func hazard_slow(kind: StringName, u: Dictionary, ult_left: float) -> float:
	if ult_left > 0.0 and bool(ult_row(kind)["slows"]):
		return 1.0 - float(u.get("slow", 0.0))
	return 1.0


## The auto-fire policy (bot, level_check, LevelSim): 1.0 = fire now, 0.0 = hold. Meta-1 rule
## for every kind: always in a clash or the siege; else when the squads overlapping the blob's
## lane within `reach` hold >= max(8, 35% of the army) hp (the fortress counts 99); a `guard`
## kind also fires for its armour when a hazard is close ahead of a decent army.
static func ult_worth(kind: StringName, view: KindView, u: Dictionary) -> float:
	if view.in_fight():
		return 1.0
	var pol: Dictionary = ult_row(kind)["policy"]
	var reach := float(pol["reach"])
	if reach < 0.0:
		reach = float(u.get("range", 13.0))
	var n := float(view.army()["n"])
	if pol.has("guard"):
		var g: Array = pol["guard"]
		if n >= float(g[0]) and view.hazard_near(float(g[1])):
			return 1.0
	return 1.0 if view.threat_ahead(reach) >= maxf(8.0, n * 0.35) else 0.0
