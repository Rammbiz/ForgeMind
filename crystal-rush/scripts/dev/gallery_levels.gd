extends Control
## Dev preview for the LEVELS role: a top-down "level atlas" poster of one level. The bridge
## runs bottom (start) to top (fortress) with every item drawn to scale across, the planner's
## best line (gold), the lazy line down the middle (silver) and random wanderers (violet); the
## right panel plots the army along the same distance axis. Saves a PNG and quits.
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_levels.tscn
##       -- [--level=7] [--hero=bolt|titan] [--name=FILE] [--random=6]

const OUT_DIR := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
const W := 720.0
const H := 1280.0
const MAP_TOP := 214.0
const MAP_BOTTOM := 1168.0
const BRIDGE_X := 34.0
const PX_PER_U := 50.0          # across the bridge
const CHART_X0 := 438.0
const CHART_X1 := 690.0

const C_BG0 := Color(0.035, 0.05, 0.14)
const C_BG1 := Color(0.09, 0.05, 0.2)
const C_DECK := Color(0.1, 0.13, 0.3)
const C_RAIL := Color(0.55, 0.78, 1.0)
const C_GOLD := Color(1.0, 0.82, 0.38)
const C_SILVER := Color(0.8, 0.85, 0.96)
const C_VIOLET := Color(0.66, 0.5, 1.0)
const C_GOOD := Color(0.25, 0.62, 1.0)
const C_MULT := Color(0.3, 0.9, 1.0)
const C_BAD := Color(1.0, 0.3, 0.38)
const C_CHARGE := Color(0.72, 0.42, 1.0)
const C_POWER := Color(1.0, 0.75, 0.28)
const C_ARM := Color(0.2, 0.85, 0.75)
const C_HIDDEN := Color(0.55, 0.6, 0.75)
const C_ENEMY := Color(1.0, 0.36, 0.22)
const C_TEXT := Color(0.93, 0.95, 1.0)
const C_DIM := Color(0.62, 0.68, 0.85)

