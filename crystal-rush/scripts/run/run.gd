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
signal crate_resolved(item: Dictionary)                  ## a crate / RANK gate locked its contents (30 u ahead)
signal rank_changed(id: String, rank: int)               ## a fielded machine changed Rank (or overflow)

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
## The account as the run reads it (Meta.run_profile, built once in setup(); §6.4).
var profile: Dictionary = {}
## The hero's painted target (PAINT machines lock onto it; refreshed by every hero hit).
var painted: Dictionary = {}
## A NEW crate opened this run ("" = none): the machine unlocks even on a loss.
var new_unlock := ""
## Run statistics with the fixed keys of EconData.STATS_KEYS (design §9.4).
var stats: Dictionary = {}

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
## The ult clock (HeroKinds.Clock, shared rules with LevelSim; heroes design §10.4). The four
## fields below forward to it.
var ult_clock := HeroKinds.Clock.new()
var _ult_left: float:
	get:
		return ult_clock.left
	set(v):
		ult_clock.left = v
var _ult_tick: float:
	get:
		return ult_clock.tick
	set(v):
		ult_clock.tick = v
var _quake_d: float:
	get:
		return ult_clock.wave_d
	set(v):
		ult_clock.wave_d = v
var _quake_wave: int:
	get:
		return ult_clock.wave
	set(v):
		ult_clock.wave = v
var _armor := 0.0
## The hero's kinds (HeroKinds.KINDS): the run reads behaviour through them, never the id.
var _ult_kind: StringName = &"storm"
var _attack_kind: StringName = HeroKinds.ATTACK_DART
## The rules' window on this run (HeroKinds / ChampionKinds act through it).
var kind_view: RunKindView
## The new hero kinds' VFX (§6.2-6.10, §6.28, §6.29: `ult_shape` and `hero_attack`, one draw). Null for
## the starters (Руді, Горан, Мейра keep the Meta-1 attack and ult VFX of Effects), so a starter's run
## builds exactly what it did before.
var hero_fx: HeroFx
## A hero without a Meta-1 row (§6: every hero but the three starters): its volleys run through
## HeroKinds.attack (its pattern and procs) and draw through hero_fx.
var _new_kind := false
## The run row is a v3 row (HeroKinds.scaled): its hp, damage, ult charge and ult numbers are final, so
## the hero block's dmg / hp / ult-rate multipliers are not applied again (Reinforcements still are).
var _v3 := false
## Soldiers lost this run from any cause (KindView army()["lost"]: Пава's ward, the army_loss policy).
var lost_total := 0.0
## The ult pose of the cast in flight was played (a new kind's cast poses once, on `ult_cast` or its
## shape's start, whichever comes first).
var _cast_posed := false
## Champion slots (empty until the heroes phase H2; Champions.setup reads profile.team).
var champions := Champions.new()
## The champions on screen and on the HUD (null while Champions.active() is false).
var champ_view: ChampionView
## Champions.step cost (§10.6 budget 0.25 ms, dev): steps timed, total and worst microseconds,
## steps over the budget, and the share spent in the run's own hit path (hurt: kill fx, statuses)
## and in the champ_* VFX / HUD handlers, so the rules' own cost is us - hit_us - fx_us.
var champ_perf := {"steps": 0, "us": 0, "max_us": 0, "over_250us": 0, "hit_us": 0, "fx_us": 0}
## True while Champions.step runs (champ_perf counts its hit / fx shares only then).
var champ_stepping := false
# Champion-scaled losses (ChampionKinds multipliers): fractions carry, rounded (start at 0.5).
var _clash_acc := 0.5
var _haz_acc := 0.5
var _turret_acc := 0.5
## True inside a clash / siege tick: the tick feeds the Healer pools itself, after clash_hit.
var _feed_hold := false
var _champ_rng := RandomNumberGenerator.new()
## Fallen champions: id -> {t, cause} for result.team_report.
var _champ_down := {}
## Hazard clock (WS2b): blades and sweepers move on it; the Seer's rift slows it (hazard_slow).
var hz_t := 0.0
var _carry_placed := false            ## profile.new_carry: the first crate became the NEW crate
var _rift: Node3D
var _slow_acc := 0.0
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
## Set by main when the result / loss flow opens: the big army count would print through its scrim.
var hide_army_label := false
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
var _paint_t := 0.0
var _resolve: Array[Dictionary] = []     # crates and RANK gates, by d: contents lock at CRATE_RESOLVE_D
var _rk := 0
var _crates: Array[Dictionary] = []
var _pairs := {}                         # pair id -> [crate items]
var _pick_rng := RandomNumberGenerator.new()
var _siege_t := 0.0
var _ult_uses := 0


func setup(p_level: int, p_hero: String) -> void:
	level = p_level
	hero_type = p_hero
	world = Worlds.for_level(level)
	profile = _load_profile(level)
	# The hero's run row (§10.1): Balance.HEROES for the starters at heroes phase 0, from phase 2 the
	# hero's HeroData attack / ult numbers on the profile's v3 block (HeroKinds.def_for).
	def = HeroKinds.def_for(hero_type, profile.get("hero", {}) if profile.get("hero") is Dictionary else {})
	ult = def["ult"]
	_new_kind = not Balance.HEROES.has(hero_type)
	_v3 = HeroKinds.scaled(def)
	_ult_kind = HeroKinds.ult_kind(hero_type)
	_attack_kind = HeroKinds.attack_kind(hero_type)
	kind_view = RunKindView.new(self)
	champions.setup(profile, level)
	_champ_rng.seed = 7919 * level + 101
	_pick_rng.seed = 7919 * level + 31 * int(profile.get("run_id", 0)) + 17
	# Levels and the start army ignore account power (§6.4); Reinforcements add soldiers.
	army = Balance.START_ARMY + int((profile.get("assist", {}) as Dictionary).get("soldiers", 0))
	hero_hp = int(round(float(def["hp"]) * (1.0 if _v3 else hero_mult("hp_mult"))))
	stats = _fresh_stats()


## Meta.run_profile(level) (the account), or a synthetic fresh profile when Meta is missing.
func _load_profile(lvl: int) -> Dictionary:
	var meta := _meta()
	if meta and meta.has_method("run_profile"):
		return meta.call("run_profile", lvl)
	return LevelSim.reference_profile(lvl)


## The account dictionary behind the profile (Arsenal Sync levels), {} without Meta.
func account() -> Dictionary:
	var meta := _meta()
	if meta:
		var acc: Variant = meta.get("account")
		if acc is Dictionary:
			return acc
	return {}


## The Meta autoload (setup() runs before the run enters the tree).
static func _meta() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Meta") if tree else null


## A hero multiplier of the profile (dmg_mult, hp_mult, ult_rate_mult): RunHero.mult(key) when
## the hero implements it (WS2b), else the profile's hero block.
func hero_mult(key: String) -> float:
	if hero and hero.has_method("mult"):
		return float(hero.call("mult", key))
	return float((profile.get("hero", {}) as Dictionary).get(key, 1.0))


## Army volley multiplier (Barracks "volleys"): Army.volley_mult() when present, else the profile;
## x the Ranger aura while champions run (ChampionKinds.volley_mult).
func volley_mult() -> float:
	var k := float((profile.get("army", {}) as Dictionary).get("volley_mult", 1.0))
	if army_view and army_view.has_method("volley_mult"):
		k = float(army_view.call("volley_mult"))
	if champions.active():
		k *= ChampionKinds.volley_mult(champions.members)
	if kind_view:
		# A hero kind's team buff (KindView.buff &"volleys": Веста's Sun Field); 1 without one.
		k *= 1.0 + kind_view.buff_value(&"volleys")
	return k


