extends Node3D
## Dev preview of the run HUD (role UI) over the real level road, driven by a mock that emits
## Run's signals (spec §2) into HudView the same way RunHud wires them.
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_ui_hud.tscn [-- --out=DIR --lang=en]
## Saves ui_hud_play.png, ui_weapon_card.png, ui_ult_ready.png, ui_power.png, ui_pause.png,
## ui_result_win.png, ui_result_lose.png, ui_ult_states.png and ui_icons.png.

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var view: HudView
var mock: MockRun
var layer: CanvasLayer


## Stand-in for Run: same signals and the fields the HUD reads.
class MockRun extends Node:
	signal finished(won: bool, coins: int, reason: String)
	signal army_changed(n: int)
	signal coins_changed(n: int)
	signal ult_changed(ratio: float, ready: bool)
	signal hint(key: String)
	signal weapon_added(kind: String, level: int)
	signal power_changed(stat: String, total: float)
	signal stairs_done(mult: float)
	var level := 2
	var hero_type := "bolt"
	var coins := 0
	var weapons: Array[Dictionary] = []
	var arm_tier := 0
	var result := {}


func _ready() -> void:
	var lang := "uk"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--lang="):
			lang = a.trim_prefix("--lang=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Loc.set_language(lang, false)
	_build_world()
	mock = MockRun.new()
	add_child(mock)
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	view = HudView.new()
	var def: Dictionary = Balance.HEROES["bolt"]
	view.setup(mock.level, str(def["ult"]["icon"]), def["color"])
	layer.add_child(view)
	# Same wiring as RunHud.
	mock.coins_changed.connect(func(n: int): view.set_coins(n))
	mock.ult_changed.connect(view.set_ult)
	mock.hint.connect(view.show_hint)
	mock.weapon_added.connect(func(kind: String, lvl: int):
		_add_weapon(kind, lvl)
		view.weapon_added(kind, lvl, mock.weapons))
	mock.power_changed.connect(view.power_toast)
	mock.stairs_done.connect(func(m: float): view.toast(Loc.t("STAIRS_MULT") % HudView._fmt_mult(m), Color(1.0, 0.8, 0.3), 96))
	mock.finished.connect(func(won: bool, earned: int, reason: String): view.show_result(won, reason, mock.result, earned))
	var tex := await UIKit.render_portrait(self, "bolt", 200)
	view.set_portrait(tex)
	await _play()
	get_tree().quit(0)


func _add_weapon(kind: String, lvl: int) -> void:
	for wd in mock.weapons:
		if wd["kind"] == kind:
			wd["level"] = lvl
			return
	mock.weapons.append({"kind": kind, "level": lvl})


func _play() -> void:
	# 1. Early run: drag hint, a tutorial banner, partial ult charge, one machine.
	view.show_drag_hint(true)
	mock.weapons.append({"kind": "ballista", "level": 2})
	view.set_weapons(mock.weapons)
	mock.coins_changed.emit(24)
	mock.ult_changed.emit(0.38, false)
	mock.hint.emit("HINT_CRATE")
	await _wait(0.9)
	await _shot("ui_hud_play")
	# 2. Weapon card.
	view.show_drag_hint(false)
	mock.hint.emit("")
	mock.weapon_added.emit("cannon", 1)
	await _wait(0.75)
	await _shot("ui_weapon_card")
	await _wait(1.8)
	# 3. Ult ready edge (+ re-emits must not re-toast).
	mock.ult_changed.emit(0.92, false)
	await _wait(0.4)
	mock.ult_changed.emit(1.0, true)
	mock.ult_changed.emit(1.0, true)
	await _wait(0.35)
	await _shot("ui_ult_ready")
	await _wait(1.6)
	# 4. Power-ups and army arms.
	mock.power_changed.emit("rate", 0.2)
	await _wait(0.15)
	mock.power_changed.emit("arm", 1)
	await _wait(0.15)
	mock.power_changed.emit("multi", 1)
	mock.hint.emit("HINT_SPIKES")
	await _wait(0.6)
	await _shot("ui_power")
	await _wait(2.0)
	# 5. Pause panel.
	view.show_pause()
	await _wait(0.7)
	await _shot("ui_pause")
	view.close_modal()
	# 6. Victory with stairs multiplier.
	mock.stairs_done.emit(2.5)
	await _wait(0.8)
	mock.result = {"coins_run": 38, "victory": 45, "mult": 2.5, "total": 208, "survivors": 37}
	mock.finished.emit(true, 208, "FORTRESS_FALLS")
	await _wait(3.2)
	await _shot("ui_result_win")
	view.close_modal()
	# 7. Defeat.
	mock.result = {"coins_run": 17, "victory": 0, "mult": 1.0, "total": 17, "survivors": 0}
	mock.finished.emit(false, 17, "ARMY_LOST")
	await _wait(2.6)
	await _shot("ui_result_lose")
	view.close_modal()
	# 8. Close-ups: ult button states and the icon sheet.
	view.visible = false
	await _ult_states()
	await _icon_sheet()


func _ult_states() -> void:
	var board := ColorRect.new()
	board.color = Color(0.06, 0.08, 0.16)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(board)
	var tex := view.ult_btn.icon_texture
	var specs := [[0.0, false], [0.62, false], [1.0, true]]
	var i := 0
	for sp: Array in specs:
		for hero: String in ["bolt", "titan"]:
			var b := RoundButton.new(HudView.ULT_RADIUS)
			b.ult_style = true
			b.custom_minimum_size = Vector2(180, 168)
			var def: Dictionary = Balance.HEROES[hero]
			b.glow_color = (def["color"] as Color).lerp(Color(1.0, 0.6, 0.95), 0.35)
			b.base_color = Color(0.08, 0.06, 0.18)
			b.progress_color = Color(0.55, 0.7, 1.0)
			b.icon_kind = str(def["ult"]["icon"])
			b.badge_icon = b.icon_kind
			if hero == "bolt":
				b.icon_texture = tex
			b.progress = sp[0]
			b.disabled = not sp[1]
			b.highlight = sp[1]
			b.caption = Loc.t("ULT") if not sp[1] else Loc.t("ULT").to_upper() + "!"
			b.position = Vector2(60 + (i % 3) * 210, 120 + int(i / 3) * 230 + (0 if hero == "bolt" else 0))
			board.add_child(b)
			i += 1
	await _wait(0.6)
	await _shot("ui_ult_states")
	board.queue_free()


func _icon_sheet() -> void:
	var board := ColorRect.new()
	board.color = Color(0.07, 0.09, 0.18)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(board)
	var kinds := ["ballista", "cannon", "laser", "rockets", "drone", "crossbow", "blaster", "spear",
		"rate", "dmg", "multi", "hand", "star", "shield", "crate", "spikes", "blade", "turret", "geode",
		"gate", "soldier", "coin", "storm", "quake"]
	var i := 0
	for k: String in kinds:
		var cell := Vector2(40 + (i % 5) * 132, 40 + int(i / 5) * 150)
		var ic := Icons.make(k, 104.0)
		ic.position = cell
		board.add_child(ic)
		var l := UIKit.label(k, 18, UIKit.TEXT_DIM)
		l.position = cell + Vector2(0, 108)
		board.add_child(l)
		i += 1
	# Small sizes too (HUD slots use ~48 px).
	var j := 0
	for k: String in ["ballista", "cannon", "laser", "rockets", "drone", "crossbow", "blaster", "rate", "dmg", "multi"]:
		var ic2 := Icons.make(k, 44.0)
		ic2.position = Vector2(40 + j * 64, 1180)
		board.add_child(ic2)
		j += 1
	await _wait(0.3)
	await _shot("ui_icons")


func _build_world() -> void:
	var track := Track.new()
	add_child(track)
	track.build(160.0, true, Worlds.for_level(2))
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 260.0
	cam.fov = 62.0
	add_child(cam)
	cam.position = Vector3(0, 8.6, 6.0)
	cam.look_at(Vector3(0, 0, -3.2))
	cam.make_current()
	var hero := HeroModels.hero("bolt")
	hero.position = Vector3(0, 0, -1.0)
	hero.rotation.y = PI
	add_child(hero)


## Waits `s` seconds of game time (frame deltas; xvfb renders slowly and deltas are capped).
func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)
