extends Node
## test_run_palette (heroes design §10.3, §12.6 #12): the run's characters never read as a gate or a
## pickup, and no gem colour leaks into the run outside the medallion's 10 px gem pip.
##
## 1. Pixels (needs a real renderer): every champion placeholder (RunChampion, one per ChampionData row)
##    and the three starter heroes (RunHero: bolt, titan, seer; the ult ring under the hero hidden) are
##    rendered alone in a 512 x 512 SubViewport from the run camera's angle (from behind and above, the
##    35.6 deg pitch of Run.CAM_NEAR, the run's 50 deg vertical FOV) under the run's own lights (a Track
##    built for --level's world, kept: its WorldEnvironment and directional lights) on a neutral grey
##    background. Each model renders twice in the same frame (two SubViewports over one World3D, the two
##    cameras' environments differ only in the grey, 0.25 and 0.55): model pixels = the pixels that stay
##    the same (within 3 / 255) on both, so edges blended with the background never count. A pixel
##    passes when its CIE ΔE2000 to EVERY reference colour is >= 10; a model passes with >= 90% of its
##    pixels passing. Reference colours: all three colours of every Models.GATE_KINDS kind (field,
##    highlight, label outline; good bad charge hidden power arm closed) and the pickups (the tile's ice
##    plate Models.ICE and gold rim Models.GOLD, the coin's rim and face from Run._coin_mesh, and
##    Models.REWARD_COLORS army / coins / ult). The tile's white cross, the coin's white star glint and the
##    recruits' near-white silver are glints, not identity colours, and stay out.
## 2. Static scan (always): scripts/run/**/*.gd and the run scenes (every .tscn / .tres under scenes/
##    outside scenes/dev) for the gem colours: UITokens.GEMS (top, bot, rim, light, deep and the opal
##    flecks; the "metal" setting colours are not gem colours), HeroGemEmblem.BODY and SummonFx.HEX /
##    PILLAR. A hit = a hex literal ("#3FA9FF", "3FA9FF", 8-digit with alpha too) or a numeric Color(r, g, b)
##    whose 8-bit values equal a gem colour (+-0.6). Gem colour APIs (UITokens.GEMS / gem( / gem_of( /
##    RARITY_GEM / TOPAZ, GemDraw.draw_mark / draw_gem / draw_pip, HeroGemEmblem, SummonFx.) are hits too,
##    except the pip calls (UITokens.gem( / gem_of(, GemDraw.draw_mark) in the PIP_FILES, which must draw
##    it at 10 px (const PIP := 10.0): the medallion (§10.3) and the start banner's discs (the same 10 px
##    pip, §10.5); every allowed line is printed. Colours within ΔE2000 < 3 of a gem colour are printed as
##    near misses (info: e.g. the run's white-gold #FFE7A3 sits next to topaz "light" #FFE3A6 by design).
## Also a ΔE2000 self-check on reference pairs (Sharma, Wu, Dalal 2005).
##
##   godot --path . --resolution 720x1280 res://scenes/dev/test_run_palette.tscn -- --autotest --out=DIR
##        [--level=45] [--verbose]      (windowed: pixels + scan; DIR gets one PNG per model, model pixels
##                                       that fail tinted magenta, and run_palette.csv)
##   godot --headless --path . res://scenes/dev/test_run_palette.tscn -- --autotest
##        (headless: the scan, the self-check and a setup check of the stage and every model; it says the
##        pixel part was skipped)
## Exit code = failures. Last line: TEST_RUN_PALETTE PASS|FAIL: ...

