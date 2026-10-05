class_name Run
extends Node3D
## One level of Crystal Rush (Etap 1 spec, sections 1, 2 and 5.6).
##
## The finger drags the hero sideways 1:1 (DRAG_GAIN world units per screen width, a
## critically damped follow); the army is a blob of soldiers behind it (Army). The hero shoots
## whatever is in its corridor ahead: squads, spikes, turrets, geodes, weapon crates, the
## fortress and gates (shots grow + gates, shrink - gates and flip charge gates). Gate rows apply
## the one gate the hero passes through and fold the rest. Spikes and blades kill the soldiers
## that touch them, turrets pick soldiers off, squads clash 1:1. War machines from crates ride
## with the army (Weapons). At the end the army besieges the fortress, then the survivors climb
## the multiplier stairs.
##
## Rules mirror LevelSim so the bot and level_check stay trustworthy; item dictionaries keep the
## fields the bot reads (alive, hp, live x, live op/value, revealed, node, crowd, label).

signal finished(won: bool, coins: int, reason: String)   ## reason: FORTRESS_FALLS / ARMY_LOST / NOT_ENOUGH
signal army_changed(n: int)
signal coins_changed(n: int)
signal ult_changed(ratio: float, ready: bool)            ## only when the ratio or readiness changes
signal hint(key: String)                                 ## tutorial banner; "" hides it
signal weapon_added(kind: String, level: int)
signal power_changed(stat: String, total: float)         ## "rate" | "dmg" | "multi" | "arm"
signal stairs_done(mult: float)

enum State { READY, RUNNING, CLASH, SIEGE, STAIRS, WON, LOST }

const SUBSTEP := 1.0 / 40.0
const MAX_FRAME := 0.25
const KEY_SPEED := 6.0
const VIEW_AHEAD := 75.0
const VIEW_BEHIND := 12.0
const CAM_HFOV := 40.0
const CAM_NEAR := Vector3(7.6, 7.0, 3.6)    # small army: height, back, look-ahead
const CAM_FAR := Vector3(10.4, 12.2, 1.2)   # army at its widest blob
const TILE_STREAK := 0.6
const STAIR_TIME := 0.3
const FALL_TIME := 1.5
const STAIRS_W := 5.0
const FORT_BACK := 0.6           # fortress root sits this far past its d
const ARMY_LABEL_COLOR := Color(1.0, 1.0, 1.0)
const GAIN := Color(0.35, 1.0, 0.5)
const LOSS := Color(1.0, 0.33, 0.3)
const GOLD := Color(1.0, 0.82, 0.3)
const EMERALD := Color(0.18, 1.0, 0.55)
const KNIGHT_BASE := "res://assets/units/knight/knight"
## Army weapon tier shown on the knights (no tiered models yet): fresnel edge colour, amount.
## Per tier: edge colour, edge amount, crystal (crest and blades) colour, crystal tint, glow.
const TIER_EDGE := [
	[Color(0.55, 0.8, 1.0), 0.35, Color(0.45, 0.9, 1.0), 0.3, 0.45],
	[Color(0.15, 1.0, 0.8), 1.2, Color(0.1, 1.0, 0.7), 0.9, 1.5],
	[Color(0.78, 0.42, 1.0), 1.1, Color(0.85, 0.4, 1.0), 0.95, 1.7],
]
const HITTABLE := ["gate", "barricade", "turret", "squad", "geode", "crate", "fortress"]
const TILE_SHADER := "shader_type spatial;
render_mode blend_mix, cull_back;
uniform float glow = 1.4;
void fragment() {
	vec3 c = COLOR.rgb;
	// Decodes sRGB vertex colours. gl_compatibility (OUTPUT_IS_SRGB) does not re-encode, so the
	// plate renders darker than a StandardMaterial would; it is tuned to look right this way.
	c = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
	ALBEDO = c;
	float ice = smoothstep(0.05, 0.3, c.b - c.r);
	float t = mod(TIME, 6.2831853);
	EMISSION = c * ice * glow * (0.85 + 0.15 * sin(t * 3.0));
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}
"

# ------------------------------------------------------------------ public state (spec section 2)

var level := 1
var hero_type := "bolt"
var def: Dictionary
var ult: Dictionary
var state: State = State.READY
var d := 0.0                    ## distance run
var hx := 0.0                   ## hero x
var army := 0
var coins := 0
var hero_hp := 0
var items: Array[Dictionary] = []
var weapons: Array[Dictionary] = []
var arm_tier := 0
var power := {"rate": 0.0, "dmg": 0, "multi": 0}
var stairs_mult := 1.0
var result := {}
var world: Dictionary

# Extra state the bot / autotest / HUD read.
var t := 0.0                    ## seconds since start() (clash time included)
var length := 100.0             ## fortress distance
var expected := 0.0
var ult_points := 0.0
var hazard_deaths := 0.0
var target_x := 0.0
var quality_high := true
var step_advance := 0.0         ## z the army moved in the current step (machines follow it)

# Nodes.
var track: Track
var effects: Effects
var juice: Juice
var fx: UnitFx
var army_view: Army
var hazards: Hazards
var arsenal: Weapons
var hero: RunHero
var cam: Camera3D

var _gen: Dictionary
var _pick: Array[Dictionary] = []     # tiles, coins, recruits and the first gate of each row
var _block: Array[Dictionary] = []    # squads and the fortress
var _targ: Array[Dictionary] = []     # anything the hero / machines may hit
var _vaults: Array[Dictionary] = []   # things the hero hops over
var _gates: Array[Dictionary] = []
var _rows := {}                       # row -> Array of gate items
var _tile_items: Array[Dictionary] = []
var _coin_items: Array[Dictionary] = []
var _recruit_items: Array[Dictionary] = []
var _hints: Array = []
var _fortress: Dictionary = {}
var _stairs: Dictionary = {}
var _pk := 0
var _bk := 0
var _armed: Array[Dictionary] = []  # squads met clear of the blob, still live until passed
var _tk := 0
var _vk := 0
var _hk := 0
var _foe: Dictionary = {}
var _tick := 0.0
var _atk_cd := 0.0
var _ult_left := 0.0
var _ult_tick := 0.0
var _quake_d := 0.0
var _quake_wave := 99
var _armor := 0.0
var _finale := 0.0
var _end_t := 0.0
var _loss_acc := 0.0
var _last_ult := Vector2(-1.0, -1.0)
var _script_done := false
var _hints_started := false
var _tile_streak := 0
var _tile_ms := -100000
var _touch_id := -1
var _touch_x0 := 0.0
var _target_x0 := 0.0
var _down := {}                     # fingers that went down on the play area (not on a button)
var _max_shown := Balance.MAX_SHOWN
var _radius_vis := Balance.BLOB_MIN
var _vis_t := 0.0
var _cull_t := 0.0
var _peak := 0
var _army_at_fortress := -1
var _won := false
var _finish_sent := false
var _stair_plan: Array = []           # [{mult, cost, units}] steps reached
var _stair_front := -1
var _stair_t := 0.0
var _stair_phase := 0
var _stair_plan_rest := 0
var _pop_cd := {}
var _army_label: Label3D
var _label_off := Vector3.ZERO
var _tiles: MultiMeshInstance3D
var _coins_mm: MultiMeshInstance3D
var _recruit_view: CrowdView
## The owner's Crystal Knight as a baked VAT crowd (null: the procedural soldier fallback).
var army_anim: VatClip
var recruit_anim: VatClip
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _cam_vel := Vector3.ZERO
var _look_vel := Vector3.ZERO
var _fov := 60.0
var _fov_base := 60.0
var _cam_ready := false


func setup(p_level: int, p_hero: String) -> void:
	level = p_level
	hero_type = p_hero
	def = Balance.HEROES[hero_type]
	ult = def["ult"]
	army = Balance.start_army(int(Save.upgrades["army"]))
	hero_hp = int(def["hp"])
	world = Worlds.for_level(level)


func _ready() -> void:
	Audio.reset_laser()
	quality_high = Save.quality == "high"
	_max_shown = Balance.MAX_SHOWN if quality_high else Balance.MAX_SHOWN_LOW
	# Levels are laid out for the base army: upgrades are a real advantage (review bug).
	_gen = LevelGen.build(level, Balance.START_ARMY)
	length = float(_gen["length"])
	expected = float(_gen["expected"])
	_hints = _gen.get("hints", [])
	Models.use_world(world)
	track = Track.new()
	add_child(track)
	track.build(length, quality_high, world)
	effects = Effects.new()
	effects.quality_high = quality_high
	add_child(effects)
	juice = Juice.new()
	add_child(juice)
	fx = UnitFx.new()
	add_child(fx)
	army_anim = _knight_clip()
	if army_anim:
		fx.setup(army_anim.mesh, Models.raider_mesh(), army_anim.albedo, Models.asset_texture("raider"))
	else:
		fx.setup(Models.soldier_mesh(0), Models.raider_mesh(), Models.asset_texture("soldier"), Models.asset_texture("raider"))
	hazards = Hazards.new()
	hazards.setup(self)
	add_child(hazards)
	_spawn_items(_gen["items"])
	hero = RunHero.new()
	add_child(hero)
	hero.setup(hero_type)
	army_view = Army.new()
	add_child(army_view)
	army_view.setup(fx, _max_shown, army_anim.mesh if army_anim else Models.soldier_mesh(0))
	if army_anim:
		army_anim.attach(army_view.view)
		army_anim.play("idle", 0.0)
	_radius_vis = blob_radius()
	army_view.radius = _radius_vis
	army_view.center = _army_center()
	army_view.spawn(mini(army, _max_shown))
	arsenal = Weapons.new()
	add_child(arsenal)
	arsenal.setup(self)
	_army_label = Models.label(str(army), 110, ARMY_LABEL_COLOR, true)
	_army_label.outline_modulate = Color(0.04, 0.14, 0.42)
	_army_label.outline_size = 26
	_army_label.render_priority = 6
	_army_label.no_depth_test = true
	add_child(_army_label)
	_peak = army
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 300.0
	add_child(cam)
	_fit_fov()
	get_viewport().size_changed.connect(_fit_fov)
	cam.make_current()
	_visuals(0.0)


## Starts the run (first touch, a key, the bot or the HUD).
func start() -> void:
	if state == State.READY:
		state = State.RUNNING
		Audio.play("whoosh_gate", -10.0)


## Target x for the hero (the bot and tests steer with this).
func steer_to(x: float) -> void:
	target_x = clampf(x, -Balance.X_LIMIT, Balance.X_LIMIT)


func blob_radius() -> float:
	return Balance.blob_radius(float(army))


## A VatClip for the baked knight, or null when the bake is missing (procedural fallback).
static func _knight_clip() -> VatClip:
	if not ResourceLoader.exists(KNIGHT_BASE + "_vat_mesh.res"):
		return null
	return VatClip.create(KNIGHT_BASE)


