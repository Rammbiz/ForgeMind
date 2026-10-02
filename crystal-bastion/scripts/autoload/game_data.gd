extends Node
## Static game definitions: towers, enemies, levels and waves.
## Distances are in tiles (1 tile = 1 world unit), times in seconds.

const TOWER_ORDER: Array[String] = ["arrow", "cannon", "frost", "tesla", "laser"]

const TOWERS := {
	"arrow": {
		"name": "TOWER_ARROW", "desc": "TOWER_ARROW_DESC",
		"color": Color(0.95, 0.72, 0.32),
		"air": true, "ground": true, "dmg_type": "phys",
		"levels": [
			{"cost": 70, "damage": 8.0, "rate": 1.5, "range": 2.6, "proj_speed": 13.0},
			{"cost": 60, "damage": 13.0, "rate": 1.7, "range": 2.9, "proj_speed": 14.0},
			{"cost": 110, "damage": 22.0, "rate": 2.0, "range": 3.2, "proj_speed": 16.0},
		],
	},
	"cannon": {
		"name": "TOWER_CANNON", "desc": "TOWER_CANNON_DESC",
		"color": Color(0.95, 0.45, 0.25),
		"air": false, "ground": true, "dmg_type": "phys",
		"levels": [
			{"cost": 90, "damage": 18.0, "rate": 0.65, "range": 2.5, "splash": 1.1, "proj_speed": 7.0},
			{"cost": 75, "damage": 30.0, "rate": 0.7, "range": 2.7, "splash": 1.2, "proj_speed": 7.5},
			{"cost": 130, "damage": 50.0, "rate": 0.75, "range": 3.0, "splash": 1.35, "proj_speed": 8.0},
		],
	},
	"frost": {
		"name": "TOWER_FROST", "desc": "TOWER_FROST_DESC",
		"color": Color(0.45, 0.85, 1.0),
		"air": true, "ground": true, "dmg_type": "magic",
		"levels": [
			{"cost": 80, "damage": 4.0, "rate": 1.0, "range": 2.4, "splash": 1.05, "slow": 0.4, "slow_time": 2.2, "proj_speed": 9.0},
			{"cost": 70, "damage": 6.0, "rate": 1.0, "range": 2.6, "splash": 1.15, "slow": 0.46, "slow_time": 2.4, "proj_speed": 10.0},
			{"cost": 110, "damage": 9.0, "rate": 1.0, "range": 2.8, "splash": 1.25, "slow": 0.52, "slow_time": 2.6, "proj_speed": 11.0},
		],
	},
	"tesla": {
		"name": "TOWER_TESLA", "desc": "TOWER_TESLA_DESC",
		"color": Color(0.55, 0.7, 1.0),
		"air": true, "ground": true, "dmg_type": "magic",
		"levels": [
			{"cost": 115, "damage": 13.0, "rate": 0.75, "range": 2.3, "chains": 3, "chain_range": 1.5},
			{"cost": 100, "damage": 19.0, "rate": 0.85, "range": 2.5, "chains": 4, "chain_range": 1.6},
			{"cost": 160, "damage": 29.0, "rate": 0.95, "range": 2.8, "chains": 5, "chain_range": 1.7},
		],
	},
	"laser": {
		"name": "TOWER_LASER", "desc": "TOWER_LASER_DESC",
		"color": Color(0.85, 0.45, 1.0),
		"air": true, "ground": true, "dmg_type": "magic",
		"levels": [
			{"cost": 140, "dps": 10.0, "ramp": 3.0, "ramp_time": 2.5, "range": 2.8},
			{"cost": 120, "dps": 17.0, "ramp": 3.0, "ramp_time": 2.5, "range": 3.0},
			{"cost": 180, "dps": 28.0, "ramp": 3.0, "ramp_time": 2.5, "range": 3.3},
		],
	},
}

const SELL_REFUND := 0.7

