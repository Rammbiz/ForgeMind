class_name CacheAltar
extends Node3D
## The Cache opening ceremony on the Crystal Altar (arsenal_design.md §5.6, §5.7): World Caches
## from the Vault, first unlocks and every Legendary+ walkout. The reveal bundle (§6.6) was
## rolled, granted and SAVED by Meta.open_cache() before this scene exists: the tell shows the
## final best rarity from the first frame, there is no suspense ladder and nothing can reroll.
##
## Beats (EconData.REVEAL; "Швидкі церемонії" runs them at 0.5x, Reduce Motion / "Швидке
## відкриття" cross-fade straight to the cards with one chime):
##   Present 0-0.35 s  the Cache drops onto the altar (ease-out-back), dust ring, rune ring
##                     lights; idle breathe; the odds (i) chip and the Legendary pity bar show.
##   Strike            one tap or 1.0 s auto: the camera swings to 3/4 behind the hero, who
##                     strikes (Bolt: lightning from the sky, Titan: emerald fist and quake).
##   Tell   +0.15 s    the crack leaks the BEST rarity colour; Legendary+ light pillars.
##   Burst  +0.25 s    80 ms hit-stop, the egg shatters, shockwave and sparks by tier, camera
##                     trauma 0.35 (0.6 Legendary+), a light beam in the rarity colour.
##   Fan-out +0.35 s   cards fly face-down into an arc (60 ms stagger, ascending rarity).
##   Flips             tap (next card) or "Відкрити все": C 0.25 / R 0.35 / E 0.5 s; NEW
##                     machines and Legendary+ walk out: the card dissolves into the 3D
##                     machine, it rolls onto the altar, turns and fires one volley; identity
##                     in three beats (family glyph -> world emblem -> name + model).
##   Sparks +0.40 s    duplicates spark into their blueprint bars (count-up, green arrow).
##   Summary           grid by rarity, the coin bonus flies to the chip; "Готово" (primary),
##                     "Покращити <machine>" (secondary, deep link).
## Hold 0.3 s anywhere (or Android back) -> summary (Meta.note_skip("altar")); a NEW machine's
## first walkout still plays. `done(action, id)`: action "done" | "upgrade" (id = machine).

signal done(action: String, id: String)

const HOLD_SKIP := 0.3
const BASE := Vector3(0, 0, -10)
## Camera framings relative to the altar: [position, look target, v_offset].
const CAM_WIDE := [Vector3(0.6, 2.7, 5.6), Vector3(0, 1.1, 0), 0.0]
const CAM_FAN := [Vector3(0.0, 2.5, 5.9), Vector3(0, 0.95, 0), -0.95]
const CAM_WALK := [Vector3(-0.35, 2.25, 3.9), Vector3(0, 0.8, 0), -0.45]
const CAM_SUMMARY := [Vector3(0.0, 2.9, 7.4), Vector3(0, 0.95, 0), -1.75]

var rev: Dictionary = {}
var hero_id := "bolt"
## 1 = design timings; 0.5 with "Швидкі церемонії".
var speed := 1.0
var quick := false
var state := "present"
## Dev hook (galleries): freezes the beat timeline (visuals keep animating).
var hold_clock := false

var track: Track
var altar: Node3D
var cache: Node3D
var hero: Node3D
var cam: Camera3D
var fx: Effects
var ui: CanvasLayer

var _t := 0.0
var _anim_t := 0.0
var _freeze := 0.0
var _trauma := 0.0
var _events: Array = []
var _clock := 0.0
var _cam_from: Array = CAM_WIDE
var _cam_to: Array = CAM_WIDE
var _cam_k := 1.0
var _cam_dur := 0.5
var _strike := -1.0
var _strike_dur := 0.6
var _drop := -1.0
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _beam_k := 0.0
var _machine: Node3D
var _machine_t := -1.0
var _machine_fire := 0.0
var _machine_from := Vector3.ZERO
var _cards: Array[AltarCard] = []
var _next := 0
var _open_all := false
var _busy := false
var _hold := -1.0
var _root_ui: Control
var _title: Label
var _info: RoundButton
var _pity: Control
var _hint: Label
var _open_btn: Button
var _done_btn: Button
var _up_btn: Button
var _chip: HubTopBar.HubChip
var _coins_row: HBoxContainer
var _rays: UIKit.Rays
var _flash: ColorRect
var _ident: Control
var _ident_glyph: Icons
var _ident_world: Label
var _ident_name: Label
var _ident_sub: Label
var _sheet: Control
var _summary_shown := false


## A ceremony for the reveal bundle `p_rev` (Meta.open_cache / roll_cache result, §6.6).
func setup(p_rev: Dictionary) -> void:
	rev = p_rev


func _ready() -> void:
	hero_id = Meta.hero()
	if not ResourceLoader.exists(HeroModels.HERO_DIR + hero_id + ".glb"):
		hero_id = "bolt"
	if bool(Meta.setting("fast_ceremonies", false)):
		speed = 0.5
	quick = UITokens.reduce_motion() or bool(Meta.setting("quick_reveal", false))
	_build_world()
	_build_ui()
	Audio.play_music("canyon")
	if quick:
		_quick()
		return
	_present()


# ------------------------------------------------------------------ world