func ult_ready() -> bool:
	return ult_points >= float(ult["charge"]) - 0.001 and _ult_left <= 0.0 and _quake_wave >= 99


# ------------------------------------------------------------------ building

func _spawn_items(list: Array) -> void:
	var tiles: Array[Dictionary] = []
	for spec: Dictionary in list:
		var it: Dictionary = spec.duplicate(true)
		it["alive"] = true
		if not it.has("x"):
			it["x"] = 0.0
		var kind := str(it["kind"])
		var at := Vector3(float(it["x"]), 0.0, -float(it["d"]))
		match kind:
			"tile":
				_tile_items.append(it)
				_pick.append(it)
			"coin":
				_coin_items.append(it)
				_pick.append(it)
			"recruits":
				_recruit_items.append(it)
				_pick.append(it)
				_recruit_points(it)
			"gate":
				_build_gate(it)
			"barricade", "blade", "turret", "geode", "crate", "squad":
				hazards.add(it)
				if kind == "squad":
					_block.append(it)
				if kind != "blade":
					_targ.append(it)
				if kind in ["barricade", "blade", "geode", "crate"]:
					_vaults.append(it)
			"fortress":
				it["hp"] = float(it["value"])
				it["hp0"] = float(it["value"])
				var f := Models.fortress(Balance.BRIDGE_HALF * 2.0, int(it["value"]))
				f.position = at + Vector3(0, 0, -FORT_BACK)
				add_child(f)
				it["node"] = f
				it["label"] = f.get_meta("label")
				_fortress = it
				_block.append(it)
				_targ.append(it)
			"stairs":
				var mults: Array = []
				for st: Dictionary in it.get("steps", []):
					mults.append(float(st.get("mult", 1.0)))
				var s := Models.stairs(mults, STAIRS_W)
				s.position = Vector3(0, 0, -float(it["d"]))
				add_child(s)
				it["node"] = s
				_stairs = it
		items.append(it)
	_build_tiles()
	_build_coins()
	_recruit_view = CrowdView.new()
	_recruit_view.name = "Recruits"
	add_child(_recruit_view)
	recruit_anim = _knight_clip()
	_recruit_view.setup(recruit_anim.mesh if recruit_anim else Models.soldier_mesh(0), 96)
	_recruit_view.set_saturation(0.0)
	# Light silver with a soft white rim: friendly-but-unjoined, never mistaken for a dark enemy.
	_recruit_view.set_tint(Color(1.05, 1.07, 1.12))
	_recruit_view.set_edge(Color(0.9, 0.95, 1.0), 1.6)
	_recruit_view.set_gait(10.0)
	if recruit_anim:
		recruit_anim.attach(_recruit_view)
		recruit_anim.play("idle", 0.0)


func _build_gate(it: Dictionary) -> void:
	it["x0"] = float(it["x"])
	it["w"] = float(it.get("w", 2.0))
	it["value"] = float(it["value"])
	it["value0"] = float(it["value"])
	it["revealed"] = not bool(it.get("hidden", false))
	var faces: Array = [[str(it["op"]), float(it["value"])]]
	if it.has("blink"):
		var b: Dictionary = it["blink"]
		faces.append([str(b.get("op", "+")), float(b.get("value", 0))])
	it["faces"] = faces
	it["face"] = 0
	var node := Models.gate(float(it["w"]))
	node.position = Vector3(float(it["x"]), 0, -float(it["d"]))
	add_child(node)
	it["node"] = node
	it["label"] = node.get_meta("label")
	_gates.append(it)
	var row := int(it.get("row", items.size()))
	if not _rows.has(row):
		_rows[row] = []
		_pick.append(it)
	(_rows[row] as Array).append(it)
	_targ.append(it)
	_style_gate(it)


func _recruit_points(it: Dictionary) -> void:
	var n := clampi(int(it.get("value", 3)), 1, 24)
	var pts := PackedVector3Array()
	var c := Vector3(float(it["x"]), 0, -float(it["d"]))
	for k in n:
		var rr := 0.26 * sqrt(k + 0.4)
		var a := k * Army.GOLDEN
		pts.append(c + Vector3(cos(a) * rr, 0, sin(a) * rr * 0.8))
	it["units"] = pts


func _build_tiles() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.tile_mesh()
	mm.instance_count = _tile_items.size()
	for i in _tile_items.size():
		var it := _tile_items[i]
		it["idx"] = i
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, 0.4 * i), Vector3(float(it["x"]), 0.02, -float(it["d"]))))
	_tiles = MultiMeshInstance3D.new()
	_tiles.name = "Tiles"
	_tiles.multimesh = mm
	var sh := Shader.new()
	sh.code = TILE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_tiles.material_override = m
	_tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tiles)


func _build_coins() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _coin_mesh()
	mm.instance_count = _coin_items.size()
	for i in _coin_items.size():
		_coin_items[i]["idx"] = i
	_coins_mm = MultiMeshInstance3D.new()
	_coins_mm.name = "Coins"
	_coins_mm.multimesh = mm
	_coins_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coins_mm)


## A minted gold coin: a polished rim (lit metal) around a glowing embossed face with a star.
func _coin_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(1.0, 0.72, 0.2)
	rim.metallic = 0.85
	rim.roughness = 0.25
	rim.emission_enabled = true
	rim.emission = Color(1.0, 0.6, 0.12)
	rim.emission_energy_multiplier = 0.45
	rim.rim_enabled = true
	rim.rim = 0.6
	var face := Mats.glow(Color(1.0, 0.86, 0.38), 1.15)
	var star := Mats.glow(Color(1.0, 0.97, 0.8), 1.5)
	var parts := [
		[Mats.cyl(0.25, 0.25, 0.07, 20, false), rim, Transform3D.IDENTITY],
		[Mats.cyl(0.19, 0.19, 0.085, 20, false), face, Transform3D.IDENTITY],
		[Mats.crystal(0.085, 0.13), star, Transform3D.IDENTITY],
	]
	for p: Array in parts:
		var st := SurfaceTool.new()
		st.append_from(p[0] as Mesh, 0, p[2] as Transform3D)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, p[1] as Material)
	return mesh


# ------------------------------------------------------------------ input

## A press only becomes the steering finger when no button took it (_unhandled_input); once it
## steers, its drags and its release are read here, before the GUI, so sliding the thumb over
## the ult or pause button keeps steering.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		# A new press is the play area's only if it reaches _unhandled_input.
		_down.erase(st.index)
		if not st.pressed and st.index == _touch_id:
			_touch_id = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touch_id == -1 and _down.has(sd.index):
			# The steering finger lifted (or a pause lost track of it): a finger still down on
			# the play area takes over from where the hero is, with no jump.
			_anchor(sd.index, sd.position.x)
			return
		if sd.index != _touch_id:
			return
		var w := maxf(get_viewport().get_visible_rect().size.x, 1.0)
		var x := _target_x0 + (sd.position.x - _touch_x0) / w * Balance.DRAG_GAIN
		target_x = clampf(x, -Balance.X_LIMIT, Balance.X_LIMIT)
		if not is_equal_approx(x, target_x):
			# Re-anchor at the rail so turning back answers at once.
			_touch_x0 = sd.position.x
			_target_x0 = target_x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_down[st.index] = true
			# Also re-anchor a press reusing the tracked index: its release was lost (paused).
			if _touch_id == -1 or st.index == _touch_id:
				_anchor(st.index, st.position.x)
				start()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		start()


func _anchor(index: int, x: float) -> void:
	_touch_id = index
	_touch_x0 = x
	_target_x0 = target_x


func _notification(what: int) -> void:
	# Paused runs get no input, so a release during the pause panel is never seen: forget the
	# tracked finger (one still held re-anchors on its next drag).
	if what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_PAUSED:
		_touch_id = -1


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if not _hints_started:
		_hints_started = true
		_emit_hints()
	var left := minf(delta, MAX_FRAME)
	while left > 0.00001:
		var dt := minf(left, SUBSTEP)
		left -= dt
		_step(dt)
	_visuals(delta)


func _step(dt: float) -> void:
	step_advance = 0.0
	var active := state == State.RUNNING or state == State.CLASH or state == State.SIEGE
	if active:
		t += dt
		_steer(dt)
	elif state == State.READY:
		_steer(dt)
	match state:
		State.RUNNING:
			_run(dt)
		State.STAIRS:
			_stairs_step(dt)
		State.WON, State.LOST:
			_end_step(dt)
	if active:
		_after_move(dt)
	# The army follows the hero in every state.
	_army_step(dt)
	if active:
		hazards.check_army(army_view, _armor > 0.0)
		hazards.step_turrets(dt, army_view)
		match state:
			State.CLASH:
				_clash(dt)
			State.SIEGE:
				_siege(dt)
		_armor = maxf(_armor - dt, 0.0)
	else:
		army_view.hold_slots(false)
	hazards.step_squads(dt, d, _foe if state == State.CLASH else {}, -d - 0.75, hx)


func _steer(dt: float) -> void:
	var k := 0.0
	if Input.is_action_pressed("ui_left"):
		k -= 1.0
	if Input.is_action_pressed("ui_right"):
		k += 1.0
	if k != 0.0:
		target_x = clampf(target_x + k * KEY_SPEED * dt, -Balance.X_LIMIT, Balance.X_LIMIT)
	if state == State.RUNNING or state == State.READY:
		hx += (target_x - hx) * (1.0 - pow(0.5, dt / Balance.STEER_HALFLIFE))


## Everything that happens after the hero moved this step (LevelSim.step order).
func _after_move(dt: float) -> void:
	_update_live()
	if _hk < _hints.size():
		_emit_hints()
	var ready_at := float((_gen.get("script", {}) as Dictionary).get("ult_ready_at", -1.0))
	if ready_at >= 0.0 and not _script_done and d >= ready_at:
		_script_done = true
		ult_points = float(ult["charge"])
		_emit_ult()
	_reveal()
	_hero_attack(dt)
	arsenal.step(dt)
	_ult_step(dt)
	_vault_check()


func _run(dt: float) -> void:
	var nd := d + Balance.RUN_SPEED * dt
	nd = _blocks(nd)
	_picks(nd)
	step_advance = -(nd - d)
	d = nd