const ENEMIES := {
	"slime": {"name": "ENEMY_SLIME", "hp": 30.0, "speed": 1.0, "reward": 4, "armor": 0.0, "flying": false, "lives": 1, "size": 0.34, "color": Color(0.2, 0.72, 0.7)},
	"runner": {"name": "ENEMY_RUNNER", "hp": 22.0, "speed": 1.9, "reward": 4, "armor": 0.0, "flying": false, "lives": 1, "size": 0.3, "color": Color(0.95, 0.55, 0.25)},
	"beetle": {"name": "ENEMY_BEETLE", "hp": 90.0, "speed": 0.7, "reward": 9, "armor": 0.5, "flying": false, "lives": 2, "size": 0.38, "color": Color(0.3, 0.45, 0.85)},
	"bat": {"name": "ENEMY_BAT", "hp": 28.0, "speed": 1.35, "reward": 5, "armor": 0.0, "flying": true, "lives": 1, "size": 0.3, "color": Color(0.6, 0.35, 0.8)},
	"splitter": {"name": "ENEMY_SPLITTER", "hp": 75.0, "speed": 0.85, "reward": 6, "armor": 0.0, "flying": false, "lives": 2, "size": 0.42, "color": Color(0.85, 0.4, 0.75), "split": "slimelet", "split_count": 3},
	"slimelet": {"name": "ENEMY_SLIME", "hp": 16.0, "speed": 1.3, "reward": 1, "armor": 0.0, "flying": false, "lives": 1, "size": 0.22, "color": Color(0.95, 0.55, 0.85)},
	"golem": {"name": "ENEMY_GOLEM", "hp": 800.0, "speed": 0.45, "reward": 70, "armor": 0.3, "flying": false, "lives": 5, "size": 0.6, "color": Color(0.55, 0.52, 0.5), "boss": true},
}

