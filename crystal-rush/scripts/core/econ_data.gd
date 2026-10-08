class_name EconData
## Every meta-economy number (arsenal_design.md §2.1, §4, §5, §6, §8; numbers printed by
## scratchpad economy_sim.py v2). Pure data plus pure formulas; nothing here reads Save or Meta.
## tools/export_econ.gd exports these for the sim, so the sim always tests the shipped numbers.
##
## Cost conventions (they differ on purpose, as in the sim):
## - COIN_TO[L] / BP_TO[r][L]: price to REACH machine level L (from L-1).
## - hero_cost(L): price of the level-up FROM hero level L to L+1.
## - barracks_cost(L): price to REACH track level L.

# ------------------------------------------------------------------ machine levels

const COIN_TO := {2: 40, 3: 80, 4: 150, 5: 250, 6: 380, 7: 540, 8: 740, 9: 980, 10: 1260,
		11: 1580, 12: 1950, 13: 3600, 14: 5200, 15: 7500}
const BP_TO := {
	"C": {2: 0, 3: 3, 4: 4, 5: 5, 6: 6, 7: 8, 8: 10, 9: 12, 10: 15, 11: 18, 12: 22, 13: 40, 14: 55, 15: 75},
	"R": {3: 1, 4: 2, 5: 2, 6: 3, 7: 3, 8: 4, 9: 5, 10: 6, 11: 7, 12: 9, 13: 16, 14: 22, 15: 30},
	"E": {4: 1, 5: 1, 6: 1, 7: 1, 8: 2, 9: 2, 10: 2, 11: 3, 12: 3, 13: 6, 14: 8, 15: 10},
	"L": {5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1, 11: 1, 12: 2, 13: 3, 14: 4, 15: 5},
	"M": {6: 1, 7: 1, 8: 1, 9: 1, 10: 1, 11: 1, 12: 1, 13: 3, 14: 4, 15: 5},
}
const START_LEVEL := {"C": 1, "R": 2, "E": 3, "L": 4, "M": 5}
## Arsenal Sync: a new machine starts at max(rarity start, min(SYNC_CAP, 3rd-best Lv - SYNC_BEHIND)).
const SYNC_CAP := 7
const SYNC_BEHIND := 2

# ------------------------------------------------------------------ heroes (§4.1)

const HERO := {
	"max": 30, "k": 30.0, "exp": 1.4,
	"dmg_per_lvl": 0.035, "hp_per_lvl": 0.04, "ult_rate_per_lvl": 0.01,
	"cap_base": 6, "cap_per_world": 3,               # cap = 6 + 3 x world reached (30 in Invasion)
	"ult_rank_at": [1, 5, 15, 25],                   # Ult Rank I..IV from these hero levels
	"ult_rank_bonus": 0.20,                          # per Ult Rank above I (+20% ult effect)
	"awakening_at": [10, 20, 30],                    # Meta-2 looks
	"aspect_at": [1, 10, 20],                        # Meta-2
	"overdrive_at": 10,                              # Meta-2 (plan2 §4)
}
## Campaign level whose WIN unlocks each hero (0 = from the start; -1 = later phase).
## Seer: playable from L6 for now (design §4.1 target: the World 3 boss).
const HERO_UNLOCK := {"bolt": 0, "titan": 4, "seer": 5}
## The 2.2.1 (Save v2) hero unlock table, FROZEN: the v2 -> v3 update day gives every hero a v2 player
## had met by these rules (a Seer met at L5 stays owned after she moves to L24, heroes_design.md §11.1).
const HERO_UNLOCK_V2 := {"bolt": 0, "titan": 4, "seer": 5}

# ------------------------------------------------------------------ Heroes & Champions phase flag

## Heroes & Champions build phase (heroes_design.md §13.2). While HEROES_PHASE < HEROES_LIVE_PHASE the
## game behaves exactly as 2.2.1: Save v3 sections exist, load, sanitise and migrate, but nothing in the
## shipped flow reads them and the update-day conversion + lump grant (SaveMigrate.update_day) waits for
## the build that turns the hero systems on (H3).
const HEROES_PHASE := 0
const HEROES_LIVE_PHASE := 3
## Champions in the run (WS-C, phase H2): from this phase DEV runs (Save.readonly: autotest, bot,
## level_check) read the v3 hero / team blocks of Meta.run_profile; a real account only from
## HEROES_LIVE_PHASE.
const HEROES_RUN_PHASE := 2
## The Workshop (WS-F, phase H4) opens its unlock row only from this phase (release 1 if green by the
## release cut, else release 2; the retro grant makes a late unlock lossless).
const HEROES_WORKSHOP_PHASE := 4

## Tests and dev tools ONLY (never set by the shipped flow): -1 = the shipped flags; >= 0 forces
## the heroes phase / the Meta-1 ArsenalData.PHASE so a flag-off build can test the live rules.
## Every test that sets one restores -1.
static var phase_override := -1
static var meta_phase_override := -1


## The heroes build phase in effect (HEROES_PHASE unless a test overrides it).
static func heroes_phase() -> int:
	return HEROES_PHASE if phase_override < 0 else phase_override


static func heroes_live() -> bool:
	return heroes_phase() >= HEROES_LIVE_PHASE


## Champions-in-the-run phase reached (dev runs only until heroes_live()).
static func heroes_run() -> bool:
	return heroes_phase() >= HEROES_RUN_PHASE


## The Meta-1 content phase the UnlockQueue opens rows for (ArsenalData.PHASE unless overridden).
static func meta_phase() -> int:
	return ArsenalData.PHASE if meta_phase_override < 0 else meta_phase_override
