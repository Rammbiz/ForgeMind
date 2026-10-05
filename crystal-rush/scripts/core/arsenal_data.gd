class_name ArsenalData
## The Arsenal: every war machine, rarity, family, status and in-run budget (arsenal_design.md
## §2, §3, §9.1). Pure data plus a few pure helpers; nothing here reads Save or Meta.
##
## Phases: Meta-1 ships the 9 machines with `"meta2": false` (Drone, Ballista, Plasma Cannon,
## Rocket Pod, Siege Mortar, Gatling, Laser, Railgun, Prism). The other 15 entries carry
## `"meta2": true`: enough data to list them in the UI as locked, no in-run behaviour yet.
## `FEATURES` says which rules of the design are live in the current phase.
##
## Conventions (shared by Arsenal.stats, Weapons, LevelSim, the hub cards):
## - `base` is Rank I at Lv1. Keys: damage (per hit), rate (shots/s), period (s between volleys
##   or charges), range (u), pierce (targets per shot, 1 = no pierce), splash (extra squad
##   kills per hit, etap1 rule), radius (u), volley (projectiles per volley), structures (vs
##   multiplier on turrets, barricades, geodes, fortress), dps / dps_crowd (beams).
## - `scale` lists the keys the machine's damage multiplier applies to (acc_mult x rank_mult).
## - `ranks` are CUMULATIVE overrides: Rank R = base + ranks[1] + ... + ranks[R-1]. A key
##   ending in `_mult` multiplies the stem key ("rate_mult": 1.25 -> rate x 1.25); "dmg_mult"
##   multiplies every key in `scale`; any other key replaces / adds the value.
## - Talent and Ascension `mods` use the same grammar plus `_add` (adds to the stem key) and
##   "add" (bucket 2 additive damage, §2.1). Keys the generic merge cannot apply are passed
##   through in `machine_stats().mods` for the run to read.
## - Distances in world units, times in seconds, "u/s" speeds; machines face -Z.

# ------------------------------------------------------------------ phase and beats

## Current meta phase (design §9.7). Meta-2 / Meta-3 rules stay data-only until this rises.
const PHASE := 1

## Which design rules are live (the run, UI and Rewards check these, never PHASE directly).
const FEATURES := {
	"statuses": true, "reactions": false, "sets": false,
	"talents12": true, "talent3": false, "lead": true, "deck": true,
	"ascension": true,           # Common/Rare single form and the default branch "a" for Epic+
	"branches": false,           # choosing A/B (Meta-2)
	"apex": false, "prestige_frames": true,
	"new_crates": true, "pairs": true, "crate_bonus": true, "rank_gates": true,
	"catalyst_gates": false, "evolutions": false, "fusions": false, "codex": false,
	"properties": false, "army_tiers_t3": false, "mythics": false, "finishes": false,
	"stone_cache": true, "world_cache": true, "royal_cache": false, "xray_cache": false,
	"wild": true, "focus": true, "vault": true, "altar": true,
	"deck_slots_max": 3,         # Meta-1 ships the 3-slot Deck (design: +1 at World 3/4/5, max 6)
}

const MAX_LEVEL := 15
const TALENT_LEVELS: Array[int] = [3, 6, 10]   ## Talent I, II, III
const LEAD_LEVEL := 5
const ASCENSION_LEVEL := 8
const APEX_LEVEL := 12
const PRESTIGE_FROM := 13                       ## Lv13/14/15 = Bronze / Silver / Gold frame
const PER_LEVEL := 0.08                         ## acc_mult(L) = 1 + PER_LEVEL x (L - 1)

## Machines owned on a brand-new account (Lv = rarity start).
const START_OWNED: Array[String] = ["drone"]
const MYTHIC_ORDER: Array[String] = ["starfall", "chrono", "phoenix", "echo"]

## Campaign layout used by the meta (Worlds.LEVELS_PER_WORLD follows it when the 8-level
## worlds land; until then the meta still counts 8 levels per world, design §9).
const LEVELS_PER_WORLD := 8
const CAMPAIGN_LEVELS := 56

# ------------------------------------------------------------------ in-run rules

const MAX_FIELDED := 3
const MAX_EVOLVED := 2
const RANK_MULT: Array[float] = [1.0, 1.5, 2.1]          ## = Balance.WEAPON_LEVEL_MULT
const RANK_SCALE: Array[float] = [1.0, 1.15, 1.3]        ## model scale per Rank (§2.8)
const OVERFLOW: Array[float] = [0.10, 0.07, 0.05, 0.03]  ## bucket 2 per copy past Rank III (last repeats)
const EVO_MULT := 1.25
const DUP_SHARE_AT_2 := 0.5
const RECIPE_WEIGHT := 3.0
const RARITY_PICK_W := {"C": 1.0, "R": 0.8, "E": 0.6, "L": 0.45, "M": 0.35}
const CRATE_BONUS_HP := 0.6          ## BONUS segment = 0.6 x the crate's OPEN value
const CRATE_RESOLVE_D := 30.0        ## crate / RANK gate contents lock this far ahead of the hero
const PAIR_GAP := 2.2                ## two crates of a pair stand this far apart (x)
const PAINT_S := 2.0                 ## the hero's paint mark lasts this long (refreshed per hit)
const VS_CLAMP := Vector2(0.25, 3.0) ## bucket 3 clamp
const ARMOR_LIGHT_MULT := 0.5
const LIGHT_HIT := 2.0               ## a hit below this (bucket 1) is "light"
const CAPS := {"pierce": 6, "chain": 8, "volley": 5, "summons": 3, "drones": 6}

## Convoy placement (§2.2): slots A/B on the flanks, C behind on the roomier side.
const CONVOY := {"gap": 0.9, "clamp_x": 3.0, "c_back": 1.4, "small_army": 10, "small_ahead": 1.0,
		"scale": 1.25, "evolved_dx": 1.2, "evolved_back": 1.5, "camera_bottom": 0.18}

## In-run arsenal budget per level band (§3.2). crates: [from, to, crate events];
## boss_extra on every 8th level; rank_gates: [from, to, count]; pairs from `pairs_from`.
const INRUN_BUDGET := {
	"crates": [[1, 1, 0], [2, 10, 2], [11, 30, 2], [31, 999, 4]],
	"boss_extra": 1,
	"rank_gates": [[11, 999, 1]],
	"catalyst_gates": [[11, 999, 1]],        # Meta-2 (FEATURES.catalyst_gates)
	"pairs_from": 5,
	"expedition_crates": 4,
	# Ship targets measured by the bot (level_check fails a band > 10 pp off).
	"targets": {
		"L2-10": {"rank2": 0.70, "evo_any": [0.05, 0.20]},
		"L11-30": {"rank3": [0.60, 0.85], "evo_any": [0.30, 0.45]},
		"L31+": {"rank3": 0.70, "evo_any": [0.50, 0.65], "fusion": [0.10, 0.25]},
	},
}

## Platinum NEW crate schedule: world -> {level in world -> machine} (§3.3). Always the
## level's first crate. Drone is owned at start; World 7 has none (Mythics come from the Anvil).
const NEW_CRATES := {
	1: {2: "ballista", 3: "cannon", 5: "rockets", 6: "mortar"},
	2: {1: "gatling", 3: "laser", 5: "railgun"},
	3: {1: "tesla", 3: "banner", 5: "prism"},
	4: {1: "cryo", 3: "frost_miner", 5: "ram"},
	5: {1: "harvester", 3: "arc_fence", 5: "aegis"},
	6: {1: "sentinel", 3: "gravity", 5: "tuner"},
}

# ------------------------------------------------------------------ rarities, families, statuses

const RARITY_ORDER: Array[String] = ["C", "R", "E", "L", "M"]
const RARITIES := {
	"C": {"name": "RAR_COMMON", "ui_color": Color("#D6DEE6"), "pips": 1, "start": 1, "gem": "round", "frame": "steel", "shell": "steel"},
	"R": {"name": "RAR_RARE", "ui_color": Color("#3FA9FF"), "pips": 2, "start": 2, "gem": "square", "frame": "inner_glow", "shell": "sapphire"},
	"E": {"name": "RAR_EPIC", "ui_color": Color("#B06CFF"), "pips": 3, "start": 3, "gem": "triangle", "frame": "energy_lines", "shell": "amethyst"},
	"L": {"name": "RAR_LEGENDARY", "ui_color": Color("#FFB52E"), "pips": 4, "start": 4, "gem": "star", "frame": "filigree", "shell": "gold", "beam": true},
	"M": {"name": "RAR_MYTHIC", "ui_color": Color("#E8D8FF"), "pips": 5, "start": 5, "gem": "eye", "frame": "breakout", "shell": "opal", "beam": true, "opal": true},
}