const MIN_DE := 10.0
const MIN_SHARE := 0.9
const NEAR_DE := 3.0
const SIZE := 512
const BG_A := 0.25
const BG_B := 0.55
const SAME := 3.0 / 255.0
## Every STRIDE-th pixel in x and y is scored (a quarter of the pixels: the shares are unchanged).
const STRIDE := 2
## Run camera: pitch of Run.CAM_NEAR (height 7.6 over back 7.0 + look-ahead 3.6) and the run's vertical FOV
## at a square aspect (Run._fit_fov clamps to 50).
const PITCH := 35.6
const FOV := 50.0
## The 10 px gem pip (§10.3) and the files allowed to draw it, with why (printed every run).
const PIP_FILES := {
	"res://scripts/run/champion_medallions.gd": "the medallion's 10 px gem pip, §10.3",
	"res://scripts/run/team_banner.gd": "the start banner's 10 px gem pips under the class discs, the same pip, §10.5",
}
## Gem colour APIs (UITokens.TOPAZ is the topaz rim #FFB52E; GemDraw.draw_pip defaults to it) ...
const GEM_API := "UITokens\\.(GEMS|gem\\(|gem_of\\(|RARITY_GEM|TOPAZ\\b)|GemDraw\\.(draw_mark|draw_gem|draw_pip)\\(|HeroGemEmblem|SummonFx\\."
## ... and the ones a pip file may call to draw the 10 px pip.
const PIP_API := "^(UITokens\\.(gem\\(|gem_of\\()|GemDraw\\.draw_mark\\()$"
const HEROES: Array[String] = ["bolt", "titan", "seer"]
## Pickup identity colours (see the header).
const COIN_RIM := Color(1.0, 0.72, 0.2)      ## Run._coin_mesh rim albedo
const COIN_FACE := Color(1.0, 0.86, 0.38)    ## Run._coin_mesh face glow

var _fails := 0
var _passes := 0
var _verbose := false
var _out := ""
var _csv: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_verbose = args.has("verbose")
	_out = str(args.get("out", ""))
	Save.readonly = true
	var t0 := Time.get_ticks_msec()
	_self_check()
	_scan()
	var pixels: String = await _pixels(maxi(1, int(args.get("level", "45"))), DisplayServer.get_name() != "headless")
	print("TEST_RUN_PALETTE %s: %d passed, %d failed; pixels %s (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes,
			_fails, pixels, float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		if _verbose:
			print("  ok ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


# ------------------------------------------------------------------ colour science

## sRGB (0..1, gamma encoded) -> CIE Lab (D65).
static func lab(c: Color) -> Vector3:
	var rgb := [c.r, c.g, c.b]
	for i in 3:
		var v: float = clampf(rgb[i], 0.0, 1.0)
		rgb[i] = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var x: float = (0.4124564 * rgb[0] + 0.3575761 * rgb[1] + 0.1804375 * rgb[2]) / 0.95047
	var y: float = 0.2126729 * rgb[0] + 0.7151522 * rgb[1] + 0.0721750 * rgb[2]
	var z: float = (0.0193339 * rgb[0] + 0.1191920 * rgb[1] + 0.9503041 * rgb[2]) / 1.08883
	var fx := _f(x)
	var fy := _f(y)
	var fz := _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 216.0 / 24389.0 else (24389.0 / 27.0 * t + 16.0) / 116.0


## CIE ΔE2000 between two Lab colours (kL = kC = kH = 1).
static func de2000(p: Vector3, q: Vector3) -> float:
	var c1 := sqrt(p.y * p.y + p.z * p.z)
	var c2 := sqrt(q.y * q.y + q.z * q.z)
	var cm := (c1 + c2) * 0.5
	var cm7 := pow(cm, 7.0)
	var g := 0.5 * (1.0 - sqrt(cm7 / (cm7 + 6103515625.0)))
	var a1 := p.y * (1.0 + g)
	var a2 := q.y * (1.0 + g)
	var c1p := sqrt(a1 * a1 + p.z * p.z)
	var c2p := sqrt(a2 * a2 + q.z * q.z)
	var h1 := 0.0 if c1p == 0.0 else fposmod(rad_to_deg(atan2(p.z, a1)), 360.0)
	var h2 := 0.0 if c2p == 0.0 else fposmod(rad_to_deg(atan2(q.z, a2)), 360.0)
	var dl := q.x - p.x
	var dc := c2p - c1p
	var dh := 0.0
	if c1p * c2p != 0.0:
		dh = h2 - h1
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
	var dhh := 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dh) * 0.5)
	var lm := (p.x + q.x) * 0.5
	var cpm := (c1p + c2p) * 0.5
	var hm := h1 + h2
	if c1p * c2p != 0.0:
		if absf(h1 - h2) <= 180.0:
			hm = (h1 + h2) * 0.5
		elif h1 + h2 < 360.0:
			hm = (h1 + h2 + 360.0) * 0.5
		else:
			hm = (h1 + h2 - 360.0) * 0.5
	var t := 1.0 - 0.17 * cos(deg_to_rad(hm - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hm)) \
			+ 0.32 * cos(deg_to_rad(3.0 * hm + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hm - 63.0))
	var d_theta := 30.0 * exp(-pow((hm - 275.0) / 25.0, 2.0))
	var cpm7 := pow(cpm, 7.0)
	var rc := 2.0 * sqrt(cpm7 / (cpm7 + 6103515625.0))
	var lm50 := (lm - 50.0) * (lm - 50.0)
	var sl := 1.0 + 0.015 * lm50 / sqrt(20.0 + lm50)
	var sc := 1.0 + 0.045 * cpm
	var sh := 1.0 + 0.015 * cpm * t
	var rt := -sin(deg_to_rad(2.0 * d_theta)) * rc
	var a := dl / sl
	var b := dc / sc
	var c := dhh / sh
	return sqrt(a * a + b * b + c * c + rt * b * c)


