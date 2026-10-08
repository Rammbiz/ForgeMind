class_name HeroShowcaseBackdrop
extends Control
## The bright painted backdrop of the Hero Showcase (Genshin character screen, C-bright): a light
## sky graded in the hero's gem (Кварц mist, Сапфір sky, Аметист lilac, Топаз sunrise, Опал pearl
## with soft play-of-colour), a sun bloom behind the hero, slow light rays, the hero's gem cut
## engraved huge as a halo, a warm horizon haze and drifting light motes. Never dark (dark is
## only the Portal night sky). Idle motion is slow (rays turn ~1° / s, motes rise) and stops
## under Reduce Motion. No flashes.
##   var bg := HeroShowcaseBackdrop.make("L", "plasma"); bg.focus = Vector2(0.64, 0.33)

## Gem -> [sky top, sky mid, ground, accent, mote]
const SKY := {
	"C": [Color("#F3F6F9"), Color("#DCE4EC"), Color("#C9D3DD"), Color("#AEB9C6"), Color("#FFFFFF")],
	"R": [Color("#EEF7FF"), Color("#C7E3F8"), Color("#A9CFEE"), Color("#63A9DD"), Color("#E6F5FF")],
	"E": [Color("#F6F0FF"), Color("#E0D2F6"), Color("#C8B3EA"), Color("#9C7BD0"), Color("#F1E6FF")],
	"L": [Color("#FFF7E6"), Color("#FCE0AE"), Color("#F1C27E"), Color("#E8AE5C"), Color("#FFF1CF")],
	"M": [Color("#F7F3FF"), Color("#E7DEF7"), Color("#D3C6EE"), Color("#B48CFF"), Color("#FFFFFF")],
}
const OPAL_FIRE: Array[Color] = [Color("#7FE3FF"), Color("#B48CFF"), Color("#FF9FD6"), Color("#FFE28A")]

var gem := "L":
	set(v):
		gem = HeroesText.gem_letter(v)
		queue_redraw()
var element := "":
	set(v):
		element = v
		queue_redraw()
## Normalised centre of the sun bloom / gem halo (behind the hero's head).
var focus := Vector2(0.64, 0.34)
var halo := true
var _t := 0.0
var _motes: Array = []


static func make(p_gem: String, p_element := "") -> HeroShowcaseBackdrop:
	var b := HeroShowcaseBackdrop.new()
	b.gem = p_gem
	b.element = p_element
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		_motes.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.5, 1.0),
				"v": rng.randf_range(0.008, 0.022), "ph": rng.randf() * TAU, "a": rng.randf_range(0.25, 0.6)})


func _ready() -> void:
	set_process(not UITokens.reduce_motion())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _band(y0: float, y1: float, c0: Color, c1: Color) -> void:
	var w := size.x
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
			PackedColorArray([c0, c0, c1, c1]))