## Families (§2.1). `accent` is the in-run colour of the family (projectiles, rings, chips).
const FAMILY_ORDER: Array[String] = ["kinetic", "volt", "frost", "plasma", "tech", "rune", "rift"]
const FAMILIES := {
	"kinetic": {"name": "FAM_KINETIC", "accent": Color("#D9B8A6"), "glyph": "chevron", "status": "stagger",
			"projectile": "bolt", "overlay": "", "set2": {"structures_add": 0.15}, "set3": {"pierce_add": 1}},
	"volt": {"name": "FAM_VOLT", "accent": Color("#FFA5FF"), "glyph": "bolt", "status": "jolt",
			"projectile": "arc", "overlay": "crackle", "set2": {"chain_add": 1}, "set3": {"hero_jolt": true}},
	"frost": {"name": "FAM_FROST", "accent": Color("#F8FFD8"), "glyph": "snowflake", "status": "chill",
			"projectile": "shard", "overlay": "frost_rim", "set2": {"chill_add": 1}, "set3": {"blade_slow": 0.3, "blade_r": 4.0}},
	"plasma": {"name": "FAM_PLASMA", "accent": Color("#D80A71"), "glyph": "orb", "status": "burn",
			"projectile": "orb", "overlay": "ember", "set2": {"burn_s": 4.0}, "set3": {"wipe_burst": 2.0, "wipe_r": 1.0}},
	"tech": {"name": "FAM_TECH", "accent": Color("#49FF0C"), "glyph": "reticle", "status": "mark",
			"projectile": "missile", "overlay": "reticle", "set2": {"mark_add": 0.10}, "set3": {"homing_projectiles_add": 1}},
	"rune": {"name": "FAM_RUNE", "accent": Color("#0A0AD8"), "glyph": "rune", "status": "seal",
			"projectile": "rune_disc", "overlay": "rune_ring", "set2": {"seal_s": 6.0}, "set3": {"soldier_per_kills": 10}},
	"rift": {"name": "FAM_RIFT", "accent": Color("#E8D8FF"), "glyph": "eye", "status": "",
			"projectile": "", "overlay": "", "set2": {}, "set3": {}, "wild_set": true},
}

## Squad statuses (§2.1). `proc` stacks per hit come from the SOURCE machine (`MACHINES[id].proc`).
const STATUSES := {
	"stagger": {"name": "ST_STAGGER", "max_stacks": 1, "decay_s": 0.4, "push": 0.3, "ignores_armor": true},
	"jolt": {"name": "ST_JOLT", "max_stacks": 3, "decay_s": 2.0, "per_stack": true, "chain_r": 2.0},
	"chill": {"name": "ST_CHILL", "max_stacks": 3, "decay_s": 1.5, "per_stack": true, "slow": 0.10, "clash": 0.10,
			"freeze_s": 1.0, "immune_s": 1.0, "resist_max_stacks": 5, "resist_slow": 0.05},
	"burn": {"name": "ST_BURN", "max_stacks": 1, "decay_s": 3.0, "refresh": true, "units_per_s": 1.0,
			"jump_r": 3.0, "resist_units_per_s": 0.5},
	"mark": {"name": "ST_MARK", "max_stacks": 1, "decay_s": 3.0, "refresh": true, "vs": 1.25, "reveals": true},
	"seal": {"name": "ST_SEAL", "max_stacks": 1, "decay_s": 4.0, "refresh": true, "coin_chance": 0.2, "ult_add": 0.005},
}

## Reactions (Meta-2, FEATURES.reactions).
const REACTIONS := {
	"superconduct": {"name": "RX_SUPERCONDUCT", "a": "jolt", "b": "chill", "vs": 2.0},
	"thermal_shock": {"name": "RX_THERMAL", "a": "burn", "b": "chill", "burst": 5.0, "consumes": true},
	"flare": {"name": "RX_FLARE", "a": "mark", "b": "burn", "spread": 2, "spread_r": 3.0},
}
const REACTION_HITSTOP := 0.06

## Enemy squad properties (Meta-2, FEATURES.properties). LevelGen emits squad.props.
const PROPERTIES := {
	"swarm": {"name": "PROP_SWARM", "world": 2, "show_mult": 2.0, "dmg_kills": 2, "unit_value": 0.5, "icon": "swarm",
			"answers": ["gatling", "cannon", "mortar", "tesla"]},
	"phantom": {"name": "PROP_PHANTOM", "world": 3, "hidden_until": "mark_or_hero", "icon": "phantom",
			"answers": ["tesla", "drone", "prism"]},
	"armored": {"name": "PROP_ARMORED", "world": 4, "light_mult": 0.5, "burn_units_per_s": 0.5, "icon": "armored",
			"answers": ["ram", "frost_miner", "railgun", "ballista", "mortar"]},
	"shielded": {"name": "PROP_SHIELDED", "world": 5, "pool": 0.30, "icon": "shielded",
			"answers": ["arc_fence", "laser", "railgun", "tesla"]},
	"chill_resist": {"name": "PROP_CHILL_RESIST", "world": 5, "freeze_stacks": 5, "slow": 0.05, "icon": "chill_resist",
			"answers": []},
	"flying": {"name": "PROP_FLYING", "world": 6, "hover": 1.2, "icon": "flying",
			"answers": ["gravity", "sentinel", "rockets", "drone", "tesla", "laser"]},
	"rift": {"name": "PROP_RIFT", "world": 7, "props": 2, "icon": "rift", "answers": []},
}
const PROPERTY_RULES := {"first_level_in_world": 3, "max_share": 0.5, "not_boss_phase1": true}

const VERBS := {
	"lane": {"name": "VERB_LANE", "desc": "VERB_LANE_DESC"},
	"paint": {"name": "VERB_PAINT", "desc": "VERB_PAINT_DESC"},
	"place": {"name": "VERB_PLACE", "desc": "VERB_PLACE_DESC"},
	"rule": {"name": "VERB_RULE", "desc": "VERB_RULE_DESC"},
}

## Talent I (Lv3) and Talent II (Lv6) per family, two options each (§2.1).
## TAL_<ID> / TAL_<ID>_DESC are the Loc keys.
const FAMILY_TALENTS := {
	"kinetic": [
		[{"id": "tempered", "mods": {"add": 0.15}}, {"id": "long_barrel", "mods": {"range_mult": 1.2}}],
		[{"id": "piercing", "mods": {"pierce_add": 1}}, {"id": "concussive", "mods": {"stagger_push_mult": 2.0}}],
	],
	"volt": [
		[{"id": "capacitor", "mods": {"chain_add": 1}}, {"id": "hair_trigger", "mods": {"rate_mult": 1.2, "charge_mult": 0.8333}}],
		[{"id": "lingering_charge", "mods": {"jolt_s_add": 1.0}}, {"id": "arc_reach", "mods": {"jump_r_add": 1.0}}],
	],
	"frost": [
		[{"id": "deep_cold", "mods": {"chill_slow_add": 0.05}}, {"id": "wide_spray", "mods": {"radius_mult": 1.15, "cone_mult": 1.15}}],
		[{"id": "hard_freeze", "mods": {"freeze_s_add": 0.5}}, {"id": "brittle", "mods": {"frozen_kinetic_add": 0.25}}],
	],
	"plasma": [
		[{"id": "hot_core", "mods": {"burn_units_add": 0.5}}, {"id": "wide_bloom", "mods": {"radius_mult": 1.15}}],
		[{"id": "wildfire", "mods": {"burn_jumps_add": 1}}, {"id": "fission", "mods": {"split_add": 1}}],
	],
	"tech": [
		[{"id": "twin_feed", "mods": {"volley_add": 1, "drones_add": 1}}, {"id": "long_link", "mods": {"range_mult": 1.2}}],
		[{"id": "paint_target", "mods": {"mark_add": 0.10}}, {"id": "smart_fuse", "mods": {"hits_phantom": true}}],
	],
	"rune": [
		[{"id": "resonance", "mods": {"primary_mult": 1.2}}, {"id": "wide_field", "mods": {"radius_mult": 1.15}}],
		[{"id": "prospector", "mods": {"seal_ult_add": 0.005}}, {"id": "echo_stone", "mods": {"linger_s_add": 1.0}}],
	],
	"rift": [[], []],
}