static func _fresh_stats() -> Dictionary:
	var st := {}
	for k: String in EconData.STATS_KEYS:
		st[k] = 0
	for k2 in ["kills_by_machine", "kills_by_family", "gates_by_op", "statuses", "reactions", "wins_with_lead"]:
		st[k2] = {}
	st["evolutions_ids"] = []
	st["fusions_ids"] = []
	st["stairs_mult"] = 0.0
	return st


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
	hero.setup(hero_type, profile, def)
	if _new_kind:
		hero_fx = HeroFx.new()
		add_child(hero_fx)
		hero_fx.setup(self, hero_type)
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
	arsenal.ranked.connect(_on_ranked)
	# The Lead (deck slot 1, Lv5+) rolls with the army from the start at Rank I (§3.1).
	var lead := str(profile.get("lead", ""))
	if lead != "" and ArsenalData.is_live(lead) and bool(ArsenalData.FEATURES["lead"]):
		arsenal.field(lead, 1, Vector3.INF, true)
		weapons = arsenal.summary()
	if champions.active():
		champ_view = ChampionView.new()
		champ_view.name = "Champions"
		add_child(champ_view)
		champ_view.setup(self)
	_army_label = Models.label(str(army), 110, Color("#FFF8EC"), true)
	_army_label.render_priority = 6
	_army_label.no_depth_test = true
	Models.soft_outline(_army_label, Color("#1E2433"), 0.34)
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
	return ult_points >= float(ult["charge"]) - 0.001 and not ult_clock.active()


# ------------------------------------------------------------------ building

func _spawn_items(list: Array) -> void:
	var tiles: Array[Dictionary] = []
	for spec: Dictionary in list:
		var it: Dictionary = spec.duplicate(true)
		it["alive"] = true
		# KindView target id (RunKindView, kind_item): the item's index in `items`.
		it["kid"] = items.size()
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
				if kind == "crate":
					_prepare_crate(it)
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
	_resolve.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
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
	if str(it["op"]) == "rank":
		it["rank_id"] = ""
		_resolve.append(it)
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
		hz_t += dt * hazard_slow()
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
		if champions.active():
			_champions_step(dt)
		hazards.check_army(army_view, _armor > 0.0)
		hazards.step_turrets(dt * hazard_slow(), army_view)
		match state:
			State.CLASH:
				_clash(dt)
			State.SIEGE:
				_siege(dt)
		_armor = maxf(_armor - dt, 0.0)
	else:
		army_view.hold_slots(false)
	hazards.step_squads(dt * hazard_slow(), d, _foe if state == State.CLASH else {}, -d - 0.75, hx)


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
	_resolve_ahead()
	_paint_t -= dt
	if _paint_t <= 0.0 or (not painted.is_empty() and not painted.get("alive", false)):
		painted = {}
	_hero_attack(dt)
	arsenal.step(dt)
	_crate_contact()
	_ult_step(dt)
	if _v3:
		# The hero kind's own state (H2): the revive pool, loss samples, drones, Eyes, Awakening.
		HeroKinds.hero_step(kind_view, def, dt)
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
	stats["tiles"] = int(stats["tiles"]) + 1
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
	var n := int(it.get("value", 3)) + army_view.recruit_bonus()
	var pts: PackedVector3Array = it.get("units", PackedVector3Array())
	var before := army
	army += n
	stats["recruits"] = int(stats["recruits"]) + n
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
	hazards.update_live(hz_t)
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


## The Seer's foresight: a hit on a gate reveals every hidden gate of its row.
func _reveal_row(g: Dictionary) -> void:
	for o: Dictionary in _rows.get(int(g.get("row", -1)), [g]):
		if o["alive"] and not bool(o["revealed"]):
			_reveal_gate(o)
			_style_gate(o)
			effects.flash((o["node"] as Node3D).global_position + Vector3(0, 1.1, 0.1), Effects.ARCANE, 1.2, 0.3)


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
		"rank":
			return Loc.t("GATE_RANK")
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
			text = Loc.t(str((ArsenalData.MACHINES[wk] as Dictionary)["name"])) if ArsenalData.is_live(wk) else Loc.t("DECK")
			icon = wk if ArsenalData.is_live(wk) else "star"
		"ult":
			kind = "power"
			icon = "star"
		"rank":
			# A RANK gate: the machine it powers up and its next Rank numeral (§3.4).
			kind = "power"
			var rid := str(it.get("rank_id", ""))
			var m: Dictionary = arsenal.find(rid) if arsenal and rid != "" else {}
			if m.is_empty():
				text = "?"
				sub = Loc.t("GATE_RANK")
				icon = "star"
			else:
				text = roman(mini(int(m["rank"]) + 1, 3)) if int(m["rank"]) < 3 else "+%d%%" % int(round(ArsenalData.overflow_bonus(int(m["over"]) + 1) * 100.0))
				sub = Loc.t(str((ArsenalData.MACHINES[rid] as Dictionary)["name"]))
				icon = "rank:" + rid
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
	Models.gate_style(node, text, sub, kind, "star" if icon.begins_with("rank:") else icon)
	hazards.gate_machine_icon(node, icon.trim_prefix("rank:") if icon.begins_with("rank:") else "")
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
			return Loc.t(str((ArsenalData.MACHINES[wk] as Dictionary)["name"])) if ArsenalData.is_live(wk) else Loc.t("DECK")
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
	var gbo: Dictionary = stats["gates_by_op"]
	var gk := {"+": "good", "-": "bad", "/": "bad", "x": "x", "arm": "arm", "rate": "power", "dmg": "power", "multi": "power", "rank": "rank"}
	if gk.has(op) and not (op == "rank" and str(it.get("rank_id", "")) == ""):
		gbo[gk[op]] = int(gbo.get(gk[op], 0)) + 1
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
		"rank":
			var rid := str(it.get("rank_id", ""))
			if rid == "" or arsenal.find(rid).is_empty():
				var fb: Dictionary = it.get("fallback", {"op": "+", "value": 10})
				_pass_gate(it, str(fb.get("op", "+")), float(fb.get("value", 10)))
				return
			arsenal.rank_up(rid)
			stats["rank_gates"] = int(stats["rank_gates"]) + 1
			juice.popup(Loc.t("RANK_UP") % roman(int(arsenal.find(rid)["rank"])), at + Vector3(0, 1.6, -0.3), GOLD, 1.25)
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
				var gbo2: Dictionary = stats["gates_by_op"]
				gbo2["charge_flipped"] = int(gbo2.get("charge_flipped", 0)) + 1
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
	if army < before:
		lost_total += float(before - army)
	# Every soldier lost feeds the Healers' revive pools (a clash / siege tick feeds after clash_hit).
	if army < before and not _feed_hold and champions.active():
		ChampionKinds.feed(champions.members, float(before - army))
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
	# Barracks Scrape Guard: the first soldiers this hazard takes are saved.
	var spared := army_view.scrape_spare(it, lost)
	if spared > 0:
		lost -= spared
		_side_popup("+%d" % spared, Vector3(float(it["x"]), 1.6, -float(it["d"])), GAIN, 0.7)
	if lost > 0:
		# Hero ult wards (KindView.absorb, H2), where LevelSim._hazards spends them: one charge spares one
		# soldier's contact (a blade spends a blade ward, then a contact one; a barricade keeps its wear).
		# No-op until a hero kind grants wards (RunKindView.absorb answers false at once without any).
		var wk: StringName = &"contact" if spikes else &"blade"
		var warded := 0
		while lost > 0 and kind_view.absorb(wk):
			lost -= 1
			warded += 1
		if warded > 0:
			hazard_deaths -= float(warded)
	if lost > 0 and champions.active():
		lost = _champion_hazard(it, lost)
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
func turret_hit(it: Dictionary, at: Vector3) -> void:
	if kind_view and kind_view.silenced(it):
		# Ольга form IV: a silenced turret's shot misses (KindView.silence).
		effects.hit_spark(at, Color(0.86, 0.9, 1.0))
		return
	if _armor > 0.0:
		effects.hit_spark(at, EMERALD)
		return
	if army <= 0 or not (state == State.RUNNING or state == State.CLASH or state == State.SIEGE):
		return
	if champions.active():
		# Healer aura: turret losses x hazard_loss_mult (never Blocked; turrets never aim at champions).
		_turret_acc += ChampionKinds.hazard_loss_mult(champions.members)
		if _turret_acc < 1.0:
			effects.hit_spark(at, Color(0.86, 1.0, 0.9))
			return
		_turret_acc -= 1.0
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
		if champ_view:
			champ_view.add_solids(solids)
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
func hurt(it: Dictionary, n: float, source := "") -> float:
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
		_count_kills(source, dealt)
		if arsenal and arsenal.statuses:
			arsenal.statuses.on_hit(it, dealt, source)
			if source == "volley" and champions.active():
				_volley_procs(it)
			if source == "volley" and kind_view and _new_kind:
				_volley_buff(it)
		if kind_view and kind_view.tethered():
			# KindView.tether (H2): a share of what a tethered squad takes hits its partner.
			kind_view.tether_share(it, dealt)
	elif kind == "crate":
		_crate_hit(it)
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
			# Emptied through the BONUS segment: +1 Rank.
			_open_crate(it, bool(ArsenalData.FEATURES["crate_bonus"]) and int(it.get("bonus", 0)) > 0)
	match kind:
		"barricade":
			stats["barricades_broken"] = int(stats["barricades_broken"]) + 1
		"turret":
			stats["turrets_destroyed"] = int(stats["turrets_destroyed"]) + 1
		"geode":
			stats["geodes_broken"] = int(stats["geodes_broken"]) + 1
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