func _self_check() -> void:
	print("== ΔE2000 self-check (Sharma et al. 2005 pairs)")
	var pairs := [[Vector3(50.0, 2.6772, -79.7751), Vector3(50.0, 0.0, -82.7485), 2.0425],
			[Vector3(50.0, 0.0, 0.0), Vector3(50.0, -1.0, 2.0), 2.3669],
			[Vector3(50.0, 2.5, 0.0), Vector3(73.0, 25.0, -18.0), 27.1492],
			[Vector3(2.0776, 0.0795, -1.1350), Vector3(0.9033, -0.0636, -0.5514), 0.9082]]
	for pr: Array in pairs:
		var de := de2000(pr[0], pr[1])
		_ok(absf(de - float(pr[2])) < 0.001, "ΔE2000 %s %s = %.4f (want %.4f)" % [str(pr[0]), str(pr[1]), de, float(pr[2])])
	var w := lab(Color(1, 1, 1))
	_ok(absf(w.x - 100.0) < 0.01 and absf(w.y) < 0.01 and absf(w.z) < 0.01, "sRGB white -> Lab (100, 0, 0) (%s)" % str(w))


## The reference colours: [[name, Color], ...] (GATE_KINDS and the pickups, see the header).
static func references() -> Array:
	var out: Array = []
	var parts := ["field", "highlight", "outline"]
	for kind: String in Models.GATE_KINDS:
		var cols: Array = Models.GATE_KINDS[kind]
		for i in cols.size():
			out.append(["gate %s %s" % [kind, parts[mini(i, 2)]], cols[i]])
	out.append(["tile plate (Models.ICE)", Models.ICE])
	out.append(["tile rim (Models.GOLD)", Models.GOLD])
	out.append(["coin rim", COIN_RIM])
	out.append(["coin face", COIN_FACE])
	for k: String in Models.REWARD_COLORS:
		out.append(["reward %s" % k, Models.REWARD_COLORS[k]])
	return out


# ------------------------------------------------------------------ static scan

