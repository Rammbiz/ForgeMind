class_name HeroPriceCTA
extends KitCTA
## The amber «Покращити» jewel with its coin price on the second line: «Рів. 12 → 13 · 290 ◎»
## (the shipped UI v2 hero screen shows the price beside the CTA; the Showcase dock has no room
## for a separate plate). The coin is the kit's painted coin icon, drawn right after the sub-line.
##   var b := HeroPriceCTA.make("Покращити", "Рів. 12 → 13", 290, Vector2(0, 88), 30)

var price := 0:
	set(v):
		price = v
		queue_redraw()
var _base_sub := ""


static func make(p_text: String, p_sub: String, p_price: int, min_size := Vector2(0, 88), font_size := 30) -> HeroPriceCTA:
	var b := HeroPriceCTA.new()
	b.text = p_text
	b._base_sub = p_sub
	b.price = p_price
	# Trailing spaces keep the centred sub-line balanced with the coin drawn after it.
	b.sub = ((p_sub + " · " + HeroesText.num(p_price)) if p_sub != "" else HeroesText.num(p_price)) + "     " if p_price > 0 else p_sub
	b.custom_minimum_size = min_size
	b.label_size = font_size
	return b


func _draw() -> void:
	super()
	if price <= 0 or sub == "":
		return
	# Same metrics as KitCTA._draw: find where the sub-line ends, put the coin after it.
	var f := UIKit.font_w("extrabold")
	var fs := label_size
	var area_x0 := _gem_zone() + (6.0 if topaz else 18.0)
	var area_x1 := size.x - (22.0 if topaz else 18.0)
	if KitCTA.refined():
		# Refined CTA study styles: the label area KitCTA itself uses (centred when no gem).
		var la := _label_area()
		area_x0 = la.x
		area_x1 = la.y
	var avail := area_x1 - area_x0
	while fs > 18 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	var fsub := UIKit.font_w("bold")
	var coin := float(sub_size) + 4.0
	var sw := fsub.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	var sx := area_x0 + (avail - sw) * 0.5
	sw = fsub.get_string_size(sub.strip_edges(false, true), HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	var asc := f.get_ascent(fs)
	var desc := f.get_descent(fs)
	var sub_h := fsub.get_ascent(sub_size) + fsub.get_descent(sub_size) - 2.0
	var block := (asc + desc) * 0.86 + sub_h
	var dy := 2.0 if (is_pressed() and not disabled) else 0.0
	var top := (size.y - block) * 0.5 + dy - 1.0
	var base_y := top + asc * 0.93
	var sy := base_y + desc + fsub.get_ascent(sub_size) - 2.0
	var r := Rect2(Vector2(sx + sw + 5.0, sy - fsub.get_ascent(sub_size) * 0.86), Vector2(coin, coin))
	Icons.draw_icon(self, "coin", r, Color(1, 1, 1, 0.6 if disabled else 1.0))
