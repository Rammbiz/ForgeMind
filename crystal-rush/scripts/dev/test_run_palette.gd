extends Node
## test_run_palette (heroes design §10.3, §12.6 #12): the run's characters never read as a gate or a
## pickup, and no gem colour leaks into the run outside the medallion's 10 px gem pip.
##
## 1. Pixels (needs a real renderer): every champion placeholder (RunChampion, one per ChampionData row)
##    and the three starter heroes (RunHero: bolt, titan, seer; the ult ring under the hero hidden) are
##    rendered alone in a 512 x 512 SubViewport from the run camera's angle (from behind and above, the
##    35.6 deg pitch of Run.CAM_NEAR, the run's 50 deg vertical FOV) under the run's own lights and
##    environment, unchanged (a Track built for --level's world, kept: its WorldEnvironment with the run's
##    sky, tonemap, glow and fog, and its directional lights). Each model renders twice in the same frame
##    over one World3D: the lit image (the camera uses the world's environment: what the run shows) and a
##    mask (a second SubViewport with transparent_bg, its camera on a plain clear-colour environment):
##    model pixels = mask alpha > 0.5, scored on the lit image. A pixel passes when its CIE ΔE2000 to EVERY
##    reference colour is >= 10; a model passes with >= 90% of its pixels passing. Reference colours (the
##    identity of a gate or pickup): the field colour of every Models.GATE_KINDS kind (good bad charge
##    hidden power arm closed) and the pickups (the tile's ice plate Models.ICE and gold rim Models.GOLD,
##    the coin's rim and face from Run._coin_mesh, and Models.REWARD_COLORS army / coins / ult). Left out
##    as glints, not identity colours: the gates' highlight (the near-white core / label tint, L* 87-98)
##    and label outline (the 38%-alpha near-black stroke, L* 5-22), as the tile's white cross, the coin's
##    white star glint and the recruits' near-white silver: every lit model has near-white speculars and
##    near-black shade, so a neutral porcelain sphere would "read as a hidden gate" (measured: 85% of its
##    pixels within ΔE 10 of the hidden highlight #E6EBFF). The share against all three colours of every
##    kind (the strict §10.3 reading) is printed beside the verdict and written to the CSV, not asserted:
##    the pixel section opens with READING (which reading is asserted, pending the lead's sign-off) and
##    every model's line (always printed) carries both shares side by side.
##    Two self-checks on the same stage must hold or the test fails: a sphere painted exactly in a gate
##    colour (unshaded, the "good" gate's field) FAILS, and a neutral grey porcelain sphere (lit, albedo
##    PORCELAIN) PASSES; the mask is also checked to cover the model and not the background.
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
##        [--level=45] [--verbose]      (windowed, e.g. on a hidden desktop: pixels + scan; DIR gets one PNG
##                                       per model, model pixels that fail tinted magenta, the mask outside
##                                       the model darkened, and run_palette.csv)
##   godot --headless --path . res://scenes/dev/test_run_palette.tscn -- --autotest [--setup-only]
##        (headless: the scan and the ΔE self-check; the pixels print SKIPPED and the exit code is 77 unless
##        --setup-only, which builds the stage, every model and both spheres as a setup check, exit 0)
## Exit code = failures (77: pixels skipped). Last line: TEST_RUN_PALETTE PASS|FAIL|SKIPPED: ...