func _build_world() -> void:
	var hq := Save.quality == "high"
	track = Track.new()
	add_child(track)
	track.build(48.0, hq, Worlds.LIST[Worlds.ORDER[0]])
	altar = CacheModels.altar()
	altar.position = BASE
	add_child(altar)
	CacheModels.altar_light(altar, 0.3, Color(0.5, 0.8, 1.0))
	cache = CacheModels.cache(str(rev.get("type", "world")))
	add_child(cache)
	CacheModels.place_on_altar(altar, cache)
	cache.visible = false
	hero = HeroModels.hero(hero_id)
	hero.position = BASE + Vector3(-1.55, 0, 1.35)
	var to := (BASE - hero.position)
	hero.rotation.y = atan2(to.x, to.z)
	add_child(hero)
	fx = Effects.new()
	add_child(fx)
	cam = Camera3D.new()
	cam.far = 300.0
	add_child(cam)
	cam.make_current()
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.62
	cyl.height = 26.0
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = CacheModels.BEAM_SHADER
	_beam_mat.set_shader_parameter("noise_tex", CacheModels.NOISE_TEX)
	_beam_mat.set_shader_parameter("strength", 0.0)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	_set_cam(CAM_WIDE, 0.0)


func _socket() -> Vector3:
	var s: Node3D = altar.get_meta("socket")
	return s.global_position


func _egg_centre() -> Vector3:
	return _socket() + Vector3(0, float(cache.get_meta("height", 1.0)) * 0.5, 0)


## Moves the camera to framing `f` ([pos, look, v_offset] relative to the altar) over `dur`.
func _set_cam(f: Array, dur: float) -> void:
	_cam_from = _cam_now()
	_cam_to = f
	_cam_dur = maxf(dur, 0.0)
	_cam_k = 0.0 if dur > 0.0 else 1.0
	if dur <= 0.0:
		_apply_cam(f)


func _cam_now() -> Array:
	if cam == null or not cam.is_inside_tree():
		return CAM_WIDE
	var look: Vector3 = cam.get_meta("look", Vector3(0, 1, 0))
	return [cam.position - BASE, look, cam.v_offset]


func _apply_cam(f: Array) -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(52.0 * 0.5)) / aspect))
	cam.position = BASE + Vector3(f[0])
	cam.set_meta("look", Vector3(f[1]))
	cam.look_at(BASE + Vector3(f[1]))
	cam.v_offset = float(f[2])


