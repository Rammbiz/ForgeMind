class_name Balance
## Tuning numbers for the run, the heroes, the weapons and the upgrades.
## World axes: the run goes to -Z, `d` is the distance run, x is across the bridge.

# ------------------------------------------------------------------ movement and army

const RUN_SPEED := 6.5          # units per second along the bridge
const BRIDGE_HALF := 3.5        # walkway half width
const X_LIMIT := 3.0            # how far from the centre the hero may go
const DRAG_GAIN := 9.0          # world units per full screen width of finger travel
const STEER_HALFLIFE := 0.045   # seconds for the hero to halve the distance to its target x
const BLOB_K := 0.35            # army blob radius = BLOB_K * sqrt(army), clamped
const BLOB_MIN := 0.35
const BLOB_MAX := 2.2
const BLOB_STRETCH := 1.15      # the blob is an ellipse this much longer along the run
const HERO_GAP := 0.6           # gap between the hero and the front of the army
const UNIT_R := 0.12            # soldier radius for hazard checks
const CORRIDOR := 0.8           # the hero hits targets whose span is within this of its x
const CONTACT := 1.1            # how far ahead of the hero a squad / the fortress is met
const FIGHT_TICK := 0.07        # seconds between casualties in a clash
const HAZARD_SHRINK := 0.88     # hazard hit boxes are this much smaller than their models
const FINALE_TIME := 3.0        # how long the hero (and its machines) may batter the fortress alone
const MAX_SHOWN := 220          # soldiers drawn; the counter shows the real number
const MAX_SHOWN_LOW := 120
const PICKUP_PAD := 0.3         # tiles / coins: collected within blob radius + this
const RECRUIT_PAD := 0.4        # recruits: within blob radius + this
const REVEAL_DIST := 6.5        # hidden gates show their value this close to the hero
const WEAPON_LATERAL := 2.6     # war machines shoot targets at most this far across from the hero
const SQUAD_SHOWN := 160         # enemy squad: raiders drawn at most
const SQUAD_DX := 0.42          # squad formation spacing across / along the run
const SQUAD_DZ := 0.45
const MACHINE_TARGETS: Array[String] = ["squad", "turret", "barricade", "geode", "crate", "fortress"]

## Points added to a gate value per point of hero damage that hits it.
const GATE_HIT_GAIN := {"+": 1.0, "-": 1.0, "charge": 2.0, "rate": 2.0}

const START_ARMY := 3
## Barracks Drill: a squad the hero hit this many seconds before the clash counts as drilled.
const DRILL_WINDOW := 2.0
const MAX_UPGRADE := 10

# ------------------------------------------------------------------ heroes

# Damage is in "soldiers": 1 kills one enemy or takes 1 off a barricade / crate / fortress.
#   hp         how many enemies the hero can hold off alone once the army is gone
#   rate       attacks per second; range: how far ahead it hits (corridor: optional override)
#   damage     per attack; splash: extra enemies killed around a squad target
#   ult        points from soldiers gained and enemies killed charge the ultimate
#   aspect     default Aspect (design §4.1) when the profile names none: Bolt "forked_fox" (every
#              3rd cast chains to one more target), Titan "bulwark" (its splash), Seer "foresight"
const HEROES := {
	"bolt": {
		"name": "HERO_BOLT", "desc": "HERO_BOLT_DESC", "color": Color(0.35, 0.65, 1.0),
		"hp": 14, "rate": 3.6, "damage": 1, "splash": 0, "range": 15.0, "corridor": 0.8, "aspect": "forked_fox",
		"ult": {"name": "ULT_STORM", "icon": "storm", "charge": 35, "duration": 3.0, "range": 18.0, "tick": 0.25, "kills": 5, "breaks": 3},
	},
	"titan": {
		"name": "HERO_TITAN", "desc": "HERO_TITAN_DESC", "color": Color(0.35, 0.9, 0.55),
		"hp": 32, "rate": 1.2, "damage": 4, "splash": 3, "range": 12.0, "corridor": 1.0, "aspect": "bulwark",
		"ult": {"name": "ULT_QUAKE", "icon": "quake", "charge": 40, "waves": 4, "spacing": 3.5, "gap": 0.18, "kills": 12, "breaks": 12, "armor_time": 6.0},
	},
	# The lynx mystic (owner's model): two violet homing orbs per cast (`targets`), her hits
	# reveal the whole hidden gate row (`reveal_row`) and fill charge gates x`charge_mult`.
	# Ult "Star Rift": a tear `ahead` u in front of her for `duration` s; blades, sweepers,
	# turrets and squads run at (1 - `slow`) speed (squads in a clash kill that much slower)
	# while an arcane barrage hits everything within `range` every `tick` s.
	"seer": {
		"name": "HERO_SEER", "desc": "HERO_SEER_DESC", "color": Color(0.68, 0.4, 1.0),
		"hp": 20, "rate": 1.8, "damage": 1, "splash": 0, "range": 16.0, "corridor": 1.0,
		"targets": 2, "reveal_row": true, "charge_mult": 1.5, "aspect": "foresight",
		"ult": {"name": "ULT_RIFT", "icon": "fam_rift", "charge": 38, "duration": 4.0, "slow": 0.6, "ahead": 7.0,
				"range": 16.0, "tick": 0.5, "kills": 5, "breaks": 4},
	},
}
## Hero ids in roster order (hub carousel, dev tools).
const HERO_ORDER: Array[String] = ["bolt", "titan", "seer"]