const MIN_DE := 10.0
const MIN_SHARE := 0.9
const NEAR_DE := 3.0
const SIZE := 512
## Model pixel = mask alpha above this.
const MASK_ALPHA := 0.5
## The self-check spheres: the gate colour (unshaded) and the porcelain albedo (lit).
const GATE_SPHERE := "good"
const PORCELAIN := Color(0.86, 0.86, 0.85)
## Headless without --setup-only: the pixel part is skipped, exit code 77.
const SKIPPED := 77
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
## The reading this test asserts, printed as the pixel section's header (the strict one waits for a decision).
const READING := "§10.3 reading: field colours + pickups (strict share printed, not asserted) — pending the lead's sign-off"

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
	var render := DisplayServer.get_name() != "headless"
	if not render and not args.has("setup-only"):
		print("== pixels: SKIPPED (headless: no renderer; run windowed on a hidden desktop, or --setup-only)")
		print("TEST_RUN_PALETTE SKIPPED: %d passed, %d failed; pixels skipped (headless) (%.1f s)" % [_passes, _fails,
				float(Time.get_ticks_msec() - t0) / 1000.0])
		get_tree().quit(_fails if _fails > 0 else SKIPPED)
		return
	var pixels: String = await _pixels(maxi(1, int(args.get("level", "45"))), render)
	print("TEST_RUN_PALETTE %s: %d passed, %d failed; pixels %s (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes,
			_fails, pixels, float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


## Books a check; a pass prints only with --verbose or `always` (the per-model lines: both shares every run).
func _ok(cond: bool, what: String, always := false) -> void:
	if cond:
		_passes += 1
		if _verbose or always:
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


## The reference colours: [[name, Color, identity], ...] (GATE_KINDS and the pickups, see the header):
## identity = a gate field or a pickup (asserted); the gates' highlights and outlines only count for the
## strict share (printed).
static func references() -> Array:
	var out: Array = []
	var parts := ["field", "highlight", "outline"]
	for kind: String in Models.GATE_KINDS:
		var cols: Array = Models.GATE_KINDS[kind]
		for i in cols.size():
			out.append(["gate %s %s" % [kind, parts[mini(i, 2)]], cols[i], i == 0])
	out.append(["tile plate (Models.ICE)", Models.ICE, true])
	out.append(["tile rim (Models.GOLD)", Models.GOLD, true])
	out.append(["coin rim", COIN_RIM, true])
	out.append(["coin face", COIN_FACE, true])
	for k: String in Models.REWARD_COLORS:
		out.append(["reward %s" % k, Models.REWARD_COLORS[k], true])
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


## Renders every model and scores its pixels (`render` false, headless --setup-only: builds the stage,
## every model and both spheres, frames them and frees them, a setup check). Two SubViewports render the
## same World3D in the same frame: the lit one through a camera on the world's environment (the run's
## own), the mask one with transparent_bg through a camera on a plain clear-colour environment, so an
## animated model is in the same pose on both images. Returns the pixel summary line.
func _pixels(level: int, render: bool) -> String:
	if render:
		print("== pixels: run models vs gate / pickup colours (ΔE2000 >= %.0f on >= %d%% of the model's pixels; mask alpha > %.1f)" % [
				MIN_DE, int(MIN_SHARE * 100.0), MASK_ALPHA])
		print(READING)
	else:
		print("== pixels: setup only (headless: no renderer); the stage, every model and both spheres are built")
	if _out != "" and render:
		DirAccess.make_dir_recursive_absolute(_out)
	var refs := references()
	var ref_labs: Array = []
	for r: Array in refs:
		ref_labs.append(lab(r[1]))
	var vp_lit := _viewport(false)
	vp_lit.own_world_3d = true
	add_child(vp_lit)
	var track := Track.new()
	vp_lit.add_child(track)
	track.build(100.0, true, Worlds.for_level(level))
	for c in track.get_children():
		if not (c is WorldEnvironment or c is DirectionalLight3D):
			c.queue_free()
	var env := track.environment
	if env == null:
		for c in track.get_children():
			if c is WorldEnvironment:
				env = (c as WorldEnvironment).environment
	var vp_mask := _viewport(true)
	add_child(vp_mask)
	vp_mask.world_3d = vp_lit.find_world_3d()
	# The lit camera keeps the world's environment (the run's sky, tonemap, glow and fog); the mask camera
	# clears to transparent with nothing on top (no glow or fog to touch the alpha).
	var cam_lit := Camera3D.new()
	cam_lit.fov = FOV
	vp_lit.add_child(cam_lit)
	cam_lit.make_current()
	var cam_mask := Camera3D.new()
	cam_mask.fov = FOV
	var plain := Environment.new()
	plain.background_mode = Environment.BG_CLEAR_COLOR
	plain.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	plain.glow_enabled = false
	plain.fog_enabled = false
	cam_mask.environment = plain
	vp_mask.add_child(cam_mask)
	cam_mask.make_current()
	var cams: Array[Camera3D] = [cam_lit, cam_mask]
	_csv.append("model,kind,pixels,pass_share,pass,worst_reference,worst_share,strict_share")
	# The two self-check spheres first: the gate-coloured one must fail, the porcelain one pass.
	var models: Array = [["check", "gate_sphere"], ["check", "porcelain_sphere"]]
	for id: String in ChampionData.CHAMPIONS:
		models.append(["champion", id])
	for h in HEROES:
		models.append(["hero", h])
	var passed := 0
	var built := 0
	var scored := 0
	for m: Array in models:
		var node := _model(str(m[0]), str(m[1]))
		vp_lit.add_child(node)
		_frame(cams[0], node)
		cams[1].global_transform = cams[0].global_transform
		if not render:
			await get_tree().process_frame
			built += 1 if node.is_inside_tree() and node.get_child_count() > 0 else 0
			vp_lit.remove_child(node)
			node.free()
			continue
		var res: Dictionary = await _score(vp_lit, vp_mask, refs, ref_labs, "%s_%s" % [str(m[0]), str(m[1])])
		vp_lit.remove_child(node)
		node.free()
		var share := float(res["share"])
		var ok := share >= MIN_SHARE and int(res["pixels"]) > 200
		# The asserted share (fields + pickups) and the strict one (+ the gates' highlights and outlines) side by side.
		var line := "%s %s: fields + pickups %.1f%% (asserted >= %d%%) | strict %.1f%% (printed, not asserted) of %d model pixels at ΔE >= %.0f (worst: %s, %.1f%% of pixels within ΔE %.0f; mask %.1f%% of the frame, sky-coloured %.1f%%)" % [
				str(m[0]), str(m[1]), share * 100.0, int(MIN_SHARE * 100.0), float(res["strict"]) * 100.0, int(res["pixels"]),
				MIN_DE, str(res["worst"]), float(res["worst_share"]) * 100.0, MIN_DE, float(res["cover"]) * 100.0,
				float(res["bg_like"]) * 100.0]
		_csv.append("%s,%s,%d,%.4f,%s,%s,%.4f,%.4f" % [str(m[1]), str(m[0]), int(res["pixels"]), share, str(ok),
				str(res["worst"]), float(res["worst_share"]), float(res["strict"])])
		# The mask must hold the model and never the background (the old two-grey mask counted the sky).
		var mask_ok := float(res["cover"]) > 0.002 and float(res["cover"]) < 0.6
		if str(m[0]) == "check":
			var want_pass := str(m[1]) == "porcelain_sphere"
			_ok(mask_ok and ok == want_pass, "self-check %s %s: %s" % [str(m[1]), "PASSES" if want_pass else "FAILS",
					line], true)
			continue
		scored += 1
		passed += 1 if ok else 0
		_ok(mask_ok and ok, line, true)
	vp_mask.queue_free()
	vp_lit.queue_free()
	if not render:
		_ok(built == models.size() and env != null, "headless setup check: the lit stage and %d of %d models built" % [built,
				models.size()])
		return "setup only (headless: no renderer; stage and %d models built)" % built
	if _out != "":
		var f := FileAccess.open(_out.path_join("run_palette.csv"), FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_csv) + "\n")
			f.close()
			print("  written ", _out.path_join("run_palette.csv"))
	return "%d of %d models pass" % [passed, scored]