var args := {}
var level := 7
var hero := "bolt"
var def := {}
var lv: LevelSim.Level
var best := {}
var best_samples := PackedVector3Array()
var lazy_s: LevelSim.State
var randoms: Array = []          ## [LevelSim.State]
var f_bold: Font
var f_med: Font
var _frames := 0
var _stars: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	level = int(args.get("level", "7"))
	hero = str(args.get("hero", "bolt"))
	f_bold = _font("res://assets/fonts/Rubik-ExtraBold.ttf")
	f_med = _font("res://assets/fonts/Rubik-Medium.ttf")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	def = LevelGen.build(level, Balance.START_ARMY)
	lv = LevelSim.make_level(def, level)
	var bp := LevelSim.best_path(lv, hero, Balance.START_ARMY, {"sample": 1.0})
	best = bp["result"]
	best_samples = bp["samples"]
	lazy_s = LevelSim.simulate(lv, hero, Balance.START_ARMY, LevelSim.lazy_path(), {"sample": 1.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + level
	for k in int(args.get("random", "6")):
		randoms.append(LevelSim.simulate(lv, hero, Balance.START_ARMY, LevelSim.random_path(lv.length, rng), {"sample": 1.0}))
	var srng := RandomNumberGenerator.new()
	srng.seed = 99
	for k in 140:
		_stars.append([Vector2(srng.randf() * W, srng.randf() * H), srng.randf_range(0.4, 1.6), srng.randf_range(0.15, 0.7)])
	queue_redraw()


func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		if f != null:
			return f
	return ThemeDB.fallback_font


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 4:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
		var name := str(args.get("name", "levels_L%d_%s" % [level, hero]))
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT_DIR + "/" + name + ".png")
		print("GALLERY saved ", OUT_DIR + "/" + name + ".png")
		get_tree().quit(0)


# ------------------------------------------------------------------ mapping

func _y(d: float) -> float:
	return MAP_BOTTOM - d / (lv.length + 6.0) * (MAP_BOTTOM - MAP_TOP)


func _x(x: float) -> float:
	return BRIDGE_X + (x + Balance.BRIDGE_HALF) * PX_PER_U


func _cx(army: float, top: float) -> float:
	return CHART_X0 + clampf(army / maxf(top, 1.0), 0.0, 1.0) * (CHART_X1 - CHART_X0)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	_background()
	_header()
	_bridge()
	_items()
	_paths()
	_chart()
	_legend()


func _background() -> void:
	var steps := 32
	for k in steps:
		var c := C_BG0.lerp(C_BG1, float(k) / steps)
		draw_rect(Rect2(0, H * k / steps, W, H / steps + 1.0), c)
	for s: Array in _stars:
		draw_circle(s[0], s[1], Color(0.8, 0.85, 1.0, s[2]))
	# Soft nebula glows.
	_glow(Vector2(600, 260), 260.0, Color(0.45, 0.25, 0.9, 0.10))
	_glow(Vector2(120, 1050), 300.0, Color(0.15, 0.45, 1.0, 0.08))


func _glow(c: Vector2, r: float, col: Color) -> void:
	for k in 10:
		var f := 1.0 - float(k) / 10.0
		draw_circle(c, r * f, Color(col.r, col.g, col.b, col.a * 0.25))


func _header() -> void:
	_panel(Rect2(18, 18, W - 36, 176), 22.0)
	_text(f_med, Vector2(40, 52), "LEVEL ATLAS  ·  LevelSim", 15, C_DIM)
	var hero_name := "Bolt" if hero == "bolt" else "Titan"
	_text(f_bold, Vector2(40, 104), "Level %d" % level, 48, C_GOLD, true)
	_text(f_med, Vector2(250, 104), "%s  ·  %d u  ·  %.0f s" % [hero_name, int(lv.length), lv.length / Balance.RUN_SPEED], 22, C_TEXT)
	var fort := 0
	for it: Dictionary in def["items"]:
		if str(it["kind"]) == "fortress":
			fort = int(it["value"])
	var lz := LevelSim.result(lv, lazy_s)
	var wins := 0
	for r: LevelSim.State in randoms:
		if r.mode == LevelSim.Mode.WON:
			wins += 1
	_stat(Vector2(40, 132), "BEST", "%d  →  %d  ×%s" % [best["army_at_fortress"], best["survivors"], str(best["stairs_mult"])], C_GOLD, best["won"])
	_stat(Vector2(40, 162), "LAZY", "%d  →  %s" % [lz["army_at_fortress"], "won" if lz["won"] else "lost"], C_SILVER, lz["won"])
	_stat(Vector2(380, 132), "FORTRESS", "%d hp" % fort, C_ENEMY, true)
	_stat(Vector2(380, 162), "RANDOM", "%d / %d won" % [wins, randoms.size()], C_VIOLET, wins * 2 <= randoms.size())


func _stat(p: Vector2, label: String, value: String, col: Color, ok: bool) -> void:
	draw_circle(p + Vector2(5, -6), 5.0, col)
	_text(f_bold, p + Vector2(18, 0), label, 14, col)
	_text(f_med, p + Vector2(110, 0), value, 18, C_TEXT if ok else Color(1.0, 0.75, 0.75))


func _panel(r: Rect2, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.2, 0.82)
	sb.border_color = Color(1.0, 0.82, 0.4, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(radius))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	draw_style_box(sb, r)


func _bridge() -> void:
	var x0 := _x(-Balance.BRIDGE_HALF)
	var x1 := _x(Balance.BRIDGE_HALF)
	var deck := Rect2(x0, MAP_TOP - 6, x1 - x0, MAP_BOTTOM - MAP_TOP + 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_DECK
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.2, 0.45, 1.0, 0.25)
	sb.shadow_size = 18
	draw_style_box(sb, deck)
	# Lane grid every unit, distance ticks every 50 u.
	for k in range(-3, 4):
		draw_line(Vector2(_x(k), MAP_TOP), Vector2(_x(k), MAP_BOTTOM), Color(0.5, 0.65, 1.0, 0.07 if k != 0 else 0.16), 1.0)
	var d := 0.0
	while d <= lv.length:
		var y := _y(d)
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.6, 0.75, 1.0, 0.08), 1.0)
		_text(f_med, Vector2(x0 - 30, y + 4), "%d" % int(d), 11, Color(0.6, 0.7, 0.95, 0.6))
		d += 50.0
	# Glowing rails.
	for x in [x0, x1]:
		draw_line(Vector2(x, MAP_TOP - 6), Vector2(x, MAP_BOTTOM + 6), Color(C_RAIL, 0.25), 7.0)
		draw_line(Vector2(x, MAP_TOP - 6), Vector2(x, MAP_BOTTOM + 6), C_RAIL, 2.0)