## Gem colours: [[name, Color], ...] (see the header).
static func gem_colours() -> Array:
	var out: Array = []
	for gem: String in UITokens.GEMS:
		var g: Dictionary = UITokens.GEMS[gem]
		for key in ["top", "bot", "rim", "light", "deep"]:
			if g.has(key):
				out.append(["UITokens.GEMS.%s.%s" % [gem, key], g[key]])
		for i in (g.get("flecks", []) as Array).size():
			out.append(["UITokens.GEMS.%s.flecks[%d]" % [gem, i], (g["flecks"] as Array)[i]])
	for k: String in HeroGemEmblem.BODY:
		out.append(["HeroGemEmblem.BODY.%s" % k, HeroGemEmblem.BODY[k]])
	for k: String in SummonFx.HEX:
		out.append(["SummonFx.HEX.%s" % k, SummonFx.HEX[k]])
	for k: String in SummonFx.PILLAR:
		out.append(["SummonFx.PILLAR.%s" % k, SummonFx.PILLAR[k]])
	return out


static func _files(dir: String, exts: Array, skip: Array, out: PackedStringArray) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		if f.get_extension() in exts:
			out.append(dir.path_join(f))
	for sub in da.get_directories():
		var p := dir.path_join(sub)
		if not p in skip:
			_files(p, exts, skip, out)


func _scan() -> void:
	print("== static scan: gem colours in the run's scripts and scenes")
	var gems := gem_colours()
	var by_hex := {}
	var labs: Array = []
	for g: Array in gems:
		by_hex[(g[1] as Color).to_html(false).to_upper()] = str(g[0])
		labs.append([str(g[0]), lab(g[1]), g[1]])
	var files: PackedStringArray = PackedStringArray()
	_files("res://scripts/run", ["gd"], [], files)
	_files("res://scenes", ["tscn", "tres"], ["res://scenes/dev"], files)
	var hex_re := RegEx.create_from_string("[\"']#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?[\"']")
	var num_re := RegEx.create_from_string("Color\\(\\s*([0-9]*\\.?[0-9]+)\\s*,\\s*([0-9]*\\.?[0-9]+)\\s*,\\s*([0-9]*\\.?[0-9]+)")
	var api_re := RegEx.create_from_string(GEM_API)
	var pip_re := RegEx.create_from_string(PIP_API)
	var hits: PackedStringArray = PackedStringArray()
	var near: PackedStringArray = PackedStringArray()
	var allowed_lines: PackedStringArray = PackedStringArray()
	var colours := 0
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		var lines := text.split("\n")
		var allowed := PIP_FILES.has(path)
		if allowed:
			_ok(text.contains("const PIP := 10.0"), "%s draws its gem pip at 10 px (const PIP := 10.0)" % path.get_file())
		for ln in lines.size():
			var line := lines[ln]
			var at := "%s:%d" % [path.trim_prefix("res://"), ln + 1]
			for m in hex_re.search_all(line):
				var hx := m.get_string(1).to_upper()
				colours += 1
				var c := Color.html("#" + hx)
				if by_hex.has(hx):
					hits.append("%s #%s = %s" % [at, hx, by_hex[hx]])
				else:
					_near(at, "#" + hx, c, labs, near)
			for m in num_re.search_all(line):
				var c := Color(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)))
				if c.r > 1.0 or c.g > 1.0 or c.b > 1.0:
					continue
				colours += 1
				var same := ""
				for g: Array in gems:
					var gc: Color = g[1]
					if absf(c.r - gc.r) * 255.0 <= 0.6 and absf(c.g - gc.g) * 255.0 <= 0.6 and absf(c.b - gc.b) * 255.0 <= 0.6:
						same = str(g[0])
				if same != "":
					hits.append("%s %s = %s" % [at, m.get_string(0), same])
				else:
					_near(at, m.get_string(0) + ")", c, labs, near)
			for m in api_re.search_all(line):
				if allowed and pip_re.search(m.get_string(0)) != null:
					allowed_lines.append("%s %s (%s)" % [at, m.get_string(0), PIP_FILES[path]])
				else:
					hits.append("%s gem API %s (gem colours only in the 10 px gem pip)" % [at, m.get_string(0)])
	print("  %d files, %d colour literals checked against %d gem colours" % [files.size(), colours, gems.size()])
	for h in allowed_lines:
		print("  allowed ", h)
	for h in hits:
		print("  HIT ", h)
	for n in near:
		print("  near (info) ", n)
	_ok(hits.is_empty(), "no gem colour or gem API in the run's scripts / scenes outside the medallion pip (%d hits)" % hits.size())


