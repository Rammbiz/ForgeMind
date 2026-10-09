extends Node3D
## Dev preview of the champion HUD (heroes design §10.5): the real HudView over the level road, four
## champion medallions above the ult button (top to bottom: faded under a fake gate label, full,
## hurt 40 %, fallen) and the start banner at the top third. Shot "row" shows the fallback bottom row
## (with a low-HP ring) instead of the stack.
##   godot --path . --resolution 720x1280 res://scenes/dev/hud_champions.tscn
##       -- --out=DIR --shots=medallions[,row] [--tag=720]
## Saves DIR/medallions_720.png (and medallions_row_720.png) once the fades settle (0.3 s) + 2 frames,
## then quits. Headless it builds everything, saves nothing and quits (a script check).

## Front, left, right, rear: four gems and four classes (stats_at = the expected f0 Lv1 numbers).
const TEAM := [["brant", "E", &"front"], ["mila", "C", &"left"], ["taya", "R", &"right"], ["dara", "L", &"rear"]]
const SYNERGY := ["fac_dawn_1", "cls_ranger", "affinity"]

var out_dir := ""
var tag := "720"
var shots: PackedStringArray = PackedStringArray()
var view: HudView
var meds: ChampionMedallions
var banner: TeamBanner
var gate: _FakeGate
var members: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=").split(",", false)
	Save.readonly = true
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	_build_world()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	view = HudView.new()
	var def: Dictionary = Balance.HEROES["bolt"]
	view.setup(2, str(def["ult"]["icon"]), def["color"])
	layer.add_child(view)
	view.set_ult(0.55, false)
	await get_tree().process_frame
	_build_team()
	meds = ChampionMedallions.new()
	view.add_child(meds)
	meds.setup(members)
	meds.place(view.ult_btn.get_rect())
	# States: brant (front, top) full under the gate label, mila full, taya hurt 40 %, dara fallen.
	_set_hp("taya", 0.4)
	_set_hp("dara", 0.0)
	meds.refresh(members)
	meds.on_fx(&"champ_down", {"id": "dara", "slot": &"rear", "x": 0.0, "d": 0.0})
	# A fake gate label over the top medallion (the run passes the next gate row's label rects).
	gate = _FakeGate.new()
	view.add_child(gate)
	var top: Rect2 = meds.rects()[0]
	gate.position = Vector2(top.position.x - 150.0, top.position.y - 26.0)
	gate.size = Vector2(196, 64)
	banner = TeamBanner.new()
	view.add_child(banner)
	banner.show_team(members, SYNERGY, 60.0)
	await _settle()
	if "medallions" in shots:
		await _shot("medallions")
	if "row" in shots:
		_set_hp("mila", 0.22)
		meds.refresh(members)
		meds.use_bottom_row = true
		meds.place(view.ult_btn.get_rect())
		var first: Rect2 = meds.rects()[0]
		gate.position = Vector2(first.position.x - 40.0, first.position.y - 30.0)
		await _settle()
		await _shot("medallions_row")
	get_tree().quit(0)


func _build_team() -> void:
	members.clear()
	for t: Array in TEAM:
		var st := ChampionsMeta.stats_at(str(t[0]), str(t[1]), 0, 1)
		members.append(ChampionKinds.member(st, t[2]))


func _set_hp(id: String, share: float) -> void:
	for m: Dictionary in members:
		if m["id"] == id:
			m["hp"] = float(m["hp_max"]) * share
			m["alive"] = share > 0.0


## Lets the fades finish (avoid rects tween 0.15 s, the banner fades in 0.15 s), then 2 frames.
func _settle() -> void:
	var t := 0.0
	while t < 0.3:
		meds.set_avoid_rects([Rect2(gate.global_position, gate.size)])
		await get_tree().process_frame
		t += get_process_delta_time()
	meds.set_avoid_rects([Rect2(gate.global_position, gate.size)])
	for i in 2:
		await get_tree().process_frame


func _shot(name: String) -> void:
	var file := name + ("_" + tag if tag != "" else "") + ".png"
	if DisplayServer.get_name() == "headless" or out_dir == "":
		print("SHOT ", file, " (not saved: headless or no --out)")
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("SHOT ", file)


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


## Stand-in for a gate row's value label in the right lane: a dark glass plate with "×2".
class _FakeGate extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pts := GemDraw.chamfer_rect(r, UITokens.CHAMFER_S)
		var sc := UITokens.SCRIM
		draw_colored_polygon(pts, Color(sc.r, sc.g, sc.b, 0.55))
		GemDraw.outline(self, pts, UITokens.LINE_GOLD, UIKit.line_px(1.0))
		HeroV3.text_in(self, r, "×2", 40, UITokens.ON_SCENE, "bold")