# Wave group: [enemy_type, count, gap_seconds, start_delay, spawn_index (-1 = alternate)]
const LEVELS := [
	{
		"id": "meadow",
		"name": "LEVEL_1", "subtitle": "LEVEL_1_SUB",
		"map": [
			"xx..t......t..xx",
			"x.S####.......rx",
			".t....#..####...",
			"......#..#..#.t.",
			"..r...#..#..#...",
			"...####..#..###.",
			"t..#.....#....#.",
			"x..#######..t.Cx",
			"xx.....t....r.xx",
		],
		"start_gold": 220, "lives": 20, "hp_scale": 1.05, "hp_growth": 0.009,
		"towers": ["arrow", "cannon", "frost"],
		"music": "meadow",
		"theme": {
			"grass_a": Color(0.4, 0.66, 0.27), "grass_b": Color(0.36, 0.61, 0.24),
			"path": Color(0.86, 0.68, 0.44), "path_edge": Color(0.6, 0.44, 0.27),
			"dirt": Color(0.56, 0.39, 0.25), "rock": Color(0.5, 0.47, 0.46), "deep": Color(0.32, 0.27, 0.32),
			"water": Color(0.22, 0.62, 0.86),
			"foliage": Color(0.32, 0.64, 0.3), "foliage_b": Color(0.42, 0.74, 0.32), "trunk": Color(0.48, 0.32, 0.2),
			"tree": "round",
			"sky_top": Color(0.3, 0.52, 0.85), "sky_horizon": Color(0.74, 0.86, 0.96),
			"ground_horizon": Color(0.62, 0.78, 0.95), "ground_bottom": Color(0.16, 0.32, 0.62),
			"fog": Color(0.74, 0.84, 0.96), "fog_density": 0.005,
			"sun_color": Color(1.0, 0.94, 0.82), "sun_energy": 1.0, "sun_rot": Vector3(-40.0, -38.0, 0.0),
			"ambient": Color(0.62, 0.72, 0.92), "ambient_energy": 0.45,
			"particles": "pollen", "clouds": Color(1.0, 1.0, 1.0),
			"flowers": [Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.6), Color(0.95, 0.95, 1.0), Color(0.6, 0.7, 1.0)],
		},
		"waves": [
			[["slime", 6, 1.2, 0.0, -1]],
			[["slime", 10, 1.0, 0.0, -1]],
			[["slime", 8, 0.9, 0.0, -1], ["runner", 4, 0.7, 4.0, -1]],
			[["runner", 10, 0.6, 0.0, -1]],
			[["slime", 12, 0.7, 0.0, -1], ["runner", 6, 0.6, 3.0, -1]],
			[["beetle", 4, 2.0, 0.0, -1], ["slime", 8, 0.8, 2.0, -1]],
			[["runner", 14, 0.45, 0.0, -1]],
			[["bat", 8, 0.9, 0.0, -1], ["slime", 10, 0.7, 1.0, -1]],
			[["beetle", 6, 1.6, 0.0, -1], ["runner", 8, 0.5, 4.0, -1]],
			[["splitter", 6, 1.8, 0.0, -1], ["slime", 10, 0.6, 2.0, -1]],
			[["bat", 12, 0.7, 0.0, -1], ["beetle", 4, 1.8, 3.0, -1]],
			[["runner", 20, 0.35, 0.0, -1], ["splitter", 4, 2.0, 5.0, -1]],
			[["beetle", 10, 1.2, 0.0, -1], ["bat", 10, 0.8, 4.0, -1]],
			[["slime", 14, 0.45, 0.0, -1], ["splitter", 5, 1.3, 3.0, -1], ["runner", 8, 0.5, 8.0, -1]],
			[["golem", 1, 0.0, 0.0, -1], ["slime", 14, 0.6, 2.0, -1], ["bat", 8, 0.8, 6.0, -1]],
		],
	},
	{
		"id": "canyon",
		"name": "LEVEL_2", "subtitle": "LEVEL_2_SUB",
		"map": [
			"xx...r....t...xx",
			"S####...#####..x",
			"x.t.#...#...#.r.",
			"....#.r.#...#...",
			".r..#####..t#..t",
			"....#.....r.#...",
			"x.t.#...t...##Cx",
			"S####..r.......x",
			"xx....t.....r.xx",
		],
		"start_gold": 280, "lives": 20, "hp_scale": 0.85, "hp_growth": 0.0082,
		"towers": ["arrow", "cannon", "frost", "tesla"],
		"music": "canyon",
		"theme": {
			"grass_a": Color(0.9, 0.7, 0.44), "grass_b": Color(0.84, 0.63, 0.39),
			"path": Color(0.66, 0.38, 0.26), "path_edge": Color(0.5, 0.27, 0.18),
			"dirt": Color(0.66, 0.38, 0.24), "rock": Color(0.68, 0.43, 0.32), "deep": Color(0.38, 0.19, 0.17),
			"water": Color(0.2, 0.7, 0.75),
			"foliage": Color(0.36, 0.6, 0.32), "foliage_b": Color(0.45, 0.68, 0.36), "trunk": Color(0.5, 0.33, 0.2),
			"tree": "cactus",
			"sky_top": Color(0.22, 0.2, 0.45), "sky_horizon": Color(0.98, 0.6, 0.38),
			"ground_horizon": Color(0.96, 0.6, 0.42), "ground_bottom": Color(0.3, 0.13, 0.3),
			"fog": Color(0.95, 0.62, 0.48), "fog_density": 0.007,
			"sun_color": Color(1.0, 0.74, 0.5), "sun_energy": 1.1, "sun_rot": Vector3(-34.0, 55.0, 0.0),
			"ambient": Color(0.85, 0.62, 0.62), "ambient_energy": 0.42,
			"particles": "dust", "clouds": Color(1.0, 0.82, 0.74),
			"flowers": [Color(0.95, 0.35, 0.35), Color(1.0, 0.8, 0.35)],
		},
		"waves": [
			[["slime", 8, 1.0, 0.0, -1]],
			[["slime", 6, 0.9, 0.0, 0], ["runner", 5, 0.8, 2.0, 1]],
			[["slime", 12, 0.8, 0.0, -1]],
			[["runner", 12, 0.5, 0.0, -1]],
			[["beetle", 3, 2.0, 0.0, -1], ["slime", 10, 0.8, 2.0, -1]],
			[["bat", 8, 0.9, 0.0, -1], ["slime", 8, 0.8, 3.0, -1]],
			[["splitter", 5, 1.6, 0.0, -1], ["runner", 6, 0.5, 4.0, -1]],
			[["beetle", 6, 1.4, 0.0, -1], ["bat", 6, 0.9, 3.0, -1]],
			[["slime", 22, 0.4, 0.0, -1], ["runner", 8, 0.5, 5.0, -1]],
			[["golem", 1, 0.0, 0.0, 0], ["splitter", 4, 1.5, 2.0, 1]],
			[["bat", 16, 0.6, 0.0, -1]],
			[["beetle", 9, 1.1, 0.0, -1], ["runner", 10, 0.45, 4.0, -1]],
			[["splitter", 10, 1.0, 0.0, -1]],
			[["slime", 26, 0.35, 0.0, -1], ["bat", 10, 0.6, 4.0, -1]],
			[["beetle", 11, 0.9, 0.0, -1], ["splitter", 5, 1.2, 5.0, -1]],
			[["runner", 30, 0.28, 0.0, -1], ["bat", 10, 0.6, 3.0, -1]],
			[["golem", 2, 6.0, 0.0, -1], ["slime", 18, 0.5, 2.0, -1]],
			[["beetle", 14, 0.8, 0.0, -1], ["bat", 14, 0.5, 3.0, -1]],
			[["splitter", 12, 0.8, 0.0, -1], ["runner", 16, 0.32, 5.0, -1]],
			[["golem", 2, 6.0, 0.0, -1], ["beetle", 6, 0.9, 3.0, -1], ["bat", 10, 0.5, 8.0, -1]],
		],
	},
	{
		"id": "frost",
		"name": "LEVEL_3", "subtitle": "LEVEL_3_SUB",
		"map": [
			"xx.t...S...t..xx",
			"x....r.#.....r.x",
			".t######..t.....",
			"..#......r....t.",
			"..#.ww....#####S",
			"t.#####...#.r...",
			"x.....#.t.#....x",
			"xC#########..t.x",
			"xx...t....r...xx",
		],
		"start_gold": 320, "lives": 20, "hp_scale": 0.66, "hp_growth": 0.0095,
		"towers": ["arrow", "cannon", "frost", "tesla", "laser"],
		"music": "frost",
		"theme": {
			"grass_a": Color(0.8, 0.86, 0.94), "grass_b": Color(0.74, 0.81, 0.91),
			"path": Color(0.42, 0.5, 0.66), "path_edge": Color(0.32, 0.38, 0.54),
			"dirt": Color(0.42, 0.47, 0.6), "rock": Color(0.56, 0.62, 0.72), "deep": Color(0.2, 0.22, 0.34),
			"water": Color(0.55, 0.8, 0.95),
			"foliage": Color(0.2, 0.42, 0.38), "foliage_b": Color(0.9, 0.95, 1.0), "trunk": Color(0.38, 0.28, 0.24),
			"tree": "snowpine",
			"sky_top": Color(0.03, 0.05, 0.15), "sky_horizon": Color(0.15, 0.3, 0.46),
			"ground_horizon": Color(0.16, 0.3, 0.46), "ground_bottom": Color(0.02, 0.04, 0.12),
			"fog": Color(0.18, 0.3, 0.48), "fog_density": 0.008,
			"sun_color": Color(0.62, 0.72, 1.0), "sun_energy": 0.62, "sun_rot": Vector3(-50.0, 25.0, 0.0),
			"ambient": Color(0.42, 0.5, 0.85), "ambient_energy": 0.42, "rocks": "ice",
			"particles": "snow", "clouds": Color(0.62, 0.7, 0.88),
			"flowers": [Color(0.6, 0.9, 1.0), Color(0.8, 0.7, 1.0)],
		},
		"waves": [
			[["slime", 10, 0.9, 0.0, -1]],
			[["runner", 8, 0.7, 0.0, 0], ["slime", 6, 1.0, 1.0, 1]],
			[["bat", 10, 0.9, 0.0, -1]],
			[["beetle", 4, 1.6, 0.0, -1], ["slime", 10, 0.7, 2.0, -1]],
			[["runner", 16, 0.45, 0.0, -1]],
			[["bat", 14, 0.7, 0.0, -1]],
			[["splitter", 6, 1.3, 0.0, -1], ["slime", 10, 0.6, 3.0, -1]],
			[["beetle", 9, 1.2, 0.0, -1], ["slime", 6, 0.8, 4.0, -1]],
			[["runner", 22, 0.35, 0.0, -1], ["bat", 8, 0.7, 4.0, -1]],
			[["golem", 1, 0.0, 0.0, 0], ["golem", 1, 0.0, 4.0, 1], ["bat", 6, 0.7, 2.0, -1]],
			[["splitter", 8, 1.0, 0.0, -1], ["beetle", 4, 1.4, 5.0, -1]],
			[["slime", 36, 0.26, 0.0, -1], ["runner", 6, 0.5, 6.0, -1]],
			[["bat", 22, 0.45, 0.0, -1]],
			[["beetle", 15, 0.8, 0.0, -1], ["slime", 10, 0.5, 4.0, -1]],
			[["golem", 2, 4.0, 0.0, -1], ["runner", 18, 0.35, 2.0, -1]],
			[["splitter", 12, 0.85, 0.0, -1], ["bat", 10, 0.5, 4.0, -1]],
			[["runner", 30, 0.25, 0.0, -1], ["beetle", 9, 1.0, 4.0, -1]],
			[["bat", 30, 0.38, 0.0, -1]],
			[["beetle", 18, 0.7, 0.0, -1], ["splitter", 8, 1.0, 4.0, -1]],
			[["golem", 3, 4.0, 0.0, -1], ["slime", 30, 0.3, 2.0, -1]],
			[["bat", 30, 0.35, 0.0, -1], ["runner", 26, 0.28, 4.0, -1]],
			[["beetle", 26, 0.52, 0.0, -1], ["bat", 12, 0.5, 5.0, -1]],
			[["splitter", 20, 0.65, 0.0, -1], ["runner", 24, 0.25, 4.0, -1]],
			[["slime", 44, 0.2, 0.0, -1], ["beetle", 14, 0.7, 3.0, -1], ["bat", 16, 0.45, 6.0, -1]],
			[["golem", 4, 3.5, 0.0, -1], ["beetle", 16, 0.7, 2.0, -1], ["bat", 20, 0.4, 6.0, -1]],
		],
	},
]


func level_count() -> int:
	return LEVELS.size()


func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


func tower_stats(type: String, level: int) -> Dictionary:
	return TOWERS[type]["levels"][level]


func tower_max_level(type: String) -> int:
	return TOWERS[type]["levels"].size() - 1


## Health multiplier applied to every enemy in the given (0-based) wave:
## hp_scale sets the level's base toughness, hp_growth how steeply late waves ramp.
func wave_hp_mult(level_index: int, wave: int) -> float:
	var lvl: Dictionary = get_level(level_index)
	return float(lvl["hp_scale"]) * (1.0 + 0.1 * wave + float(lvl["hp_growth"]) * wave * wave)


## Bonus gold for clearing a wave.
func wave_bonus(wave: int) -> int:
	return 10 + wave * 3


## Stars for finishing a level with the given lives left.
func stars_for(lives_left: int, lives_max: int) -> int:
	if lives_left <= 0:
		return 0
	if lives_left >= lives_max - 2:
		return 3
	if lives_left >= lives_max / 2:
		return 2
	return 1