const HERO_ASPECTS := {
	"bolt": ["forked_fox", "railshot", "storm_fox"],
	"titan": ["bulwark", "seismic", "crystal_colossus"],
	"seer": ["foresight", "starweave", "eclipse"],
}
const GLORY_AT_BOSS_WINS: Array[int] = [1, 3, 5, 7]   # Glory 2..5 (Meta-2)

# ------------------------------------------------------------------ Barracks (§4.2)

const BARRACKS_MAX := 10
const BARRACKS_K := 70.0
const BARRACKS_EXP := 1.55
## Track cap = BARRACKS_CAP_BASE + BARRACKS_CAP_PER_WORLD x world reached (W1 4 ... W4+ 10).
const BARRACKS_CAP_BASE := 2
const BARRACKS_CAP_PER_WORLD := 2
## Effect of each track at level L: value = per_level x L (per x L / every for "every": Recruits is
## +0.5 soldier per group per level on average; the run hands the halves out alternately, so every
## level counts).
const BARRACKS_ORDER: Array[String] = ["recruits", "reserves", "scrape_guard", "drill", "volleys"]
const BARRACKS := {
	"recruits": {"name": "BAR_RECRUITS", "desc": "BAR_RECRUITS_DESC", "per": 1, "every": 2, "unit": "soldiers_per_group", "icon": "recruits"},
	"reserves": {"name": "BAR_RESERVES", "desc": "BAR_RESERVES_DESC", "per_level": 2, "unit": "soldiers_at_siege", "icon": "reserves"},
	"scrape_guard": {"name": "BAR_SCRAPE", "desc": "BAR_SCRAPE_DESC", "per_level": 1, "unit": "saved_per_contact", "icon": "shield"},
	"drill": {"name": "BAR_DRILL", "desc": "BAR_DRILL_DESC", "per_level": 0.03, "unit": "clash_loss_add", "icon": "drill", "window_s": 2.0},
	"volleys": {"name": "BAR_VOLLEYS", "desc": "BAR_VOLLEYS_DESC", "per_level": 0.06, "unit": "volley_add", "icon": "volley"},
}

## Tactics row (Meta-2, opens after L26). Independent price per rank.
const TACTICS_PRICE: Array[int] = [600, 1400, 2800]
const TACTICS_MAX := 3
const TACTICS := {
	"crate_craft": {"name": "TAC_CRATE_CRAFT", "per_rank": -0.10, "unit": "crate_bonus_hp"},
	"weak_point": {"name": "TAC_WEAK_POINT", "per_rank": 0.15, "unit": "weak_point_add", "move_s": 3.0},
	"streak": {"name": "TAC_STREAK", "every": [8, 6, 5], "unit": "tiles_per_soldier"},
	"lead_engineer": {"name": "TAC_LEAD_ENGINEER", "per_rank": 0.04, "unit": "lead_add"},
	"war_chest": {"name": "TAC_WAR_CHEST", "per_rank": 0.05, "unit": "victory_coins"},
	"ult_primer": {"name": "TAC_ULT_PRIMER", "per_rank": 0.05, "unit": "ult_start"},
}

# ------------------------------------------------------------------ Haven, Crowns (Meta-2)

const HAVEN_COST: Array[int] = [2, 3, 4, 4, 5]
const HAVEN_PASSIVES := {
	1: ["deck_preset", "shard_glint_25", "victory_coins_3", "lowgrav_arcs", "finish_starlight"],
	2: ["current_early", "rank_label_40", "pickup_coins_3", "bubble_capacity", "finish_coral"],
	3: ["phantom_range", "mirror_preview", "victory_coins_3", "rune_reveal_fast", "finish_runic"],
	4: ["lava_early", "light_hit_icon", "pickup_coins_3", "melt_forecast", "finish_magma"],
	5: ["ice_path", "shield_bar", "victory_coins_3", "frozen_hp", "finish_frostglass"],
	6: ["splitter_preview", "flyer_shadow", "pickup_coins_3", "portal_ring", "finish_stormcloud"],
	7: ["rift_icons", "evolve_extra_row", "victory_coins_3", "deck_preset", "finish_void"],
}
const HAVEN_FEATURED := {"bp_bundle": {"C": 8, "R": 4, "E": 2, "L": 2}, "items": ["bp_bundle", "bp_bundle", "soldier_skin", "altar_theme"]}
## Crown 2 threshold per level (baked by tools/bake_crowns.gd from LevelSim; empty until baked).
const CROWN_ARMY := {}

# ------------------------------------------------------------------ Caches (§5)