## Squads and the fortress met before `nd`: returns how far the hero may go. A squad met clear
## of the blob stays armed until the hero passes its last rank, so swerving into the formation
## after the meet still starts the clash (LevelSim._blocks).
func _blocks(nd: float) -> float:
	for k in range(_armed.size() - 1, -1, -1):
		var a := _armed[k]
		var last := float(a["d"]) + Balance.squad_depth(float(a.get("w", 2.4)), float(a.get("value", a["hp"])))
		if not a["alive"] or d > last:
			_armed.remove_at(k)
		elif absf(hx - float(a["x"])) < blob_radius() + _hw(a):
			_armed.remove_at(k)
			_begin_clash(a)
			return d
	while _bk < _block.size():
		var it := _block[_bk]
		var meet := float(it["d"]) - Balance.CONTACT
		if meet > nd:
			break
		_bk += 1
		if not it["alive"]:
			continue
		if str(it["kind"]) == "fortress":
			_begin_siege(it)
			return maxf(d, meet)
		if absf(hx - float(it["x"])) < blob_radius() + _hw(it):
			_begin_clash(it)
			return maxf(d, meet)
		_armed.append(it)
	return nd


## Tiles, coins, recruits and gate rows the hero crosses up to `nd`.
func _picks(nd: float) -> void:
	while _pk < _pick.size():
		var it := _pick[_pk]
		if float(it["d"]) > nd:
			break
		_pk += 1
		var kind := str(it["kind"])
		if kind == "gate":
			_gate_row(it)
			continue
		if not it["alive"]:
			continue
		var pad := Balance.RECRUIT_PAD if kind == "recruits" else Balance.PICKUP_PAD
		if absf(float(it["x"]) - hx) > blob_radius() + pad:
			continue
		it["alive"] = false
		match kind:
			"tile":
				_take_tile(it)
			"coin":
				_take_coin(it)
			"recruits":
				_take_recruits(it)


func _emit_hints() -> void:
	while _hk < _hints.size():
		var h: Dictionary = _hints[_hk]
		if float(h.get("d", 0.0)) > d:
			break
		_hk += 1
		hint.emit(str(h.get("key", "")))


# ------------------------------------------------------------------ pickups

func _take_tile(it: Dictionary) -> void:
	_tiles.multimesh.set_instance_transform(int(it["idx"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -10, 0)))
	var at := Vector3(float(it["x"]), 0.15, -float(it["d"]))
	_change_army(1, at, Vector3(0.1, 0.0, 0.1))
	_charge(1.0)
	var now := Time.get_ticks_msec()
	_tile_streak = mini(_tile_streak + 1, 14) if now - _tile_ms < int(TILE_STREAK * 1000.0) else 0
	_tile_ms = now
	Audio.note(_tile_streak, -9.0)
	juice.haptic("tile")
	juice.popup("+1", at + Vector3(0, 0.6, 0), Color.WHITE, 0.7)
	effects.burst(at + Vector3(0, 0.1, 0), Color(0.5, 0.85, 1.0), 6, 1.8, 0.06, 0.3, -3.0)


func _take_coin(it: Dictionary) -> void:
	_coins_mm.multimesh.set_instance_transform(int(it["idx"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -10, 0)))
	coins += 1
	coins_changed.emit(coins)
	effects.coin_pop(Vector3(float(it["x"]), 0.55, -float(it["d"])))
	Audio.play("coin", -9.0, 0.15)


func _take_recruits(it: Dictionary) -> void:
	var n := int(it.get("value", 3))
	var pts: PackedVector3Array = it.get("units", PackedVector3Array())
	var before := army
	army += n
	var room := mini(army, _max_shown) - army_view.shown
	if room > 0:
		var src := PackedVector3Array()
		for k in mini(room, pts.size()):
			src.append(pts[k])
		army_view.grow_from(src)
		if room > pts.size():
			army_view.grow(room - pts.size(), Vector3(float(it["x"]), 0, -float(it["d"])))
	_army_changed(before)
	_charge(float(n))
	var at := Vector3(float(it["x"]), 1.0, -float(it["d"]))
	_side_popup("+%d" % n, at, GAIN, 0.9)
	effects.burst(at, Color(0.85, 0.9, 1.0), 14, 2.2, 0.07, 0.45, -3.0)
	Audio.play("recruit", -4.0)
	juice.haptic("gate_good")


# ------------------------------------------------------------------ gates

## The [op, value] a gate shows now.
func _gate_face(it: Dictionary) -> Array:
	var faces: Array = it["faces"]
	return faces[int(it.get("face", 0))]


func _update_live() -> void:
	hazards.update_live(t)
	var lo := maxi(_tk - 2, 0)
	for i in range(lo, _targ.size()):
		var it := _targ[i]
		if float(it["d"]) > d + VIEW_AHEAD:
			break
		if str(it["kind"]) != "gate":
			continue
		if it.has("move"):
			var m: Dictionary = it["move"]
			it["x"] = float(it["x0"]) + float(m.get("amp", 0.0)) * sin(TAU * t / maxf(float(m.get("period", 2.0)), 0.1) + float(m.get("phase", 0.0)))
			if it["alive"]:
				(it["node"] as Node3D).position.x = float(it["x"])
		if it.has("blink"):
			var period := maxf(float((it["blink"] as Dictionary).get("period", 1.0)), 0.05)
			var face := int(floor(t / period)) % 2
			if face != int(it["face"]):
				it["face"] = face
				_sync_face(it)
				_style_gate(it)


## Copies the shown face into the item's live op/value (the bot reads them).
func _sync_face(it: Dictionary) -> void:
	var f := _gate_face(it)
	it["op"] = str(f[0])
	it["value"] = float(f[1])
	if it.has("blink") and int(it["face"]) == 1:
		(it["blink"] as Dictionary)["op"] = str(f[0])
		(it["blink"] as Dictionary)["value"] = float(f[1])


func _reveal() -> void:
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		var gd := float(it["d"])
		if gd > d + Balance.REVEAL_DIST:
			break
		if str(it["kind"]) == "gate" and not bool(it["revealed"]) and gd >= d:
			_reveal_gate(it)


func _reveal_gate(it: Dictionary) -> void:
	it["revealed"] = true
	var node := it["node"] as Node3D
	Models.gate_hit(node, 1.0)
	effects.flash(node.global_position + Vector3(0, 1.1, 0.1), Color(0.9, 0.95, 1.0), 1.4, 0.25)
	Audio.play("upgrade", -12.0, 0.1)


func _gate_text(op: String, v: float) -> String:
	match op:
		"+":
			return "+%d" % int(round(v))
		"-":
			return "−%d" % int(round(v))
		"x":
			return "×%s" % _num(v)
		"/":
			return "÷%s" % _num(v)
		"arm":
			var tier: Dictionary = Balance.ARM_TIERS[clampi(int(v), 0, Balance.ARM_TIERS.size() - 1)]
			return Loc.t(str(tier["name"]))
		"rate":
			return Loc.t("POWER_RATE") % int(round(v))
		"dmg":
			return Loc.t("POWER_DMG") % int(round(v))
		"multi":
			return Loc.t("POWER_MULTI")
		"charge":
			return "−%d" % ceili(-v)
		"ult":
			return Loc.t("ULT")
	return "?"


static func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else String.num(v, 1)


## Forecast of the army after a plain army gate (LevelSim._forecast).
func _forecast(op: String, v: float) -> int:
	match op:
		"+":
			return army + int(round(v))
		"-":
			return maxi(army - int(round(v)), 0)
		"x":
			return int(round(army * v))
		"/":
			return int(floor(army / maxf(v, 1.0)))
		"charge":
			return maxi(army + int(round(v)), 0) if v < 0.0 else army
	return army


## Restyles a gate when what it shows changed (text, forecast, kind).
func _style_gate(it: Dictionary) -> void:
	var node := it["node"] as Node3D
	var f := _gate_face(it)
	var op := str(f[0])
	var v := float(f[1])
	var text := _gate_text(op, v)
	var sub := ""
	var kind := "good"
	var icon := ""
	match op:
		"+", "x":
			kind = "good"
			sub = "→ %d" % _forecast(op, v)
		"-", "/":
			kind = "bad"
			sub = "→ %d" % _forecast(op, v)
		"charge":
			kind = "charge"
			sub = "→ " + _reward_text(it)
		"arm":
			kind = "arm"
			icon = "crossbow" if int(v) <= 1 else "blaster"
		"rate", "dmg", "multi":
			kind = "power"
			icon = op
			# "+30% швидкість": the number goes big, the word into the pill under it.
			var cut := text.find(" ")
			if cut > 0:
				sub = text.substr(cut + 1)
				text = text.substr(0, cut)
		"weapon":
			kind = "power"
			var wk := _reward_weapon(it)
			text = Loc.t(str((Balance.WEAPONS[wk] as Dictionary)["name"])) if Balance.WEAPONS.has(wk) else "?"
			icon = wk
		"ult":
			kind = "power"
			icon = "star"
	if not bool(it["revealed"]):
		kind = "hidden"
		text = ""
		sub = ""
		icon = ""
	if not it["alive"]:
		kind = "closed"
		sub = ""
	var key := "%s|%s|%s|%s" % [text, sub, kind, icon]
	if str(it.get("_style", "")) == key:
		return
	it["_style"] = key
	Models.gate_style(node, text, sub, kind, icon)
	if kind == "charge":
		Models.gate_charge(node, 1.0 - v / minf(float(it["value0"]), -0.001))


func _reward_weapon(it: Dictionary) -> String:
	var rw: Dictionary = it.get("reward", {})
	return str(rw.get("weapon", it.get("weapon", "ballista")))


func _reward_text(it: Dictionary) -> String:
	var rw: Dictionary = it.get("reward", {})
	var op := str(rw.get("op", "+"))
	match op:
		"weapon":
			var wk := _reward_weapon(it)
			return Loc.t(str((Balance.WEAPONS[wk] as Dictionary)["name"])) if Balance.WEAPONS.has(wk) else "?"
		"ult":
			return Loc.t("ULT")
	return _gate_text(op, float(rw.get("value", 0)))


## The hero crosses a gate row: the gate holding the hero applies, the rest fold.
func _gate_row(first: Dictionary) -> void:
	var row := int(first.get("row", -1))
	var gates: Array = _rows.get(row, [first])
	var chosen: Dictionary = {}
	for g: Dictionary in gates:
		if not g["alive"]:
			continue
		if absf(hx - float(g["x"])) <= float(g["w"]) * 0.5:
			chosen = g
	for g: Dictionary in gates:
		g["alive"] = false
		if g != chosen:
			_style_gate(g)
		_retract_gate(g)
	if chosen.is_empty():
		Audio.play("whoosh_gate", -12.0, 0.1)
		return
	var f := _gate_face(chosen)
	_pass_gate(chosen, str(f[0]), float(f[1]))