## Army soldier tiers (§2.7). T0-T2 exist in etap1 (Balance.ARM_TIERS); T3+ unlock by world.
const ARMY_TIERS := [
	{"id": "spear", "name": "ARM_SPEAR", "unlock_world": 1},
	{"id": "crossbow", "name": "ARM_CROSSBOW", "unlock_world": 1, "volley": 0.05, "period": 0.5, "range": 7.0},
	{"id": "blaster", "name": "ARM_BLASTER", "unlock_world": 1, "volley": 0.09, "period": 0.45, "range": 8.0, "structures": true},
	{"id": "arc_lance", "name": "ARM_ARC_LANCE", "unlock_world": 3, "volley": 0.10, "period": 0.45, "range": 8.0, "chain_every": 3, "meta2": true},
	{"id": "prism_rifle", "name": "ARM_PRISM_RIFLE", "unlock_world": 5, "volley": 0.12, "period": 0.45, "range": 8.0, "pierce": 1, "structures_vs": 1.5, "meta2": true},
	{"id": "starforged", "name": "ARM_STARFORGED", "unlock_world": 7, "volley": 0.14, "period": 0.45, "range": 8.0, "ignore_loss_every": 3.0, "meta2": true},
]
const ARM_MAX_BONUS := {"label": "ARM_VOLLEY_BONUS", "add": 0.20, "max_stacks": 2}

# ------------------------------------------------------------------ machines

const ORDER: Array[String] = ["drone", "ballista", "cannon", "rockets", "mortar", "gatling", "laser", "railgun",
		"tesla", "banner", "prism", "cryo", "frost_miner", "ram", "harvester", "arc_fence", "aegis", "sentinel",
		"gravity", "tuner", "starfall", "chrono", "phoenix", "echo"]

