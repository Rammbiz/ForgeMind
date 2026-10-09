class_name HeroFacetPips
extends Control
## A row of rhombus facet pips (never stars; heroes_design.md §9.1): lit pips in the gem's tone with
## a white table line, unlit pips engraved in gold. Full facets (lit == count) adds a slow light
## sweep along the row (off with Reduce Motion). Optional cream bed so it reads on any ground.
##   var p := HeroFacetPips.make("L", 3)        # Топаз, 3 / 5
##   p.pip = 22.0; p.lit = 4

var gem := "L":
	set(v):
		gem = HeroesText.gem_letter(v)
		queue_redraw()
var count := 5:
	set(v):
		count = v
		_resize()
var lit := 0:
	set(v):
		lit = v
		_sync_process()
		queue_redraw()
var pip := 18.0:
	set(v):
		pip = v
		_resize()
var bed := false
var _t := 0.0


static func make(p_gem: String, p_lit := 0, p_pip := 18.0, p_count := 5) -> HeroFacetPips:
	var p := HeroFacetPips.new()
	p.gem = p_gem
	p.count = p_count
	p.pip = p_pip
	p.lit = p_lit
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _ready() -> void:
	_resize()
	_sync_process()


func _resize() -> void:
	custom_minimum_size = Vector2(pip * 0.95 * (count - 1) + pip * 1.4, pip * 1.15)
	queue_redraw()


func _sync_process() -> void:
	set_process(lit >= count and count > 0 and not UITokens.reduce_motion())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## The pip colour of a gem (its UI hex; opal uses its light rim).
static func pip_color(g: String) -> Color:
	var key := UITokens.gem_of(g)
	if key == "opal":
		return Color("#E8D8FF")
	if key == "quartz":
		return Color("#B9C6D3")
	return UITokens.gem(key)["rim"]


func _draw() -> void:
	var gapx := pip * 0.95
	var total := gapx * (count - 1)
	var x0 := (size.x - total) * 0.5
	var cy := size.y * 0.5
	if bed:
		var r := Rect2(Vector2(x0 - pip * 0.7, cy - pip * 0.55), Vector2(total + pip * 1.4, pip * 1.1))
		draw_colored_polygon(GemDraw.chamfer_rect(r, pip * 0.5), UITokens.PAPER_2)
	var col := pip_color(gem)
	for i in count:
		GemDraw.draw_pip(self, Vector2(x0 + i * gapx, cy), pip, i < lit, col)
	if lit >= count and count > 0:
		# Full facets: a light that walks along the row every 2.4 s.
		var ph := fmod(_t, UITokens.GLOW_PERIOD) / UITokens.GLOW_PERIOD
		var x := lerpf(x0 - pip, x0 + total + pip, ph)
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(x - pip, cy - pip), Vector2(pip, pip) * 2.0), false, Color(1, 1, 1, 0.55 * sin(ph * PI)))