static func _near(at: String, lit: String, c: Color, labs: Array, out: PackedStringArray) -> void:
	var lc := lab(c)
	for g: Array in labs:
		var de := de2000(lc, g[1])
		if de < NEAR_DE:
			out.append("%s %s is ΔE %.1f from %s #%s" % [at, lit, de, str(g[0]), (g[2] as Color).to_html(false).to_upper()])


# ------------------------------------------------------------------ pixels


## Renders every model and scores its pixels (`render` false, headless: builds the stage and every model,
## frames it and frees it, a setup check). Two SubViewports render the same World3D in the same frame
## through two cameras whose environments differ only in the background grey, so an animated model is
## in the same pose on both images. Returns the pixel summary line.
func _pixels(level: int, render: bool) -> String:
	if render:
		print("== pixels: run models vs gate / pickup colours (ΔE2000 >= %.0f on >= %d%% of the model's pixels)" % [MIN_DE,
				int(MIN_SHARE * 100.0)])
	else:
		print("== pixels: skipped (headless: no renderer); the stage and every model are built as a setup check")
	if _out != "" and render:
		DirAccess.make_dir_recursive_absolute(_out)
	var refs := references()
	var ref_labs: Array = []
	for r: Array in refs:
		ref_labs.append(lab(r[1]))
	var vp_a := _viewport()
	vp_a.own_world_3d = true
	add_child(vp_a)
	var track := Track.new()
	vp_a.add_child(track)
	track.build(100.0, true, Worlds.for_level(level))
	for c in track.get_children():
		if not (c is WorldEnvironment or c is DirectionalLight3D):
			c.queue_free()
	var env := track.environment
	if env == null:
		for c in track.get_children():
			if c is WorldEnvironment:
				env = (c as WorldEnvironment).environment
	var vp_b := _viewport()
	add_child(vp_b)
	vp_b.world_3d = vp_a.find_world_3d()
	var cams: Array[Camera3D] = []
	for i in 2:
		var cam := Camera3D.new()
		cam.fov = FOV
		var e := env.duplicate() as Environment
		e.background_mode = Environment.BG_COLOR
		var g := BG_A if i == 0 else BG_B
		e.background_color = Color(g, g, g)
		e.fog_enabled = false
		cam.environment = e
		(vp_a if i == 0 else vp_b).add_child(cam)
		cam.make_current()
		cams.append(cam)
	_csv.append("model,kind,pixels,pass_share,pass,worst_reference,worst_share")
	var models: Array = []
	for id: String in ChampionData.CHAMPIONS:
		models.append(["champion", id])
	for h in HEROES:
		models.append(["hero", h])
	var passed := 0
	var built := 0
	for m: Array in models:
		var node := _model(str(m[0]), str(m[1]))
		vp_a.add_child(node)
		_frame(cams[0], node)
		cams[1].global_transform = cams[0].global_transform
		if not render:
			await get_tree().process_frame
			built += 1 if node.is_inside_tree() and node.get_child_count() > 0 else 0
			vp_a.remove_child(node)
			node.free()
			continue
		var res: Dictionary = await _score(vp_a, vp_b, refs, ref_labs, "%s_%s" % [str(m[0]), str(m[1])])
		vp_a.remove_child(node)
		node.free()
		var share := float(res["share"])
		var ok := share >= MIN_SHARE and int(res["pixels"]) > 200
		passed += 1 if ok else 0
		_ok(ok, "%s %s: %.1f%% of %d model pixels at ΔE >= %.0f (worst: %s, %.1f%% of pixels within ΔE %.0f)" % [str(m[0]),
				str(m[1]), share * 100.0, int(res["pixels"]), MIN_DE, str(res["worst"]), float(res["worst_share"]) * 100.0, MIN_DE])
		_csv.append("%s,%s,%d,%.4f,%s,%s,%.4f" % [str(m[1]), str(m[0]), int(res["pixels"]), share, str(ok), str(res["worst"]),
				float(res["worst_share"])])
	vp_b.queue_free()
	vp_a.queue_free()
	if not render:
		_ok(built == models.size() and env != null, "headless setup check: the lit stage and %d of %d models built" % [built,
				models.size()])
		return "skipped (headless: no renderer; stage and %d models built)" % built
	if _out != "":
		var f := FileAccess.open(_out.path_join("run_palette.csv"), FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_csv) + "\n")
			f.close()
			print("  written ", _out.path_join("run_palette.csv"))
	return "%d of %d models pass" % [passed, models.size()]