const CACHE_ORDER: Array[String] = ["stone", "world", "royal", "xray"]
const CACHES := {
	"stone": {"name": "CACHE_STONE", "slots": 3, "guaranteed": "R", "coins": [30, 3], "leg_weight": 1.0,
			"mythic": false, "altar": false, "inline": true, "meshy": "A-32"},
	"world": {"name": "CACHE_WORLD", "slots": 5, "guaranteed": "E", "coins": [120, 8], "leg_weight": 1.0,
			"mythic": true, "altar": true, "inline": false, "meshy": "A-33"},
	"royal": {"name": "CACHE_ROYAL", "slots": 8, "guaranteed": "E", "coins": [300, 12], "leg_weight": 4.0,
			"mythic": true, "altar": true, "inline": false, "meshy": "A-34", "phase": 3},
	"xray": {"name": "CACHE_XRAY", "slots": 0, "fixed": true, "altar": true, "inline": false, "meshy": "A-35", "phase": 3},
}
## Per-card rarity weights in a free slot (%), re-normalised over the rarities in the pool.
const CARD_ODDS := {"C": 68.0, "R": 24.0, "E": 6.5, "L": 1.4, "M": 0.1}
## Blueprints per card: [min, max] uniform.
const STACK := {"C": [2, 4], "R": [1, 2], "E": [1, 1], "L": [1, 1], "M": [1, 1]}
const PITY := {"epic": 8, "leg_soft": 20, "leg_hard": 30, "leg_soft_step": 0.03, "leg_welcome": true}
const WILD_CARD_CHANCE := 0.005
const DECK_WEIGHT := 1.5
const FOCUS_SHARE := 0.40
## First level whose WIN grants a Cache (and from which 3 losses give one).
const CACHE_FROM_LEVEL := 6
const LOSS_CACHE_CHARGE := 1.0 / 3.0
## Caches from this many Stone Caches on go to the Vault by default (setting caches_to_vault).
const VAULT_DEFAULT_FROM := 11
## Inline Stone reveal / Altar beat timings (§5.6) for the UI.
const REVEAL := {"inline_max": 2.5, "skip_from": 0.5, "auto_strike": 1.0, "tell": 0.15, "burst": 0.25, "fan": 0.35,
		"fan_stagger": 0.06, "flip": {"C": 0.25, "R": 0.35, "E": 0.5, "L": 1.2, "M": 2.0}, "hitstop": 0.08,
		"trauma": 0.35, "trauma_leg": 0.6, "particles": {"C": 40, "R": 70, "E": 120, "L": 200, "M": 250}}

# ------------------------------------------------------------------ run rewards (§6.2)

## Run drip: each fielded machine of a WON run fills its blueprint bar by this (x DRIP_RANK3 at
## Rank III; x DRIP_LOSS on a loss). Fractions accumulate in the machine's `frac`.
const DRIP := {"C": 1.0, "R": 0.5, "E": 0.25, "L": 0.12, "M": 0.06}
const DRIP_RANK3 := 1.5
const DRIP_LOSS := 0.5
const LOSS := {"victory_share": 0.25, "pickup_share": 0.70}
const REPLAY := {"share": 0.60, "caches_per_day": 3, "crowns": false}
const INVASION := {"from_level": 57, "levels": 56, "difficulty_offset": 56, "pay_half": true}
## Reinforcements (retry assist, §4.4): per loss on the same level, capped.
const RETRY_ASSIST := {"soldiers": 2, "dmg_add": 0.05, "cap": 5, "default_on": true}
const AD_RULES := {"cap_per_day": 3, "free_levels": 10, "mult": 2.0, "on_loss": false}
## Harvester / Seal coins are capped at this share of the level's victory coins.
const COIN_CAP_SHARE := 0.25

# ------------------------------------------------------------------ mastery, finishes (Meta-2 display)

const MASTERY_XP := {"run": 10, "rank3": 5, "evolved": 5, "tiers": [40, 120, 250, 450, 750, 1200]}
const FINISHES := [
	{"id": "polished", "name": "FIN_POLISHED"}, {"id": "gold_trim", "name": "FIN_GOLD_TRIM"},
	{"id": "crystal_inlay", "name": "FIN_CRYSTAL_INLAY"}, {"id": "energy_veins", "name": "FIN_ENERGY_VEINS"},
	{"id": "halo", "name": "FIN_HALO"}, {"id": "infinity", "name": "FIN_INFINITY"},
]
const FLARES: Array[String] = ["obsidian", "aurora", "ember", "frostglass", "rose_gold", "void"]
## Arsenal Rating (no damage): per machine level, Ascension, finish, Apex.
const RATING := {"per_level": 1, "ascension": 5, "finish": 2, "apex": 3}

# ------------------------------------------------------------------ liveops-lite (Meta-2/3 data)

const LOGIN_CYCLE := [["coins", 150], ["bp_rare", 2], ["coins", 250], ["cache", "stone"], ["gems", 20],
		["coins", 400], ["cache", "royal"]]