## A machine from a charge gate's reward (or a dev helper): `kind` "deck" asks the CratePicker.
func _give_weapon(kind: String, at: Vector3) -> void:
	if not ArsenalData.is_live(kind):
		kind = CratePicker.parse(_pick_content({}))[0]
	var res := arsenal.grant(kind, Vector3(at.x, 0.0, at.z))
	_after_grant(res, false)


# ------------------------------------------------------------------ crates and RANK gates (§3.3, §3.4)

## Crate fields before its model is built: a NEW crate whose machine is already owned becomes a
## deck crate; the BONUS segment (0.6 x OPEN) joins the hit points.
func _prepare_crate(it: Dictionary) -> void:
	var w := str(it.get("weapon", "deck"))
	var nc := str(profile.get("new_crate", ""))
	if bool(profile.get("new_carry", false)) and nc != "" and not _carry_placed:
		# A NEW machine missed on an earlier level: the level's first crate brings it back.
		_carry_placed = true
		it["new"] = true
		it["weapon"] = nc
		w = nc
	if bool(it.get("new", false)) and (w != nc or nc == "" or not bool(ArsenalData.FEATURES["new_crates"])):
		it["new"] = false
		w = "deck"
	if not bool(it.get("new", false)) and w != "deck" and not ArsenalData.is_live(w):
		w = "deck"
	# Etap-1 fixed-weapon crates follow the deck too (only NEW crates name their machine).
	if not bool(it.get("new", false)):
		w = "deck"
	it["weapon"] = w
	it["content"] = w if bool(it.get("new", false)) else ""
	it["bonus"] = int(round(float(it["value"]) * ArsenalData.CRATE_BONUS_HP)) if bool(ArsenalData.FEATURES["crate_bonus"]) else 0
	it["opened"] = false
	_crates.append(it)
	_resolve.append(it)
	if it.has("pair"):
		var pid := int(it["pair"])
		if not _pairs.has(pid):
			_pairs[pid] = []
		(_pairs[pid] as Array).append(it)


## Locks crate contents and RANK gate machines that came within CRATE_RESOLVE_D (pairs jointly,
## with two different contents).
func _resolve_ahead() -> void:
	while _rk < _resolve.size() and float(_resolve[_rk]["d"]) <= d + ArsenalData.CRATE_RESOLVE_D:
		var it := _resolve[_rk]
		_rk += 1
		if bool(it.get("resolved", false)) or not it.get("alive", false):
			continue
		if str(it["kind"]) == "gate":
			_resolve_rank_gate(it)
			continue
		var group: Array = [it]
		if it.has("pair"):
			group = _pairs.get(int(it["pair"]), [it])
		var taken := ""
		for c: Dictionary in group:
			if bool(c.get("resolved", false)):
				taken = str(c.get("content", ""))
		for c: Dictionary in group:
			if bool(c.get("resolved", false)):
				continue
			c["resolved"] = true
			if str(c.get("content", "")) == "":
				c["content"] = _pick_content(c, taken)
			taken = str(c["content"])
			hazards.resolve_crate(c)
			crate_resolved.emit(c)
	_restyle_crates()


## CratePicker on the deck, counting crates already resolved but not yet opened as fielded.
func _pick_content(it: Dictionary, exclude := "") -> String:
	var fl := arsenal.fielded()
	for c in _crates:
		if c == it or not c.get("alive", false) or not bool(c.get("resolved", false)):
			continue
		var p := CratePicker.parse(str(c.get("content", "")))
		var id := str(p[0])
		if id != "" and not bool(p[1]):
			fl[id] = mini(int(fl.get(id, 0)) + 1, 3)
	var deck: Array = profile.get("deck", [])
	if deck.is_empty():
		deck = ["drone"]
	return CratePicker.pick(deck, fl, profile.get("levels", _deck_levels()), _pick_rng, exclude)


func _deck_levels() -> Dictionary:
	var out := {}
	var ms: Dictionary = profile.get("machines", {})
	for id: String in ms:
		out[id] = int((ms[id] as Dictionary).get("lvl", 1))
	return out


## The forecast of a crate now: [badge text, machine id, after-rank].
func crate_forecast(it: Dictionary) -> Array:
	var c := str(it.get("content", ""))
	if c == "":
		return ["", "", 0]
	var p := CratePicker.parse(c)
	var id := str(p[0])
	var fc := arsenal.forecast(id, false)
	var name := Loc.t(str((ArsenalData.MACHINES.get(id, {}) as Dictionary).get("name", id)))
	var text := ""
	if bool(it.get("new", false)):
		text = "%s\n%s" % [Loc.t("CRATE_NEW"), name]
	else:
		match str(fc["kind"]):
			"overflow":
				text = Loc.t("CRATE_OVERFLOW") % [int(fc.get("pct", 10)), name]
			"swap":
				var sid := str(fc["id"])
				text = "%s %s" % [Loc.t(str((ArsenalData.MACHINES[sid] as Dictionary)["name"])), roman(int(fc["rank"]))]
				id = sid
			"new":
				text = name if int(fc["rank"]) <= 1 else "%s %s" % [name, roman(int(fc["rank"]))]
			_:
				text = "%s %s" % [name, roman(int(fc["rank"]))]
	return [text, id, int(fc.get("rank", 1))]


static func roman(r: int) -> String:
	return ["I", "II", "III"][clampi(r, 1, 3) - 1]


func _restyle_crates() -> void:
	for c in _crates:
		if c.get("alive", false) and bool(c.get("resolved", false)):
			hazards.style_crate(c, crate_forecast(c)[0])
	for g in _resolve:
		if str(g["kind"]) == "gate" and g.get("alive", false) and bool(g.get("resolved", false)):
			_style_gate(g)