const MACHINES := {
	# ---------------------------------------------------------------- Meta-1
	"drone": {
		"name": "M_DRONE", "desc": "M_DRONE_DESC", "rarity": "C", "family": "tech", "verb": "paint", "shape": "spotter",
		"home": 1, "meta2": false, "mount": "free", "crew": false, "silhouette": "x_quad_eye", "meshy": "A-08",
		"flags": {"hits_flying": true, "light": true, "ground_only": false, "bypass_shield": false},
		# Balance.WEAPONS.drone is the Rank I / Lv1 anchor (design sheet: 0.6 x 2/s; etap1 tuned 1 x 2/s).
		"base": {"damage": 1.0, "rate": 2.0, "range": 8.0, "drones": 1, "mark_s": 3.0},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08, "also": ["mark_s"]},
		"status": "mark", "proc": 0.5, "move": {"hover": 1.2},
		"ranks": [{}, {"drones": 2}, {"mark_vs": 1.35, "repaint": true}],
		"talent3": [{"id": "overwatch", "mods": {"marks_structures": true}}, {"id": "sting", "mods": {"dmg_mult": 2.5, "no_mark": true}}],
		"ascension": {"id": "wasp_drone", "mods": {"pierce_add": 1}, "look": "shader"},
		"apex": {"id": "drone_storm", "drones": 6, "duration": 5.0},
		"recipes": ["E7", "E9"],
		"sim": {"dps": 1.2, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "mark_uptime": 0.6},
		"vfx": {"kind": "tracer_dot", "width": 0.08, "length": 0.8, "lifetime": 0.15, "particles_max": 6, "telegraph": ""},
		"sfx": ["drone_chirp", "tick_hit"],
		"parts": {"rotors": {"how": "P", "count": 4, "axis": Vector3.UP, "speed": 40.0}},
	},
	"ballista": {
		"name": "M_BALLISTA", "desc": "M_BALLISTA_DESC", "rarity": "C", "family": "kinetic", "verb": "lane", "shape": "pierce_line",
		"home": 1, "meta2": false, "mount": "chassis_kinetic", "crew": true, "silhouette": "wide_bow", "meshy": "A-09",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"damage": 3.0, "rate": 0.9, "range": 16.0, "pierce": 2, "bolts": 1},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08},
		"status": "stagger", "proc": 1.0, "move": {},
		"ranks": [{}, {"pierce": 3, "dmg_mult": 1.2}, {"bolts": 2}],
		"talent3": [{"id": "barbed_bolts", "mods": {"stagger_push_mult": 2.0}}, {"id": "ricochet", "mods": {"bounce": 1}}],
		"ascension": {"id": "storm_ballista", "mods": {"applies_jolt": true}, "look": "shader"},
		"apex": {"id": "volley_of_kings", "bolts": 12, "duration": 3.0, "pierce": 6},
		"recipes": ["E1"],
		"sim": {"dps": 2.7, "aoe_r": 0.0, "control_s": 0.3, "structure_mult": 1.0, "gate_gain": 0.0, "targets": 3},
		"vfx": {"kind": "bolt", "width": 0.24, "length": 2.3, "lifetime": 0.5, "particles_max": 8, "telegraph": ""},
		"sfx": ["ballista_twang", "wood_thunk"],
		"parts": {"bow_arms": {"how": "P", "flex_s": 0.12}, "bolt": {"how": "P"}},
	},
	"cannon": {
		"name": "M_CANNON", "desc": "M_CANNON_DESC", "rarity": "C", "family": "plasma", "verb": "paint", "shape": "splash_orb",
		"home": 1, "meta2": false, "mount": "chassis_plasma", "crew": true, "silhouette": "fat_round_muzzle", "meshy": "A-10",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"damage": 2.0, "rate": 0.6, "range": 12.0, "splash": 3, "radius": 1.2},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08},
		"status": "burn", "proc": 1.0, "move": {},
		"ranks": [{}, {"radius": 1.5}, {"split": 3}],
		"talent3": [{"id": "nova_core", "mods": {"radius_add": 0.4, "rate_mult": 0.85}}, {"id": "sticky_plasma", "mods": {"burn_puddle_s": 2.0}}],
		"ascension": {"id": "sun_cannon", "mods": {"orb_scale": 1.3, "burn_ring": true}, "look": "shader"},
		"apex": {"id": "supernova", "damage": 25.0, "radius": 3.0, "burn_s": 5.0},
		"recipes": ["F2", "F5"],
		"sim": {"dps": 1.2, "aoe_r": 1.2, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "burn": 0.6},
		"vfx": {"kind": "orb", "width": 0.55, "length": 1.5, "lifetime": 0.6, "particles_max": 24, "telegraph": ""},
		"sfx": ["plasma_whoomp", "plasma_pop"],
		"parts": {"barrel": {"how": "P", "recoil": 0.15}},
	},
	"rockets": {
		"name": "M_ROCKETS", "desc": "M_ROCKETS_DESC", "rarity": "C", "family": "tech", "verb": "paint", "shape": "homing_burst",
		"home": 1, "meta2": false, "mount": "chassis_tech", "crew": true, "silhouette": "box_pod_2x3", "meshy": "A-11",
		"flags": {"hits_flying": true, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"damage": 2.0, "volley": 4, "period": 2.5, "range": 18.0, "radius": 0.8, "structures": 1.5},
		"scale": ["damage", "bomblet_damage"], "primary": {"stat": "damage", "per_level": 0.08},
		"status": "", "proc": 1.0, "move": {},
		"ranks": [{}, {"volley": 6}, {"bomblets": 2, "bomblet_damage": 1.0, "bomblet_radius": 0.6}],
		"talent3": [{"id": "bunker_buster", "mods": {"buster_vs": 3.0}}, {"id": "swarm_feed", "mods": {"micro_rockets": 2, "micro_dmg": 0.5}}],
		"ascension": {"id": "hunter_pod", "mods": {"applies_mark": true}, "look": "shader"},
		"apex": {"id": "doomsday_salvo", "rockets": 16, "duration": 2.0},
		"recipes": ["E3", "F4"],
		"sim": {"dps": 3.2, "aoe_r": 0.8, "control_s": 0.0, "structure_mult": 1.5, "gate_gain": 0.0},
		"vfx": {"kind": "missile_trail", "width": 0.24, "length": 1.2, "lifetime": 0.9, "particles_max": 40, "telegraph": ""},
		"sfx": ["rocket_hiss", "rocket_boom"],
		"parts": {},
	},
	"mortar": {
		"name": "M_MORTAR", "desc": "M_MORTAR_DESC", "rarity": "R", "family": "kinetic", "verb": "place", "shape": "lobbed_splash",
		"home": 1, "meta2": false, "mount": "chassis_kinetic", "crew": true, "silhouette": "stubby_tube_45", "meshy": "A-12",
		"flags": {"hits_flying": false, "light": false, "ground_only": true, "bypass_shield": false},
		"base": {"damage": 4.0, "period": 2.2, "range": 14.0, "radius": 1.6, "telegraph": 0.8},
		"scale": ["damage", "bomblet_damage"], "primary": {"stat": "damage", "per_level": 0.08},
		"status": "stagger", "proc": 1.0, "move": {"ahead": 12.0},
		"ranks": [{}, {"radius": 2.0}, {"bomblets": 3, "bomblet_damage": 1.5, "bomblet_radius": 0.8}],
		"talent3": [{"id": "earthbreaker", "mods": {"stun_s": 0.5}}, {"id": "carpet", "mods": {"shells": 3}}],
		"ascension": {"id": "titan_mortar", "mods": {"quake_s": 1.0}, "look": "shader"},
		"apex": {"id": "bombardment", "shells": 10},
		"recipes": ["F2", "E4"],
		"sim": {"dps": 1.8, "aoe_r": 1.6, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0},
		"vfx": {"kind": "shell_arc", "width": 0.3, "length": 0.0, "lifetime": 0.8, "particles_max": 30, "telegraph": "ring"},
		"sfx": ["mortar_thoomp", "shell_boom"],
		"parts": {"tube": {"how": "M", "asset": "mortar_tube", "axis": Vector3.RIGHT, "pitch": Vector2(35.0, 60.0)}},
	},
	"gatling": {
		"name": "M_GATLING", "desc": "M_GATLING_DESC", "rarity": "C", "family": "kinetic", "verb": "paint", "shape": "shredder",
		"home": 2, "meta2": false, "mount": "chassis_kinetic", "crew": true, "silhouette": "six_barrel_drum", "meshy": "A-13",
		"flags": {"hits_flying": true, "light": true, "ground_only": false, "bypass_shield": false},
		"base": {"damage": 0.6, "rate": 6.0, "range": 10.0, "ricochet": 1, "swarm_vs": 1.5, "spinup": 1.0, "spin_from": 0.5},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08},
		"status": "stagger", "proc": 0.3, "move": {},
		"ranks": [{}, {"rate_mult": 1.25}, {"ricochet": 2}],
		"talent3": [{"id": "shredder", "mods": {"shield_strip_mult": 2.0}}, {"id": "twin_vulcan", "mods": {"targets": 2}}],
		"ascension": {"id": "vulcan_drum", "mods": {"spinup": 0.0, "gold_tracers": true}, "look": "shader"},
		"apex": {"id": "lead_storm", "rate": 30.0, "duration": 3.0, "ricochet": 3},
		"recipes": ["E2", "F4"],
		"sim": {"dps": 3.6, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "swarm": 1.5},
		"vfx": {"kind": "tracer_stream", "width": 0.1, "length": 3.0, "lifetime": -1.0, "particles_max": 12, "telegraph": ""},
		"sfx": ["gatling_loop", "bullet_tick"],
		"parts": {"drum": {"how": "M", "asset": "gatling_drum", "axis": Vector3.BACK, "speed": 30.0}},
	},
	"laser": {
		"name": "M_LASER", "desc": "M_LASER_DESC", "rarity": "R", "family": "plasma", "verb": "lane", "shape": "ramping_beam",
		"home": 2, "meta2": false, "mount": "chassis_plasma", "crew": true, "silhouette": "long_barrel_lens", "meshy": "A-14",
		"flags": {"hits_flying": true, "light": false, "ground_only": false, "bypass_shield": true},
		"base": {"dps": 6.0, "dps_crowd": 3.0, "range": 10.0, "ramp": 0.5, "ramp_cap": 2.5, "pierce": 1},
		"scale": ["dps", "dps_crowd"], "primary": {"stat": "dps", "per_level": 0.08},
		"status": "", "proc": 0.2, "move": {},
		"ranks": [{}, {"ramp_cap": 3.0}, {"pierce": 2}],
		"talent3": [{"id": "cutter", "mods": {"sweep": true}}, {"id": "focus", "mods": {"ramp_cap": 4.0, "single": true}}],
		"ascension": {"id": "spectral_lance", "mods": {"applies_burn": true}, "look": "shader"},
		"apex": {"id": "solar_line", "dps": 40.0, "duration": 2.0},
		"recipes": ["E6", "F3"],
		"sim": {"dps": 9.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "beam": true},
		"vfx": {"kind": "beam", "width": 0.18, "length": 10.0, "lifetime": -1.0, "particles_max": 20, "telegraph": ""},
		"sfx": ["laser_loop", "sizzle"],
		"parts": {"lens": {"how": "M", "asset": "laser_lens", "axis": Vector3.BACK, "speed": 2.0, "speed_firing": 12.0}},
	},
	"railgun": {
		"name": "M_RAILGUN", "desc": "M_RAILGUN_DESC", "rarity": "E", "family": "volt", "verb": "lane", "shape": "charged_pierce",
		"home": 2, "meta2": false, "mount": "chassis_volt", "crew": true, "silhouette": "twin_rails", "meshy": "A-15",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": true},
		"base": {"damage": 18.0, "charge": 3.0, "telegraph": 0.4, "pierce": 99, "range": 22.0, "structures": 2.0},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08},
		"status": "jolt", "proc": 1.0, "move": {},
		"ranks": [{}, {"charge": 2.4}, {"lane_jolt_s": 2.0}],
		"talent3": [{"id": "overcap", "mods": {"charge_mult": 1.25, "dmg_mult": 1.6}}, {"id": "rapid_rails", "mods": {"charge_mult": 0.7, "dmg_mult": 0.8}}],
		"ascension": {
			"a": {"id": "breacher", "mods": {"boss_vs": 3.0}, "asset": "railgun_a"},
			"b": {"id": "splitter", "mods": {"fork": 3}, "asset": "railgun_b"},
		},
		"apex": {"id": "rail_barrage", "shots": 3},
		"recipes": ["E10", "F3"],
		"sim": {"dps": 6.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 2.0, "gate_gain": 0.0, "beam": true},
		"vfx": {"kind": "rail_beam", "width": 0.3, "length": 22.0, "lifetime": 0.25, "particles_max": 30, "telegraph": "rails"},
		"sfx": ["rail_charge", "rail_crack", "pierce_ring"],
		"parts": {},
	},
	"prism": {
		"name": "M_PRISM", "desc": "M_PRISM_DESC", "rarity": "L", "family": "plasma", "verb": "lane", "shape": "amplifier",
		"home": 3, "meta2": false, "mount": "free", "crew": false, "silhouette": "diamond_gyro", "meshy": "A-18",
		"flags": {"hits_flying": true, "light": false, "ground_only": false, "bypass_shield": true},
		"base": {"amp": 0.20, "pierce_add": 1, "beam_split": 3, "beam_split_share": 0.6, "ray_damage": 1.0, "ray_rate": 1.0,
				"range": 10.0, "size": 1.0},
		"scale": ["ray_damage"], "primary": {"stat": "amp", "per_level": 0.01, "mode": "add"},
		"status": "", "proc": 1.0, "move": {"ahead": 3.0},
		"ranks": [{}, {"amp": 0.30}, {"split": 2}],
		"talent3": [{"id": "focusing_lens", "mods": {"amp_add": 0.10}}, {"id": "wide_facet", "mods": {"size_mult": 1.4}}],
		"ascension": {
			"a": {"id": "lens_of_ruin", "mods": {"reveal_r": 8.0}, "asset": "prism_a"},
			"b": {"id": "rainbow_prism", "mods": {"split_statuses": ["burn", "chill", "jolt"]}, "asset": "prism_b"},
		},
		"apex": {"id": "refraction_storm", "split": 3, "duration": 4.0},
		"recipes": ["E6"],
		"sim": {"dps": 1.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "amp": 0.2},
		"vfx": {"kind": "refract_flash", "width": 0.4, "length": 0.0, "lifetime": 0.2, "particles_max": 12, "telegraph": ""},
		"sfx": ["prism_chime"],
		"parts": {"gyro": {"how": "M", "asset": "prism_ring", "axis": Vector3.RIGHT, "speed": 1.5}, "body": {"how": "M", "asset": "prism_body"}},
	},
	# ---------------------------------------------------------------- Meta-2 / Meta-3 (listed, locked)
	"tesla": {
		"name": "M_TESLA", "desc": "M_TESLA_DESC", "rarity": "R", "family": "volt", "verb": "paint", "shape": "chain",
		"home": 3, "meta2": true, "phase": 2, "mount": "chassis_volt", "crew": true, "silhouette": "cage_coil", "meshy": "A-16",
		"flags": {"hits_flying": true, "light": false, "ground_only": false, "bypass_shield": true},
		"base": {"damage": 2.0, "rate": 0.8, "range": 9.0, "jumps": 3, "jump_falloff": 0.25, "jump_r": 2.5},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08}, "status": "jolt", "proc": 0.5,
		"talent3": [{"id": "forked_arcs", "mods": {}}, {"id": "static_field", "mods": {}}],
		"ascension": {"id": "thunder_spire", "mods": {}}, "apex": {"id": "skybreaker"}, "recipes": ["E5", "F1"],
		"sim": {"dps": 4.4, "aoe_r": 2.5, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0},
		"vfx": {"kind": "chain_arc", "width": 0.12, "length": 0.0, "lifetime": 0.18, "particles_max": 16, "telegraph": ""},
		"sfx": ["tesla_zap", "arc_snap"],
	},
	"banner": {
		"name": "M_BANNER", "desc": "M_BANNER_DESC", "rarity": "R", "family": "rune", "verb": "rule", "shape": "army_buff",
		"home": 3, "meta2": true, "phase": 2, "mount": "chassis_rune", "crew": true, "silhouette": "pole_flag", "meshy": "A-17",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"volley_add": 0.30, "clash_loss": 0.15},
		"scale": [], "primary": {"stat": "volley_add", "per_level": 0.015, "mode": "add"}, "status": "", "proc": 0.0,
		"talent3": [{"id": "warlord", "mods": {}}, {"id": "pilgrim", "mods": {}}],
		"ascension": {"id": "royal_standard", "mods": {}}, "apex": {"id": "last_stand"}, "recipes": ["F6"],
		"sim": {"dps": 0.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "volley": 1.3, "clash": 0.85},
		"vfx": {"kind": "aura_ring", "width": 0.0, "length": 2.0, "lifetime": -1.0, "particles_max": 20, "telegraph": ""},
		"sfx": ["banner_flap"],
	},
	"cryo": {
		"name": "M_CRYO", "desc": "M_CRYO_DESC", "rarity": "C", "family": "frost", "verb": "lane", "shape": "cone_control",
		"home": 4, "meta2": true, "phase": 2, "mount": "chassis_frost", "crew": true, "silhouette": "tank_nozzle", "meshy": "A-19",
		"flags": {"hits_flying": true, "light": true, "ground_only": false, "bypass_shield": false},
		"base": {"dps": 1.5, "cone_deg": 60.0, "cone_len": 6.0, "chill_every": 0.5},
		"scale": ["dps"], "primary": {"stat": "dps", "per_level": 0.08}, "status": "chill", "proc": 1.0,
		"talent3": [{"id": "glacier", "mods": {}}, {"id": "cryo_burst", "mods": {}}],
		"ascension": {"id": "avalanche_sprayer", "mods": {}}, "apex": {"id": "flash_freeze"}, "recipes": ["E8", "F1"],
		"sim": {"dps": 1.5, "aoe_r": 1.0, "control_s": 2.0, "structure_mult": 1.0, "gate_gain": 0.0},
		"vfx": {"kind": "cone_mist", "width": 60.0, "length": 6.0, "lifetime": -1.0, "particles_max": 60, "telegraph": ""},
		"sfx": ["cryo_hiss", "freeze_crack"],
	},
	"frost_miner": {
		"name": "M_FROST_MINER", "desc": "M_FROST_MINER_DESC", "rarity": "R", "family": "frost", "verb": "place", "shape": "mines",
		"home": 4, "meta2": true, "phase": 2, "mount": "chassis_frost", "crew": true, "silhouette": "drum_magazine", "meshy": "A-20",
		"flags": {"hits_flying": false, "light": false, "ground_only": true, "bypass_shield": false},
		"base": {"damage": 4.0, "period": 2.5, "radius": 1.5, "freeze_s": 1.5, "ahead": 8.0},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08}, "status": "chill", "proc": 1.0,
		"talent3": [{"id": "cryo_field", "mods": {}}, {"id": "chain_mines", "mods": {}}],
		"ascension": {"id": "permafrost_miner", "mods": {}}, "apex": {"id": "minefield"}, "recipes": ["E8"],
		"sim": {"dps": 1.6, "aoe_r": 1.5, "control_s": 6.0, "structure_mult": 1.0, "gate_gain": 0.0},
		"vfx": {"kind": "mine_toss", "width": 0.3, "length": 0.0, "lifetime": 0.7, "particles_max": 24, "telegraph": "ring"},
		"sfx": ["mine_clack", "ice_burst"],
	},
	"ram": {
		"name": "M_RAM", "desc": "M_RAM_DESC", "rarity": "E", "family": "kinetic", "verb": "lane", "shape": "anti_structure",
		"home": 4, "meta2": true, "phase": 2, "mount": "chassis_kinetic", "crew": true, "silhouette": "spike_wedge", "meshy": "A-21",
		"flags": {"hits_flying": false, "light": false, "ground_only": true, "bypass_shield": false},
		"base": {"damage": 24.0, "squad_damage": 3.0, "period": 4.0, "structures": 2.0, "knockback": 1.0},
		"scale": ["damage", "squad_damage"], "primary": {"stat": "damage", "per_level": 0.08}, "status": "stagger", "proc": 1.0,
		"move": {"out": 14.0, "back": 10.0, "reach": 6.0},
		"talent3": [{"id": "momentum", "mods": {}}, {"id": "pinning_spike", "mods": {}}],
		"ascension": {"a": {"id": "juggernaut", "mods": {}}, "b": {"id": "drill_ram", "mods": {}}}, "apex": {"id": "battering_charge"},
		"recipes": ["E4"],
		"sim": {"dps": 0.75, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 8.0, "gate_gain": 0.0},
		"vfx": {"kind": "dash_streak", "width": 1.0, "length": 6.0, "lifetime": 0.5, "particles_max": 30, "telegraph": ""},
		"sfx": ["ram_rumble", "ram_crash"],
	},
	"harvester": {
		"name": "M_HARVESTER", "desc": "M_HARVESTER_DESC", "rarity": "R", "family": "rune", "verb": "rule", "shape": "economy",
		"home": 5, "meta2": true, "phase": 2, "mount": "chassis_rune", "crew": true, "silhouette": "claw_funnel", "meshy": "A-22",
		"flags": {"hits_flying": false, "light": true, "ground_only": false, "bypass_shield": false},
		"base": {"dps": 0.5, "reach": 1.5, "coin_chance": 0.20, "geode_mult": 2.0},
		"scale": ["dps"], "primary": {"stat": "coin_chance", "per_level": 0.01, "mode": "add"}, "status": "seal", "proc": 1.0,
		"talent3": [{"id": "golden_maw", "mods": {}}, {"id": "recruiter", "mods": {}}],
		"ascension": {"id": "golden_funnel", "mods": {}}, "apex": {"id": "gold_rush"}, "recipes": ["E9", "F8"],
		"sim": {"dps": 0.5, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0},
		"vfx": {"kind": "magnet_lines", "width": 0.05, "length": 1.5, "lifetime": 0.4, "particles_max": 16, "telegraph": ""},
		"sfx": ["harvest_ping", "coin_drop"],
	},
	"arc_fence": {
		"name": "M_ARC_FENCE", "desc": "M_ARC_FENCE_DESC", "rarity": "E", "family": "volt", "verb": "place", "shape": "stun_wall",
		"home": 5, "meta2": true, "phase": 2, "mount": "chassis_volt", "crew": true, "silhouette": "twin_pylons", "meshy": "A-23",
		"flags": {"hits_flying": true, "light": true, "ground_only": false, "bypass_shield": true},
		"base": {"damage": 1.0, "period": 3.0, "stun_s": 0.6, "width": 3.0, "ahead": 3.0},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08}, "status": "jolt", "proc": 1.0,
		"talent3": [{"id": "static_snare", "mods": {}}, {"id": "conductor", "mods": {}}],
		"ascension": {"a": {"id": "tesla_gate", "mods": {}}, "b": {"id": "storm_net", "mods": {}}}, "apex": {"id": "thunder_cage"},
		"recipes": ["E5", "E10", "F7"],
		"sim": {"dps": 0.33, "aoe_r": 1.5, "control_s": 2.0, "structure_mult": 1.0, "gate_gain": 0.0},
		"vfx": {"kind": "fence_wall", "width": 3.0, "length": 0.2, "lifetime": 0.35, "particles_max": 40, "telegraph": ""},
		"sfx": ["fence_hum", "fence_pulse"],
	},
	"aegis": {
		"name": "M_AEGIS", "desc": "M_AEGIS_DESC", "rarity": "E", "family": "frost", "verb": "rule", "shape": "hazard_absorb",
		"home": 5, "meta2": true, "phase": 2, "mount": "chassis_frost", "crew": true, "silhouette": "three_fins", "meshy": "A-24",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"absorb_every": 5.0, "absorb_cap": 10, "block_n": 4.4},
		"scale": [], "primary": {"stat": "absorb_cap", "per_level": 0.5, "mode": "add"}, "status": "", "proc": 0.0,
		"talent3": [{"id": "quick_ward", "mods": {}}, {"id": "reflector", "mods": {}}],
		"ascension": {"a": {"id": "bastion_dome", "mods": {}}, "b": {"id": "mirror_dome", "mods": {}}}, "apex": {"id": "sanctum"},
		"recipes": ["F7"],
		"sim": {"dps": 0.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "hazard_save": 2.0},
		"vfx": {"kind": "dome", "width": 1.6, "length": 0.0, "lifetime": 0.5, "particles_max": 24, "telegraph": ""},
		"sfx": ["dome_ward", "dome_bash"],
	},
	"sentinel": {
		"name": "M_SENTINEL", "desc": "M_SENTINEL_DESC", "rarity": "E", "family": "tech", "verb": "place", "shape": "tank_walker",
		"home": 6, "meta2": true, "phase": 2, "mount": "free", "crew": false, "silhouette": "chicken_walker", "meshy": "A-25",
		"flags": {"hits_flying": true, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"damage": 2.0, "period": 0.8, "soak": 15, "redeploy": 8.0},
		"scale": ["damage"], "primary": {"stat": "soak", "per_level": 1.0, "mode": "add"}, "status": "mark", "proc": 1.0,
		"move": {"speed_add": 1.0, "ahead": 4.0},
		"talent3": [{"id": "heavy_plating", "mods": {}}, {"id": "last_gift", "mods": {}}],
		"ascension": {"a": {"id": "colossus", "mods": {}}, "b": {"id": "guardian", "mods": {}}}, "apex": {"id": "titan_protocol"},
		"recipes": ["E7", "F6"],
		"sim": {"dps": 2.5, "aoe_r": 0.0, "control_s": 3.0, "structure_mult": 1.0, "gate_gain": 0.0, "soak": 15.0},
		"vfx": {"kind": "twin_tracer", "width": 0.1, "length": 1.0, "lifetime": 0.2, "particles_max": 10, "telegraph": ""},
		"sfx": ["mech_step", "mech_shot", "metal_hit"],
	},
	"gravity": {
		"name": "M_GRAVITY", "desc": "M_GRAVITY_DESC", "rarity": "L", "family": "rune", "verb": "paint", "shape": "clump",
		"home": 6, "meta2": true, "phase": 2, "mount": "chassis_rune", "crew": true, "silhouette": "rings_orb", "meshy": "A-26",
		"flags": {"hits_flying": true, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"period": 4.0, "range": 14.0, "clump": 0.5, "slow": 0.5, "slow_s": 1.5, "ground_s": 2.0, "clump_vs": 1.5},
		"scale": [], "primary": {"stat": "slow", "per_level": 0.01, "mode": "add"}, "status": "seal", "proc": 1.0,
		"talent3": [{"id": "long_pull", "mods": {}}, {"id": "dense_core", "mods": {}}],
		"ascension": {"a": {"id": "event_horizon", "mods": {}}, "b": {"id": "black_star", "mods": {}}}, "apex": {"id": "collapse"},
		"recipes": ["F5"],
		"sim": {"dps": 0.0, "aoe_r": 2.0, "control_s": 3.75, "structure_mult": 1.0, "gate_gain": 0.0, "clump": 1.5},
		"vfx": {"kind": "singularity", "width": 1.8, "length": 0.0, "lifetime": 1.5, "particles_max": 50, "telegraph": "ring"},
		"sfx": ["gravity_drone", "implode"],
	},
	"tuner": {
		"name": "M_TUNER", "desc": "M_TUNER_DESC", "rarity": "L", "family": "volt", "verb": "rule", "shape": "gate_economy",
		"home": 6, "meta2": true, "phase": 2, "mount": "chassis_volt", "crew": true, "silhouette": "dish_fork", "meshy": "A-27",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"gate_add": 3.0, "rate": 1.5, "range": 14.0},
		"scale": [], "primary": {"stat": "gate_add", "per_level": 0.15, "mode": "add"}, "status": "", "proc": 0.0,
		"talent3": [{"id": "fast_cycle", "mods": {}}, {"id": "long_dish", "mods": {}}],
		"ascension": {"a": {"id": "flipper_array", "mods": {}}, "b": {"id": "prospector_dish", "mods": {}}}, "apex": {"id": "full_spectrum"},
		"recipes": ["E12", "F8"],
		"sim": {"dps": 0.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 4.5},
		"vfx": {"kind": "gate_beam", "width": 0.06, "length": 14.0, "lifetime": -1.0, "particles_max": 8, "telegraph": ""},
		"sfx": ["tuner_tone", "gate_tick_up"],
	},
	"starfall": {
		"name": "M_STARFALL", "desc": "M_STARFALL_DESC", "rarity": "M", "family": "rift", "verb": "place", "shape": "orbital",
		"home": 0, "meta2": true, "phase": 3, "mount": "chassis_rift", "crew": true, "silhouette": "antenna_spire", "meshy": "A-28",
		"flags": {"hits_flying": false, "light": false, "ground_only": true, "bypass_shield": true},
		"base": {"damage": 30.0, "period": 7.0, "radius": 2.0, "structures": 2.0, "delay": 1.2, "lock": 0.4},
		"scale": ["damage"], "primary": {"stat": "damage", "per_level": 0.08}, "status": "", "proc": 1.0,
		"talent3": [{"id": "meteor_shower", "mods": {}}, {"id": "sun_pillar", "mods": {}}],
		"ascension": {"a": {"id": "meteor_choir", "mods": {}}, "b": {"id": "solar_spear", "mods": {}}}, "apex": {"id": "starfall"},
		"recipes": ["E11"],
		"sim": {"dps": 4.3, "aoe_r": 2.0, "control_s": 0.0, "structure_mult": 2.0, "gate_gain": 0.0},
		"vfx": {"kind": "orbital_beam", "width": 1.2, "length": 0.0, "lifetime": 0.6, "particles_max": 80, "telegraph": "ring"},
		"sfx": ["star_lock", "orbital_boom"],
	},
	"chrono": {
		"name": "M_CHRONO", "desc": "M_CHRONO_DESC", "rarity": "M", "family": "rift", "verb": "rule", "shape": "time_slow",
		"home": 0, "meta2": true, "phase": 3, "mount": "chassis_rift", "crew": true, "silhouette": "bell_arch", "meshy": "A-29",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"cooldown": 10.0, "radius": 9.0, "slow": 0.3, "duration": 2.5, "rate_add": 0.3},
		"scale": [], "primary": {"stat": "duration", "per_level": 0.05, "mode": "add"}, "status": "", "proc": 0.0,
		"talent3": [{"id": "long_toll", "mods": {}}, {"id": "quick_toll", "mods": {}}],
		"ascension": {"a": {"id": "stasis_bell", "mods": {}}, "b": {"id": "haste_bell", "mods": {}}}, "apex": {"id": "stopped_clock"},
		"recipes": [],
		"sim": {"dps": 0.0, "aoe_r": 9.0, "control_s": 2.1, "structure_mult": 1.0, "gate_gain": 0.0},
		"vfx": {"kind": "toll_wave", "width": 9.0, "length": 0.0, "lifetime": 0.8, "particles_max": 40, "telegraph": ""},
		"sfx": ["bell_toll"],
	},
	"phoenix": {
		"name": "M_PHOENIX", "desc": "M_PHOENIX_DESC", "rarity": "M", "family": "rift", "verb": "rule", "shape": "rebirth",
		"home": 0, "meta2": true, "phase": 3, "mount": "chassis_rift", "crew": true, "silhouette": "winged_brazier", "meshy": "A-30",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"rebirth": 0.25, "cap": 30, "delay": 1.5},
		"scale": [], "primary": {"stat": "rebirth", "per_level": 0.007, "mode": "add"}, "status": "burn", "proc": 1.0,
		"talent3": [{"id": "pyre", "mods": {}}, {"id": "ember_guard", "mods": {}}],
		"ascension": {"a": {"id": "sunpyre", "mods": {}}, "b": {"id": "ashen_host", "mods": {}}}, "apex": {"id": "rebirth"},
		"recipes": [],
		"sim": {"dps": 0.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "rebirth": 0.25},
		"vfx": {"kind": "flame_soldier", "width": 0.0, "length": 0.0, "lifetime": 1.5, "particles_max": 30, "telegraph": ""},
		"sfx": ["pyre_whoosh", "ember_burst"],
	},
	"echo": {
		"name": "M_ECHO", "desc": "M_ECHO_DESC", "rarity": "M", "family": "rift", "verb": "rule", "shape": "gate_echo",
		"home": 0, "meta2": true, "phase": 3, "mount": "chassis_rift", "crew": true, "silhouette": "twin_rings", "meshy": "A-31",
		"flags": {"hits_flying": false, "light": false, "ground_only": false, "bypass_shield": false},
		"base": {"echo": 0.5, "recharge": 14.0, "window": 12.0},
		"scale": [], "primary": {"stat": "echo", "per_level": 0.01, "mode": "add"}, "status": "", "proc": 0.0,
		"talent3": [{"id": "resonant_echo", "mods": {}}, {"id": "twin_echo", "mods": {}}],
		"ascension": {"a": {"id": "perfect_echo", "mods": {}}, "b": {"id": "harmonic_echo", "mods": {}}}, "apex": {"id": "reverb"},
		"recipes": ["E12"],
		"sim": {"dps": 0.0, "aoe_r": 0.0, "control_s": 0.0, "structure_mult": 1.0, "gate_gain": 0.0, "echo": 0.5},
		"vfx": {"kind": "echo_gate", "width": 0.0, "length": 0.0, "lifetime": 0.6, "particles_max": 20, "telegraph": "gate_outline"},
		"sfx": ["echo_reverb"],
	},
}