static func _viewport(transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return vp


## A model in its run look: a champion grey-box in its class carry pose (idle), a hero running in place
## (RunHero animates itself) with its ult ring hidden; or a self-check sphere (RunChampion.HEIGHT across):
## "gate_sphere" unshaded in the GATE_SPHERE gate's field colour, "porcelain_sphere" lit in PORCELAIN.
static func _model(kind: String, id: String) -> Node3D:
	if kind == "check":
		var root := Node3D.new()
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = RunChampion.HEIGHT * 0.5
		sp.height = RunChampion.HEIGHT
		mi.mesh = sp
		mi.position = Vector3(0.0, RunChampion.HEIGHT * 0.5, 0.0)
		var mat := StandardMaterial3D.new()
		if id == "gate_sphere":
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = (Models.GATE_KINDS[GATE_SPHERE] as Array)[0]
		else:
			mat.albedo_color = PORCELAIN
			mat.roughness = 0.4
			mat.metallic = 0.0
		mi.material_override = mat
		root.add_child(mi)
		return root
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


## Renders the model lit and as a mask (the same frame) and scores the lit pixels under the mask:
## {pixels, share, worst, worst_share, cover (mask share of the frame), bg_like (share of model pixels
## within 3 / 255 of the lit background sampled in the frame's corners: should be ~0)}.
func _score(vp_lit: SubViewport, vp_mask: SubViewport, refs: Array, ref_labs: Array, name: String) -> Dictionary:
	for k in 4:
		await RenderingServer.frame_post_draw
	var a := vp_lit.get_texture().get_image()
	var b := vp_mask.get_texture().get_image()
	if a == null or b == null or a.is_empty() or b.is_empty():
		return {"pixels": 0, "share": 0.0, "worst": "no image", "worst_share": 0.0, "cover": 0.0, "bg_like": 0.0}
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var corner := a.get_pixel(2, 2)
	var total := 0
	var good := 0
	var strict := 0
	var bg_like := 0
	var seen := 0
	var near := PackedInt32Array()
	near.resize(refs.size())
	var shot: Image = (a.duplicate() as Image) if _out != "" else null
	for y in range(0, a.get_height(), STRIDE):
		for x in range(0, a.get_width(), STRIDE):
			seen += 1
			if b.get_pixel(x, y).a <= MASK_ALPHA:
				if shot:
					shot.set_pixel(x, y, shot.get_pixel(x, y).darkened(0.6))
				continue
			total += 1
			var ca := a.get_pixel(x, y)
			if absf(ca.r - corner.r) < 3.0 / 255.0 and absf(ca.g - corner.g) < 3.0 / 255.0 and absf(ca.b - corner.b) < 3.0 / 255.0:
				bg_like += 1
			var lc := lab(ca)
			var fine := true
			var fine_strict := true
			for i in ref_labs.size():
				if de2000(lc, ref_labs[i]) < MIN_DE:
					near[i] += 1
					fine_strict = false
					if bool(refs[i][2]):
						fine = false
			if fine:
				good += 1
			elif shot:
				shot.fill_rect(Rect2i(x, y, STRIDE, STRIDE), Color(1.0, 0.0, 1.0))
			strict += 1 if fine_strict else 0
	var worst := -1
	for i in near.size():
		if bool(refs[i][2]) and (worst < 0 or near[i] > near[worst]):
			worst = i
	if shot:
		shot.save_png(_out.path_join("palette_%s.png" % name))
	if _verbose:
		for i in near.size():
			if near[i] > 0:
				print("    %s: %.1f%% within ΔE %.0f of %s" % [name, 100.0 * float(near[i]) / maxf(float(total), 1.0), MIN_DE,
						str(refs[i][0])])
	return {"pixels": total, "share": float(good) / maxf(float(total), 1.0),
			"strict": float(strict) / maxf(float(total), 1.0),
			"worst": str(refs[worst][0]) if worst >= 0 and near[worst] > 0 else "none",
			"worst_share": float(near[worst]) / maxf(float(total), 1.0) if worst >= 0 else 0.0,
			"cover": float(total) / maxf(float(seen), 1.0), "bg_like": float(bg_like) / maxf(float(total), 1.0)}
