extends Node
## Persistent progress and settings (user://save.cfg).

signal settings_changed

const PATH := "user://save.cfg"

var unlocked := 1
var stars: Array[int] = []
var music_volume := 0.7
var sfx_volume := 0.85
var language := ""
var quality := "high"
var show_damage := true
var vibration := true
var arena_models := true   # sculpted Meshy arenas where a level has one
var readonly := false   # dev/test runs must not touch the player's save


func _ready() -> void:
	load_data()


func load_data() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest") or a.begins_with("--shot"):
			readonly = true
	stars.clear()
	for i in GameData.level_count():
		stars.append(0)
	var cfg := ConfigFile.new()
	if readonly:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--arena="):
				arena_models = a.trim_prefix("--arena=") != "0"
			elif a.begins_with("--unlocked="):
				unlocked = clampi(int(a.trim_prefix("--unlocked=")), 1, GameData.level_count())
				for i in unlocked - 1:
					stars[i] = 3 - i % 2
		return
	if cfg.load(PATH) != OK and cfg.load(PATH + ".bak") != OK:
		return
	unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, GameData.level_count())
	var saved: Array = cfg.get_value("progress", "stars", [])
	for i in mini(saved.size(), stars.size()):
		stars[i] = clampi(int(saved[i]), 0, 3)
	music_volume = clampf(float(cfg.get_value("settings", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx", sfx_volume)), 0.0, 1.0)
	language = str(cfg.get_value("settings", "language", ""))
	quality = str(cfg.get_value("settings", "quality", quality))
	show_damage = bool(cfg.get_value("settings", "show_damage", show_damage))
	vibration = bool(cfg.get_value("settings", "vibration", vibration))
	arena_models = bool(cfg.get_value("settings", "arenas", arena_models))


func save_data() -> void:
	if readonly:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "sfx", sfx_volume)
	cfg.set_value("settings", "language", language)
	cfg.set_value("settings", "quality", quality)
	cfg.set_value("settings", "show_damage", show_damage)
	cfg.set_value("settings", "vibration", vibration)
	cfg.set_value("settings", "arenas", arena_models)
	# Write to a temp file and swap it in, keeping the previous save as a backup,
	# so a crash mid-write can never wipe the player's progress.
	var main := ProjectSettings.globalize_path(PATH)
	if cfg.save(main + ".tmp") != OK:
		return
	if FileAccess.file_exists(main):
		DirAccess.remove_absolute(main + ".bak")
		DirAccess.rename_absolute(main, main + ".bak")
	DirAccess.rename_absolute(main + ".tmp", main)


func record_result(level_index: int, earned_stars: int) -> void:
	if earned_stars <= 0:
		return
	if level_index < stars.size():
		stars[level_index] = maxi(stars[level_index], earned_stars)
	unlocked = clampi(maxi(unlocked, level_index + 2), 1, GameData.level_count())
	save_data()


func total_stars() -> int:
	var total := 0
	for s in stars:
		total += s
	return total


func reset_progress() -> void:
	unlocked = 1
	for i in stars.size():
		stars[i] = 0
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