## Import data per machine model (§10.3); WS3 measures and overwrites these in
## gallery_weapons.gd. Placeholders follow the etap1 procedural models ("measured": false).
const FIT := {
	"drone": {"fit": AABB(Vector3(-0.4, 0.4, -0.4), Vector3(0.8, 0.4, 0.8)), "deck_y": 0.62, "yaw_pivot": Vector3(0, 0.62, 0),
			"muzzle": Vector3(0, -0.07, -0.25), "forward_deg": 0.0, "parts": {}, "measured": false},
	"ballista": {"fit": AABB(Vector3(-0.5, 0, -0.7), Vector3(1.0, 0.6, 1.4)), "deck_y": 0.34, "yaw_pivot": Vector3(0, 0.34, 0),
			"muzzle": Vector3(0, 0.245, -0.6), "forward_deg": 0.0, "parts": {}, "measured": false},
	"cannon": {"fit": AABB(Vector3(-0.45, 0, -0.75), Vector3(0.9, 0.7, 1.5)), "deck_y": 0.34, "yaw_pivot": Vector3(0, 0.34, 0),
			"muzzle": Vector3(0, 0.15, -0.72), "forward_deg": 0.0, "parts": {}, "measured": false},
	"rockets": {"fit": AABB(Vector3(-0.45, 0, -0.5), Vector3(0.9, 0.7, 1.0)), "deck_y": 0.34, "yaw_pivot": Vector3(0, 0.34, 0),
			"muzzle": Vector3(0, 0.02, -0.34), "forward_deg": 0.0, "parts": {}, "measured": false},
	"mortar": {"fit": AABB(Vector3(-0.45, 0, -0.55), Vector3(0.9, 0.8, 1.1)), "deck_y": 0.34, "yaw_pivot": Vector3(0, 0.34, 0),
			"muzzle": Vector3(0, 0.55, -0.4), "forward_deg": 0.0, "parts": {}, "measured": false},
	"gatling": {"fit": AABB(Vector3(-0.45, 0, -0.7), Vector3(0.9, 0.65, 1.4)), "deck_y": 0.34, "yaw_pivot": Vector3(0, 0.34, 0),
			"muzzle": Vector3(0, 0.2, -0.7), "forward_deg": 0.0, "parts": {}, "measured": false},
	"laser": {"fit": AABB(Vector3(-0.45, 0, -0.7), Vector3(0.9, 0.7, 1.4)), "deck_y": 0.34, "yaw_pivot": Vector3(0, 0.34, 0),
			"muzzle": Vector3(0, 0.0, -0.52), "forward_deg": 0.0, "parts": {}, "measured": false},
	"railgun": {"fit": AABB(Vector3(-0.45, 0, -0.9), Vector3(0.9, 0.7, 1.8)), "deck_y": 0.42, "yaw_pivot": Vector3(0, 0.42, 0),
			"muzzle": Vector3(0, 0.55, -0.95), "forward_deg": 0.0, "parts": {}, "measured": false},
	"prism": {"fit": AABB(Vector3(-0.45, 0.6, -0.45), Vector3(0.9, 1.0, 0.9)), "deck_y": 1.1, "yaw_pivot": Vector3(0, 1.1, 0),
			"muzzle": Vector3(0, 1.1, 0), "forward_deg": 0.0, "parts": {}, "measured": false},
}