static func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return vp


## A model in its run look: a champion grey-box in its class carry pose (idle), a hero running in place
## (RunHero animates itself) with its ult ring hidden.
static func _model(kind: String, id: String) -> Node3D:
	if kind == "hero":
		var h := RunHero.new()
		h.setup(id, {})
		h.ring.visible = false
		return h
	var row: Dictionary = ChampionData.CHAMPIONS.get(id, {})
	var c := RunChampion.new()
	c.setup(str(row.get("class", "warrior")), str(row.get("element", "")))
	c.animate(0.0, false, false)
	return c


## The camera behind and above the model (the run looks along -Z from +Z), framing its height.
static func _frame(cam: Camera3D, node: Node3D) -> void:
	var h := 1.5 if node is RunHero else RunChampion.HEIGHT
	var look := Vector3(0.0, h * 0.5, 0.0)
	var dir := Vector3(0.0, sin(deg_to_rad(PITCH)), cos(deg_to_rad(PITCH)))
	var dist := (h * 0.8) / tan(deg_to_rad(FOV) * 0.5)
	cam.position = look + dir * dist
	cam.look_at(look)


## Renders the model on both greys (the same frame) and scores its pixels: {pixels, share, worst,
## worst_share}.
func _score(vp_a: SubViewport, vp_b: SubViewport, refs: Array, ref_labs: Array, name: String) -> Dictionary:
	for k in 4:
		await RenderingServer.frame_post_draw
	var a := vp_a.get_texture().get_image()
	var b := vp_b.get_texture().get_image()
	if a == null or b == null or a.is_empty() or b.is_empty():
		return {"pixels": 0, "share": 0.0, "worst": "no image", "worst_share": 0.0}
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var total := 0
	var good := 0
	var near := PackedInt32Array()
	near.resize(refs.size())
	var shot: Image = (a.duplicate() as Image) if _out != "" else null
	for y in range(0, a.get_height(), STRIDE):
		for x in range(0, a.get_width(), STRIDE):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) > SAME or absf(ca.g - cb.g) > SAME or absf(ca.b - cb.b) > SAME:
				continue
			total += 1
			var lc := lab(ca)
			var fine := true
			for i in ref_labs.size():
				if de2000(lc, ref_labs[i]) < MIN_DE:
					near[i] += 1
					fine = false
			if fine:
				good += 1
			elif shot:
				shot.fill_rect(Rect2i(x, y, STRIDE, STRIDE), Color(1.0, 0.0, 1.0))
	var worst := -1
	for i in near.size():
		if worst < 0 or near[i] > near[worst]:
			worst = i
	if shot:
		shot.save_png(_out.path_join("palette_%s.png" % name))
	if _verbose:
		for i in near.size():
			if near[i] > 0:
				print("    %s: %.1f%% within ΔE %.0f of %s" % [name, 100.0 * float(near[i]) / maxf(float(total), 1.0), MIN_DE,
						str(refs[i][0])])
	return {"pixels": total, "share": float(good) / maxf(float(total), 1.0),
			"worst": str(refs[worst][0]) if worst >= 0 and near[worst] > 0 else "none",
			"worst_share": float(near[worst]) / maxf(float(total), 1.0) if worst >= 0 else 0.0}