func _strike_cam() -> Array:
	var d := (BASE - hero.position)
	d.y = 0.0
	d = d.normalized()
	var right := Vector3(-d.z, 0, d.x)
	var p := hero.position - d * 2.9 + right * 0.9 + Vector3(0, 2.0, 0) - BASE
	return [p, Vector3(0.1, 0.95, 0), 0.0]


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	_root_ui = Control.new()
	_root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_ui.theme = UIKit.theme()
	_root_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ui.gui_input.connect(_on_input)
	ui.add_child(_root_ui)
	var ins := UIKit.safe_insets(get_viewport())
	var vp := get_viewport().get_visible_rect().size
	# Bottom shade so the cards read over the road.
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.015, 0.05, 0.0))
	g.set_color(1, Color(0.01, 0.015, 0.05, 0.86))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2(0, vp.y * 0.45)
	shade.size = Vector2(vp.x, vp.y * 0.55)
	_root_ui.add_child(shade)
	var top := TextureRect.new()
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.01, 0.015, 0.05, 0.75))
	g2.set_color(1, Color(0.01, 0.015, 0.05, 0.0))
	var gt2 := GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill_from = Vector2(0.5, 0.0)
	gt2.fill_to = Vector2(0.5, 1.0)
	top.texture = gt2
	top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.stretch_mode = TextureRect.STRETCH_SCALE
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size = Vector2(vp.x, 260 + ins.y)
	_root_ui.add_child(top)
	_rays = UIKit.Rays.new()
	_rays.color = Color(1, 1, 1, 0)
	_rays.count = 18
	_rays.inner = 0.08
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.size = Vector2(vp.x * 1.8, vp.x * 1.8)
	_root_ui.add_child(_rays)
	# Title, odds (i), pity bar.
	var type := str(rev.get("type", "world"))
	_title = UIKit.gradient_heading(Loc.t(str((EconData.CACHES[type] as Dictionary)["name"])), 46)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size = Vector2(vp.x, 60)
	_title.position = Vector2(0, ins.y + 96)
	_root_ui.add_child(_title)
	_info = RoundButton.new(26.0)
	_info.icon_kind = "info"
	_info.position = Vector2(vp.x - 86 - ins.z, ins.y + 98)
	_info.pressed.connect(_toggle_odds)
	_root_ui.add_child(_info)
	_pity = VaultView.PityBar.make()
	_pity.custom_minimum_size = Vector2(440, 0)
	_pity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pity.position = Vector2((vp.x - 440) * 0.5, ins.y + 160)
	_pity.size = Vector2(440, 56)
	_root_ui.add_child(_pity)
	# Coins chip (top right): the bonus slot flies into it at the summary.
	_chip = HubTopBar.HubChip.new("coins")
	_root_ui.add_child(_chip)
	_chip.set_amount(Meta.currency("coins") - int(rev.get("coins", 0)), false)
	_chip.size = _chip.custom_minimum_size
	_chip.position = Vector2(vp.x - _chip.size.x - 22 - ins.z, ins.y + 22)
	_hint = UIKit.heading(Loc.t("TAP_TO_CRACK"), 28, UIKit.GOLD_LIGHT, 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.size = Vector2(vp.x, 40)
	_hint.position = Vector2(0, vp.y * 0.80)
	_root_ui.add_child(_hint)
	var hint_tw := _hint.create_tween().set_loops()
	hint_tw.tween_property(_hint, "modulate:a", 0.45, 0.6)
	hint_tw.tween_property(_hint, "modulate:a", 1.0, 0.6)
	# Identity beats of a walkout (family glyph -> world emblem -> name).
	_ident = Control.new()
	_ident.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ident.size = Vector2(vp.x, 420)
	_ident.position = Vector2(0, ins.y + 90)
	_ident.modulate.a = 0.0
	_root_ui.add_child(_ident)
	# A soft night shade under the beats so the world line and the name read over the arch.
	var id_shade := TextureRect.new()
	id_shade.texture = UIKit.glow_texture()
	id_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	id_shade.modulate = Color(0.0, 0.0, 0.05, 0.62)
	id_shade.size = Vector2(vp.x * 1.25, 360)
	id_shade.position = Vector2(-vp.x * 0.125, 10)
	id_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ident.add_child(id_shade)
	_ident_glyph = Icons.make("fam_kinetic", 104.0)
	_ident_glyph.position = Vector2(vp.x * 0.5 - 52, 0)
	_ident.add_child(_ident_glyph)
	_ident_world = UIKit.heading("", 26, UIKit.TEXT_DIM, 6)
	_ident_world.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ident_world.size = Vector2(vp.x, 34)
	_ident_world.position = Vector2(0, 112)
	_ident.add_child(_ident_world)
	_ident_name = UIKit.gradient_heading("", 70)
	_ident_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ident_name.size = Vector2(vp.x, 90)
	_ident_name.position = Vector2(0, 150)
	_ident_name.pivot_offset = _ident_name.size * 0.5
	_ident.add_child(_ident_name)
	_ident_sub = UIKit.heading("", 28, UIKit.GOLD_LIGHT, 6)
	_ident_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ident_sub.size = Vector2(vp.x, 36)
	_ident_sub.position = Vector2(0, 240)
	_ident.add_child(_ident_sub)
	# Cards.
	for cd: Dictionary in rev.get("cards", []):
		var c := AltarCard.new(cd)
		c.custom_minimum_size = _card_size()
		c.size = _card_size()
		c.visible = false
		_root_ui.add_child(c)
		_cards.append(c)
	_coins_row = HBoxContainer.new()
	_coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_coins_row.add_theme_constant_override("separation", 8)
	_coins_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coins := int(rev.get("coins", 0))
	if coins > 0:
		_coins_row.add_child(Icons.make("coin", 44.0))
		_coins_row.add_child(UIKit.heading("+" + Loc.num(coins), 40, UIKit.GOLD_LIGHT, 8))
	_coins_row.size = Vector2(vp.x, 50)
	_coins_row.position = Vector2(0, vp.y * 0.785)
	_coins_row.modulate.a = 0.0
	_root_ui.add_child(_coins_row)
	# Buttons.
	_open_btn = UIKit.styled_button(Loc.t("OPEN_ALL"), "button", Vector2(360, 84), 30)
	_open_btn.position = Vector2((vp.x - 360) * 0.5, vp.y - 140 - ins.w)
	_open_btn.visible = false
	_open_btn.pressed.connect(_on_open_all)
	_root_ui.add_child(_open_btn)
	_done_btn = UIKit.button(Loc.t("DONE"), true, 420.0)
	_done_btn.custom_minimum_size.y = 96
	_done_btn.add_theme_font_size_override("font_size", 40)
	_done_btn.size = Vector2(420, 96)
	_done_btn.position = Vector2((vp.x - 420) * 0.5, vp.y - 150 - ins.w)
	_done_btn.visible = false
	_done_btn.pressed.connect(func(): _leave("done", ""))
	_root_ui.add_child(_done_btn)
	_up_btn = UIKit.styled_button("", "button", Vector2(420, 72), 26)
	_up_btn.position = Vector2((vp.x - 420) * 0.5, vp.y - 236 - ins.w)
	_up_btn.visible = false
	_root_ui.add_child(_up_btn)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ui.add_child(_flash)


func _card_size() -> Vector2:
	return Vector2(150, 214) if _n_cards() > 3 else Vector2(176, 250)


func _n_cards() -> int:
	return (rev.get("cards", []) as Array).size()


## Arc slot of card `i` (top-left) for the fan-out.
func _arc_slot(i: int) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var n := _cards.size()
	var cs := _card_size()
	# Keeps >= 50 px to the screen edges (the tilted outer cards used to sit ~20 px from them).
	var step := minf(cs.x - 32.0 + (48.0 if n <= 3 else 0.0), (vp.x - 100.0 - cs.x) / maxf(n - 1, 1))
	var u := i - (n - 1) * 0.5
	var x := vp.x * 0.5 + u * step - cs.x * 0.5
	var y := vp.y * 0.6 + u * u * 9.0
	return Vector2(x, y)


func _arc_rot(i: int) -> float:
	var u := i - (_cards.size() - 1) * 0.5
	return deg_to_rad(u * 3.5)


## Summary grid slot (rows of 3, best rarity first).
func _grid_slot(rank: int) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var cs := _card_size()
	var n := _cards.size()
	var per := 3
	var row := rank / per
	var in_row := mini(per, n - row * per)
	var col := rank % per
	var gap := 18.0
	var w := in_row * cs.x + (in_row - 1) * gap
	var rows := int(ceil(float(n) / per))
	var top := vp.y * 0.74 - rows * (cs.y + gap) + 10.0
	return Vector2((vp.x - w) * 0.5 + col * (cs.x + gap), top + row * (cs.y + gap))


# ------------------------------------------------------------------ timeline

func _at(t: float, fn: Callable) -> void:
	_events.append([_clock + t * speed, fn])
	_events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _present() -> void:
	state = "present"
	cache.visible = true
	_drop = 0.0
	cache.position.y = 2.6
	_at(0.33, func():
		fx.ring(_socket() + Vector3(0, 0.05, 0), Color(0.7, 0.85, 1.0), 1.6, 0.45)
		fx.shockwave(_socket(), Color(0.55, 0.8, 1.0), 1.4)
		Audio.play("crate_hit", -2.0)
		Audio.play("build", -10.0)
		UIJuice.haptic("THUD", 0.7)
		CacheModels.altar_light(altar, 0.65, Color(0.5, 0.8, 1.0)))
	_at(float(EconData.REVEAL["auto_strike"]), _do_strike)


func _do_strike() -> void:
	if state != "present":
		return
	state = "strike"
	_events.clear()
	_hint.visible = false
	_set_cam(_strike_cam(), 0.3 * speed)
	_strike = 0.0
	_strike_dur = 0.55
	var hit := 0.2
	_at(hit, _impact)
	_at(hit + float(EconData.REVEAL["tell"]), _tell)
	_at(hit + float(EconData.REVEAL["tell"]) + float(EconData.REVEAL["burst"]), _burst)


## The hero's blow lands.
func _impact() -> void:
	var c := _egg_centre()
	if hero_id == "titan":
		fx.shockwave(_socket(), Color(0.35, 1.0, 0.55), 2.0)
		var pts: Array[Vector3] = []
		for i in 7:
			var a := TAU * i / 7.0
			pts.append(_socket() + Vector3(cos(a), 0, sin(a)) * 0.9)
		fx.crystal_spikes(pts, _socket(), Color(0.35, 1.0, 0.55))
		fx.flash(c, Color(0.5, 1.0, 0.6), 0.9, 0.2)
	else:
		var sky := c + Vector3(0.6, 7.0, -1.5)
		var pts: Array[Vector3] = [sky, sky.lerp(c, 0.35) + Vector3(-0.4, 0, 0.2), sky.lerp(c, 0.7) + Vector3(0.3, 0, 0), c]
		fx.lightning(pts, Color(0.55, 0.85, 1.0), 0.28, 0.09)
		var hand := hero.global_position + Vector3(0, 1.0, 0)
		fx.lightning([hand, hand.lerp(c, 0.5) + Vector3(0, 0.3, 0), c] as Array[Vector3], Color(0.55, 0.85, 1.0), 0.2, 0.05)
		fx.flash(c, Color(0.7, 0.9, 1.0), 0.9, 0.2)
	Audio.play("hit", -2.0)
	Audio.play("tesla" if hero_id == "bolt" else "explosion", -6.0)
	UIJuice.haptic("CLICK", 0.7)
	_trauma = maxf(_trauma, 0.2)


func _tell() -> void:
	state = "tell"
	var best := str(rev.get("best", "C"))
	var rc := CacheModels.rarity_color(best)
	CacheModels.set_tell(cache, best)
	CacheModels.set_crack(cache, 1)
	CacheModels.altar_light(altar, 1.0, rc)
	var tier := CacheModels.tier(best)
	# Riser, pitched by tier (Legendary+: a 0.25 s pre-sting before the pillars rise).
	for i in 3 + tier:
		var step := 2 + i * 2
		get_tree().create_timer(i * 0.05 * speed).timeout.connect(func(): Audio.note(step, -12.0))
	UIJuice.haptic("QUICK_RISE", 0.5)
	_at(0.12, func(): CacheModels.set_crack(cache, 2))


func _burst() -> void:
	state = "burst"
	var best := str(rev.get("best", "C"))
	var rc := CacheModels.rarity_color(best)
	var tier := CacheModels.tier(best)
	_freeze = float(EconData.REVEAL["hitstop"])
	CacheModels.set_crack(cache, 3)
	fx.cache_burst(_egg_centre(), rc, tier)
	_trauma = float(EconData.REVEAL["trauma_leg"] if tier >= 3 else EconData.REVEAL["trauma"])
	_beam.visible = true
	_beam.position = _socket() + Vector3(0, 13.0, 0)
	_beam_mat.set_shader_parameter("color", rc)
	_beam_k = 1.0 + 0.25 * tier
	_flash.color = Color(rc.r, rc.g, rc.b, 0.0).lerp(Color(1, 1, 1, 0.7), 0.6)
	_rays.color = Color(rc.r, rc.g, rc.b, 0.0)
	_rays.create_tween().tween_property(_rays, "color:a", 0.34, 0.4)
	Audio.play("geode_break", 0.0)
	Audio.play("crate_open", -3.0)
	Audio.chord(4 + tier, true, -7.0)
	UIJuice.haptic("THUD", 1.0)
	_set_cam(CAM_FAN, 0.55 * speed)
	_at(float(EconData.REVEAL["fan"]) - float(EconData.REVEAL["burst"]) + 0.1, _fan)


func _fan() -> void:
	state = "fan"
	var from := _screen(_egg_centre())
	var cs := _card_size()
	var stagger := float(EconData.REVEAL["fan_stagger"])
	for i in _cards.size():
		var c := _cards[i]
		c.visible = true
		c.pivot_offset = cs * 0.5
		c.position = from - cs * 0.5
		c.scale = Vector2(0.3, 0.3)
		c.rotation = 0.0
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(i * stagger * speed)
		tw.tween_callback(func(): Audio.play("whoosh_gate", -12.0))
		tw.tween_property(c, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(c, "position", _arc_slot(i), 0.42 * speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.38 * speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "rotation", _arc_rot(i), 0.38 * speed)
		if i == 0 or i == _cards.size() - 1:
			tw.tween_callback(func(): UIJuice.haptic("TICK", 0.5))
	_rays.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, _arc_slot(0).y + cs.y * 0.5) - _rays.size * 0.5
	_at(0.45 + _cards.size() * stagger, func():
		state = "flips"
		_hint.text = Loc.t("TAP_TO_OPEN")
		_hint.position.y = get_viewport().get_visible_rect().size.y * 0.53
		_hint.visible = true
		_open_btn.visible = not _open_all
		if _open_all:
			_flip_next()
		else:
			UIJuice.pop(_open_btn, 0.0))


## Flips the next card (tap) - or every card left, one after another ("Відкрити все").
func _flip_next() -> void:
	if _busy or state != "flips":
		return
	if _next >= _cards.size():
		_summary()
		return
	_busy = true
	_hint.visible = false
	var c := _cards[_next]
	_next += 1
	if c.is_walkout():
		await _walkout(c)
	else:
		var dur := c.flip_time(speed)
		if c.rarity() in ["E", "L", "M"]:
			Audio.play("upgrade", -10.0)
		await c.flip(dur)
		if not is_inside_tree():
			return
		if c.rarity() in ["E", "L", "M"]:
			UIKit.sparkles(_root_ui, c.position + c.size * 0.5, c.color().lightened(0.35), 30, 260.0)
		_after(0.08, c.sparks)
	_busy = false
	if _next >= _cards.size():
		_after(0.55, _summary)
	elif _open_all:
		_after(0.12, _flip_next)


func _after(sec: float, fn: Callable) -> void:
	get_tree().create_timer(sec * speed).timeout.connect(func():
		if is_inside_tree():
			fn.call())


func _on_open_all() -> void:
	_open_all = true
	_open_btn.visible = false
	_hint.visible = false
	if state == "flips":
		_flip_next()


## A NEW machine (or a Legendary+) walks out on the altar: the card dissolves into the 3D
## machine, it rolls onto the altar, turns and fires one volley; identity in three beats.
func _walkout(c: AltarCard) -> void:
	var id := str(c.data.get("id", ""))
	var rc := c.color()
	var is_new := bool(c.data.get("new", false))
	var long := is_new
	var ws := speed if not (is_new and not _summary_shown) else maxf(speed, 0.75)
	# The card rises, glows white and dissolves.
	c.z_index = 5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.25, 1.25), 0.22 * ws).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate", Color(3, 3, 3, 1), 0.22 * ws)
	tw.tween_property(c, "modulate:a", 0.0, 0.16 * ws)
	for o in _cards:
		if o != c:
			o.create_tween().tween_property(o, "modulate:a", 0.25, 0.2)
	Audio.play("weapon_get", -4.0)
	await tw.finished
	if not is_inside_tree():
		return
	# Beam down onto the socket, the machine rolls onto the altar.
	_set_cam(CAM_WALK, 0.45 * ws)
	_beam.visible = true
	_beam_mat.set_shader_parameter("color", rc.lerp(Color.WHITE, 0.2))
	_beam_k = 1.4
	if _machine:
		_machine.queue_free()
	_machine = WeaponModels.machine(id, {"rank": 1})
	HubShowcase.hide_rank_marks(_machine)
	add_child(_machine)
	_machine.scale = Vector3.ONE * 1.0
	_machine_from = _socket() + Vector3(1.1, 0.0, 0.35)
	_machine.global_position = _machine_from
	_machine.rotation.y = deg_to_rad(90)
	_machine_t = 0.0
	fx.flash(_socket() + Vector3(0, 0.6, 0), rc, 1.0, 0.3)
	fx.shockwave(_socket(), rc, 1.6)
	UIJuice.haptic("THUD", 0.8)
	# Identity: family glyph -> world emblem -> name + model.
	var fam := ArsenalData.family_of(id)
	_ident_glyph.set_kind("fam_" + fam)
	var home := int((ArsenalData.MACHINES[id] as Dictionary).get("home", 1))
	_ident_world.text = Loc.f("WORLD_N", [maxi(home, 1)])
	_ident_name.text = Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"]))
	_ident_name.add_theme_font_size_override("font_size", UIKit.fit_size(_ident_name.text, 660.0, 70, 38))
	var rar := str((ArsenalData.RARITIES[c.rarity()] as Dictionary)["name"])
	_ident_sub.text = (Loc.t("NEW_MACHINE") + "  ·  " if is_new else "") + Loc.t(rar)
	_ident_sub.add_theme_color_override("font_color", rc.lightened(0.3))
	_ident.modulate.a = 1.0
	_title.visible = false
	_pity.visible = false
	for n: Control in [_ident_glyph, _ident_world, _ident_name, _ident_sub]:
		n.modulate.a = 0.0
	var beat := (0.4 if long else 0.25) * ws
	_ident_glyph.create_tween().tween_property(_ident_glyph, "modulate:a", 1.0, 0.2)
	UIJuice.pop(_ident_glyph, 0.0, 0.3, 0.5)
	_after(beat / speed, func():
		_ident_world.create_tween().tween_property(_ident_world, "modulate:a", 1.0, 0.2))
	_after(beat * 2.0 / speed, func():
		_ident_name.modulate.a = 1.0
		_ident_name.scale = Vector2(2.2, 2.2)
		_ident_name.create_tween().tween_property(_ident_name, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_ident_sub.create_tween().tween_property(_ident_sub, "modulate:a", 1.0, 0.25)
		Audio.play("stairs_top", -4.0)
		UIJuice.haptic("THUD", 1.0)
		UIKit.sparkles(_root_ui, _ident.position + _ident_name.position + _ident_name.size * 0.5, rc.lightened(0.4), 30, 320.0))
	var total := (2.4 if long else 1.2) * ws
	await get_tree().create_timer(total * 0.62).timeout
	if not is_inside_tree():
		return
	_machine_volley(id)
	await get_tree().create_timer(total * 0.38).timeout
	if not is_inside_tree():
		return
	# Back to the fan: the card shows its face (NEW ribbon), the machine stays on the altar.
	_set_cam(CAM_SUMMARY if _summary_shown else CAM_FAN, 0.4 * speed)
	_ident.create_tween().tween_property(_ident, "modulate:a", 0.0, 0.2)
	_title.visible = true
	_pity.visible = true
	c.scale = Vector2.ONE
	c.modulate = Color(1, 1, 1, 1)
	c.z_index = 0
	c.show_face_now()
	UIJuice.pop(c, 0.0, 0.3, 0.7)
	for o in _cards:
		o.create_tween().tween_property(o, "modulate:a", 1.0, 0.2)
	if not is_new:
		_after(0.1, c.sparks)


func _machine_volley(id: String) -> void:
	if _machine == null:
		return
	_machine_fire = 1.0
	var mz: Node3D = _machine.get_meta("muzzle") if _machine.has_meta("muzzle") else null
	var from := mz.global_position if mz else _machine.global_position + Vector3(0, 0.6, 0)
	var col := WeaponModels.glow_color(id)
	var dir := -_machine.global_transform.basis.z.normalized()
	fx.muzzle(from, col, dir)
	var to := from + Vector3(dir.x, 0.0, dir.z * 0.35).normalized() * 7.0 + Vector3(0, 0.4, 0)
	var kind := Effects.shot_kind(id)
	if kind == "beam" or not Effects.KINDS.has(Effects.ALIAS.get(kind, kind)):
		fx.rail_fire(from, to, col)
	else:
		for i in (3 if id in ["rockets", "gatling", "drone"] else 1):
			fx.projectile(from, to + Vector3(randf_range(-0.8, 0.8), randf_range(0, 0.6), 0), str(Effects.ALIAS.get(kind, kind)), 0.4 + i * 0.07, func(): pass)
	var fallback := {"ballista": "ballista", "cannon": "plasma", "rockets": "rocket", "drone": "drone",
			"laser": "laser", "mortar": "cannon", "gatling": "turret_shot", "railgun": "tesla", "prism": "laser"}
	Audio.play(str(fallback.get(id, "ballista")), -3.0)
	UIJuice.haptic("CLICK", 0.7)
	_trauma = maxf(_trauma, 0.15)


func _summary() -> void:
	if _summary_shown:
		return
	_summary_shown = true
	state = "summary"
	_events.clear()
	_hint.visible = false
	_open_btn.visible = false
	_ident.modulate.a = 0.0
	_title.visible = true
	_pity.visible = true
	_set_cam(CAM_SUMMARY, 0.5)
	# Grid by rarity, best first.
	var order: Array[AltarCard] = _cards.duplicate()
	order.sort_custom(func(a: AltarCard, b: AltarCard) -> bool:
		return CacheModels.tier(a.rarity()) > CacheModels.tier(b.rarity()))
	for i in order.size():
		var c := order[i]
		c.visible = true
		c.modulate.a = 1.0
		c.z_index = 0
		if not c.face_up:
			c.show_face_now()
		var tw := c.create_tween().set_parallel(true)
		tw.tween_property(c, "position", _grid_slot(i), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.04)
		tw.tween_property(c, "rotation", 0.0, 0.3).set_delay(i * 0.04)
		tw.tween_property(c, "scale", Vector2.ONE, 0.3).set_delay(i * 0.04)
	var vp := get_viewport().get_visible_rect().size
	_rays.position = Vector2(vp.x * 0.5, _grid_slot(0).y + _card_size().y) - _rays.size * 0.5
	var coins := int(rev.get("coins", 0))
	if coins > 0:
		_coins_row.position.y = _grid_slot(order.size() - 1).y + _card_size().y + 8
		_coins_row.modulate.a = 1.0
		UIJuice.pop(_coins_row, 0.2)
		_after(0.55, func():
			_chip.expect_fly()
			_chip.set_amount(Meta.currency("coins"), false)
			RewardFly.layer(get_tree()).fly(_coins_row.get_global_rect().get_center(), "coins", coins, _chip))
	# "Покращити <machine>": the best upgradable machine among the cards.
	var up_id := ""
	var best_t := -1
	for c in _cards:
		var id := str(c.data.get("id", ""))
		if id != "" and bool(c.data.get("upgradable", false)) and CacheModels.tier(c.rarity()) > best_t:
			best_t = CacheModels.tier(c.rarity())
			up_id = id
	_done_btn.visible = true
	UIJuice.pop(_done_btn, 0.25)
	UIKit.add_shine(_done_btn, 30.0, 0.9, 2.4, 0.5)
	if up_id != "":
		_up_btn.text = Loc.f("UPGRADE_MACHINE", [Loc.t(str((ArsenalData.MACHINES[up_id] as Dictionary)["name"]))])
		_up_btn.add_theme_font_size_override("font_size", UIKit.fit_size(_up_btn.text, 380.0, 26, 18))
		_up_btn.visible = true
		for cn in _up_btn.pressed.get_connections():
			_up_btn.pressed.disconnect(cn["callable"])
		_up_btn.pressed.connect(func(): _leave("upgrade", up_id))
		UIJuice.pop(_up_btn, 0.35)
	Audio.chord(5, true, -9.0)


## Hold-to-skip / back: straight to the summary (a NEW machine's first walkout still plays).
func skip() -> void:
	if _summary_shown:
		return
	Meta.note_skip("altar")
	_events.clear()
	if state in ["present", "strike", "tell"]:
		_hint.visible = false
		CacheModels.set_tell(cache, str(rev.get("best", "C")))
		CacheModels.set_crack(cache, 3)
		CacheModels.altar_light(altar, 1.0, CacheModels.rarity_color(str(rev.get("best", "C"))))
	for i in _cards.size():
		var c := _cards[i]
		c.visible = true
		c.modulate.a = 1.0
	if state in ["present", "strike", "tell", "burst", "fan"]:
		for i in _cards.size():
			_cards[i].position = _arc_slot(i)
			_cards[i].rotation = _arc_rot(i)
			_cards[i].scale = Vector2.ONE
	state = "flips"
	# Unplayed first walkouts of NEW machines still play once, fast.
	var pending: Array[AltarCard] = []
	for i in range(_next, _cards.size()):
		var c := _cards[i]
		if bool(c.data.get("new", false)):
			pending.append(c)
		else:
			c.show_face_now()
	_next = _cards.size()
	if pending.is_empty() or _busy:
		_summary()
		return
	_busy = true
	for c in pending:
		await _walkout(c)
		if not is_inside_tree():
			return
	_busy = false
	_summary()


func _quick() -> void:
	state = "flips"
	cache.visible = true
	_hint.visible = false
	CacheModels.set_tell(cache, str(rev.get("best", "C")))
	CacheModels.set_crack(cache, 3)
	CacheModels.altar_light(altar, 1.0, CacheModels.rarity_color(str(rev.get("best", "C"))))
	_set_cam(CAM_SUMMARY, 0.0)
	Audio.chord(7, true, -8.0)
	_next = _cards.size()
	for c in _cards:
		c.modulate.a = 0.0
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.2)
	_summary()