## In-run Evolutions (gold EVOLVE gate; Meta-2). Catalyst: {"gate": op} or {"partner": id}.
const EVOLUTIONS := {
	"E1": {"machine": "ballista", "catalyst": {"gate": "multi"}, "name": "EVO_E1", "into": {"bolts": 5, "damage": 3.5, "rate": 1.0, "pierce": 4, "range": 16.0}},
	"E2": {"machine": "gatling", "catalyst": {"gate": "rate"}, "name": "EVO_E2", "into": {"damage": 0.7, "rate": 10.0, "ricochet": 2, "spinup": 0.0, "swarm_vs": 1.5}},
	"E3": {"machine": "rockets", "catalyst": {"gate": "dmg"}, "name": "EVO_E3", "into": {"volley": 12, "damage": 2.5, "period": 3.0, "fortress_share": 0.05}},
	"E4": {"machine": "ram", "catalyst": {"partner": "mortar"}, "name": "EVO_E4", "into": {"period": 3.0, "damage": 40.0, "spike_s": 2.0, "spike_dps": 2.0}},
	"E5": {"machine": "tesla", "catalyst": {"partner": "arc_fence"}, "name": "EVO_E5", "into": {"damage": 3.0, "radius": 6.0, "period": 1.2, "applies_jolt": true}},
	"E6": {"machine": "laser", "catalyst": {"partner": "prism"}, "name": "EVO_E6", "into": {"beams": 3, "dps": 5.0, "ramp_cap": 2.5}},
	"E7": {"machine": "drone", "catalyst": {"partner": "sentinel"}, "name": "EVO_E7", "into": {"drones": 3, "mark_vs": 1.35, "auto_paint": true}},
	"E8": {"machine": "cryo", "catalyst": {"partner": "frost_miner"}, "name": "EVO_E8", "into": {"period": 6.0, "ahead": 10.0, "damage": 2.0, "freeze_s": 1.5}},
	"E9": {"machine": "harvester", "catalyst": {"partner": "drone"}, "name": "EVO_E9", "into": {"reach": 3.0, "coin_chance": 0.35, "stair_add": 1}},
	"E10": {"machine": "railgun", "catalyst": {"partner": "arc_fence"}, "name": "EVO_E10", "into": {"charge": 1.5, "damage": 22.0, "lane_jolt_s": 3.0}},
	"E11": {"machine": "starfall", "catalyst": {"gate": "dmg"}, "name": "EVO_E11", "into": {"damage": 36.0, "crater_burn_s": 3.0}},
	"E12": {"machine": "echo", "catalyst": {"partner": "tuner"}, "name": "EVO_E12", "into": {"x_echo": 1.0}},
}

