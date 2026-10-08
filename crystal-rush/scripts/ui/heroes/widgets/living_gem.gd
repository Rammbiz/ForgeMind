class_name HeroLivingGem
extends HeroGemEmblem
## The Living Gem (heroes_design.md §3.2, §9.3): the hero's emblem with its facets engraved on the
## stone. Each bought facet engraves one light line (0..5); Full facets (5 / 5) lights the whole
## girdle. Used on the Showcase (200 px), the Manage sheet and the facet / recut ceremonies.
##   var lg := HeroLivingGem.make_living("L", 200, 3)     # Топаз, Грані 3 / 5
##   lg.native = "E"                                       # recut: doublet stone
##   lg.engrave(4)                                         # micro ceremony: the 4th line lights


static func make_living(p_gem: String, px := 200.0, p_facets := 0, p_native := "") -> HeroLivingGem:
	var e := HeroLivingGem.new()
	e.gem = p_gem
	e.native = p_native
	e.facets = p_facets
	e.live = true
	e.custom_minimum_size = Vector2(px, px)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


## Sets the facet count with the micro beat (a soft pop; skipped with Reduce Motion).
func engrave(n: int) -> void:
	facets = clampi(n, 0, Ladder.FACETS_PER_GEM)
	if UITokens.reduce_motion() or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.23).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