## A hero hit on a crate: once the OPEN segment is empty the crate is open (its pair partner
## folds) and the gold BONUS ring starts to fill.
func _crate_hit(it: Dictionary) -> void:
	var b := float(it.get("bonus", 0))
	if not bool(it.get("opened", false)) and float(it["hp"]) <= b + 0.001:
		it["opened"] = true
		hazards.crate_opened(it)
		if it.has("pair"):
			for c: Dictionary in _pairs.get(int(it["pair"]), []):
				if c != it and c.get("alive", false):
					c["alive"] = false
					hazards.fold_crate(c)
		if b <= 0.0:
			return
		Audio.play("upgrade", -8.0, 0.05)


## Open crates are taken when the army reaches them (without the BONUS step).
func _crate_contact() -> void:
	for c in _crates:
		if c.get("alive", false) and bool(c.get("opened", false)) and d >= float(c["d"]) - 0.3:
			c["alive"] = false
			_open_crate(c, false)
			hazards.on_destroy(c)


## Grants a crate's contents (+1 Rank with the BONUS). A NEW crate unlocks its machine.
func _open_crate(it: Dictionary, bonus: bool) -> void:
	if bool(it.get("granted", false)):
		return
	it["granted"] = true
	if not bool(it.get("resolved", false)):
		it["resolved"] = true
		if str(it.get("content", "")) == "":
			it["content"] = _pick_content(it)
	var p := CratePicker.parse(str(it["content"]))
	var id := str(p[0])
	var at := Vector3(float(it["x"]), 0.0, -float(it["d"]))
	var res: Dictionary
	if bool(p[1]):
		arsenal.add_overflow(id)
		res = {"kind": "overflow", "id": id, "rank": 3}
	else:
		res = arsenal.grant(id, at, bonus)
	if bool(it.get("new", false)):
		new_unlock = id
	stats["crates_opened"] = int(stats["crates_opened"]) + 1
	if bonus:
		stats["crate_bonus"] = int(stats["crate_bonus"]) + 1
		juice.popup(Loc.t("CRATE_BONUS"), at + Vector3(0, 2.6, 0), GOLD, 1.2)
	if it.has("pair"):
		for c: Dictionary in _pairs.get(int(it["pair"]), []):
			if c != it and c.get("alive", false):
				c["alive"] = false
				hazards.fold_crate(c)
	_after_grant(res, bool(it.get("new", false)))


func _after_grant(res: Dictionary, is_new: bool) -> void:
	weapons = arsenal.summary()
	var id := str(res.get("id", ""))
	var m := arsenal.find(id)
	# Overflow copies only punch their slot (rank_changed); new machines and Ranks get the card.
	if str(res.get("kind", "")) != "overflow":
		weapon_added.emit(id, int(m.get("rank", 1)) if not m.is_empty() else 1)
	juice.haptic("weapon")
	Audio.play("weapon_get", -3.0)
	if is_new:
		juice.hitstop(0.06)
	_restyle_crates()


func _on_ranked(id: String, rank: int) -> void:
	weapons = arsenal.summary()
	if rank >= 3:
		stats["rank3_reached"] = maxi(int(stats["rank3_reached"]), 1)
	rank_changed.emit(id, rank)
	_restyle_crates()


## A RANK gate locks its machine 30 u ahead: the fielded machine closest to Rank III (the
## highest Rank below III, first fielded on ties; Meta-1 has no recipes to be "closest to");
## with none it becomes its fallback "+N" gate.
func _resolve_rank_gate(it: Dictionary) -> void:
	it["resolved"] = true
	var best: Dictionary = {}
	for m in arsenal.machines:
		if int(m["rank"]) < 3 and (best.is_empty() or int(m["rank"]) > int(best["rank"])):
			best = m
	if best.is_empty():
		var fb: Dictionary = it.get("fallback", {"op": "+", "value": 10})
		it["faces"] = [[str(fb.get("op", "+")), float(fb.get("value", 10))]]
		it["face"] = 0
		_sync_face(it)
		it["value0"] = float(it["value"])
		_style_gate(it)
		return
	it["rank_id"] = str(best["id"])
	_style_gate(it)


# ------------------------------------------------------------------ machine targets