const DAILY := {"missions": 3, "bank_days": 3, "rerolls": 1, "gems": 5, "road_xp": 40, "coins_base": 60, "coins_per_frontier": 4}
const WEEKLY := {"missions": 5, "target_mult": 4, "bank_weeks": 1, "cache": "world", "coins": 1500, "gems": 50, "road_xp": 100}
## [id, counter key in Run.result.stats / [counters], target]. MIS_<id> is the Loc key.
const MISSION_POOL := [
	["M01", "wins", 3], ["M02", "crates_opened", 4], ["M03", "crate_bonus", 2], ["M04", "rank3_reached", 1],
	["M05", "rank_gates", 2], ["M06", "evolutions+fusions", 1], ["M07", "wins_with_lead", 2], ["M08", "kills_by_family", 60],
	["M09", "statuses.freeze", 10], ["M10", "statuses.burn", 15], ["M11", "statuses.mark", 20], ["M12", "reactions_total", 3],
	["M13", "barricades_broken", 4], ["M14", "turrets_destroyed", 5], ["M15", "recruits", 30], ["M16", "levels_no_hazard_loss", 1],
	["M17", "stairs_reached_3", 2], ["M18", "gates_by_op.good", 8], ["M19", "gates_by_op.charge_flipped", 3], ["M20", "ult_uses", 4],
	["M21", "apex_uses", 2], ["M22", "fortress_fast", 1], ["M23", "levels_all_shards", 1], ["M24", "crowns_gained", 5],
	["M25", "invasion_wins", 2], ["M26", "wins_family3", 1], ["M27", "caches_opened", 2], ["M28", "upgrades_bought", 3],
]
## [id, counter, [tier1, tier2, tier3]]; FEAT_<id> Loc key. Rewards: FEAT_GEMS per tier.
const FEAT_GEMS: Array[int] = [10, 25, 50]
const FEATS := [
	["F01", "wins", [25, 100, 400]], ["F02", "crowns_total", [30, 90, 168]], ["F03", "haven_complete", [1, 4, 7]],
	["F04", "citadel", [10, 20, 35]], ["F05", "machines_owned", [8, 16, 24]], ["F06", "ascensions", [1, 6, 20]],
	["F07", "apex_unlocked", [1, 6, 20]], ["F08", "mastered", [1, 8, 24]], ["F09", "finishes_total", [10, 50, 144]],
	["F10", "rank3_reached", [10, 100, 500]], ["F11", "evolutions", [5, 40, 150]], ["F12", "fusions", [3, 25, 100]],
	["F13", "evolutions_distinct", [3, 8, 12]], ["F14", "fusions_distinct", [2, 5, 8]], ["F15", "crates_opened", [50, 400, 2000]],
	["F16", "crate_bonus", [20, 150, 800]], ["F17", "rank_gates", [10, 80, 400]], ["F18", "catalyst_gates", [5, 40, 200]],
	["F19", "gates_by_op.good", [200, 1500, 8000]], ["F20", "gates_by_op.charge_flipped", [20, 150, 800]],
	["F21", "statuses.freeze", [50, 400, 2000]], ["F22", "statuses.burn", [50, 400, 2000]], ["F23", "statuses.mark", [50, 400, 2000]],
	["F24", "statuses.stun", [50, 400, 2000]], ["F25", "reactions.superconduct", [10, 80, 400]],
	["F26", "reactions.thermal_shock", [10, 80, 400]], ["F27", "reactions.flare", [10, 80, 400]],
	["F28", "blades_frozen", [1, 25, 150]], ["F29", "lava_quenched", [1, 25, 150]], ["F30", "phantoms_revealed", [10, 100, 500]],
	["F31", "flyers_grounded", [10, 100, 500]], ["F32", "barricades_broken", [30, 250, 1500]], ["F33", "turrets_destroyed", [30, 250, 1500]],
	["F34", "geodes_broken", [30, 250, 1500]], ["F35", "recruits", [200, 2000, 10000]], ["F36", "levels_no_hazard_loss", [5, 40, 200]],
	["F37", "stairs_reached_5", [1, 20, 100]], ["F38", "fortress_fast", [5, 40, 200]], ["F39", "levels_all_shards", [10, 60, 112]],
	["F40", "ult_uses", [50, 400, 2000]], ["F41", "apex_uses", [10, 100, 600]], ["F42", "overdrive_uses", [5, 50, 300]],
	["F43", "codex_entries", [5, 12, 20]], ["F44", "mythics_forged", [1, 2, 4]], ["F45", "bosses_beaten", [3, 7, 14]],
	["F46", "nightmares_cleared", [1, 4, 7]], ["F47", "invasion_wins", [8, 28, 56]], ["F48", "expedition_full", [1, 5, 20]],
	["F49", "glory_total", [4, 8, 12]], ["F50", "hero_max_level", [10, 20, 30]], ["F51", "barracks_levels", [10, 30, 50]],
	["F52", "tactics_ranks", [3, 10, 18]], ["F53", "caches_opened", [25, 200, 1000]], ["F54", "legendary_cards", [3, 20, 100]],
	["F55", "missions_done", [20, 150, 600]], ["F56", "weeklies_done", [2, 10, 40]], ["F57", "road_tiers", [10, 60, 120]],
	["F58", "families_won_with", [2, 4, 6]], ["F59", "comeback_no_assist", [1, 5, 20]], ["F60", "wins_no_machines", [1, 5, 20]],
]
## Arsenal Track (Meta-3): a node every `step` rating, 12-node cycle, fixed Wild Legendary overrides.
const TRACK := {"step": 10, "cycle": [["coins", 0], ["coins", 0], ["cache", "stone"], ["wild_C", 3], ["gems", 20],
		["cache", "stone"], ["coins", 0], ["wild_R", 2], ["cache", "stone"], ["gems", 20], ["wild_E", 1], ["cache", "royal"]],
		"coins_base": 100, "coins_per_frontier": 10, "wild_L_at": [150, 300, 450]}
const ROAD := {"chapters": 12, "tiers": 10, "xp_per_tier": 100, "xp_win": 5, "wins_per_day": 20}


## What one Road node pays (arsenal_design.md §8.3; Road is Meta-3 data until road.gd ships):
## {cur, n}. From the heroes phase the paid lane (`road_premium`) pays no Gems (heroes_design.md §7.7,
## critique m4): a Gem node of the premium lane pays coins at the Arsenal Track's own exchange rate
## (a Track Gem node and a Track coin node are equal steps of the TRACK cycle, so n Gems =
## n / track_gem_node() x track_coin_node(frontier) coins). The free lane is unchanged.
static func road_node(lane: String, cur: String, n: int, frontier: int) -> Dictionary:
	if lane == "premium" and cur == "gems" and heroes_live():
		return {"cur": "coins", "n": int(round(float(n) * float(track_coin_node(frontier)) / float(maxi(1, track_gem_node()))))}
	return {"cur": cur, "n": n}


## Coins of an Arsenal Track coin node at `frontier` (TRACK coins_base + coins_per_frontier x frontier).
static func track_coin_node(frontier: int) -> int:
	return int(TRACK["coins_base"]) + int(TRACK["coins_per_frontier"]) * mini(maxi(1, frontier), ArsenalData.CAMPAIGN_LEVELS)