func _items() -> void:
	for i in lv.items.size():
		var it := lv.items[i]
		var y := _y(lv.d[i])
		var x := _x(lv.x[i])
		match str(it["kind"]):
			"tile":
				var p := Vector2(x, y)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), Color(0.45, 0.8, 1.0, 0.9))
			"coin":
				draw_circle(Vector2(x, y), 3.2, C_GOLD)
			"recruits":
				draw_circle(Vector2(x, y), 9.0, Color(0.62, 0.65, 0.72))
				draw_arc(Vector2(x, y), 9.0, 0, TAU, 20, Color(0.92, 0.94, 1.0), 1.5)
				_text_c(f_bold, Vector2(x, y + 4.5), str(int(it["value"])), 12, Color(0.06, 0.08, 0.16))
			"gate":
				_gate(i, it, x, y)
			"squad":
				var hw := float(it["w"]) * 0.5 * PX_PER_U
				_ellipse(Vector2(x, y), hw, 11.0, Color(C_ENEMY, 0.85))
				_ellipse(Vector2(x, y), hw + 3.0, 14.0, Color(C_ENEMY, 0.18))
				_text_c(f_bold, Vector2(x, y + 6), str(int(it["value"])), 16, Color.WHITE)
			"barricade":
				var bw := float(it["w"]) * PX_PER_U
				var r := Rect2(x - bw * 0.5, y - 5, bw, 10)
				draw_rect(r, Color(0.55, 0.18, 0.12))
				var n := int(bw / 9.0)
				for k in n:
					var sx := r.position.x + (k + 0.5) * bw / n
					draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, y - 4), Vector2(sx + 4, y - 4), Vector2(sx, y - 13)]), Color(1.0, 0.55, 0.3))
				_text_c(f_bold, Vector2(x, y + 19), "%d" % int(it["value"]), 13, Color(1.0, 0.7, 0.5))
			"blade":
				_blade(it, x, y)
			"turret":
				var side := signf(lv.x[i])
				var p2 := Vector2(_x(Balance.BRIDGE_HALF * side), y)
				draw_arc(p2, float(it.get("range", 7.0)) * PX_PER_U * 0.5, PI * 0.5 + side * PI * 0.5 - 1.2, PI * 0.5 + side * PI * 0.5 + 1.2, 24, Color(C_ENEMY, 0.25), 2.0)
				draw_colored_polygon(PackedVector2Array([p2 + Vector2(-side * 14, 0), p2 + Vector2(0, -9), p2 + Vector2(0, 9)]), C_ENEMY)
				_text_c(f_bold, p2 + Vector2(-side * 26, 5), str(int(it["value"])), 12, Color(1.0, 0.7, 0.55))
			"geode":
				var col := {"army": C_GOOD, "coins": C_GOLD, "ult": C_CHARGE}.get(str(it.get("reward", "army")), C_GOOD) as Color
				var hex := PackedVector2Array()
				for k in 6:
					hex.append(Vector2(x, y) + Vector2.from_angle(TAU * k / 6.0 + PI / 6.0) * 10.0)
				draw_colored_polygon(hex, col)
				draw_polyline(hex + PackedVector2Array([hex[0]]), Color.WHITE, 1.5)
				_text(f_bold, Vector2(x + 14, y + 5), "%s %d" % [_reward_tag(it), int(it.get("amount", 0))], 12, col.lightened(0.3))
			"crate":
				var cr := Rect2(x - 10, y - 9, 20, 18)
				draw_rect(cr, Color(0.25, 0.2, 0.08))
				draw_rect(cr, C_GOLD, false, 2.0)
				draw_line(cr.position, cr.end, Color(C_GOLD, 0.6), 1.5)
				_text(f_bold, Vector2(x + 14, y + 5), str(it.get("weapon", "")).to_upper(), 12, C_GOLD)
			"fortress":
				_fortress(y, int(it["value"]))


func _reward_tag(it: Dictionary) -> String:
	match str(it.get("reward", "army")):
		"coins":
			return "$"
		"ult":
			return "ult"
	return "+"