func _pass_gate(it: Dictionary, op: String, v: float) -> void:
	var node := it["node"] as Node3D
	var gx := float(it["x"])
	var at := Vector3(gx, 1.1, -float(it["d"]))
	var from := Vector3(gx, 0.4, -float(it["d"]) - 0.1)
	var spread := Vector3(float(it["w"]) * 0.4, 0.8, 0.1)
	var before := army
	var good := true
	var popup := ""
	var pcol := GAIN
	match op:
		"+":
			_change_army(int(round(v)), from, spread)
			_charge(minf(v, 15.0))
			popup = "+%d" % int(round(v))
		"-":
			_change_army(-mini(int(round(v)), army), from, spread)
			good = v <= 0.0
			popup = "−%d" % int(round(v))
			pcol = LOSS
		"x":
			var add := int(round(army * v)) - army
			_change_army(add, from, spread)
			_charge(minf(float(add), 15.0))
			popup = "×%s" % _num(v)
			pcol = GOLD
		"/":
			_change_army(int(floor(army / maxf(v, 1.0))) - army, from, spread)
			good = false
			popup = "÷%s" % _num(v)
			pcol = LOSS
		"charge":
			if v < 0.0:
				_change_army(-mini(int(round(-v)), army), from, spread)
				good = false
				popup = "−%d" % int(round(-v))
				pcol = LOSS
			else:
				var rw: Dictionary = it.get("reward", {})
				_pass_gate(it, str(rw.get("op", "+")), float(rw.get("value", 0)))
				return
		"arm":
			var tier := clampi(int(v), 0, Balance.ARM_TIERS.size() - 1)
			if tier > arm_tier:
				arm_tier = tier
				show_arm_tier()
				effects.shockwave(Vector3(hx, 0, -d + 1.5), Color(0.1, 0.9, 0.75), 2.6)
				var e: Array = TIER_EDGE[clampi(arm_tier, 0, TIER_EDGE.size() - 1)]
				effects.burst(Vector3(hx, 0.8, -d + 1.5), e[2] as Color, 30, 3.2, 0.08, 0.6, -4.0)
				power_changed.emit("arm", float(arm_tier))
			popup = ""      # the HUD's pill toast says it
		"rate":
			power["rate"] = float(power["rate"]) + v / 100.0
			power_changed.emit("rate", float(power["rate"]))
			popup = ""
		"dmg":
			power["dmg"] = int(power["dmg"]) + int(round(v))
			power_changed.emit("dmg", float(power["dmg"]))
			popup = ""
		"multi":
			power["multi"] = int(power["multi"]) + int(round(v))
			power_changed.emit("multi", float(power["multi"]))
			popup = ""
		"weapon":
			_give_weapon(_reward_weapon(it), at)
			popup = ""
		"ult":
			ult_points = float(ult["charge"])
			_emit_ult()
			popup = Loc.t("ULT") + "!"
			pcol = Color(0.8, 0.6, 1.0)
	# Juice: the chosen gate flares, then folds with the rest of the row.
	var col := Color(0.45, 0.8, 1.0) if good else Color(1.0, 0.35, 0.3)
	Models.gate_hit(node, 1.0)
	effects.flash(at, col, 2.2, 0.3)
	effects.shockwave(Vector3(gx, 0.0, at.z), col, 1.6)
	effects.burst(at, col.lerp(Color.WHITE, 0.3), 26, 3.4, 0.08, 0.55, -4.0)
	if popup != "":
		# Above the army counter (which rides over the hero right at the gate).
		juice.popup(popup, at + Vector3(0, 1.6, -0.3), pcol, 1.25)
	if good:
		var gain := maxf(float(army - before), 0.0)
		Audio.chord(clampi(int(round(gain / maxf(float(before), 1.0) * 6.0)), 0, 9), true)
		Audio.play("whoosh_gate", -6.0)
		juice.haptic("gate_good")
	else:
		Audio.chord(clampi(int(round(float(before - army) / maxf(float(before), 1.0) * 6.0)), 0, 9), false)
		Audio.play("leak", -6.0)
		juice.haptic("gate_bad")
		juice.add_trauma(0.18)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3(1.12, 1.12, 1.12), 0.07)
	tw.tween_property(node, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	tw.tween_callback(func() -> void: _style_gate(it))


## A passed gate retracts into the bridge once the army is through, so folded frames never
## loom huge in the foreground.
func _retract_gate(it: Dictionary) -> void:
	var node := it.get("node") as Node3D
	if node == null or not node.is_inside_tree():
		return
	var through := (Balance.HERO_GAP + 2.0 * _radius_vis * Balance.BLOB_STRETCH) / Balance.RUN_SPEED
	var tw := node.create_tween()
	tw.tween_interval(0.12 + through * 0.3)
	tw.tween_property(node, "position:y", -3.4, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.hide)


## A hero hit (or a storm tick) on a gate: + grows, - shrinks, rate grows, charge fills and
## flips to its reward. Reveals a hidden gate.
func _hit_gate(it: Dictionary, dmg: float) -> void:
	if not it["alive"]:
		return
	var was_hidden := not bool(it["revealed"])
	it["revealed"] = true
	var node := it["node"] as Node3D
	var f := _gate_face(it)
	var op := str(f[0])
	var v := float(f[1])
	Models.gate_hit(node, 0.7)
	if was_hidden:
		_reveal_gate(it)
	if not Balance.GATE_HIT_GAIN.has(op):
		_style_gate(it)
		return
	var gain := float(Balance.GATE_HIT_GAIN[op]) * dmg
	var top := Vector3(float(it["x"]), 2.0, -float(it["d"]) + 0.1)
	match op:
		"-":
			v = maxf(v - gain, 0.0)
			juice.popup("−%s" % _num(gain), top, GAIN, 0.6)
		"charge":
			v += gain
			if v >= 0.0:
				var rw: Dictionary = it.get("reward", {})
				op = str(rw.get("op", "+"))
				v = float(rw.get("value", 0))
				if op == "weapon" or op == "ult":
					v = 1.0
				effects.shockwave(Vector3(float(it["x"]), 0.0, -float(it["d"])), Color(0.75, 0.45, 1.0), 2.2)
				effects.flash(top, Color(0.85, 0.6, 1.0), 2.6, 0.35)
				juice.popup(_gate_text(op, v) if op != "weapon" else Loc.t("NEW_WEAPON"), top + Vector3(0, 0.6, 0), GOLD, 1.2)
				Audio.chord(6, true, -8.0)
				Audio.play("upgrade", -4.0)
				juice.haptic("gate_good")
		_:
			v += gain
			juice.popup("+%s" % _num(gain), top, GAIN, 0.6)
	f[0] = op
	f[1] = v
	_sync_face(it)
	_style_gate(it)
	var l := it["label"] as Label3D
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.22, 0.04)
	tw.tween_property(l, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gates in view whose forecast depends on the army get their numbers refreshed.
func _restyle_gates() -> void:
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		if float(it["d"]) > d + VIEW_AHEAD:
			break
		if str(it["kind"]) == "gate" and it["alive"]:
			_style_gate(it)


# ------------------------------------------------------------------ army

func _army_center() -> Vector3:
	return Vector3(hx, 0.0, -d + Balance.HERO_GAP + _radius_vis * Balance.BLOB_STRETCH)


## Army changed by `delta_n` (gates, tiles, geodes, clashes). Newcomers fly from `from`.
func _change_army(delta_n: int, from := Vector3.INF, spread := Vector3(0.4, 0.0, 0.2), kill := "random") -> void:
	var before := army
	army = maxi(army + delta_n, 0)
	var want := mini(army, _max_shown)
	if want > army_view.shown:
		if from == Vector3.INF:
			army_view.fit(want)
		else:
			army_view.grow(want - army_view.shown, from, spread)
	elif want < army_view.shown:
		var n := army_view.shown - want
		if kill == "front":
			army_view.kill_front(n)
		else:
			army_view.kill_random(n, Vector3(0, 0, 1.0))
	_army_changed(before)


func _army_changed(before: int) -> void:
	if army == before:
		return
	_peak = maxi(_peak, army)
	army_changed.emit(army)
	juice.counter(_army_label, army)
	_restyle_gates()


## Soldiers per drawn unit.
func _weight() -> float:
	return maxf(float(army) / maxf(float(army_view.shown), 1.0), 1.0)


## Units `idxs` touched a hazard `it` (spikes or a blade) and die; a barricade loses one hp per
## soldier and stops killing at 0.
func hazard_kills(it: Dictionary, idxs: PackedInt32Array, push: Vector3) -> void:
	if army <= 0:
		return
	var w := _weight()
	var arr: Array = Array(idxs)
	arr.sort()
	arr.reverse()
	var killed := 0
	var spikes := str(it["kind"]) == "barricade"
	for i: int in arr:
		if spikes and float(it["hp"]) <= 0.0:
			break
		if spikes:
			it["hp"] = float(it["hp"]) - w
		_loss_acc += w
		hazard_deaths += w
		army_view.kill(i, push + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.4, 0.4)))
		killed += 1
	if killed == 0:
		return
	var before := army
	var lost := int(floor(_loss_acc + 0.0001))
	_loss_acc -= lost
	army = maxi(army - lost, 0)
	army_view.fit(mini(army, _max_shown))
	_army_changed(before)
	var at := Vector3(float(it["x"]), 1.2, -float(it["d"]))
	if spikes:
		Audio.play("spikes", -9.0, 0.15)
		juice.haptic("barricade")
		juice.add_trauma(0.06)
		hazards.on_hit(it, at)
		if float(it["hp"]) <= 0.0 and it["alive"]:
			_destroy(it)
	else:
		Audio.play("blade", -8.0, 0.15)
		juice.add_trauma(0.08)
		juice.haptic("barricade")
	_loss_popup(it, before - army, at)


## A popup next to the army instead of on top of its counter (which rides over the hero):
## anything spawning near the hero is moved out to its own side of the hero.
func _side_popup(text: String, at: Vector3, color: Color, size := 1.0) -> int:
	var near := absf(at.x - hx) < 1.25 and at.z > -d - 2.5 and at.z < -d + 3.0
	if near:
		var side := signf(at.x - hx)
		if side == 0.0:
			side = -1.0 if hx > 0.0 else 1.0
		at.x = clampf(hx + side * 1.45, -2.9, 2.9)
		if absf(at.x - hx) < 1.0:
			at.x = hx - side * 1.45
		at.y = maxf(at.y, 1.3)
	return juice.popup(text, at, color, size)


## One running total per hazard: while a squeeze goes on, its popup counts up in place
## ("−3" → "−7" → "−12") with a punch on each step instead of stacking a column of numbers.
func _loss_popup(it: Dictionary, n: int, at: Vector3) -> void:
	if n <= 0:
		return
	var id := "%s%.2f" % [str(it["kind"]), float(it["d"])]
	var acc: Array = _pop_cd.get(id, [0, -1, ""])
	var total := int(acc[0]) + n
	var text := "−%d" % total
	if not juice.bump(int(acc[1]), str(acc[2]), text):
		total = n
		text = "−%d" % total
		acc[1] = _side_popup(text, at, LOSS, 0.95)
	acc[0] = total
	acc[2] = text
	_pop_cd[id] = acc