## Gems of an Arsenal Track Gem node (the first ["gems", n] step of the TRACK cycle).
static func track_gem_node() -> int:
	for step: Array in TRACK["cycle"]:
		if str(step[0]) == "gems":
			return int(step[1])
	return 1

## Real-money SKUs (Meta-3; all non-consumable) and the per-world set cap (filled by the sim).
const SKUS := {
	"starter_arsenal": {"tier": "2.99", "coins": 2000, "bp": {"drone": 6, "ballista": 6}, "finish": "royal_gold", "from_level": 28},
	"supporter": {"tier": "4.99", "ad_free_x2": true, "altar_theme": "sunrise", "from_level": 28},
	"world_set": {"tier": "1.99", "per_world": true, "cleared_ago": 2},
	"road_premium": {"tier": "4.99", "from_level": 43},
	"skin_storm_regalia_bolt": {"tier": "3.99", "from_level": 28},
	"skin_obsidian_titan": {"tier": "3.99", "from_level": 28},
	"flare_obsidian": {"tier": "2.99", "from_level": 33},
	"flare_aurora": {"tier": "2.99", "from_level": 33},
	"flare_rose_gold": {"tier": "2.99", "from_level": 33},
}
const WORLD_SET_CAP := {}

# ------------------------------------------------------------------ UnlockQueue (§4.6)

## Session rules: at most `per_session` new systems per session (session = foreground after
## >= `session_gap_s` away); tab/currency unlocks at least `tab_gap_levels` apart unless
## "gap_exempt". `after_win` = campaign level whose WIN opens it; `from_level` = in-run
## features live from that level. `free` names the first free step. phase > 1 = data only.
const UNLOCK_RULES := {"per_session": 2, "session_gap_s": 300, "tab_gap_levels": 2}
const UNLOCKS := [
	{"id": "drag", "kind": "inrun", "from_level": 1, "line": "UNL_DRAG", "phase": 1},
	{"id": "arsenal", "kind": "tab", "after_win": 3, "line": "UNL_ARSENAL", "free": "ballista_lv2", "phase": 1},
	{"id": "heroes", "kind": "tab", "after_win": 4, "line": "UNL_HEROES", "free": "hero_level", "gap_exempt": true, "phase": 1},
	{"id": "titan", "kind": "hero", "after_win": 4, "line": "", "phase": 1},
	{"id": "seer", "kind": "hero", "after_win": 5, "line": "", "phase": 1},
	{"id": "pairs", "kind": "inrun", "from_level": 5, "line": "UNL_PAIRS", "phase": 1},
	{"id": "stone_cache", "kind": "currency", "after_win": 6, "line": "UNL_STONE_CACHE", "free": "scripted_cache", "phase": 1},
	{"id": "altar", "kind": "system", "after_win": 8, "line": "UNL_ALTAR", "free": "world_cache", "phase": 1},
	{"id": "deck", "kind": "system", "after_win": 10, "line": "UNL_DECK", "free": "auto_deck", "phase": 1},
	{"id": "rank_gates", "kind": "inrun", "from_level": 11, "line": "UNL_RANK_GATES", "phase": 1},
	{"id": "barracks", "kind": "tab", "after_win": 12, "line": "UNL_BARRACKS", "free": "recruits_lv1", "phase": 1},
	{"id": "talents", "kind": "system", "after_win": 13, "line": "UNL_TALENTS", "free": "talent_pick", "phase": 1},
	{"id": "haven", "kind": "currency", "after_win": 16, "line": "UNL_HAVEN", "free": "haven_stage1", "phase": 2},
	{"id": "dailies", "kind": "system", "after_win": 17, "line": "UNL_DAILIES", "free": "first_mission", "phase": 2},
	{"id": "evolve_hint", "kind": "inrun", "from_level": 11, "line": "UNL_EVOLVE", "phase": 2},
	{"id": "rift_anvil", "kind": "system", "after_win": 24, "line": "UNL_RIFT_ANVIL", "free": "first_forge", "phase": 3},
	{"id": "tactics", "kind": "system", "after_win": 26, "line": "UNL_TACTICS", "free": "first_rank", "phase": 2},
	{"id": "shop", "kind": "tab", "after_win": 28, "line": "UNL_SHOP", "phase": 3},
	{"id": "finishes", "kind": "system", "after_win": 33, "line": "UNL_FINISHES", "free": "first_finish", "phase": 2},
	{"id": "track", "kind": "system", "after_win": 41, "line": "UNL_TRACK", "free": "royal_cache", "phase": 3},
	{"id": "expedition", "kind": "system", "after_win": 43, "line": "UNL_EXPEDITION", "phase": 3},
	{"id": "invasion", "kind": "system", "after_win": 56, "line": "UNL_INVASION", "phase": 3},
]

## Fixed keys of Run.result.stats (§9.4). Missions and feats reference only these (test).
const STATS_KEYS: Array[String] = ["wins", "kills_total", "kills_by_machine", "kills_by_family", "crates_opened",
		"crate_bonus", "rank_gates", "catalyst_gates", "rank3_reached", "evolutions", "fusions", "evolutions_ids",
		"fusions_ids", "gates_by_op", "statuses", "reactions", "reactions_total", "blades_frozen", "lava_quenched",
		"phantoms_revealed", "flyers_grounded", "barricades_broken", "turrets_destroyed", "geodes_broken", "recruits",
		"tiles", "hazard_losses", "clash_losses", "levels_no_hazard_loss", "star_shards", "levels_all_shards",
		"ult_uses", "apex_uses", "overdrive_uses", "fortress_time", "fortress_fast", "army_peak", "army_at_fortress",
		"survivors", "stairs_mult", "stairs_reached_3", "stairs_reached_5", "crowns_gained", "invasion_wins",
		"wins_family3", "wins_no_machines", "wins_with_lead"]