func _gate(i: int, it: Dictionary, x: float, y: float) -> void:
	var op := str(it["op"])
	var v := int(it["value"])
	var col := _gate_color(op, v)
	var hw := float(it["w"]) * 0.5 * PX_PER_U
	if it.has("move"):
		var amp := float((it["move"] as Dictionary).get("amp", 0.0)) * PX_PER_U
		draw_line(Vector2(x - amp - hw, y + 8), Vector2(x + amp + hw, y + 8), Color(col, 0.35), 2.0)
		draw_rect(Rect2(x - amp - hw, y - 6, hw * 2, 12), Color(col, 0.12))
		draw_rect(Rect2(x + amp - hw, y - 6, hw * 2, 12), Color(col, 0.12))
	var r := Rect2(x - hw + 2, y - 6, hw * 2 - 4, 12)
	draw_rect(r.grow(3), Color(col, 0.18))
	draw_rect(r, Color(col, 0.85))
	if it.has("blink"):
		var b: Dictionary = it["blink"]
		draw_rect(Rect2(r.position + Vector2(r.size.x * 0.5, 0), Vector2(r.size.x * 0.5, r.size.y)), Color(_gate_color(str(b["op"]), int(b["value"])), 0.9))
	draw_rect(r, Color(1, 1, 1, 0.55), false, 1.0)
	var label := _gate_text(op, v, it)
	if bool(it.get("hidden", false)):
		label = "? " + label
	_text_c(f_bold, Vector2(x, y - 10), label, 15, col.lightened(0.35))


func _gate_color(op: String, v: int) -> Color:
	match op:
		"-", "/":
			return C_BAD
		"x":
			return C_MULT
		"charge":
			return C_CHARGE
		"rate", "dmg", "multi":
			return C_POWER
		"arm":
			return C_ARM
	return C_GOOD


func _gate_text(op: String, v: int, it: Dictionary) -> String:
	match op:
		"+":
			return "+%d" % v
		"-":
			return "−%d" % v
		"x":
			return "×%d" % v
		"/":
			return "÷%d" % v
		"rate":
			return "+%d%% spd" % v
		"dmg":
			return "+%d dmg" % v
		"multi":
			return "+1 shot"
		"arm":
			return "crossbows" if v <= 1 else "blasters"
		"charge":
			var rw: Dictionary = it.get("reward", {})
			var to := str(rw.get("op", ""))
			if to == "weapon":
				to = str(rw.get("weapon", ""))
			elif to == "x":
				to = "×%d" % int(rw.get("value", 2))
			elif to == "+":
				to = "+%d" % int(rw.get("value", 0))
			return "%d→%s" % [v, to]
	return op


func _blade(it: Dictionary, x: float, y: float) -> void:
	var col := Color(0.85, 0.9, 1.0)
	if str(it.get("type", "rotor")) == "rotor":
		var rx := float(it.get("len", 1.5)) * PX_PER_U
		var ry := float(it.get("len", 1.5)) * (MAP_BOTTOM - MAP_TOP) / (lv.length + 6.0)
		_ellipse(Vector2(x, y), rx, ry, Color(1.0, 0.4, 0.4, 0.13))
		_ellipse_line(Vector2(x, y), rx, ry, Color(1.0, 0.55, 0.5, 0.7))
		var a := float(it.get("phase", 0.0))
		draw_line(Vector2(x, y) - Vector2(cos(a) * rx, sin(a) * ry), Vector2(x, y) + Vector2(cos(a) * rx, sin(a) * ry), col, 3.0)
		draw_circle(Vector2(x, y), 4.0, col)
	else:
		var amp := float(it.get("amp", 1.5)) * PX_PER_U
		var hw := float(it.get("w", 2.0)) * 0.5 * PX_PER_U
		draw_rect(Rect2(x - amp - hw, y - 7, (amp + hw) * 2, 14), Color(1.0, 0.4, 0.4, 0.12))
		draw_line(Vector2(x - hw, y), Vector2(x + hw, y), col, 5.0)
		for s in [-1.0, 1.0]:
			var tip := Vector2(x + s * (amp + hw), y)
			draw_line(Vector2(x + s * hw, y), tip, Color(1.0, 0.55, 0.5, 0.6), 1.5)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s * 7, -5), tip + Vector2(-s * 7, 5)]), Color(1.0, 0.55, 0.5, 0.8))


func _fortress(y: float, hp: int) -> void:
	var x0 := _x(-Balance.BRIDGE_HALF)
	var x1 := _x(Balance.BRIDGE_HALF)
	var r := Rect2(x0 + 6, y - 22, x1 - x0 - 12, 26)
	draw_rect(r.grow(4), Color(C_ENEMY, 0.2))
	draw_rect(r, Color(0.32, 0.12, 0.14))
	var n := 9
	for k in n:
		if k % 2 == 0:
			draw_rect(Rect2(r.position.x + k * r.size.x / n, r.position.y - 9, r.size.x / n, 10), Color(0.32, 0.12, 0.14))
	draw_rect(r, C_ENEMY, false, 2.0)
	_text_c(f_bold, Vector2((x0 + x1) * 0.5, y - 3), "FORTRESS  %d" % hp, 15, Color(1.0, 0.8, 0.7))


