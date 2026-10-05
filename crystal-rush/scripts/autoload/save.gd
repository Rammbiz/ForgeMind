extends Node
## Persistent progress and settings (user://save.cfg).

signal settings_changed
signal coins_changed(coins: int)

const PATH := "user://save.cfg"

var level := 1                 # next level to play (1-based)
var coins := 0
var hero := "bolt"
var upgrades := {"army": 0, "power": 0}
var music_volume := 0.7
var sfx_volume := 0.85
var language := ""
var quality := "high"
var vibration := true
var readonly := false          # dev/test runs must not touch the player's save


func _ready() -> void:
	load_data()


func load_data() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest") or a.begins_with("--shot"):
			readonly = true
	if readonly:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--hero="):
				hero = a.trim_prefix("--hero=")
			elif a.begins_with("--level="):
				level = maxi(1, int(a.trim_prefix("--level=")))
			elif a.begins_with("--army="):
				upgrades["army"] = maxi(0, int(a.trim_prefix("--army=")))
			elif a.begins_with("--power="):
				upgrades["power"] = maxi(0, int(a.trim_prefix("--power=")))
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK and cfg.load(PATH + ".bak") != OK:
		return
	level = maxi(1, int(cfg.get_value("progress", "level", 1)))
	coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))
	hero = str(cfg.get_value("progress", "hero", hero))
	if not Balance.HEROES.has(hero):
		hero = "bolt"
	for k in upgrades:
		upgrades[k] = clampi(int(cfg.get_value("upgrades", k, 0)), 0, Balance.MAX_UPGRADE)
	music_volume = clampf(float(cfg.get_value("settings", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx", sfx_volume)), 0.0, 1.0)
	language = str(cfg.get_value("settings", "language", ""))
	quality = str(cfg.get_value("settings", "quality", quality))
	vibration = bool(cfg.get_value("settings", "vibration", vibration))


func save_data() -> void:
	if readonly:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "hero", hero)
	for k in upgrades:
		cfg.set_value("upgrades", k, upgrades[k])
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "sfx", sfx_volume)
	cfg.set_value("settings", "language", language)
	cfg.set_value("settings", "quality", quality)
	cfg.set_value("settings", "vibration", vibration)
	# Write to a temp file and keep the previous save as a backup, so a crash mid-write
	# never loses progress.
	if cfg.save(PATH + ".tmp") != OK:
		return
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, PATH + ".bak")
	DirAccess.rename_absolute(PATH + ".tmp", PATH)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)
	save_data()


func upgrade_cost(kind: String) -> int:
	return Balance.upgrade_cost(kind, int(upgrades[kind]))


func can_upgrade(kind: String) -> bool:
	return int(upgrades[kind]) < Balance.MAX_UPGRADE and coins >= upgrade_cost(kind)


func buy_upgrade(kind: String) -> bool:
	if not can_upgrade(kind):
		return false
	var cost := upgrade_cost(kind)
	upgrades[kind] = int(upgrades[kind]) + 1
	add_coins(-cost)
	return true


func set_hero(type: String) -> void:
	if Balance.HEROES.has(type):
		hero = type
		save_data()


func level_won() -> void:
	level += 1
	save_data()


func apply_settings() -> void:
	save_data()
	apply_performance()
	settings_changed.emit()


## Battery saver: lower render resolution and frame cap.
func apply_performance() -> void:
	var high := quality == "high"
	Engine.max_fps = 60 if high else 30
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = 1.0 if high else 0.75


## Short haptic pulse on phones (no-op elsewhere or when disabled).
func vibrate(ms: int) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