# ------------------------------------------------------------------ weapons

## War machines from weapon crates. Damage hits structures (hp); against a squad one shot
## kills `damage * pierce + splash` enemies. Rockets fire `volley` rockets every `period` s;
## the laser burns `dps` on structures and `dps_crowd` on squads.
const WEAPONS := {
	"ballista": {"name": "W_BALLISTA", "icon": "ballista", "damage": 3, "rate": 0.9, "range": 16.0, "pierce": 2},
	"cannon": {"name": "W_CANNON", "icon": "cannon", "damage": 2, "rate": 0.6, "range": 12.0, "splash": 3},
	"laser": {"name": "W_LASER", "icon": "laser", "dps": 6.0, "dps_crowd": 3.0, "range": 10.0},
	"rockets": {"name": "W_ROCKETS", "icon": "rockets", "damage": 2, "volley": 4, "period": 2.5, "range": 18.0},
	"drone": {"name": "W_DRONE", "icon": "drone", "damage": 1, "rate": 2.0, "range": 8.0},
}
const WEAPON_LEVEL_MULT: Array[float] = [1.0, 1.5, 2.1]
const MAX_WEAPONS := 3

## Army weapon tiers. A volley kills `volley * army` enemies of a squad within `range` every
## `period` s; blasters (structures) also damage turrets, barricades and the fortress, for
## `struct_share` of that (a big army must not flatten the fortress from afar).
const ARM_TIERS := [
	{"name": "ARM_SPEAR"},
	{"name": "ARM_CROSSBOW", "volley": 0.05, "period": 0.5, "range": 7.0},
	{"name": "ARM_BLASTER", "volley": 0.09, "period": 0.45, "range": 8.0, "structures": true, "struct_share": 0.3},
]

## Multiplier stairs after the fortress (one per step, bottom to top).
const STAIRS_MULTS: Array[float] = [1.2, 1.4, 1.6, 1.8, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0]


## Legacy (Etap 1 "army" upgrade): the run no longer reads it (Barracks and Reinforcements come
## through Meta.run_profile); dev tools still use it for an `--army=N` head start.
static func start_army(army_level: int) -> int:
	return START_ARMY + 2 * army_level


## Legacy attack-speed multiplier of the retired "power" upgrade (refunded by the Save v2
## migration; the run uses the hero level's dmg_mult instead). LevelSim keeps it at level 0.
static func power_mult(power_level: int) -> float:
	return 1.0 + 0.12 * power_level


static func upgrade_cost(kind: String, current: int) -> int:
	var base := 30 if kind == "army" else 40
	return int(round(base * pow(1.45, current)))


## Coins for a won level (before the stairs multiplier): a base that grows with the level plus
## a bonus for the army that survived (capped, so one lucky run does not buy every upgrade).
static func victory_coins(level: int, survivors: int) -> int:
	return 15 + level * 5 + mini(survivors / 3, 25)


## Army blob radius for `army` soldiers.
static func blob_radius(army: float) -> float:
	return clampf(BLOB_K * sqrt(maxf(army, 0.0)), BLOB_MIN, BLOB_MAX)


## How far a squad's last rank stands behind its front rank (the formation of `hp` raiders on a
## front of width `w`, Hazards._layout). The Run and LevelSim keep a squad that was met clear of
## the blob armed until the hero has passed its last rank.
static func squad_depth(w: float, hp: float) -> float:
	var per_row := maxi(3, int(w / SQUAD_DX))
	var rows := ceili(clampf(hp, 1.0, float(SQUAD_SHOWN)) / per_row)
	return maxf(rows - 1, 0) * SQUAD_DZ