## Heroes & Champions stats keys (heroes_design.md §12.5), appended by stats_keys() from the heroes
## phase on; wins_with_hero and synergy_wins are {id: n} dictionaries like wins_with_lead.
const STATS_KEYS_HEROES: Array[String] = ["champion_kills", "champion_heals", "champion_blocks", "champions_lost",
		"wins_full_team", "wins_with_hero", "synergy_wins"]
const STATS_DICT_KEYS_HEROES: Array[String] = ["wins_with_hero", "synergy_wins"]


## The fixed Run.result.stats keys of the current phase (STATS_KEYS while the heroes phase is off,
## so the 2.2.1 result and counters stay byte-identical).
static func stats_keys() -> Array[String]:
	var out: Array[String] = STATS_KEYS.duplicate()
	if heroes_live():
		out.append_array(STATS_KEYS_HEROES)
	return out

# ------------------------------------------------------------------ formulas

## Coins to level hero from `lvl` to `lvl + 1` (L1->2 30, L10->11 750; 42 140 for 1->30).
static func hero_cost(lvl: int) -> int:
	return int(round(float(HERO["k"]) * pow(float(lvl), float(HERO["exp"])) / 10.0)) * 10


## Highest hero level allowed with `world_reached` (30 in Invasion).
static func hero_cap(world_reached: int, invasion := false) -> int:
	if invasion:
		return int(HERO["max"])
	return mini(int(HERO["max"]), int(HERO["cap_base"]) + int(HERO["cap_per_world"]) * world_reached)


static func hero_ult_rank(lvl: int) -> int:
	var r := 0
	for at: int in HERO["ult_rank_at"]:
		if lvl >= at:
			r += 1
	return maxi(r, 1)


## Hero multipliers at level `lvl`: {dmg_mult, hp_mult, ult_rate_mult, ult_rank}.
static func hero_mults(lvl: int) -> Dictionary:
	var n := float(maxi(lvl, 1) - 1)
	return {"dmg_mult": 1.0 + float(HERO["dmg_per_lvl"]) * n, "hp_mult": 1.0 + float(HERO["hp_per_lvl"]) * n,
			"ult_rate_mult": 1.0 + float(HERO["ult_rate_per_lvl"]) * n, "ult_rank": hero_ult_rank(lvl)}


## Coins to REACH Barracks track level `lvl` (L1 70, L5 850, L10 2 485).
static func barracks_cost(lvl: int) -> int:
	return int(round(BARRACKS_K * pow(float(lvl), BARRACKS_EXP) / 5.0)) * 5


static func barracks_cap(world_reached: int) -> int:
	return mini(BARRACKS_MAX, BARRACKS_CAP_BASE + BARRACKS_CAP_PER_WORLD * world_reached)


## Effect value of Barracks `track` at level `lvl` (soldiers, or a fraction for drill / volleys).
static func barracks_value(track: String, lvl: int) -> float:
	var t: Dictionary = BARRACKS[track]
	if t.has("every"):
		return float(t["per"]) * float(lvl) / float(t["every"])
	return float(t["per_level"]) * float(lvl)


## Coins for a won level before the stairs (× (1 + 0.05 × War Chest rank)).
static func victory_coins(level: int, survivors: int, war_chest_rank := 0) -> int:
	var v := 20 + 6 * level + mini(survivors / 3, 25)
	return int(round(float(v) * (1.0 + float(TACTICS["war_chest"]["per_rank"]) * war_chest_rank)))


## Expected road coins on `level` (sim model; the run reports the real pickups).
static func pickup_estimate(level: int) -> float:
	return 8.0 + 0.7 * float(level)


## Win payout: (victory + pickups) × stairs multiplier (replay pays REPLAY.share of it).
static func win_coins(victory: int, pickups: int, stairs_mult: float, replay := false) -> int:
	var c := float(victory + pickups) * stairs_mult
	return int(round(c * (float(REPLAY["share"]) if replay else 1.0)))


## Loss payout: (0.25 × victory_coins(L, 0) + 0.70 × pickups) × bridge fraction.
static func loss_coins(level: int, pickups: int, bridge_fraction: float) -> int:
	var v := float(LOSS["victory_share"]) * float(victory_coins(level, 0)) + float(LOSS["pickup_share"]) * float(pickups)
	return int(round(v * clampf(bridge_fraction, 0.0, 1.0)))


## Coin bonus slot of a Cache of `type` at campaign frontier `frontier`.
static func cache_coins(type: String, frontier: int) -> int:
	var c: Array = (CACHES[type] as Dictionary).get("coins", [0, 0])
	return int(c[0]) + int(c[1]) * frontier


## Which Cache a WIN of `level` grants ("" before CACHE_FROM_LEVEL): World on bosses, else Stone.
static func win_cache(level: int) -> String:
	if level < CACHE_FROM_LEVEL:
		return ""
	return "world" if ArsenalData.is_boss(level) else "stone"


## Reinforcements for `stacks` losses in a row on one level: {soldiers, dmg_add}.
static func assist(stacks: int) -> Dictionary:
	var s := clampi(stacks, 0, int(RETRY_ASSIST["cap"]))
	return {"stacks": s, "soldiers": s * int(RETRY_ASSIST["soldiers"]), "dmg_add": float(s) * float(RETRY_ASSIST["dmg_add"])}