## A turret shot reached the army: one soldier falls (armour shrugs it off).
func turret_hit(_it: Dictionary, at: Vector3) -> void:
	if _armor > 0.0:
		effects.hit_spark(at, EMERALD)
		return
	if army <= 0 or not (state == State.RUNNING or state == State.CLASH or state == State.SIEGE):
		return
	var before := army
	army -= 1
	hazard_deaths += 1.0
	var i := army_view.nearest(at, 1.2)
	if army_view.shown > mini(army, _max_shown) and i >= 0:
		army_view.kill(i, Vector3(randf_range(-1, 1), 0, 1.4))
	army_view.fit(mini(army, _max_shown))
	_army_changed(before)
	juice.add_trauma(0.04)


func _army_step(dt: float) -> void:
	var r := blob_radius()
	_radius_vis += (r - _radius_vis) * (1.0 - exp(-5.0 * dt))
	army_view.radius = _radius_vis
	var old := army_view.center
	if state == State.READY or state == State.RUNNING or state == State.CLASH or state == State.SIEGE:
		army_view.center = _army_center()
	var adv := army_view.center.z - old.z
	if state == State.RUNNING:
		adv = step_advance
	army_view.marching = state == State.RUNNING or state == State.STAIRS
	if state != State.STAIRS and state != State.WON:
		var solids := hazards.solids(army_view.center.z, 6.0)
		solids.append_array(arsenal.solids())
		for g in _gate_solids():
			solids.append(g)
		army_view.set_solids(solids)
	army_view.step(dt, adv)


## Gate pylons of the rows near the army (the blob parts around them).
func _gate_solids() -> Array:
	var out: Array = []
	var cz := army_view.center.z
	for i in range(maxi(_tk - 6, 0), _targ.size()):
		var it := _targ[i]
		var gz := -float(it["d"])
		if gz < cz - 6.0:
			break
		if str(it["kind"]) != "gate" or gz > cz + 6.0:
			continue
		var gx := float(it["x"])
		var hw := float(it["w"]) * 0.5
		out.append([Vector3(gx - hw, 0, gz), 0.16])
		out.append([Vector3(gx + hw, 0, gz), 0.16])
	return out


# ------------------------------------------------------------------ targeting and damage

## Half span used for corridor / overlap tests (LevelSim._index).
func _hw(it: Dictionary) -> float:
	match str(it["kind"]):
		"gate", "squad", "barricade":
			return float(it.get("w", 2.0)) * 0.5
		"turret":
			return 0.45
		"geode":
			return 0.6
		"crate":
			return 0.55
		"fortress":
			return Balance.BRIDGE_HALF
	return 0.3