## Live hostiles for the machines (squads, turrets, barricades, geodes, the fortress; never
## crates or gates) ahead within `reach`, whose span is within `lateral` of `x`, nearest first.
func machine_targets(x: float, lateral: float, reach: float, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var near := d - 0.5
	var far := d + reach
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		var di := float(it["d"])
		if di < near:
			continue
		if di > far:
			break
		if not it["alive"]:
			continue
		var k := str(it["kind"])
		if k == "gate" or k == "crate":
			continue
		if absf(float(it["x"]) - x) > lateral + _hw(it):
			continue
		out.append(it)
		if out.size() >= count:
			break
	return out


## Live hostiles (not crates or gates) whose span reaches within `r` of world point `pos`.
func machine_targets_near(pos: Vector3, r: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pd := -pos.z
	for i in range(maxi(_tk - 4, 0), _targ.size()):
		var it := _targ[i]
		var di := float(it["d"])
		if di > pd + r + 3.0:
			break
		if not it["alive"]:
			continue
		var k := str(it["kind"])
		if k == "gate" or k == "crate":
			continue
		var depth := Balance.squad_depth(float(it.get("w", 2.4)), float(it.get("hp", 1))) if k == "squad" else 0.4
		var dz := 0.0
		if pd < di:
			dz = di - pd
		elif pd > di + depth:
			dz = pd - di - depth
		var dx := maxf(absf(float(it["x"]) - pos.x) - _hw(it), 0.0)
		if dx * dx + dz * dz <= r * r:
			out.append(it)
	return out


## The squad (clash) or the fortress (siege) the army is locked with, {} otherwise.
func engaged() -> Dictionary:
	if (state == State.CLASH or state == State.SIEGE) and not _foe.is_empty() and _foe.get("alive", false):
		return _foe
	return {}


## Half span of an item (corridor / overlap tests).
func half_span(it: Dictionary) -> float:
	return _hw(it)


func _count_kills(source: String, n: float) -> void:
	stats["kills_total"] = float(stats["kills_total"]) + n
	if ArsenalData.MACHINES.has(source):
		var km: Dictionary = stats["kills_by_machine"]
		km[source] = float(km.get(source, 0.0)) + n
		var kf: Dictionary = stats["kills_by_family"]
		var f := ArsenalData.family_of(source)
		kf[f] = float(kf.get(f, 0.0)) + n


# ------------------------------------------------------------------ hero

func _hero_rate() -> float:
	return float(def["rate"]) * (1.0 + float(power["rate"]))


## Hero damage per hit: base + damage gates, x the hero level multiplier (profile / RunHero). A v3 row's
## damage is final (a float): only Reinforcements apply on top (LevelSim.hero_damage).
func _hero_damage() -> float:
	if _v3:
		var assist: Dictionary = profile.get("assist", {}) if profile.get("assist") is Dictionary else {}
		return (float(def["damage"]) + float(power["dmg"])) * (1.0 + float(assist.get("dmg_add", 0.0)))
	return float(int(def["damage"]) + int(power["dmg"])) * hero_mult("dmg_mult")


func _hero_attack(dt: float) -> void:
	if _new_kind:
		_kind_attack(dt)
		return
	_atk_cd -= dt
	if _atk_cd > 0.0:
		return
	# Base shots per cast (the Seer's twin orbs; Bolt's Forked Fox chain every 3rd cast) + power.
	var base := int(def.get("targets", 1)) + int(power["multi"])
	var shots := hero.cast_shots() + int(power["multi"])
	var corridor := float(def.get("corridor", Balance.CORRIDOR))
	var list := targets(hx, corridor, float(def["range"]), shots, true)
	if list.is_empty():
		_atk_cd = 0.0
		return
	# Extra shots never split onto the partner of a crate pair (opening one folds the other).
	for j in range(list.size() - 1, 0, -1):
		if list[j].has("pair") and list[0].has("pair") and int(list[j]["pair"]) == int(list[0]["pair"]) and str(list[j]["kind"]) == "crate":
			list.remove_at(j)
	_atk_cd += 1.0 / _hero_rate()
	_atk_cd = maxf(_atk_cd, 0.02)
	hero.strike()
	var dmg := _hero_damage()
	for k in shots:
		# A chained shot (beyond the base) only goes to another target.
		if k >= base and k >= list.size():
			continue
		var it: Dictionary = list[mini(k, list.size() - 1)]
		if not it["alive"]:
			continue
		var at := aim_point(it)
		_shot_fx(at, k)
		var kind := str(it["kind"])
		if kind == "squad":
			it["hero_hit_t"] = t
		elif kind == "gate" and bool(def.get("reveal_row", false)):
			_reveal_row(it)
		# The hero paints what it hits: PAINT machines follow (§2.2).
		if kind != "gate" and kind != "crate":
			painted = it
			_paint_t = ArsenalData.PAINT_S
		# A fielded Prism amps every hero shot, gate hits and close targets too (bucket 2), on the
		# shot's damage before the splash: LevelSim.hero_damage, which LevelGen built the levels with
		# (owner decision 10.10, docs/design/sim_drift_report.md). The flash shows where it crosses.
		var n := dmg * (1.0 + arsenal.prism_amp()) if arsenal else dmg
		if arsenal and k == 0 and kind != "gate" and arsenal.prism_crosses(it):
			effects.prism_flash(arsenal.prism_pos(), WeaponModels.glow_color("prism"), (at - arsenal.prism_pos()).normalized(), 1)
		# The Seer fills charge gates faster (HEROES.charge_mult).
		if kind == "gate" and str(_gate_face(it)[0]) == "charge":
			n *= float(def.get("charge_mult", 1.0))
		if kind == "squad":
			n += float(def["splash"])
		# ... and land Mark's vs (bucket 3).
		if kind == "squad" and arsenal:
			n *= arsenal.statuses.vs(it)
		hurt(it, n, "hero")
		if kind == "fortress":
			juice.add_trauma(0.08)


## A new hero kind's volley (§6 Run lines, LevelSim._kind_attack): the starters' cooldown and targeting
## (corridor, range, gates and crates, never the partner of a crate pair), the shots of HeroKinds.volley_shots
## + power gates, then HeroKinds.attack applies the pattern and its procs through kind_view (hits land via
## hurt as "hero" shots with MARK's vs) and sends the volley's `hero_attack` fx (HeroFx draws it).
func _kind_attack(dt: float) -> void:
	_atk_cd -= dt
	if _atk_cd > 0.0:
		return
	var shots := HeroKinds.volley_shots(kind_view, def) + int(power["multi"])
	var list := targets(hx, float(def.get("corridor", Balance.CORRIDOR)), float(def["range"]), shots, true)
	if list.is_empty():
		_atk_cd = 0.0
		return
	# Extra shots never split onto the partner of a crate pair (opening one folds the other).
	for j in range(list.size() - 1, 0, -1):
		var pj: Dictionary = list[j]
		if pj.has("pair") and list[0].has("pair") and int(pj["pair"]) == int(list[0]["pair"]) and str(pj["kind"]) == "crate":
			list.remove_at(j)
	_atk_cd += 1.0 / _hero_rate()
	_atk_cd = maxf(_atk_cd, 0.02)
	hero.strike()
	# The volley's targets as KindView rows (LevelSim._kind_attack's: id, kind, d, x, hp; a gate's face op, a
	# squad's soldiers, half width and Flying).
	var rows: Array = []
	for it in list:
		var kind := str(it["kind"])
		var row := {"id": int(it["kid"]), "kind": kind, "d": float(it["d"]), "x": float(it["x"]),
				"hp": float(it.get("hp", 0.0))}
		if kind == "gate":
			row["op"] = str(_gate_face(it)[0])
		elif kind == "squad":
			it["hero_hit_t"] = t
			row["n"] = float(it["hp"])
			row["hw"] = float(it.get("w", 2.4)) * 0.5
			var props: Variant = it.get("props")
			var grounded := float(it.get("ground_end", 0.0)) > t
			row["flying"] = props is Array and (props as Array).has("flying") and not grounded
		if kind != "gate" and kind != "crate":
			# The hero paints what it hits: PAINT machines follow (§2.2).
			painted = it
			_paint_t = ArsenalData.PAINT_S
		rows.append(row)
	# The Prism amps every hero shot (as the starters' and LevelSim.hero_damage).
	var dmg := _hero_damage() * (1.0 + arsenal.prism_amp()) if arsenal else _hero_damage()
	if arsenal and str(list[0]["kind"]) != "gate" and arsenal.prism_crosses(list[0]):
		effects.prism_flash(arsenal.prism_pos(), WeaponModels.glow_color("prism"),
				(aim_point(list[0]) - arsenal.prism_pos()).normalized(), 1)
	HeroKinds.attack(kind_view, def, rows, shots, dmg)


## Сірко form V (KindView.buff &"volley_status"): an army volley on squad `it` also applies the buff's
## statuses (id -> stacks).
func _volley_buff(it: Dictionary) -> void:
	if not it["alive"] or arsenal == null or arsenal.statuses == null:
		return
	var sts: Variant = kind_view.buff_data(&"volley_status").get("statuses", {})
	if sts is Dictionary:
		for st: String in (sts as Dictionary):
			arsenal.statuses.apply(it, st, 1.0, {"id": "hero"})


func _shot_fx(at: Vector3, k: int) -> void:
	var from := hero.muzzle() + Vector3(0.18 * k, 0, 0)
	if _attack_kind == HeroKinds.ATTACK_ORBS:
		# Twin violet orbs from her hands, curling onto their targets.
		from = hero.muzzle() + Vector3(-0.22 if k % 2 == 0 else 0.22, 0.12, 0.0)
		effects.projectile(from, at, "arcane", from.distance_to(at) / 17.0, Callable())
		effects.muzzle(from, Effects.ARCANE)
		if k == 0:
			Audio.play("laser", -16.0, 0.3)
	elif _attack_kind == HeroKinds.ATTACK_DART:
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
		var x := float(it.get("x0", it["x"]))
		if (it["alive"] or str(it["kind"]) == "blade") and absf(hx - x) < vault_reach(it):
			hero.vault()


## How far across from vault item `it` a runner still hops over it (sweepers span the bridge).
func vault_reach(it: Dictionary) -> float:
	if str(it.get("type", "")) == "sweeper":
		return 99.0
	return _hw(it) + (float(it.get("len", 0.0)) if str(it["kind"]) == "blade" else 0.0) + 0.35


## The items the hero and the champions hop over, by d (ChampionView vaults its champions).
func vault_items() -> Array[Dictionary]:
	return _vaults


# ------------------------------------------------------------------ ult

func _charge(points: float) -> void:
	if ult_clock.active():
		return
	ult_points = minf(ult_points + maxf(points, 0.0) * (1.0 if _v3 else hero_mult("ult_rate_mult")), float(ult["charge"]))
	_emit_ult()


func _emit_ult() -> void:
	var ratio := clampf(ult_points / float(ult["charge"]), 0.0, 1.0)
	if ult_clock.active():
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
	_ult_uses += 1
	_cast_posed = false
	juice.hitstop(0.07)
	juice.haptic("ult")
	HeroKinds.ult_cast(kind_view, _ult_kind, ult)
	_emit_ult()
	return true


func _ult_step(dt: float) -> void:
	if ult_clock.active():
		HeroKinds.ult_step(kind_view, _ult_kind, ult, dt)
		# A new kind's shape ended: the charge ring comes back (the starters do it on ult_end / ult_waves_end).
		if hero_fx and not ult_clock.active():
			_emit_ult()


## The run side of the ult rules' fx events (RunKindView.fx): poses, VFX, SFX, HUD.
func _ult_fx(event: StringName, data: Dictionary) -> void:
	match event:
		&"ult_cast":
			_ult_cast_fx()
		&"ult_step":
			if _rift:
				_rift.position = _rift_pos()
		&"ult_tick":
			if _ult_kind == &"rift":
				_rift_tick_fx()
			else:
				_storm_tick_fx()
		&"ult_tick_done":
			if _ult_kind == &"rift":
				_rift_tick_done_fx()
			else:
				_storm_tick_done_fx()
		&"ult_end":
			if _rift:
				effects.rift_close(_rift)
				_rift = null
			_emit_ult()
		&"ult_wave":
			_quake_wave_fx(float(data["near"]), float(data["spacing"]), int(data["wave"]))
		&"ult_waves_end":
			_emit_ult()


## A new hero kind's ult shape event (RunKindView.fx `ult_shape`; §6.2-6.10, §6.28, §6.29): the cast pose
## and its beat at the start, then HeroFx draws the shape; the end brings the charge ring back.
func _ult_shape_fx(data: Dictionary) -> void:
	var ph := StringName(str(data.get("phase", "")))
	if ph == &"start":
		_kind_cast_pose(float(data.get("s", 0.0)))
	if hero_fx:
		hero_fx.on_shape(data)
	if ph == &"end":
		_emit_ult()


## A new hero kind's volley (RunKindView.fx `hero_attack`): HeroFx draws it.
func _hero_attack_fx(data: Dictionary) -> void:
	if hero_fx:
		hero_fx.on_attack(data)


## The cast pose and the beat of a new kind's ult, once per cast (its `ult_cast` or its shape's start).
## `sec` = how long the shape lasts (0 = a one-off hit: the pose plays its default length).
func _kind_cast_pose(sec: float) -> void:
	if _cast_posed:
		return
	_cast_posed = true
	hero.cast_ult(clampf(sec, 1.0, 2.2) if sec > 0.0 else 1.4)
	juice.add_trauma(0.35)


## `hits` ult hits on gate `it` when it is at or ahead of the hero: hero hits with the Prism amp
## (LevelSim._ult_hit: hero_damage). area_hit's gates and RunKindView.hit on a gate id land here.
func ult_gate_hit(it: Dictionary, hits := 1.0) -> void:
	if float(it["d"]) >= d:
		var amp := 1.0 + arsenal.prism_amp() if arsenal else 1.0
		_hit_gate(it, float(_hero_damage()) * amp * hits)


## KindView.reveal: the hidden gates with d in [d0, d1] show their value (LevelSim.reveal).
func reveal_gates(d0: float, d1: float) -> void:
	for g: Dictionary in _gates:
		var gd := float(g["d"])
		if gd > d1:
			break
		if gd >= d0 and g["alive"] and not bool(g["revealed"]):
			_reveal_gate(g)
			_style_gate(g)


## KindView.lose: `n` soldiers off the army's front ranks (the Healers are fed as for any loss).
func kind_lose(n: int) -> void:
	if n > 0 and army > 0:
		_change_army(-mini(n, army), Vector3.INF, Vector3.ZERO, "front")


## RunKindView.revive_champion: the Healer hero's touch on champion `id` as it stands up (HeroFx).
func hero_revived(id: String) -> void:
	if hero_fx and champ_view:
		var c := champ_view.model(id)
		if c:
			hero_fx.on_revive(c.pos)


func _ult_cast_fx() -> void:
	match _ult_kind:
		&"rift":
			hero.cast_ult(_ult_left)
			_rift = effects.rift_open(_rift_pos())
			effects.flash(hero.muzzle(), Effects.ARCANE, 2.2, 0.4)
			juice.add_trauma(0.45)
			Audio.play("upgrade", -2.0)
			Audio.play("tesla", -6.0)
		&"storm":
			hero.cast_ult(_ult_left)
			effects.flash(hero.muzzle(), Color(0.6, 0.9, 1.0), 2.4, 0.35)
			effects.shockwave(Vector3(hx, 0.0, -d), Color(0.5, 0.8, 1.0), 3.0)
			juice.add_trauma(0.55)
			Audio.play("tesla", 0.0)
		&"quake":
			hero.cast_ult(HeroKinds.WAVES_CAST_POSE)
			juice.add_trauma(0.8)
			effects.shockwave(Vector3(hx, 0.0, -d), EMERALD, 3.2)
			Audio.play("explosion", -2.0)
		_:
			# A new hero kind: its pose here, its look on the shape events (HeroFx).
			_kind_cast_pose(float(ult.get("duration", 0.0)))


## Bolt storm tick, before the hit: bolts on what is in range, spare bolts on the bridge.
func _storm_tick_fx() -> void:
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


func _storm_tick_done_fx() -> void:
	Audio.play("tesla", -7.0, 0.2)
	juice.add_trauma(0.12)


## Seer ult "Star Rift": the arcane barrage (orbs falling out of the rift onto everything in
## range; the hit, HeroKinds.ult_step, takes squads, turrets, crates, barricades and additive
## gates like the storm).
func _rift_tick_fx() -> void:
	var reach := float(ult["range"])
	var n := 5 if quality_high else 3
	for it in _ult_targets(d - 0.5, d + reach):
		if n <= 0:
			break
		if str(it["kind"]) == "gate":
			continue
		n -= 1
		var at := aim_point(it)
		var src := _rift_pos() + Vector3(randf_range(-2.4, 2.4), randf_range(2.6, 4.0), randf_range(-0.6, 0.6))
		effects.projectile(src, at, "arcane", src.distance_to(at) / 24.0, Callable())


func _rift_tick_done_fx() -> void:
	# A slow-time pulse rolls out of the rift on every tick.
	effects.shockwave(_rift_pos(), Effects.ARCANE, 2.6)
	Audio.play("laser", -10.0, 0.3)
	juice.add_trauma(0.07)


## Where the Seer's rift hangs: `ahead` u in front of the hero, drifting with her lane.
func _rift_pos() -> Vector3:
	return Vector3(hx * 0.35, 0.0, -(d + float(ult.get("ahead", 7.0))))


## Speed of enemies and hazards (1 normally; 1 - slow while a slowing ult, the Seer's rift, runs).
func hazard_slow() -> float:
	if _ult_left <= 0.0:
		return 1.0
	return HeroKinds.hazard_slow(_ult_kind, ult, _ult_left)


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


## An ult hit on everything alive in [a, b] (RunKindView.area_hit; kills / breaks already x
## the Ult Rank power).
func _ult_hit(a: float, b: float, gates: bool, kills: float, breaks: float) -> void:
	for it in _ult_targets(a, b):
		match str(it["kind"]):
			"squad":
				hurt(it, kills, "ult")
			"gate":
				if gates:
					# A hero hit, Prism amp included (LevelSim._ult_hit: hero_damage).
					ult_gate_hit(it)
			_:
				hurt(it, breaks, "ult")


func _quake_wave_fx(near: float, spacing: float, wave: int) -> void:
	var pts: Array[Vector3] = []
	var zc := -(near + spacing * 0.5)
	for k in 9:
		pts.append(Vector3(-Balance.BRIDGE_HALF + 0.4 + k * (Balance.BRIDGE_HALF * 2.0 - 0.8) / 8.0, 0.0, zc + randf_range(-0.6, 0.6)))
	effects.crystal_spikes(pts, Vector3(hx, 0, -_quake_d + 2.0), Color(0.12, 0.85, 0.4))
	effects.shockwave(Vector3(hx * 0.5, 0.0, zc), EMERALD, 2.4)
	juice.add_trauma(0.3 if wave == 0 else 0.18)
	Audio.play("explosion" if wave == 0 else "cannon", -3.0 if wave == 0 else -6.0, 0.15)


# ------------------------------------------------------------------ clash and siege

func _begin_clash(it: Dictionary) -> void:
	state = State.CLASH
	_foe = it
	it["drill_k"] = army_view.drill_mult(it, t)
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
		if army >= 1 and champions.active():
			_champion_clash_tick(foes)
		elif army >= 1:
			var hit := mini(_burst(mini(army, ceili(foes))), mini(army, ceili(foes)))
			# Slowed squads (Seer's rift) kill fewer of ours; Drill makes a hit squad lose more. A held
			# squad (KindView.hold, H2) deals x (1 - strength) too.
			var lost := hit
			var slow := hazard_slow() * (1.0 - kind_view.hold_k(_foe))
			if slow < 1.0:
				_slow_acc += float(hit) * slow
				lost = int(floor(_slow_acc + 0.0001))
				_slow_acc -= float(lost)
			# Вартан's wall HP (KindView "clash" wards) takes the squad's blows first.
			lost -= kind_view.spend_wards(&"clash", lost)
			_change_army(-lost, Vector3.INF, Vector3.ZERO, "front")
			stats["clash_losses"] = int(stats["clash_losses"]) + lost
			# An exposed squad (KindView.expose: Веста / Сірко form II) loses x (1 + add).
			hurt(_foe, float(hit) * float(_foe.get("drill_k", 1.0)) * kind_view.exposed(_foe), "clash")
			_clash_fx()
		elif champions.active() and _champion_absorb_tick(foes):
			pass
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
	_siege_t = t
	_foe = it
	_tick = 0.0
	_finale = Balance.FINALE_TIME
	# Barracks Reserves: fresh soldiers join for the siege.
	var res := army_view.reserves()
	if res > 0:
		_change_army(res, Vector3(hx, 0.4, -d + 5.0), Vector3(1.2, 0.4, 0.8))
		_side_popup("+%d" % res, Vector3(hx, 1.6, -d + 1.0), GAIN, 1.0)
		juice.haptic("gate_good")
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
		if champions.active():
			_champion_siege_tick(f, hit)
		else:
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


# ------------------------------------------------------------------ champions (heroes design §4.2, §10.5)
# The rules are ChampionKinds over kind_view; these are the run's hooks, applied at the same
# moments as LevelSim (the H2 hook table). None of them runs while Champions.active() is false.

## Every active step, after the army moved and before the hazards and the clash / siege.
func _champions_step(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	champ_stepping = true
	champions.step(kind_view, dt)
	champ_stepping = false
	var us := Time.get_ticks_usec() - t0
	champ_perf["steps"] = int(champ_perf["steps"]) + 1
	champ_perf["us"] = int(champ_perf["us"]) + us
	champ_perf["max_us"] = maxi(int(champ_perf["max_us"]), us)
	if us > 250:
		champ_perf["over_250us"] = int(champ_perf["over_250us"]) + 1


## A clash tick with the army alive: a Guardian's shield makes it free, else the Guardian aura
## trims our losses (with the rift's slow and a hold on the squad; fractions carry); the squad takes
## the hit x Drill x the Warrior aura + Cleave; the front champion takes its share; then the Healers
## are fed.
func _champion_clash_tick(foes: float) -> void:
	var m := champions.members
	var hit := mini(_burst(mini(army, ceili(foes))), mini(army, ceili(foes)))
	var lost := 0
	if not ChampionKinds.tick_free(m):
		_clash_acc += float(hit) * hazard_slow() * (1.0 - kind_view.hold_k(_foe)) * ChampionKinds.clash_loss_mult(m)
		lost = mini(int(floor(_clash_acc + 0.0001)), army)
		# The whole soldiers due go, even past an army cap (no debt carried into later recruits).
		_clash_acc -= floorf(_clash_acc + 0.0001)
		# Вартан's wall HP (KindView "clash" wards) takes the squad's blows first.
		lost -= kind_view.spend_wards(&"clash", lost)
	var before := army
	_feed_hold = true
	_change_army(-lost, Vector3.INF, Vector3.ZERO, "front")
	_feed_hold = false
	stats["clash_losses"] = int(stats["clash_losses"]) + lost
	var foe := _foe
	var drill := float(foe.get("drill_k", 1.0))
	hurt(foe, (float(hit) * drill * ChampionKinds.clash_kill_mult(m) + ChampionKinds.cleave(m)) * kind_view.exposed(foe),
			"clash")
	# The tick that breaks the squad costs the front nothing (LevelSim._champ_tick).
	if foe["alive"]:
		ChampionKinds.clash_hit(kind_view, m, float(hit), champions.guardian_hero)
	ChampionKinds.feed(m, float(before - army))
	_clash_fx()


## A clash tick at army 0: the first living champion (front -> left -> right -> rear) takes it
## before the hero, the tick sized on its HP as the hero's is on hero_hp. False: none is left.
func _champion_absorb_tick(foes: float) -> bool:
	var who: Dictionary = {}
	for sl in ChampionKinds.ABSORB_ORDER:
		who = ChampionKinds.in_slot(champions.members, sl)
		if not who.is_empty():
			break
	if who.is_empty():
		return false
	var hp := maxi(ceili(float(who["hp"])), 1)
	var hit2 := maxi(int(minf(float(_burst(mini(hp, ceili(foes)))), foes)), 1)
	if not ChampionKinds.absorb_tick(kind_view, champions.members, float(hit2)):
		return false
	hurt(_foe, float(hit2), "clash")
	if champ_view:
		var c := champ_view.model(str(who["id"]))
		if c:
			effects.hit_spark(c.root + Vector3(0.0, 0.7, -0.2), Color(1.0, 0.8, 0.5))
	return true


## A siege tick with the army alive: as a clash tick, on the fortress (no Drill).
func _champion_siege_tick(f: Dictionary, hit: int) -> void:
	var m := champions.members
	var lost := 0
	if not ChampionKinds.tick_free(m):
		_clash_acc += float(hit) * (1.0 - kind_view.hold_k(f)) * ChampionKinds.clash_loss_mult(m)
		lost = mini(int(floor(_clash_acc + 0.0001)), army)
		# The whole soldiers due go, even past an army cap (no debt carried into later recruits).
		_clash_acc -= floorf(_clash_acc + 0.0001)
	var before := army
	_feed_hold = true
	_change_army(-lost, Vector3.INF, Vector3.ZERO, "front")
	_feed_hold = false
	hurt(f, float(hit) * ChampionKinds.clash_kill_mult(m) + ChampionKinds.cleave(m), "siege")
	# The tick that breaks the gate is the win: the result is final, the front takes nothing.
	if f["alive"]:
		ChampionKinds.clash_hit(kind_view, m, float(hit), champions.guardian_hero)
	ChampionKinds.feed(m, float(before - army))


## Hazard `it` (spiked barricade or blade) takes `lost` soldiers: the Healer aura trims it, a ready
## Guardian Blocks it (absorb_hazard); fractions carry. Returns the soldiers really lost (the
## Healers are fed by _army_changed).
func _champion_hazard(it: Dictionary, lost: int) -> int:
	var m := champions.members
	var lf := float(lost) * ChampionKinds.hazard_loss_mult(m)
	var kind := StringName(str(it["kind"]))
	lf = ChampionKinds.absorb_hazard(kind_view, m, int(it["kid"]), kind, lf, float(army), blob_radius())
	_haz_acc += lf
	var keep := mini(int(floor(_haz_acc + 0.0001)), army)
	_haz_acc -= floorf(_haz_acc + 0.0001)
	hazard_deaths -= float(lost - keep)
	return keep


## Mage aura: the soldiers' volley that hit squad `it` applies each living Mage's element status
## with its chance (ChampionKinds.volley_status).
func _volley_procs(it: Dictionary) -> void:
	if not it["alive"]:
		return
	for row: Dictionary in ChampionKinds.volley_status(champions.members):
		if _champ_rng.randf() < float(row["proc"]):
			arsenal.statuses.apply(it, str(row["status"]), 1.0, {"id": str(row["id"])})


## Healer Mend (RunKindView.add_soldiers): `n` soldiers come back at the blob front. Their «+N» is the
## champions' one-draw stamp over the Healer (ChampionView.mend_stamp on the champ_mend that follows), not
## an outlined popup (three Label3D, ~6 draws every pulse: §10.6).
func champion_mend(n: int) -> void:
	if n <= 0 or army <= 0:
		return
	var front := army_view.front_point()
	_change_army(n, front + Vector3(0.0, 0.5, 0.0), Vector3(0.45, 0.3, 0.2))


## The item behind KindView target id `id` ({} when there is none).
func kind_item(id: int) -> Dictionary:
	return items[id] if id >= 0 and id < items.size() else {}


## The rules' champ_* events (RunKindView.fx): the fall is remembered for the report, the rest
## is VFX and HUD (ChampionView).
func _champ_fx(event: StringName, data: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	if event == &"champ_down":
		var cause := "siege" if state == State.SIEGE else "clash"
		_champ_down[str(data.get("id", ""))] = {"t": snappedf(t, 0.1), "cause": cause}
	elif event == &"champ_revive":
		_champ_down.erase(str(data.get("id", "")))
	if champ_view:
		champ_view.on_fx(event, data)
	if champ_stepping:
		champ_perf["fx_us"] = int(champ_perf["fx_us"]) + Time.get_ticks_usec() - t0


## result.team_report: Champions.report() + when and how each fallen champion fell (§10.5,
## Rewards._team_run reads t and cause).
func _team_report() -> Array:
	var out := champions.report()
	for row: Dictionary in out:
		var down: Dictionary = _champ_down.get(str(row["id"]), {})
		if not down.is_empty():
			row["t"] = down["t"]
			row["cause"] = down["cause"]
	return out


## Label-carrying items the HUD keeps the champion medallions clear of: the next gate row ahead
## and the hostiles with counters within `reach` u (filled into `out`).
func hud_label_items(reach: float, out: Array) -> void:
	out.clear()
	var row := -1
	for i in range(maxi(_tk - 2, 0), _targ.size()):
		var it := _targ[i]
		var di := float(it["d"])
		if di < d:
			continue
		if di > d + reach:
			break
		if not it["alive"] or not it.has("label") or str(it["kind"]) == "fortress":
			continue
		if str(it["kind"]) == "gate":
			var r := int(it.get("row", -1))
			if row == -1:
				row = r
			elif r != row:
				continue
		out.append(it)


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
	var victory := EconData.victory_coins(level, survivors)
	result = {"coins_run": coins, "victory": victory, "mult": mult,
			"total": int(round(float(victory + coins) * mult)), "survivors": survivors}
	_fill_result(true)
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


## Run.result keys the meta reads (contracts §6.5 input): won, level, run_id, pickups,
## bridge_fraction, fielded, new_unlock, crowns, shards, discoveries, boss_core, stats.
func _fill_result(won: bool) -> void:
	result["won"] = won
	result["level"] = level
	result["run_id"] = int(profile.get("run_id", 0))
	result["pickups"] = coins
	result["bridge_fraction"] = 1.0 if won else clampf(d / maxf(length, 1.0), 0.0, 1.0)
	result["fielded"] = arsenal.fielded_report() if arsenal else []
	result["new_unlock"] = new_unlock
	result["shards"] = 0
	result["discoveries"] = []
	result["boss_core"] = 1 if won and ArsenalData.is_boss(level) else 0
	var crowns := 0
	if won:
		crowns = 1
		var need := float(EconData.CROWN_ARMY.get(level, EconData.CROWN_ARMY.get(str(level), expected * 0.6)))
		if _army_at_fortress >= 0 and float(_army_at_fortress) >= need:
			crowns = 2
	result["crowns"] = crowns
	var st := stats
	st["wins"] = 1 if won else 0
	st["kills_total"] = int(round(float(st["kills_total"])))
	for k in ["kills_by_machine", "kills_by_family"]:
		var dd: Dictionary = st[k]
		for id: String in dd:
			dd[id] = int(round(float(dd[id])))
	var sc: Dictionary = st["statuses"]
	if arsenal:
		for key in ["freeze", "burn", "mark", "stun", "jolt", "seal"]:
			sc[key] = int(arsenal.statuses.counts.get(key, 0))
	st["hazard_losses"] = int(round(hazard_deaths))
	st["levels_no_hazard_loss"] = 1 if won and hazard_deaths < 0.5 else 0
	st["ult_uses"] = _ult_uses
	st["army_peak"] = _peak
	st["army_at_fortress"] = maxi(_army_at_fortress, 0)
	st["survivors"] = int(result.get("survivors", 0))
	st["stairs_mult"] = float(result.get("mult", 1.0)) if won else 0.0
	st["stairs_reached_3"] = 1 if won and float(result.get("mult", 1.0)) >= 3.0 else 0
	st["stairs_reached_5"] = 1 if won and float(result.get("mult", 1.0)) >= 5.0 else 0
	if _siege_t > 0.0 and won:
		st["fortress_time"] = snappedf(t - _siege_t, 0.1)
		st["fortress_fast"] = 1 if t - _siege_t <= 3.0 else 0
	var fams := {}
	var fl: Array = result["fielded"]
	for f: Dictionary in fl:
		var fam := ArsenalData.family_of(str(f["id"]))
		fams[fam] = int(fams.get(fam, 0)) + 1
		if int(f["rank"]) >= 3:
			st["rank3_reached"] = 1
	var fam3 := false
	for fam2: String in fams:
		fam3 = fam3 or int(fams[fam2]) >= 3
	st["wins_family3"] = 1 if won and fam3 else 0
	st["wins_no_machines"] = 1 if won and fl.is_empty() else 0
	var ld := str(profile.get("lead", ""))
	if won and ld != "":
		(st["wins_with_lead"] as Dictionary)[ld] = 1
	result["stats"] = st
	if champions.active():
		result["team_report"] = _team_report()
		var team: Dictionary = profile.get("team", {}) if profile.get("team") is Dictionary else {}
		var syn: Variant = team.get("synergy_ids", [])
		result["synergies"] = (syn as Array).duplicate() if syn is Array else []


func _lose(reason: String) -> void:
	if state == State.LOST or _won:
		return
	state = State.LOST
	_end_t = 0.0
	_foe = {}
	arsenal.stop()
	result = {"coins_run": coins, "victory": 0, "mult": 1.0, "total": coins, "survivors": 0, "reason": reason}
	_fill_result(false)
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
	if champ_view:
		champ_view.draw(dt)
	if hero_fx:
		hero_fx.draw(dt)
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
	_army_label.visible = army > 0 and not (on_stairs and _stair_phase >= 2) and not hide_army_label
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
			# Closer and lower: the fortress towers over the army ramming its gate. The distance
			# grows until the whole fortress (towers included) fits the screen's width.
			look = Vector3(0.0, 2.4, fz - 1.0)
			var dir := Vector3(0.0, 6.6, 12.8).normalized()
			var fw := 12.0
			var fnode := _fortress.get("node") as Node3D
			if fnode:
				fw = float(fnode.get_meta("visual_width", fnode.get_meta("width", 7.0)))
			var vp := get_viewport().get_visible_rect().size
			var aspect := vp.x / maxf(vp.y, 1.0)
			var half_h := atan(tan(deg_to_rad(fov) * 0.5) * aspect)
			var dist := maxf(14.4, (fw * 0.5 + 0.7) / tan(half_h))
			pos = look + dir * dist
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
	hz_t = t
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