## Blueprints needed to reach `lvl` for rarity `r` (0 when none / below the rarity start).
static func bp_to(r: String, lvl: int) -> int:
	return int((BP_TO[r] as Dictionary).get(lvl, 0))


static func coin_to(lvl: int) -> int:
	return int(COIN_TO.get(lvl, 0))


## Coins (and blueprints of rarity r) from rarity start to Lv15.
static func full_machine_cost(r: String) -> Dictionary:
	var coins := 0
	var bp := 0
	for l in range(int(START_LEVEL[r]) + 1, ArsenalData.MAX_LEVEL + 1):
		coins += coin_to(l)
		bp += bp_to(r, l)
	return {"coins": coins, "bp": bp}


## Daily mission coins at `frontier`.
static func mission_coins(frontier: int) -> int:
	return int(DAILY["coins_base"]) + int(DAILY["coins_per_frontier"]) * frontier


## Unlock entry by id ({} when unknown) in the rows of the current phase (unlocks()).
static func unlock_entry(id: String) -> Dictionary:
	for u: Dictionary in unlocks():
		if str(u["id"]) == id:
			return u
	return {}


## Heroes & Champions rows (heroes_design.md §11.1). `heroes` = the heroes phase that opens the row
## (HEROES_LIVE_PHASE; the Workshop HEROES_WORKSHOP_PHASE); levels come from SaveV3Data.UNLOCK_AT
## (generated from heroes_consts.json). `kind hero` never takes a session slot. The Seer's row moves
## from the 2.2.1 L5 to UNLOCK_AT.seer (the World 3 boss) and L5 becomes her one guest level.
static func unlocks_heroes() -> Array[Dictionary]:
	var at: Dictionary = SaveV3Data.UNLOCK_AT
	var live := HEROES_LIVE_PHASE
	return [
		{"id": "seer_guest", "kind": "inrun", "from_level": int(HERO_UNLOCK_V2["seer"]), "line": "", "phase": 1, "heroes": live},
		{"id": "champions", "kind": "system", "after_win": int(at["champions"]), "line": "UNL_CHAMPIONS", "free": "first_champion", "phase": 1, "heroes": live},
		{"id": "portal", "kind": "currency", "after_win": int(at["portal"]), "line": "UNL_PORTAL", "free": "welcome_x10", "phase": 1, "heroes": live},
		{"id": "skills", "kind": "system", "after_win": int(at["skills"]), "line": "UNL_SKILLS", "free": "first_rank", "phase": 1, "heroes": live},
		{"id": "workshop", "kind": "system", "after_win": int(at["workshop"]), "line": "UNL_WORKSHOP", "free": "first_craft", "phase": 1, "heroes": HEROES_WORKSHOP_PHASE},
		{"id": "slot3", "kind": "hero", "after_win": int(at["slot3"]), "line": "UNL_SLOT3", "phase": 1, "heroes": live},
	]


static var _unlocks_cache: Array[Dictionary] = []
static var _unlocks_phase := -2


## Every UNLOCKS row of the current heroes phase, in level order. While the heroes phase is off this
## is exactly the 2.2.1 UNLOCKS table (same rows, same order); from HEROES_LIVE_PHASE the Seer row moves
## to UNLOCK_AT.seer and the §11.1 rows join (a row whose `heroes` phase is not reached stays out).
static func unlocks() -> Array[Dictionary]:
	var ph := heroes_phase()
	if ph == _unlocks_phase:
		return _unlocks_cache
	var out: Array[Dictionary] = []
	for u: Dictionary in UNLOCKS:
		out.append(u)
	if ph >= HEROES_LIVE_PHASE:
		for i in out.size():
			if str(out[i]["id"]) == "seer":
				var s: Dictionary = out[i].duplicate()
				s["after_win"] = int(SaveV3Data.UNLOCK_AT["seer"])
				out[i] = s
		for h: Dictionary in unlocks_heroes():
			if ph >= int(h["heroes"]):
				out.append(h)
		# Stable by level: rows of the same level keep the table order (2.2.1 rows first).
		var keyed: Array = []
		for i2 in out.size():
			keyed.append([_unlock_at(out[i2]) * 1000 + i2, out[i2]])
		keyed.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		out.clear()
		for k: Array in keyed:
			out.append(k[1])
	_unlocks_cache = out
	_unlocks_phase = ph
	return out


## Sort key of a row: the level from which it can open (after_win + 1, or from_level).
static func _unlock_at(u: Dictionary) -> int:
	return int(u["after_win"]) + 1 if u.has("after_win") else int(u.get("from_level", 1))


## Campaign level whose WIN unlocks hero `id` (0 = from the start, -1 = never by progress: Portal and
## Seal shop only). While the heroes phase is off this is the 2.2.1 HERO_UNLOCK table; from the
## champions-in-the-run phase (dev profiles) and live, the Seer joins at UNLOCK_AT.seer (live, her L5
## level becomes a guest level, seer_guest_level()).
static func hero_unlock_at(id: String) -> int:
	if heroes_run() and id == "seer":
		return int(SaveV3Data.UNLOCK_AT["seer"])
	return int(HERO_UNLOCK.get(id, -1))


## The campaign level Мейра leads as a guest (0 = no guest level in this phase).
static func seer_guest_level() -> int:
	return int(HERO_UNLOCK_V2["seer"]) if heroes_live() else 0