func _paths() -> void:
	for r: LevelSim.State in randoms:
		_path_line(r.samples, Color(C_VIOLET, 0.16), 1.2)
	_path_line(lazy_s.samples, Color(C_SILVER, 0.55), 2.0)
	_path_line(best_samples, Color(C_GOLD, 0.22), 9.0)
	_path_line(best_samples, C_GOLD, 3.0)


func _path_line(samples: PackedVector3Array, col: Color, width: float) -> void:
	if samples.size() < 2:
		return
	var pts := PackedVector2Array()
	for s in samples:
		if s.x > lv.length:
			break
		pts.append(Vector2(_x(s.y), _y(s.x)))
	if pts.size() >= 2:
		draw_polyline(pts, col, width, true)


func _chart() -> void:
	var top := 10.0
	for s in best_samples:
		top = maxf(top, s.z)
	top = _nice(top * 1.08)
	var r := Rect2(CHART_X0 - 8, MAP_TOP - 6, CHART_X1 - CHART_X0 + 16, MAP_BOTTOM - MAP_TOP + 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.18, 0.7)
	sb.border_color = Color(0.5, 0.65, 1.0, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	draw_style_box(sb, r)
	for k in 5:
		var a := top * k / 4.0
		var x := _cx(a, top)
		draw_line(Vector2(x, MAP_TOP), Vector2(x, MAP_BOTTOM), Color(0.6, 0.7, 1.0, 0.08), 1.0)
		_text_c(f_med, Vector2(x, MAP_BOTTOM + 22), str(int(a)), 11, C_DIM)
	_text(f_bold, Vector2(CHART_X0, MAP_TOP - 14), "ARMY ALONG THE RUN", 13, C_DIM)
	for rs: LevelSim.State in randoms:
		_army_line(rs.samples, top, Color(C_VIOLET, 0.28), 1.3)
	_army_line(lazy_s.samples, top, Color(C_SILVER, 0.75), 2.0)
	_army_line(best_samples, top, Color(C_GOLD, 0.2), 8.0)
	_army_line(best_samples, top, C_GOLD, 3.0)
	if not best_samples.is_empty():
		var last := best_samples[best_samples.size() - 1]
		var p := Vector2(_cx(last.z, top), _y(last.x))
		draw_circle(p, 6.0, C_GOLD)
		_text(f_bold, p + Vector2(-70, -12), "%d" % int(round(last.z)), 18, C_GOLD, true)


func _army_line(samples: PackedVector3Array, top: float, col: Color, width: float) -> void:
	if samples.size() < 2:
		return
	var pts := PackedVector2Array()
	for s in samples:
		pts.append(Vector2(_cx(s.z, top), _y(s.x)))
	draw_polyline(pts, col, width, true)


func _nice(v: float) -> float:
	var steps := [20.0, 40.0, 60.0, 100.0, 150.0, 200.0, 300.0, 400.0, 600.0, 800.0, 1000.0, 1500.0, 2000.0]
	for s: float in steps:
		if v <= s:
			return s
	return v


func _legend() -> void:
	var y := 1222.0
	var items := [
		[C_GOLD, "best line"], [C_SILVER, "lazy (x 0)"], [C_VIOLET, "random"],
		[C_GOOD, "+ gate"], [C_MULT, "× gate"], [C_BAD, "red gate"], [C_CHARGE, "charge"], [C_POWER, "power"], [C_ARM, "arm"],
	]
	var x := 30.0
	for k in items.size():
		if k == 3:
			x = 30.0
			y += 26.0
		var e: Array = items[k]
		draw_rect(Rect2(x, y - 9, 16, 9), e[0])
		_text(f_med, Vector2(x + 22, y), e[1], 13, C_TEXT)
		x += 22.0 + f_med.get_string_size(e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22.0


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 29:
		var a := TAU * k / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, 1.5, true)


func _text(f: Font, p: Vector2, s: String, size: int, col: Color, outline := true) -> void:
	if outline:
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.02, 0.03, 0.1, 0.85))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_c(f: Font, p: Vector2, s: String, size: int, col: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(f, p - Vector2(w * 0.5, 0), s, size, col)
