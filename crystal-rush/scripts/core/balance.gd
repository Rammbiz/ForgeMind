class_name Balance
## Tuning numbers for the run, the heroes and the upgrades.

const RUN_SPEED := 6.5          # units per second along the bridge
const LANE_X: Array[float] = [-1.6, 1.6]
const LANE_HALF := 1.55         # half the width of a lane (gates, tiles and squads)
const LANE_SWITCH := 9.0        # sideways speed when changing lane
const BRIDGE_HALF := 3.5        # walkway half width
const CONTACT := 1.1            # how far ahead of the hero the army front meets a blocker
const FIGHT_TICK := 0.07        # seconds between casualties in a clash
const MAX_SHOWN := 140          # soldiers drawn; the counter shows the real number

const START_ARMY := 3
const MAX_UPGRADE := 10

# Heroes. Damage is in "soldiers": 1 kills one enemy or takes 1 off a barricade.
#   hp         how many enemies the hero can hold off alone once the army is gone
#   rate       attacks per second, range: how far ahead it hits (its own lane only)
#   damage     per attack; splash: extra enemies hit around the target (titan)
#   ult        points from soldiers gained and enemies killed that charge the ultimate
const HEROES := {
	"bolt": {
		"name": "HERO_BOLT", "desc": "HERO_BOLT_DESC", "color": Color(0.35, 0.65, 1.0),
		"hp": 14, "rate": 3.6, "damage": 1, "splash": 0, "range": 15.0,
		"ult": {"name": "ULT_STORM", "icon": "storm", "charge": 35, "duration": 3.0, "range": 18.0, "tick": 0.25, "kills": 5, "breaks": 3},
	},
	"titan": {
		"name": "HERO_TITAN", "desc": "HERO_TITAN_DESC", "color": Color(0.35, 0.9, 0.55),
		"hp": 32, "rate": 1.1, "damage": 4, "splash": 2, "range": 8.5,
		"ult": {"name": "ULT_QUAKE", "icon": "quake", "charge": 40, "waves": 4, "spacing": 3.5, "gap": 0.18, "kills": 12, "breaks": 12, "armor_time": 6.0},
	},
}


static func start_army(army_level: int) -> int:
	return START_ARMY + 2 * army_level


## Attack-speed multiplier from the power upgrade.
static func power_mult(power_level: int) -> float:
	return 1.0 + 0.12 * power_level


static func upgrade_cost(kind: String, current: int) -> int:
	var base := 30 if kind == "army" else 40
	return int(round(base * pow(1.45, current)))


## Coins for a won level: a base that grows with the level plus a bonus for the army that
## survived (capped, so one lucky multiplier run does not buy every upgrade).
static func victory_coins(level: int, survivors: int) -> int:
	return 15 + level * 5 + mini(survivors / 3, 25)