func _draw() -> void:
	var W := size.x
	var H := size.y
	var p: Array = SKY.get(gem, SKY["L"])
	var top: Color = p[0]
	var mid: Color = p[1]
	var ground: Color = p[2]
	var accent: Color = p[3]
	var mote: Color = p[4]
	# Sky: three soft bands, the lower third warming into the ground.
	_band(0, H * 0.45, top, mid)
	_band(H * 0.45, H * 0.78, mid, mid.lerp(ground, 0.55))
	_band(H * 0.78, H, mid.lerp(ground, 0.55), ground)
	var g := UIKit.glow_texture()
	var sun := Vector2(W * focus.x, H * focus.y)
	# A second, element-tinted bloom low on the left keeps the sky from reading flat.
	if element != "":
		var ec := UITokens.family(element)
		draw_texture_rect(g, Rect2(Vector2(-W * 0.35, H * 0.42), Vector2(W * 1.0, H * 0.5)), false, Color(ec.r, ec.g, ec.b, 0.12))
	if gem == "M":
		# Pearl opal: four soft patches of play-of-colour drifting very slowly.
		for i in OPAL_FIRE.size():
			var a := TAU * i / 4.0 + _t * 0.05
			var pc := sun + Vector2(cos(a), sin(a) * 0.8) * W * 0.36
			var oc: Color = OPAL_FIRE[i]
			draw_texture_rect(g, Rect2(pc - Vector2(W, W) * 0.38, Vector2(W, W) * 0.76), false, Color(oc.r, oc.g, oc.b, 0.22))
	# Sun bloom behind the hero: a wide accent wash + a white core.
	draw_texture_rect(g, Rect2(sun - Vector2(W, W) * 0.95, Vector2(W, W) * 1.9), false, Color(accent.r, accent.g, accent.b, 0.28))
	draw_texture_rect(g, Rect2(sun - Vector2(W, W) * 0.55, Vector2(W, W) * 1.1), false, Color(1, 1, 1, 0.75))
	# Light rays: thin wedges from the sun, slowly turning (static with Reduce Motion).
	var n := 16
	var R := maxf(W, H) * 1.25
	for i in n:
		var a0 := TAU * i / n + _t * 0.018
		var wdg := 0.05 + 0.03 * sin(i * 1.7)
		var pts := PackedVector2Array([sun, sun + Vector2(cos(a0), sin(a0)) * R, sun + Vector2(cos(a0 + wdg), sin(a0 + wdg)) * R])
		var al := 0.07 if i % 2 == 0 else 0.04
		draw_polygon(pts, PackedColorArray([Color(1, 1, 1, al * 1.6), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# The gem's own cut, engraved huge behind the hero (a halo that names the rarity by shape).
	if halo:
		var cut := str(UITokens.gem(gem)["cut"])
		var hs := W * 0.52
		var rot := sin(_t * 0.12) * 0.015
		draw_set_transform(sun, rot, Vector2.ONE)
		for k: Array in [[1.0, 0.55, 2.0], [0.86, 0.3, 1.4], [1.18, 0.18, 1.2]]:
			var pts2 := GemDraw.cut_points(cut, Vector2.ZERO, hs * float(k[0]))
			GemDraw.outline(self, pts2, Color(1, 1, 1, float(k[1])), float(k[2]))
		var pts3 := GemDraw.cut_points(cut, Vector2(0, 2), hs)
		GemDraw.outline(self, pts3, Color(accent.r, accent.g, accent.b, 0.22), 1.4)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Floating crystal shards: a few large translucent rhombi, painterly depth.
	for sp: Array in [[0.14, 0.62, 70.0, 0.4], [0.9, 0.18, 46.0, -0.3], [0.06, 0.3, 34.0, 0.6], [0.82, 0.7, 58.0, 0.2]]:
		var c := Vector2(W * float(sp[0]), H * float(sp[1]) + sin(_t * 0.4 + float(sp[0]) * 9.0) * 6.0)
		var s := float(sp[2])
		var rr := float(sp[3])
		var d := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.42, 0), Vector2(0, s), Vector2(-s * 0.42, 0)])
		var xf := Transform2D(rr, c)
		var dp := xf * d
		draw_polygon(dp, PackedColorArray([Color(1, 1, 1, 0.34), Color(accent.r, accent.g, accent.b, 0.16), Color(accent.r, accent.g, accent.b, 0.1), Color(1, 1, 1, 0.22)]))
		GemDraw.outline(self, dp, Color(1, 1, 1, 0.45), 1.2)
	# Horizon haze: a wide warm-white glow where the hero would stand.
	draw_texture_rect(g, Rect2(Vector2(-W * 0.3, H * 0.7), Vector2(W * 1.6, H * 0.34)), false, Color(1, 0.99, 0.96, 0.6))
	# Motes of light rising (gem light), soft and slow.
	for m: Dictionary in _motes:
		var y := fposmod(float(m["y"]) - _t * float(m["v"]), 1.0)
		var x := float(m["x"]) + sin(_t * 0.5 + float(m["ph"])) * 0.012
		var ms := 10.0 + 18.0 * float(m["s"])
		var fade := sin(y * PI)
		draw_texture_rect(g, Rect2(Vector2(x * W, y * H) - Vector2(ms, ms) * 0.5, Vector2(ms, ms)), false,
				Color(mote.r, mote.g, mote.b, float(m["a"]) * fade))