## Up to `count` live targets ahead (nearest first) whose span is within `lateral` of `x`.
func targets(x: float, lateral: float, reach: float, count: int, gates: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var near := d - 0.5
	var far := d + reach
	while _tk < _targ.size() and float(_targ[_tk]["d"]) < d - 2.0:
		_tk += 1
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		var di := float(it["d"])
		if di < near:
			continue
		if di > far:
			break
		if not it["alive"]:
			continue
		if str(it["kind"]) == "gate":
			if not gates or di < d:
				continue
			var f := _gate_face(it)
			if bool(it["revealed"]) and not Balance.GATE_HIT_GAIN.has(str(f[0])):
				continue
		if absf(float(it["x"]) - x) > lateral + _hw(it):
			continue
		out.append(it)
		if out.size() >= count:
			break
	return out


## The nearest squad (blasters: or turret / barricade / fortress) ahead in volley range.
func volley_target(reach: float, structures: bool) -> Dictionary:
	var r := blob_radius()
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		var di := float(it["d"])
		if di < d - 1.0:
			continue
		if di > d + reach:
			break
		if not it["alive"]:
			continue
		var k := str(it["kind"])
		var ok := k == "squad" or (structures and (k == "turret" or k == "barricade" or k == "fortress"))
		if ok and absf(float(it["x"]) - hx) <= r + _hw(it) + 1.0:
			return it
	return {}


## Where shots at `it` land.
func aim_point(it: Dictionary) -> Vector3:
	match str(it["kind"]):
		"squad":
			return hazards.squad_point(it) + Vector3(0, 0.45, 0)
		"gate":
			return Vector3(float(it["x"]), 1.2, -float(it["d"]) + 0.05)
		"fortress":
			return Vector3(clampf(hx, -1.4, 1.4), 1.4, -float(it["d"]) + 0.5)
		"turret":
			return Vector3(float(it["x"]), 1.05, -float(it["d"]))
		"crate":
			return Vector3(float(it["x"]), 0.75, -float(it["d"]) + 0.2)
	return Vector3(float(it["x"]), 0.6, -float(it["d"]) + 0.1)


## Damages `it` by `n` (squads: enemies killed; gates: a hero hit). Returns the damage dealt.
func hurt(it: Dictionary, n: float, _source := "") -> float:
	if it.is_empty() or not it["alive"] or n <= 0.0:
		return 0.0
	var kind := str(it["kind"])
	if kind == "gate":
		_hit_gate(it, n)
		return n
	var dealt := minf(n, float(it["hp"]))
	it["hp"] = float(it["hp"]) - dealt
	if kind == "squad":
		_charge(dealt)
	var at := aim_point(it)
	if float(it["hp"]) <= 0.001:
		it["hp"] = 0.0
		if kind == "squad":
			hazards.squad_losses(it)
		_destroy(it)
	elif kind == "fortress":
		_fortress_hit(it, at)
	else:
		hazards.on_hit(it, at)
	return dealt


func _destroy(it: Dictionary) -> void:
	if not it["alive"]:
		return
	it["alive"] = false
	var kind := str(it["kind"])
	var at := Vector3(float(it["x"]), 0.5, -float(it["d"]))
	match kind:
		"fortress":
			_win()
			return
		"squad":
			juice.add_trauma(0.15)
			Audio.play("death", -8.0, 0.1)
		"barricade":
			juice.hitstop(0.04)
			juice.add_trauma(0.35)
			juice.haptic("hit_big")
		"turret":
			juice.add_trauma(0.25)
			juice.haptic("hit_big")
		"geode":
			_geode_reward(it, at)
			juice.add_trauma(0.15)
		"crate":
			juice.hitstop(0.05)
			juice.add_trauma(0.3)
			_give_weapon(str(it.get("weapon", "ballista")), at)
	hazards.on_destroy(it)


func _geode_reward(it: Dictionary, at: Vector3) -> void:
	var amount := int(it.get("amount", 0))
	match str(it.get("reward", "army")):
		"army":
			_change_army(amount, at + Vector3(0, 0.5, 0), Vector3(0.5, 0.6, 0.4))
			_charge(float(amount))
			juice.popup("+%d" % amount, at + Vector3(0, 1.4, 0), GAIN, 1.1)
			Audio.chord(4, true, -8.0)
		"coins":
			coins += amount
			coins_changed.emit(coins)
			for k in mini(amount, 8):
				effects.coin_pop(at + Vector3(randf_range(-0.5, 0.5), 0.6, randf_range(-0.3, 0.3)))
			juice.popup("+%d" % amount, at + Vector3(0, 1.4, 0), GOLD, 1.1)
			Audio.play("coin", -3.0)
		"ult":
			_charge(float(amount))
			juice.popup("+%d" % amount, at + Vector3(0, 1.4, 0), Color(0.8, 0.6, 1.0), 1.1)
			effects.flash(hero.muzzle(), Color(0.75, 0.5, 1.0), 1.6, 0.3)


## A weapon from a crate or a charge gate: a new machine, or a level up.
func _give_weapon(kind: String, at: Vector3) -> void:
	if not Balance.WEAPONS.has(kind):
		kind = "ballista"
	var res := arsenal.add(kind, Vector3(at.x, 0.0, at.z))
	weapons = arsenal.summary()
	weapon_added.emit(str(res[0]), int(res[1]))
	juice.haptic("weapon")
	Audio.play("weapon_get", -3.0)


# ------------------------------------------------------------------ hero

func _hero_rate() -> float:
	return float(def["rate"]) * Balance.power_mult(int(Save.upgrades["power"])) * (1.0 + float(power["rate"]))


func _hero_damage() -> int:
	return int(def["damage"]) + int(power["dmg"])


func _hero_attack(dt: float) -> void:
	_atk_cd -= dt
	if _atk_cd > 0.0:
		return
	var shots := 1 + int(power["multi"])
	var corridor := float(def.get("corridor", Balance.CORRIDOR))
	var list := targets(hx, corridor, float(def["range"]), shots, true)
	if list.is_empty():
		_atk_cd = 0.0
		return
	_atk_cd += 1.0 / _hero_rate()
	_atk_cd = maxf(_atk_cd, 0.02)
	hero.strike()
	var dmg := _hero_damage()
	for k in shots:
		var it: Dictionary = list[mini(k, list.size() - 1)]
		if not it["alive"]:
			continue
		var at := aim_point(it)
		_shot_fx(at, k)
		var kind := str(it["kind"])
		if kind == "squad":
			hurt(it, float(dmg + int(def["splash"])), "hero")
		else:
			hurt(it, float(dmg), "hero")
		if kind == "fortress":
			juice.add_trauma(0.08)


func _shot_fx(at: Vector3, k: int) -> void:
	var from := hero.muzzle() + Vector3(0.18 * k, 0, 0)
	if hero_type == "bolt":
		effects.lightning([from, from.lerp(at, 0.5) + Vector3(randf_range(-0.3, 0.3), 0.3, 0), at], Color(0.55, 0.85, 1.0), 0.14, 0.06, false)
		effects.hit_spark(at, Color(0.65, 0.9, 1.0))
		effects.muzzle(from, Color(0.6, 0.9, 1.0))
		Audio.play("tesla", -15.0, 0.25)
	else:
		effects.projectile(from, at, "plasma", from.distance_to(at) / 26.0, Callable())
		effects.shockwave(Vector3(at.x, 0.0, at.z), Color(0.35, 1.0, 0.55), 1.1)
		effects.burst(at, Color(0.45, 1.0, 0.6), 10, 2.6, 0.09, 0.4, -6.0)
		Audio.play("cannon", -11.0, 0.2)


## Hops over hazards the hero crosses (it is immune to them).
func _vault_check() -> void:
	while _vk < _vaults.size() and float(_vaults[_vk]["d"]) - 0.35 <= d:
		var it := _vaults[_vk]
		_vk += 1
		var wide := str(it.get("type", "")) == "sweeper"
		var reach := 99.0 if wide else _hw(it) + (float(it.get("len", 0.0)) if str(it["kind"]) == "blade" else 0.0) + 0.35
		var x := float(it.get("x0", it["x"]))
		if (it["alive"] or str(it["kind"]) == "blade") and absf(hx - x) < reach:
			hero.vault()


# ------------------------------------------------------------------ ult

func _charge(points: float) -> void:
	if _ult_left > 0.0 or _quake_wave < 99:
		return
	ult_points = minf(ult_points + maxf(points, 0.0), float(ult["charge"]))
	_emit_ult()


func _emit_ult() -> void:
	var ratio := clampf(ult_points / float(ult["charge"]), 0.0, 1.0)
	if _ult_left > 0.0 or _quake_wave < 99:
		ratio = 0.0
	var ready := ult_ready()
	var now := Vector2(snappedf(ratio, 0.001), 1.0 if ready else 0.0)
	if now == _last_ult:
		return
	_last_ult = now
	ult_changed.emit(ratio, ready)
	hero.set_charge(ratio, ready)


func use_ult() -> bool:
	if not ult_ready() or not (state == State.READY or state == State.RUNNING or state == State.CLASH or state == State.SIEGE):
		return false
	start()
	ult_points = 0.0
	_ult_tick = 0.0
	juice.hitstop(0.07)
	juice.haptic("ult")
	if hero_type == "bolt":
		_ult_left = float(ult["duration"])
		hero.cast_ult(_ult_left)
		effects.flash(hero.muzzle(), Color(0.6, 0.9, 1.0), 2.4, 0.35)
		effects.shockwave(Vector3(hx, 0.0, -d), Color(0.5, 0.8, 1.0), 3.0)
		juice.add_trauma(0.55)
		Audio.play("tesla", 0.0)
	else:
		_quake_d = d
		_quake_wave = 0
		_ult_tick = 0.43
		_armor = float(ult.get("armor_time", 6.0))
		hero.cast_ult(1.6)
		juice.add_trauma(0.8)
		effects.shockwave(Vector3(hx, 0.0, -d), EMERALD, 3.2)
		Audio.play("explosion", -2.0)
	_emit_ult()
	return true


func _ult_step(dt: float) -> void:
	if _ult_left > 0.0:
		_ult_left -= dt
		_ult_tick -= dt
		while _ult_tick <= 0.0 and _ult_left > -dt:
			_ult_tick += float(ult["tick"])
			_storm_tick()
		if _ult_left <= 0.0:
			_ult_left = 0.0
			_emit_ult()
	elif _quake_wave < 99:
		_ult_tick -= dt
		var waves := int(ult["waves"])
		var spacing := float(ult["spacing"])
		while _ult_tick <= 0.0 and _quake_wave < waves:
			_ult_tick += float(ult["gap"])
			var near := _quake_d + 1.0 + spacing * _quake_wave
			_quake_wave_fx(near, spacing)
			_ult_hit(near - 0.5, near + spacing, false)
			_quake_wave += 1
		if _quake_wave >= waves:
			_quake_wave = 99
			_emit_ult()


func _storm_tick() -> void:
	var bolts := 5 if quality_high else 3
	effects.ring(Vector3(hx, 0.05, -d), Color(0.45, 0.75, 1.0), 3.0, 0.3)
	for it in _ult_targets(d - 0.5, d + float(ult["range"])):
		if bolts > 0:
			bolts -= 1
			var at := aim_point(it)
			effects.lightning([at + Vector3(randf_range(-0.6, 0.6), 7.0, 0), at + Vector3(randf_range(-0.3, 0.3), 2.5, 0), at], Color(0.55, 0.85, 1.0), 0.2, 0.07, false)
			effects.hit_spark(at, Color(1.0, 0.9, 0.5))
	# The storm rages even with nothing to hit: spare bolts strike the bridge ahead of the army.
	for k in mini(bolts, 3):
		var at2 := Vector3(randf_range(-2.8, 2.8), 0.05, -d - randf_range(2.5, float(ult["range"])))
		effects.lightning([at2 + Vector3(randf_range(-0.8, 0.8), 8.0, 0), at2 + Vector3(randf_range(-0.4, 0.4), 3.0, 0), at2 + Vector3(randf_range(-0.2, 0.2), 1.2, 0), at2], Color(0.6, 0.88, 1.0), 0.3, 0.1, false)
		effects.flash(at2 + Vector3(0, 0.3, 0), Color(0.6, 0.85, 1.0), 1.6, 0.22)
		effects.shockwave(at2, Color(0.5, 0.8, 1.0), 1.1)
		effects.burst(at2 + Vector3(0, 0.2, 0), Color(0.75, 0.92, 1.0), 10, 3.0, 0.06, 0.35, -6.0)
	_ult_hit(d - 0.5, d + float(ult["range"]), true)
	Audio.play("tesla", -7.0, 0.2)
	juice.add_trauma(0.12)


func _ult_targets(a: float, b: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		var di := float(it["d"])
		if di > b:
			break
		if di >= a and it["alive"]:
			out.append(it)
	return out


func _ult_hit(a: float, b: float, gates: bool) -> void:
	for it in _ult_targets(a, b):
		match str(it["kind"]):
			"squad":
				hurt(it, float(ult["kills"]), "ult")
			"gate":
				if gates and float(it["d"]) >= d:
					_hit_gate(it, float(_hero_damage()))
			_:
				hurt(it, float(ult["breaks"]), "ult")


func _quake_wave_fx(near: float, spacing: float) -> void:
	var pts: Array[Vector3] = []
	var zc := -(near + spacing * 0.5)
	for k in 9:
		pts.append(Vector3(-Balance.BRIDGE_HALF + 0.4 + k * (Balance.BRIDGE_HALF * 2.0 - 0.8) / 8.0, 0.0, zc + randf_range(-0.6, 0.6)))
	effects.crystal_spikes(pts, Vector3(hx, 0, -_quake_d + 2.0), Color(0.12, 0.85, 0.4))
	effects.shockwave(Vector3(hx * 0.5, 0.0, zc), EMERALD, 2.4)
	juice.add_trauma(0.3 if _quake_wave == 0 else 0.18)
	Audio.play("explosion" if _quake_wave == 0 else "cannon", -3.0 if _quake_wave == 0 else -6.0, 0.15)


# ------------------------------------------------------------------ clash and siege

func _begin_clash(it: Dictionary) -> void:
	state = State.CLASH
	_foe = it
	_tick = 0.0
	army_view.mode = Army.Mode.CHARGE
	army_view.charge_z = -d - 0.2
	army_view.charge_x = float(it["x"])
	army_view.charge_half = minf(float(it.get("w", 2.4)) * 0.5 + 0.4, 2.2)
	Audio.play("brawl", -6.0, 0.1)
	juice.add_trauma(0.25)
	juice.haptic("hit_big")


func _end_clash() -> void:
	state = State.RUNNING
	_foe = {}
	army_view.mode = Army.Mode.FOLLOW


## Clash with a squad: both sides fall one for one, faster in big fights (LevelSim._clash).
func _clash(dt: float) -> void:
	if _foe.is_empty() or not _foe["alive"]:
		_end_clash()
		return
	_tick -= dt
	while _tick <= 0.0 and state == State.CLASH:
		_tick += Balance.FIGHT_TICK
		var foes := float(_foe["hp"])
		if army >= 1:
			var hit := mini(_burst(mini(army, ceili(foes))), mini(army, ceili(foes)))
			_change_army(-hit, Vector3.INF, Vector3.ZERO, "front")
			hurt(_foe, float(hit), "clash")
			_clash_fx()
		else:
			var hit2 := int(minf(float(_burst(mini(hero_hp, ceili(foes)))), foes))
			hero_hp -= maxi(hit2, 1)
			hurt(_foe, float(maxi(hit2, 1)), "hero")
			effects.hit_spark(hero.muzzle(), Color(1.0, 0.4, 0.3))
			if hero_hp <= 0 and _foe["alive"]:
				_lose("ARMY_LOST")
				return
		if not _foe["alive"]:
			_end_clash()


func _clash_fx() -> void:
	juice.add_trauma(0.1, "clash")
	var p := Vector3(army_view.charge_x + randf_range(-1.0, 1.0), 0.5, -d - 0.45)
	effects.hit_spark(p, Color(1.0, 0.8, 0.5))
	Audio.play("brawl", -11.0, 0.15)


func _burst(n: int) -> int:
	return maxi(1, ceili(n / 14.0))


func _begin_siege(it: Dictionary) -> void:
	state = State.SIEGE
	_foe = it
	_tick = 0.0
	_finale = Balance.FINALE_TIME
	_army_at_fortress = army
	army_view.mode = Army.Mode.CHARGE
	army_view.charge_z = -float(it["d"]) + 0.85
	army_view.charge_x = 0.0
	army_view.charge_half = 1.7
	Audio.play("boss", -4.0)
	juice.add_trauma(0.3)


## Siege: the army rams the gate tick by tick; with nobody left the hero has FINALE_TIME s.
func _siege(dt: float) -> void:
	var f := _foe
	if f.is_empty() or not f["alive"]:
		_win()
		return
	_tick -= dt
	while _tick <= 0.0 and state == State.SIEGE and army >= 1:
		_tick += Balance.FIGHT_TICK
		var hp := ceili(float(f["hp"]))
		var hit := mini(_burst(mini(army, hp)), mini(army, hp))
		_change_army(-hit, Vector3.INF, Vector3.ZERO, "front")
		hurt(f, float(hit), "siege")
		juice.add_trauma(0.08, "clash")
	if state != State.SIEGE:
		return
	if army < 1 and f["alive"]:
		_finale -= dt
		if _finale <= 0.0:
			_lose("NOT_ENOUGH")
	elif not f["alive"]:
		_win()


func _fortress_hit(it: Dictionary, at: Vector3) -> void:
	var node := it["node"] as Node3D
	Models.damage(node, 1.0 - float(it["hp"]) / maxf(float(it["hp0"]), 1.0))
	juice.counter(it["label"] as Label3D, ceili(float(it["hp"])))
	if randf() < 0.35:
		effects.hit_spark(at + Vector3(randf_range(-1.5, 1.5), randf_range(0.0, 1.5), 0.3), Color(1.0, 0.6, 0.3))


# ------------------------------------------------------------------ the end

## The fortress fell (any state; idempotent): the final blow, then the stairs.
func _win() -> void:
	if _won or state == State.LOST:
		return
	_won = true
	_foe = {}
	if not _fortress.is_empty():
		_fortress["alive"] = false
		_fortress["hp"] = 0.0
	if _army_at_fortress < 0:
		_army_at_fortress = army
	arsenal.stop()
	var survivors := army
	var steps: Array = _stairs.get("steps", [])
	var left := survivors
	var mult := 1.0
	_stair_plan.clear()
	for st: Dictionary in steps:
		var cost := int(st.get("cost", 1))
		if left < cost:
			break
		left -= cost
		mult = float(st.get("mult", 1.0))
		_stair_plan.append({"mult": mult, "cost": cost})
	stairs_mult = mult
	var victory := Balance.victory_coins(level, survivors)
	result = {"coins_run": coins, "victory": victory, "mult": mult,
			"total": int(round(float(victory + coins) * mult)), "survivors": survivors}
	# Final blow: freeze, slow motion, the fortress crumbles into the abyss.
	juice.hitstop(0.12, 0.3)
	juice.add_trauma(1.0)
	juice.haptic("win")
	juice.popup_velocity = Vector3.ZERO
	var f := _fortress.get("node") as Node3D
	if f:
		var at := f.global_position
		effects.flash(at + Vector3(0, 3, 1.2), Color(1.0, 0.85, 0.5), 6.0, 0.6)
		effects.shockwave(at + Vector3(0, 0, 1.5), Color(1.0, 0.6, 0.3), 5.0)
		for k in 7:
			effects.explosion(at + Vector3(randf_range(-4.0, 4.0), randf_range(0.5, 5.0), randf_range(-1.0, 1.4)), randf_range(1.2, 2.0))
		for k in 16:
			fx.debris(at + Vector3(randf_range(-4.0, 4.0), randf_range(1.0, 3.0), 1.4), [Color(0.17, 0.18, 0.23), Color(0.72, 0.1, 0.09), Color(1.0, 0.45, 0.18)][k % 3], 2)
		(_fortress["label"] as Label3D).visible = false
		var tw := f.create_tween().set_parallel(true)
		tw.tween_property(f, "position:y", -9.0, FALL_TIME * 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.25)
		tw.tween_property(f, "rotation:x", -0.22, FALL_TIME * 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.25)
		tw.tween_property(f, "rotation:z", 0.06, FALL_TIME).set_delay(0.25)
		# Gone into the abyss for good (its spire would otherwise poke up beside the stairs).
		tw.chain().tween_property(f, "position:y", -30.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(f.hide)
		for k in 4:
			get_tree().create_timer(0.35 + k * 0.28, false).timeout.connect(func() -> void:
				if is_instance_valid(f):
					effects.explosion(f.global_position + Vector3(randf_range(-3.5, 3.5), randf_range(1.0, 4.0), 1.0), 1.6)
					juice.add_trauma(0.3))
	Audio.play("explosion", 2.0)
	Audio.play("victory", -2.0)
	_end_t = 0.0
	_stair_phase = 0
	_stair_t = 0.0
	_stair_front = -1
	state = State.STAIRS
	hero.running = false
	hero.fighting = false
	hero.cheering = false
	army_view.mode = Army.Mode.FOLLOW


## Stairs: wait for the collapse, march to the stairs, climb paying each step's cost.
func _stairs_step(dt: float) -> void:
	_stair_t += dt
	match _stair_phase:
		0:
			if _stair_t >= FALL_TIME:
				_stair_phase = 1
				_stair_t = 0.0
				_assign_stair_units()
		1:
			# March to the foot of the stairs.
			var sd := float(_stairs.get("d", d + 6.0))
			var goal := sd - 0.4
			var nd := move_toward(d, goal, Balance.RUN_SPEED * dt)
			step_advance = -(nd - d)
			d = nd
			hx = move_toward(hx, 0.0, 3.0 * dt)
			army_view.center = _army_center()
			hero.running = true
			if d >= goal - 0.01:
				_stair_phase = 2
				_stair_t = 0.0
				army_view.mode = Army.Mode.POSE
				if army <= 0 or _stair_plan.is_empty():
					_stair_phase = 3
		2:
			# One step every STAIR_TIME: the climbers leave a row behind on each step.
			var want := mini(int(_stair_t / STAIR_TIME), _stair_plan.size() - 1)
			while _stair_front < want:
				_stair_front += 1
				_reach_step(_stair_front)
			_pose_stair_units()
			if _stair_t >= STAIR_TIME * (_stair_plan.size() + 1.2):
				_stair_phase = 3
				_stair_t = 0.0
		3:
			hero.running = false
			hero.cheering = true
			stairs_done.emit(stairs_mult)
			if stairs_mult > 1.0:
				var top := hero.global_position + Vector3(0, 2.2, 0)
				juice.popup(Models._mult_text(stairs_mult), top, GOLD, 1.8)
				for k in 4:
					effects.burst(top + Vector3(randf_range(-2, 2), randf_range(0, 1.5), 0), [Color(0.4, 0.75, 1.0), GOLD, Color(0.5, 1.0, 0.6), Color(1.0, 0.5, 0.8)][k], 40, 6.0, 0.1, 1.4, -4.0)
			Audio.play("stairs_top", -2.0)
			juice.haptic("win")
			_stair_phase = 4
			_stair_t = 0.0
		4:
			# A beat of celebration on top before the result panel.
			if _stair_t >= 1.8:
				state = State.WON
				_end_t = 0.0
	if _stair_phase >= 2:
		_place_hero_on_stairs(dt)


func _assign_stair_units() -> void:
	# Units per step in proportion to the soldiers each step costs.
	var shown := army_view.shown
	var w := _weight()
	var k := 0
	for p: Dictionary in _stair_plan:
		var units := mini(maxi(int(round(float(p["cost"]) / w)), 1), maxi(shown - k, 0))
		p["first"] = k
		p["units"] = units
		k += units
	# The rest climb to the top with the hero.
	_stair_plan_rest = k


func _reach_step(i: int) -> void:
	var p: Dictionary = _stair_plan[i]
	var top := hero.global_position + Vector3(0, 1.6, 0)
	Audio.play_pitched("stairs_step", -4.0, pow(2.0, float(i) / 12.0 * 2.0))
	juice.popup(Models._mult_text(float(p["mult"])), _step_world(i) + Vector3(0, 1.4, 0), GOLD.lerp(Color.WHITE, 0.2), 0.9)
	effects.flash(_step_world(i) + Vector3(0, 0.3, 0), GOLD, 2.2, 0.25)
	juice.haptic("tile")
	effects.burst(top, GOLD, 8, 2.0, 0.07, 0.4, -4.0)


func _step_world(i: int) -> Vector3:
	var node := _stairs.get("node") as Node3D
	var steps: Array = node.get_meta("steps", [])
	if steps.is_empty():
		return node.global_position
	return node.global_position + (steps[clampi(i, 0, steps.size() - 1)] as Vector3)


func _pose_stair_units() -> void:
	var shown := army_view.shown
	for s in _stair_plan.size():
		var p: Dictionary = _stair_plan[s]
		var first := int(p.get("first", 0))
		var units := int(p.get("units", 0))
		var on := mini(s, _stair_front)
		for k in units:
			var i := first + k
			if i >= shown:
				break
			army_view.set_pose(i, _stair_slot(on, k, units if on == s else 24, s != on))
	var top := maxi(_stair_front, 0)
	var rest := shown - _stair_plan_rest
	for k in rest:
		army_view.set_pose(_stair_plan_rest + k, _stair_slot(top, k, maxi(rest, 1), true))


## Position of the k-th of n units standing on step i (rows across the tread).
func _stair_slot(i: int, k: int, n: int, crowd: bool) -> Vector3:
	var c := _step_world(i)
	var per_row := 10
	var row := k / per_row
	var col := k % per_row
	var in_row := mini(per_row, n - row * per_row)
	var dx := 0.42
	var x := (col - (in_row - 1) * 0.5) * dx
	var z := c.z + 0.45 - row * 0.4
	if crowd:
		z += 0.25
	return Vector3(clampf(x, -STAIRS_W * 0.5 + 0.2, STAIRS_W * 0.5 - 0.2), c.y, z)


func _place_hero_on_stairs(dt: float) -> void:
	var i := maxi(_stair_front, 0)
	var goal := _step_world(i) + Vector3(0, 0, -0.45)
	if _stair_plan.is_empty():
		goal = Vector3(0, 0, -float(_stairs.get("d", d)) + 0.6)
	var p := hero.position
	p.x = move_toward(p.x, goal.x, 4.0 * dt)
	p.y = move_toward(p.y, goal.y, 4.5 * dt)
	p.z = move_toward(p.z, goal.z, 6.0 * dt)
	hero.position = p
	hx = p.x


func _end_step(dt: float) -> void:
	_end_t += dt
	if _finish_sent:
		return
	if state == State.WON and _end_t >= 0.2:
		_finish_sent = true
		juice.reset()
		finished.emit(true, int(result.get("total", 0)), "FORTRESS_FALLS")
	elif state == State.LOST and _end_t >= 1.3:
		_finish_sent = true
		juice.reset()
		finished.emit(false, coins, str(result.get("reason", "ARMY_LOST")))


func _lose(reason: String) -> void:
	if state == State.LOST or _won:
		return
	state = State.LOST
	_end_t = 0.0
	_foe = {}
	arsenal.stop()
	result = {"coins_run": coins, "victory": 0, "mult": 1.0, "total": coins, "survivors": 0, "reason": reason}
	hero.running = false
	hero.fighting = false
	effects.death(hero.global_position, Color(0.4, 0.6, 1.0), 0.6)
	juice.add_trauma(0.6)
	juice.haptic("hit_big")
	Audio.play("defeat", -2.0)


# ------------------------------------------------------------------ visuals

func _visuals(delta: float) -> void:
	var dt := minf(delta, 0.1)
	_vis_t += dt
	var on_stairs := state == State.STAIRS or (state == State.WON and not _stair_plan.is_empty())
	if not on_stairs or _stair_phase < 2:
		hero.position = Vector3(hx, 0.0, -d)
	hero.running = state == State.RUNNING or (state == State.STAIRS and _stair_phase == 1)
	hero.fighting = state == State.CLASH or state == State.SIEGE
	_animate_knights(delta)
	army_view.draw()
	# Army counter above the hero, leading the blob.
	var top := hero.position + Vector3(0, hero.top() + 0.75, 0.25)
	if on_stairs and _stair_phase >= 2:
		top = hero.position + Vector3(0, 2.4, 0.4)
	elif (state == State.CLASH or state == State.SIEGE) and army > 0:
		# The squad's counter owns the space over the front line: ours rides over the blob.
		var b := army_view.bounds()
		top = Vector3((float(b[0]) + float(b[1])) * 0.5, 0.9, float(b[3]) + 0.35)
	# Slide between anchors (hero / blob) instead of jumping; the hero part tracks exactly.
	var off := top - hero.position
	_label_off = off if delta <= 0.0 else _label_off.lerp(off, 1.0 - exp(-12.0 * dt))
	_army_label.position = hero.position + _label_off
	# On the stairs the step multipliers own that space.
	_army_label.visible = army > 0 and not (on_stairs and _stair_phase >= 2)
	juice.popup_velocity = Vector3(0, 0, -Balance.RUN_SPEED) if state == State.RUNNING else Vector3.ZERO
	_fade_passing_gate()
	hazards.draw(t, dt, d, _foe if state == State.CLASH else {})
	arsenal.draw(dt, t)
	_draw_pickups()
	# Ult armour glow on the army.
	var armor_k := clampf(_armor / 0.5, 0.0, 1.0)
	army_view.view.set_overlay(EMERALD, 0.85 * armor_k)
	if not _fortress.is_empty() and _fortress.get("node") and _fortress["alive"]:
		var ff := _fortress["node"] as Node3D
		if state == State.SIEGE:
			ff.position.x = sin(_vis_t * 40.0) * 0.02
	_cull_t -= dt
	if _cull_t <= 0.0:
		_cull_t = 0.5
		fx.cull_behind(-d + 14.0)
	_camera(dt)


## The army counter rides over the hero: right before the hero passes a gate, that gate's big
## number fades out so the two never stack (the pass popup shows the result next).
func _fade_passing_gate() -> void:
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		var ahead := float(it["d"]) - d
		if ahead > 4.4:
			break
		if ahead < -0.5 or str(it["kind"]) != "gate" or not it["alive"]:
			continue
		var l := it["label"] as Label3D
		if absf(hx - float(it["x"])) <= float(it["w"]) * 0.5 + 0.3:
			l.modulate.a = clampf((ahead - 1.8) / 2.4, 0.12, 1.0)


## Picks the knights' clip for the state and advances the crowd clocks (VAT path only).
func _animate_knights(delta: float) -> void:
	if army_anim == null:
		return
	var want := "run"
	var rate := VatClip.run_rate(Balance.RUN_SPEED)
	match state:
		State.READY, State.LOST:
			want = "idle"
			rate = 1.0
		State.CLASH, State.SIEGE:
			want = "attack"
			rate = 1.15
		State.STAIRS:
			if _stair_phase == 0:
				want = "victory"      # the fortress crumbles: the army cheers
				rate = 1.0
			elif _stair_phase == 2:
				want = "walk"
				rate = 1.6
			elif _stair_phase >= 3:
				want = "victory"
				rate = 1.0
		State.WON:
			want = "victory"
			rate = 1.0
	army_anim.play(want, 0.2, false, rate)
	var us := VatClip.crowd_scale(army_view.shown)
	army_anim.set_unit_scale(us)
	fx.unit_scale[0] = us
	army_anim.tick(delta)
	if recruit_anim:
		recruit_anim.tick(delta)


func _draw_pickups() -> void:
	var spin := Basis(Vector3.UP, _vis_t * 3.0) * Basis(Vector3.RIGHT, PI * 0.5)
	for it in _coin_items:
		var cd := float(it["d"])
		if not it["alive"] or cd < d - VIEW_BEHIND or cd > d + VIEW_AHEAD:
			continue
		_coins_mm.multimesh.set_instance_transform(int(it["idx"]), Transform3D(spin, Vector3(float(it["x"]), 0.55 + sin(_vis_t * 3.0 + cd) * 0.08, -cd)))
	var pts := PackedVector3Array()
	for it in _recruit_items:
		var rd := float(it["d"])
		if not it["alive"] or rd < d - VIEW_BEHIND or rd > d + VIEW_AHEAD:
			continue
		pts.append_array(it["units"])
	_recruit_view.draw(pts, pts.size(), 0.0, 0.03, 0.05)


## Keeps the bridge filling the width on any phone without a fisheye on tall screens.
func _fit_fov() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var vfov := rad_to_deg(2.0 * atan(tan(deg_to_rad(CAM_HFOV * 0.5)) / aspect))
	_fov_base = clampf(vfov, 50.0, 66.0)
	if not _cam_ready:
		_fov = _fov_base
	cam.fov = _fov


## Camera goal for the state: [position, look-at point, fov]. While running, the framing follows
## the army's rear extent (blob + machines) so the whole army stays above the ult button and the
## gate rows 40 units ahead stay readable: a small army gets a close, steep shot, a big one a
## higher, longer one.
func _camera_goal() -> Array:
	var rear := Balance.HERO_GAP + 2.0 * _radius_vis * Balance.BLOB_STRETCH + 0.5
	if arsenal and arsenal.machines.size() >= 3:
		rear += 0.9
	var k := clampf((rear - 2.5) / 4.0, 0.0, 1.25)
	var h := lerpf(CAM_NEAR.x, CAM_FAR.x, k)
	var back := lerpf(CAM_NEAR.y, CAM_FAR.y, k)
	var ahead := lerpf(CAM_NEAR.z, CAM_FAR.z, k)
	var cx := hx * 0.35
	var pos := Vector3(cx, h, -d + back)
	var look := Vector3(hx * 0.55, 0.0, -d - ahead)
	var fov := _fov_base
	match state:
		State.CLASH:
			# Push in on the fight: the front line drops towards the middle of the screen.
			fov = _fov_base - 5.0
			pos += Vector3(0.0, -0.6, -1.4)
			look += Vector3(0.0, 0.0, -1.4)
		State.SIEGE:
			var fz := -float(_fortress.get("d", d))
			# Closer and lower: the fortress towers over the army ramming its gate.
			pos = Vector3(0.0, 9.0, fz + 11.8)
			look = Vector3(0.0, 2.4, fz - 1.0)
		State.STAIRS, State.WON:
			var sz := -float(_stairs.get("d", d))
			if _stair_phase <= 1 and state == State.STAIRS:
				pos = Vector3(0.0, 12.0, -d + 12.5)
				look = Vector3(0.0, 1.0, -d - 5.0)
			else:
				var mid := sz - minf(float(maxi(_stair_front, 0)) + 2.0, 8.0) * Models.STEP_D * 0.5
				pos = Vector3(6.5, 9.5, mid + 11.0)
				look = Vector3(0.0, 1.6 + maxi(_stair_front, 0) * Models.STEP_H * 0.5, mid - 2.0)
		State.LOST:
			pos = Vector3(cx, h - 1.0, -d + back - 1.5)
	return [pos, look, fov]


func _camera(dt: float) -> void:
	var goal := _camera_goal()
	# The spring runs in a frame that moves with the run (anchor z = -d), so forward motion is
	# followed exactly and state changes (clash push-in, siege, stairs) glide without a pop.
	var anchor := Vector3(0.0, 0.0, -d)
	var gp: Vector3 = (goal[0] as Vector3) - anchor
	var gl: Vector3 = (goal[1] as Vector3) - anchor
	var smooth := 0.25
	if state == State.SIEGE or state == State.STAIRS or state == State.WON:
		smooth = 0.7
	if not _cam_ready:
		_cam_ready = true
		_cam_pos = gp
		_cam_look = gl
		_cam_vel = Vector3.ZERO
		_look_vel = Vector3.ZERO
	else:
		var res := _damp3(_cam_pos, gp, _cam_vel, smooth, dt)
		_cam_pos = res[0]
		_cam_vel = res[1]
		var res2 := _damp3(_cam_look, gl, _look_vel, smooth, dt)
		_cam_look = res2[0]
		_look_vel = res2[1]
	_fov = lerpf(_fov, float(goal[2]), 1.0 - exp(-6.0 * dt))
	cam.fov = _fov
	var shake := juice.shake_offset()
	cam.position = anchor + _cam_pos + shake
	cam.look_at(anchor + _cam_look + shake * 0.5)
	cam.rotate_object_local(Vector3.FORWARD, juice.shake_roll())


## Critically damped spring towards `target` (Unity SmoothDamp). Returns [value, velocity].
static func _damp3(cur: Vector3, target: Vector3, vel: Vector3, smooth: float, dt: float) -> Array:
	var omega := 2.0 / maxf(smooth, 0.0001)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var temp := (vel + change * omega) * dt
	var nv := (vel - temp * omega) * e
	var out := target + (change + temp) * e
	return [out, nv]


# ------------------------------------------------------------------ dev helpers

## Dev / screenshot helper: jumps the run to distance `dist` (items behind are skipped).
func skip_to(dist: float) -> void:
	start()
	dist = minf(dist, length - Balance.CONTACT - 0.5)
	t = dist / Balance.RUN_SPEED
	d = dist
	while _pk < _pick.size() and float(_pick[_pk]["d"]) <= d:
		var it := _pick[_pk]
		_pk += 1
		if str(it["kind"]) == "gate":
			for g: Dictionary in _rows.get(int(it.get("row", -1)), [it]):
				g["alive"] = false
				_style_gate(g)
				(g["node"] as Node3D).visible = false
		else:
			it["alive"] = false
	while _bk < _block.size() and float(_block[_bk]["d"]) - Balance.CONTACT <= d:
		var b := _block[_bk]
		_bk += 1
		if str(b["kind"]) == "squad":
			b["alive"] = false
	_armed.clear()
	while _vk < _vaults.size() and float(_vaults[_vk]["d"]) <= d:
		_vk += 1
	while _hk < _hints.size() and float((_hints[_hk] as Dictionary).get("d", 0.0)) <= d:
		_hk += 1
	for it in items:
		if float(it["d"]) < d - 1.0 and str(it["kind"]) in ["tile", "coin", "recruits", "geode", "crate", "barricade", "turret"]:
			it["alive"] = false
			if it.has("node") and is_instance_valid(it["node"]):
				(it["node"] as Node3D).visible = false
			if it.has("label") and is_instance_valid(it["label"]):
				(it["label"] as Node3D).visible = false
	for it in _tile_items:
		if not it["alive"]:
			_tiles.multimesh.set_instance_transform(int(it["idx"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -10, 0)))
	for it in _coin_items:
		if not it["alive"]:
			_coins_mm.multimesh.set_instance_transform(int(it["idx"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -10, 0)))
	_update_live()
	army_view.center = _army_center()
	_cam_ready = false


## Shows the army weapon tier: the procedural soldiers swap models; the knights (no tiered
## models yet) get a teal (crossbows) or violet (blasters) edge glow.
func show_arm_tier() -> void:
	if army_anim == null:
		army_view.set_mesh(Models.soldier_mesh(arm_tier))
		return
	var e: Array = TIER_EDGE[clampi(arm_tier, 0, TIER_EDGE.size() - 1)]
	army_view.view.set_edge(e[0] as Color, float(e[1]))
	var m := army_anim.material
	m.set_shader_parameter("crystal_color", e[2] as Color)
	m.set_shader_parameter("crystal_tint", float(e[3]))
	m.set_shader_parameter("crystal_glow", float(e[4]))


## Dev / screenshot helper: sets the army size at once.
func set_army(n: int) -> void:
	var before := army
	army = maxi(n, 0)
	var want := mini(army, _max_shown)
	_radius_vis = blob_radius()
	army_view.radius = _radius_vis
	army_view.center = _army_center()
	if want > army_view.shown:
		army_view.spawn(want - army_view.shown)
	while army_view.shown > want:
		army_view.drop(army_view.shown - 1)
	_army_changed(before)


## Dev / screenshot helper: grants a weapon at once.
func give_weapon(kind: String) -> void:
	_give_weapon(kind, Vector3(hx, 0.0, -d - 2.0))