## In-run Fusions (gold FUSE gate, both parents Rank II+; Meta-2). Parent A keeps Apex/branch/finish.
const FUSIONS := {
	"F1": {"a": "tesla", "b": "cryo", "name": "FUS_F1", "into": {"damage": 2.5, "rate": 1.0, "jumps": 5, "chill_per_jump": 1}},
	"F2": {"a": "cannon", "b": "mortar", "name": "FUS_F2", "into": {"damage": 5.0, "radius": 1.6, "period": 2.0, "ahead": 12.0, "burn_pool_r": 1.5, "burn_pool_s": 3.0}},
	"F3": {"a": "laser", "b": "railgun", "name": "FUS_F3", "into": {"charge": 2.0, "beam_s": 1.5, "dps": 25.0, "pierce": 99}},
	"F4": {"a": "gatling", "b": "rockets", "name": "FUS_F4", "into": {"damage": 0.6, "rate": 8.0, "micro_every": 2.0, "micro": 3, "micro_damage": 1.5}},
	"F5": {"a": "gravity", "b": "cannon", "name": "FUS_F5", "into": {"period": 3.5, "damage": 8.0, "radius": 2.0}},
	"F6": {"a": "banner", "b": "sentinel", "name": "FUS_F6", "into": {"hold_vs": 1.5, "clash_loss": 0.25}},
	"F7": {"a": "arc_fence", "b": "aegis", "name": "FUS_F7", "into": {"absorb_every": 4.0, "stun_s": 1.0, "stun_r": 3.0}},
	"F8": {"a": "tuner", "b": "harvester", "name": "FUS_F8", "into": {"gate_add": 4.0, "coin_per_gate": 1, "x_gate_add": 0.15, "x_cap": 0.6}},
}

# ------------------------------------------------------------------ helpers (pure)