func _leave(action: String, id: String) -> void:
	if state == "leaving":
		return
	state = "leaving"
	RewardFly.layer(get_tree()).land_all()
	done.emit(action, id)


# ------------------------------------------------------------------ input

func _on_input(e: InputEvent) -> void:
	var press := (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed) \
			or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var release := (e is InputEventScreenTouch and not (e as InputEventScreenTouch).pressed) \
			or (e is InputEventMouseButton and not (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if press:
		_hold = 0.0
		if _sheet:
			_sheet.queue_free()
			_sheet = null
			return
		match state:
			"present":
				_do_strike()
			"flips":
				_flip_next()
	elif release:
		_hold = -1.0


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _back() -> void:
	if _sheet:
		_sheet.queue_free()
		_sheet = null
	elif _summary_shown:
		_leave("done", "")
	else:
		skip()


## The odds (i) sheet for the CURRENT pool (Meta.odds): per card, best card, guaranteed slot.
func _toggle_odds() -> void:
	if _sheet:
		_sheet.queue_free()
		_sheet = null
		return
	var od := Meta.odds(str(rev.get("type", "world")))
	var vp := get_viewport().get_visible_rect().size
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(30, 24)))
	p.custom_minimum_size = Vector2(600, 0)
	p.position = Vector2((vp.x - 600) * 0.5, vp.y * 0.2)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e) and _sheet:
			_sheet.queue_free()
			_sheet = null)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	p.add_child(col)
	var t := UIKit.gradient_heading(Loc.t("ODDS_TITLE"), 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(UIKit.divider(520.0))
	for r: String in od.get("present", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var nm := UIKit.heading(Loc.t(str((ArsenalData.RARITIES[r] as Dictionary)["name"])), 26, UITokens.rarity(r), 5)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var pc := float((od.get("per_card", {}) as Dictionary).get(r, 0.0)) * 100.0
		var bc := float((od.get("best", {}) as Dictionary).get(r, 0.0)) * 100.0
		row.add_child(UIKit.label("%s %.2f%%" % [Loc.t("ODDS_PER_CARD"), pc], 20, UIKit.TEXT_DIM))
		row.add_child(UIKit.label("%s %.2f%%" % [Loc.t("ODDS_BEST"), bc], 20, UIKit.TEXT))
		col.add_child(row)
	col.add_child(UIKit.divider(520.0))
	var g := str((EconData.CACHES[str(rev.get("type", "world"))] as Dictionary).get("guaranteed", "R"))
	var gl := UIKit.label(Loc.f("ODDS_GUARANTEED", [Loc.t(str((ArsenalData.RARITIES[g] as Dictionary)["name"]))]), 22, UIKit.TEXT)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(gl)
	for k in ["ODDS_WILD", "ODDS_FOCUS", "ODDS_DECK", "ODDS_DUPES", "PITY_EPIC"]:
		var l := UIKit.label(Loc.t(k), 20, UIKit.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	_root_ui.add_child(p)
	_sheet = p
	UIJuice.pop(p)


# ------------------------------------------------------------------ frame

func _screen(world: Vector3) -> Vector2:
	var p := cam.unproject_position(world)
	var xf := get_viewport().get_final_transform()
	return xf.affine_inverse() * p


func _process(delta: float) -> void:
	_t = fmod(_t + delta, 3600.0)
	if _hold >= 0.0:
		_hold += delta
		if _hold >= HOLD_SKIP and state in ["present", "strike", "tell", "burst", "fan", "flips"] and not _summary_shown:
			_hold = -1.0
			skip()
	var adt := delta
	if _freeze > 0.0:
		_freeze -= delta
		adt = 0.0
	_anim_t += adt
	if not hold_clock:
		_clock += adt
	while not _events.is_empty() and float(_events[0][0]) <= _clock:
		var ev: Array = _events.pop_front()
		(ev[1] as Callable).call()
	# Cache drop (ease-out-back) and idle.
	if _drop >= 0.0:
		_drop += adt
		var k := clampf(_drop / (0.35 * speed), 0.0, 1.0)
		var u := k - 1.0
		cache.position.y = 0.02 + 2.6 * (1.0 - (1.0 + 2.70158 * u * u * u + 1.70158 * u * u))
		if k >= 1.0:
			_drop = -1.0
			cache.position.y = 0.02
	CacheModels.animate(cache, _anim_t)
	if int(cache.get_meta("stage", 0)) == 3:
		# Keep the burst's core flash a quick pop, not a white egg-sized blob.
		var core: Node3D = cache.get_meta("core")
		core.scale = Vector3.ONE * minf(core.scale.x, 1.15)
	CacheModels.animate(altar, _anim_t)
	# Hero: guard stance, the strike swing.
	var atk := 0.0
	var abil := 0.0
	if _strike >= 0.0:
		_strike += adt
		var s := clampf(_strike / (_strike_dur * speed), 0.0, 1.0)
		if hero_id == "titan":
			abil = 1.0 - s
		else:
			atk = 1.0 - s
		if s >= 1.0:
			_strike = -1.0
	HeroModels.animate_hero(hero, _anim_t, false, atk, abil, 0.0, false, true)
	# Walkout machine: roll onto the socket, turn to the camera.
	if _machine and _machine_t >= 0.0:
		_machine_t += adt
		var rk := clampf(_machine_t / (0.5 * speed), 0.0, 1.0)
		var e := 1.0 - (1.0 - rk) * (1.0 - rk)
		_machine.global_position = _machine_from.lerp(_socket(), e)
		var tk := clampf((_machine_t - 0.45 * speed) / (0.35 * speed), 0.0, 1.0)
		_machine.rotation.y = lerp_angle(deg_to_rad(90), PI - 0.5, tk * tk * (3.0 - 2.0 * tk))
		_machine_fire = maxf(0.0, _machine_fire - adt * 3.0)
		WeaponModels.animate(_machine, _anim_t, _machine_fire, e * 1.2)
	# Beam.
	if _beam.visible:
		_beam_k = maxf(0.0, _beam_k - delta * 1.3)
		_beam_mat.set_shader_parameter("strength", _beam_k)
		var bs := 0.6 + 0.4 * minf(_beam_k, 1.0)
		_beam.scale = Vector3(bs, 1.0, bs)
		if _beam_k <= 0.0:
			_beam.visible = false
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 3.0)
	# Camera move + trauma.
	if _cam_k < 1.0:
		_cam_k = minf(1.0, _cam_k + delta / maxf(_cam_dur, 0.01))
		var ck := 1.0 - pow(1.0 - _cam_k, 3.0)
		_apply_cam([Vector3(_cam_from[0]).lerp(Vector3(_cam_to[0]), ck), Vector3(_cam_from[1]).lerp(Vector3(_cam_to[1]), ck),
				lerpf(float(_cam_from[2]), float(_cam_to[2]), ck)])
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.6)
		var s2 := _trauma * _trauma
		cam.h_offset = sin(_t * 47.0) * 0.12 * s2
		cam.rotation.z = sin(_t * 31.0 + 1.3) * 0.03 * s2
	elif cam.h_offset != 0.0:
		cam.h_offset = 0.0
		cam.rotation.z = 0.0
