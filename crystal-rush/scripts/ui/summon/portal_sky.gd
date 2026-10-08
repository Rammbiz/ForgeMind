class_name PortalSky
extends ColorRect
## The Portal night sky (heroes_design.md §9.1 / ui contract §0.1: the one dark ground in the game):
## deep blue-violet night, two star layers, a soft aurora tinted by the pool's gems and a warm
## horizon glow (shaders/heroes/portal_sky.gdshader). The ceremony drives `t`, `dim`, `desat`
## and the gem `burst`; the Portal screen lets it run on its own clock (`driven = false`).
##   var sky := PortalSky.new(); sky.set_pool(HeroesUIModel.portal_state()["pool"])

const SHADER := preload("res://shaders/heroes/portal_sky.gdshader")

var driven := false              ## true: the owner sets `t` (ceremonies); false: own clock
var t := 0.0:
	set(v):
		t = v
		_mat.set_shader_parameter("t", v)
var dim := 0.0:
	set(v):
		dim = v
		_mat.set_shader_parameter("dim", v)
var desat := 0.0:
	set(v):
		desat = v
		_mat.set_shader_parameter("desat", v)
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	resized.connect(func(): _mat.set_shader_parameter("px_size", size))


func _ready() -> void:
	_mat.set_shader_parameter("px_size", size)
	set_process(not driven)


func _process(delta: float) -> void:
	if not driven:
		t += delta * (0.25 if UITokens.reduce_motion() else 1.0)


## Aurora colours from the pool: the two rarest gems present (Topaz gold and Opal violet when the
## pool has them), so the sky hints at what the Portal can hold.
func set_pool(pool: Array) -> void:
	var best := "C"
	var second := "C"
	for id in pool:
		var g := HeroData.native(str(id))
		if Ladder.gem_index(g) > Ladder.gem_index(best):
			second = best
			best = g
		elif Ladder.gem_index(g) > Ladder.gem_index(second) and g != best:
			second = g
	set_aurora(SummonFx.hex(best if best != "M" else "M"), SummonFx.hex(second))


func set_aurora(a: Color, b: Color, strength := 0.55) -> void:
	_mat.set_shader_parameter("aurora_a", a)
	_mat.set_shader_parameter("aurora_b", b)
	_mat.set_shader_parameter("aurora", strength)


## A gem-coloured light behind the crystal (`at` in 0..1 screen UV; strength 0 = off).
func set_burst(col: Color, strength: float, at := Vector2(0.5, 0.42)) -> void:
	_mat.set_shader_parameter("burst", Color(col.r, col.g, col.b, strength))
	_mat.set_shader_parameter("burst_at", at)


func set_horizon(strength: float) -> void:
	_mat.set_shader_parameter("horizon_glow", strength)