## A brand-new account in the Save v3 shape (arsenal_design.md §9.2 + heroes_design.md §12.1).
## Save uses it for defaults (a section or key missing here is dropped on load) and as the migration
## base; Meta uses it when no saved account exists. Sections are Dictionaries.
## Heroes: one entry per starter (Rudi = bolt owned at start); the Meta-1 keys (lvl, glory, boss_wins,
## aspect, skin) stay where the 2.2.1 flow reads them. The other v3 sections (champions, team, summon,
## chests, workshop, vault.hero_chests, _orphans and the new wallet keys) are not read while
## heroes_live() is false.
static func fresh_account() -> Dictionary:
	var machines := {}
	for id in ArsenalData.START_OWNED:
		machines[id] = new_machine_state(id, 1)
	var heroes := {}
	for h in ["bolt", "titan"]:            # 2.2.1 order first, then the other starters
		heroes[h] = new_hero_state(h, SaveV3Data.START_OWNED.has(h), "start" if SaveV3Data.START_OWNED.has(h) else "")
	for h2 in SaveV3Data.STARTERS:
		if not heroes.has(h2):
			heroes[h2] = new_hero_state(h2, SaveV3Data.START_OWNED.has(h2), "start" if SaveV3Data.START_OWNED.has(h2) else "")
	var presets: Array = []
	for i in 3:
		presets.append({"hero": "", "champions": []})
	return {
		"meta": {"version": 3, "rng_state": 0, "rng_seed": 0, "sessions": 0, "last_session": 0, "max_day_seen": 0},
		"progress": {"level": 1, "crowns_best": {}, "shards_best": {}, "world_reached": 1, "boss_wins": 0,
				"losses_here": 0, "assist_level": 0, "invasion_level": 0, "nightmare": {}},
		"wallet": {"coins": 0, "gems": 0, "crowns": 0, "cores": 0, "wild": {"C": 0, "R": 0, "E": 0, "L": 0, "M": 0},
				"cache_charge": 0.0, "beacons": 0, "tomes": 0, "ore": 0, "beacon_charge": 0.0, "chest_charge": 0.0,
				"ore_charge": 0.0},
		"arsenal": {"machines": machines, "decks": [[], [], []], "deck_active": 0, "focus": "", "codex": {},
				"seen": {}, "mythics_forged": []},
		"heroes": heroes,
		"champions": {"level": 1, "roster": {}},
		"team": {"hero": "bolt", "champions": [], "presets": presets, "preset": 0},
		"summon": {"seals": 0, "since_e": 0, "since_l": 0, "total": 0, "focus": {}, "history": [], "welcome_done": false},
		"chests": {"since_l": 0, "total": 0, "focus": {}, "scripted": 0, "unlock_gift": false},
		"workshop": {"items": {}, "relics": {}, "trophies": [], "retro_done": false, "migration_ore": 0},
		"barracks": {"recruits": 0, "reserves": 0, "scrape_guard": 0, "drill": 0, "volleys": 0, "tactics": {}, "skins": {},
				"grandfathered": {}},
		"haven": {"stages": {}, "featured": {}},
		"pity": {"since_epic": 0, "since_leg": 0, "leg_welcome_done": false},
		"vault": {"caches": [], "stone_total": 0, "hero_chests": []},
		"daily": {}, "track": {}, "expedition": {},
		"counters": {}, "feats": {},
		"unlocks": {"done": [], "pending": [], "session_count": 0},
		"shop": {"entitlements": {}},
		"telemetry": {"levels": {}, "session_lengths": [], "skips": {}, "events": []},
		"settings": {"fast_ceremonies": false, "quick_reveal": false, "caches_to_vault": false, "auto_apex": false,
				"reinforcements": true, "reduce_motion": false},
		"_orphans": {"heroes": {}, "champions": {}},
	}


## Hero state (Save v3, heroes_design.md §12.1). `native` is never saved (SaveV3Data.HERO_NATIVE).
## Native Amethyst / Topaz / Opal heroes are born awakened (F-AWK2, BORN_AWAKENED_MIN). The Meta-1 keys lvl, glory, boss_wins,
## aspect and skin keep their 2.2.1 meaning.
static func new_hero_state(id: String, owned := false, via := "", t := 0) -> Dictionary:
	var native := str(SaveV3Data.HERO_NATIVE.get(id, "C"))
	var born := SaveV3Data.GEMS.find(native) >= SaveV3Data.GEMS.find(SaveV3Data.BORN_AWAKENED_MIN)
	var aspects: Array = HERO_ASPECTS.get(id, [""])
	var sk := {"ult": 1, "attack": 1, "rally": 1, "awakened": 1 if born else 0}
	return {"lvl": 1, "glory": 1, "boss_wins": 0, "aspect": str(aspects[0]), "skin": "",
			"owned": owned, "gem": native, "facets": 0, "frags": 0, "skills": sk, "skills_peak": sk.duplicate(),
			"skills_paid": {"ult": [0, 0], "attack": [0, 0], "rally": [0, 0], "awakened": [0, 0]},
			"loadout": {"weapon": "", "armour": "", "charm": ""}, "seen": owned, "chronicle": 0,
			"got": {"t": t, "via": via}}


## Champion roster entry (Save v3): {owned, gem, facets, frags, seen, got {t, via}}.
static func new_champion_state(id: String, owned := false, via := "", t := 0) -> Dictionary:
	return {"owned": owned, "gem": str(SaveV3Data.CHAMPION_NATIVE.get(id, "C")), "facets": 0, "frags": 0, "seen": owned,
			"got": {"t": t, "via": via}}


## Machine state on unlock: {lvl, bp, frac, xp, talents, branch, finish, finishes, apex_auto}.
static func new_machine_state(id: String, lvl: int) -> Dictionary:
	return {"lvl": lvl, "bp": 0, "frac": 0.0, "xp": 0, "talents": ["", "", ""], "branch": "", "finish": 0,
			"finishes": 0, "apex_auto": false}