## Machines whose in-run behaviour ships in the current phase.
static func is_live(id: String) -> bool:
	return MACHINES.has(id) and not bool((MACHINES[id] as Dictionary).get("meta2", false))


## The 9 Meta-1 machines in roster order.
static func live_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if is_live(id):
			out.append(id)
	return out


static func rarity_of(id: String) -> String:
	return str((MACHINES[id] as Dictionary).get("rarity", "C"))


static func rarity_index(r: String) -> int:
	return RARITY_ORDER.find(r)


static func family_of(id: String) -> String:
	return str((MACHINES[id] as Dictionary).get("family", "kinetic"))


static func accent(id: String) -> Color:
	return (FAMILIES[family_of(id)] as Dictionary)["accent"]


static func acc_mult(lvl: int) -> float:
	return 1.0 + PER_LEVEL * float(clampi(lvl, 1, MAX_LEVEL) - 1)


## World of campaign level `level` (1-based; 8 levels per world; Invasion maps back onto 1..7).
static func world_of(level: int) -> int:
	var n := level if level <= CAMPAIGN_LEVELS else ((level - CAMPAIGN_LEVELS - 1) % CAMPAIGN_LEVELS) + 1
	return mini(7, (n - 1) / LEVELS_PER_WORLD + 1)


static func level_in_world(level: int) -> int:
	return (level - 1) % LEVELS_PER_WORLD + 1


static func is_boss(level: int) -> bool:
	return level_in_world(level) == LEVELS_PER_WORLD


## The machine of the platinum NEW crate on campaign level `level`, "" when none (or when that
## machine does not ship in this phase).
static func new_crate_at(level: int) -> String:
	if level < 1 or level > CAMPAIGN_LEVELS:
		return ""
	var per: Dictionary = NEW_CRATES.get(world_of(level), {})
	var id := str(per.get(level_in_world(level), ""))
	return id if is_live(id) else ""


## Campaign level whose NEW crate unlocks `id` (0 = owned at start or not crate-unlocked).
static func new_crate_level(id: String) -> int:
	for w: int in NEW_CRATES:
		var per: Dictionary = NEW_CRATES[w]
		for l: int in per:
			if str(per[l]) == id:
				return (w - 1) * LEVELS_PER_WORLD + l
	return 0


## Crate events on `level` (§3.2), excluding the boss extra unless `boss`.
static func crate_events(level: int, boss := false) -> int:
	var n := 0
	for band: Array in INRUN_BUDGET["crates"]:
		if level >= int(band[0]) and level <= int(band[1]):
			n = int(band[2])
	return n + (int(INRUN_BUDGET["boss_extra"]) if boss and n > 0 else 0)


static func rank_gates(level: int) -> int:
	if not bool(FEATURES["rank_gates"]):
		return 0
	for band: Array in INRUN_BUDGET["rank_gates"]:
		if level >= int(band[0]) and level <= int(band[1]):
			return int(band[2])
	return 0


static func pairs_on(level: int) -> bool:
	return bool(FEATURES["pairs"]) and level >= int(INRUN_BUDGET["pairs_from"])


## Bucket-2 overflow bonus of the `n`-th copy past Rank III (1-based).
static func overflow_bonus(n: int) -> float:
	return OVERFLOW[clampi(n - 1, 0, OVERFLOW.size() - 1)]


## Talent option pair for tier 0 (Lv3), 1 (Lv6) or 2 (Lv10) of machine `id`.
static func talent_options(id: String, tier: int) -> Array:
	if tier < 2:
		var fam: Array = FAMILY_TALENTS.get(family_of(id), [[], []])
		return fam[tier] if tier < fam.size() else []
	return (MACHINES[id] as Dictionary).get("talent3", [])


static func talent_mods(id: String, tier: int, talent_id: String) -> Dictionary:
	for t: Dictionary in talent_options(id, tier):
		if str(t["id"]) == talent_id:
			return t.get("mods", {})
	return {}


## Ascension form of `id` for `branch` ("a"/"b" for Epic+, ignored for Common/Rare).
static func ascension_of(id: String, branch := "a") -> Dictionary:
	var asc: Dictionary = (MACHINES[id] as Dictionary).get("ascension", {})
	if asc.has("a"):
		return asc.get(branch if branch in ["a", "b"] else "a", asc["a"])
	return asc


## Final numbers of machine `id` at account level `lvl`, in-run `rank` (1..3), with the chosen
## talents (ids per tier, "" = none) and Ascension branch. This is the §2.1 bucket-1 result:
## every key in `scale` already includes acc_mult x rank_mult. Arsenal.stats() wraps it with
## the account's values; Weapons reads `stats`, `add` (bucket 2) and `mods`.
static func machine_stats(id: String, lvl: int, rank := 1, talents: Array = [], branch := "") -> Dictionary:
	var m: Dictionary = MACHINES[id]
	var s: Dictionary = (m.get("base", {}) as Dictionary).duplicate(true)
	var scale: Array = m.get("scale", [])
	var mods := {}
	var add := 0.0
	rank = clampi(rank, 1, 3)
	lvl = clampi(lvl, 1, MAX_LEVEL)
	var ranks: Array = m.get("ranks", [])
	for r in range(1, mini(rank, ranks.size())):
		_merge(s, ranks[r], scale, mods, true)
	# Primary stat per level (§2.1 "+8% to the machine's PRIMARY stat per level").
	var prim: Dictionary = m.get("primary", {})
	var acc := acc_mult(lvl)
	if str(prim.get("mode", "mult")) == "add":
		var key := str(prim.get("stat", ""))
		if s.has(key):
			s[key] = float(s[key]) + float(prim.get("per_level", 0.0)) * float(lvl - 1)
	else:
		acc = 1.0 + float(prim.get("per_level", PER_LEVEL)) * float(lvl - 1)
		for k in prim.get("also", []):
			if s.has(k):
				s[k] = float(s[k]) * acc
	var rmult := RANK_MULT[rank - 1]
	for k in scale:
		if s.has(k):
			s[k] = float(s[k]) * acc * rmult
	# Talents (tier i needs Lv TALENT_LEVELS[i] and the tier's feature flag).
	var chosen: Array[String] = []
	for tier in 3:
		var tid := str(talents[tier]) if tier < talents.size() else ""
		var live := bool(FEATURES["talents12"]) if tier < 2 else bool(FEATURES["talent3"])
		if tid == "" or not live or lvl < TALENT_LEVELS[tier]:
			chosen.append("")
			continue
		chosen.append(tid)
		add += _merge(s, talent_mods(id, tier, tid), scale, mods)
	# Ascension (Lv8). Epic+ default to branch "a" until branches ship.
	var ascended := bool(FEATURES["ascension"]) and lvl >= ASCENSION_LEVEL
	var br := ""
	if ascended:
		var asc_any: Dictionary = m.get("ascension", {})
		br = (branch if branch in ["a", "b"] and bool(FEATURES["branches"]) else "a") if asc_any.has("a") else ""
		add += _merge(s, ascension_of(id, br).get("mods", {}), scale, mods)
	return {
		"id": id, "lvl": lvl, "rank": rank, "rarity": str(m["rarity"]), "family": str(m["family"]),
		"verb": str(m["verb"]), "status": str(m.get("status", "")), "proc": float(m.get("proc", 1.0)),
		"flags": (m.get("flags", {}) as Dictionary).duplicate(), "acc_mult": acc, "rank_mult": rmult,
		"add": add, "stats": s, "mods": mods, "talents": chosen, "branch": br, "ascended": ascended,
		"apex": bool(FEATURES["apex"]) and lvl >= APEX_LEVEL, "move": (m.get("move", {}) as Dictionary).duplicate(),
	}


## Merges a mods dict into stats `s` (grammar in the header). Returns the bucket-2 "add".
## `into_stats` (rank overrides): unknown keys become stats; otherwise they go to `mods`.
static func _merge(s: Dictionary, src: Dictionary, scale: Array, mods: Dictionary, into_stats := false) -> float:
	var add := 0.0
	for k: String in src:
		var v: Variant = src[k]
		var stem := k.trim_suffix("_mult").trim_suffix("_add")
		if k == "add":
			add += float(v)
		elif k == "dmg_mult":
			for sk in scale:
				if s.has(sk):
					s[sk] = float(s[sk]) * float(v)
		elif k.ends_with("_mult") and s.has(stem):
			s[stem] = float(s[stem]) * float(v)
		elif k.ends_with("_add") and s.has(stem):
			s[stem] = (int(s[stem]) + int(v)) if (s[stem] is int and v is int) else float(s[stem]) + float(v)
		elif into_stats or s.has(k):
			s[k] = v
		else:
			mods[k] = v
	return add
