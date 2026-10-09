class_name HeroCurrencyChip
extends KitCurrencyPlate
## A currency plate for the hero currencies (top bars of the Hall / Portal / Manage sheet):
## the kit porcelain plate + a painted icon from HeroIcons (Маяки `beacon`, Печатки `seal`,
## Томи `tome`, Зоряна руда `ore`, fragments `fragment`, coins `coin`). No "+" disc: every
## hero currency is earned only (heroes_design.md §7.7), so nothing here opens a shop.
##   var c := HeroCurrencyChip.make("seals", "37 / 40", 190)
##   c.pressed.connect(_explain_seals)


## `currency` = a HeroesUIModel.currencies() key ("beacons" | "seals" | "tomes" | "ore" | "coins")
## or an icon kind.
static func make(currency: String, p_value: String, width := 172.0) -> HeroCurrencyChip:
	var c := HeroCurrencyChip.new()
	c.icon = str(HeroIcons.CURRENCY_ICON.get(currency, currency))
	c.value = p_value
	c.plus = false
	c.custom_minimum_size = Vector2(width, 52)
	return c


func _draw() -> void:
	var ic := _icon_size()
	var plate := Rect2(Vector2(ic * 0.38, size.y * 0.1), Vector2(size.x - ic * 0.38, size.y * 0.8))
	# v3.1: the value is text, so the plate is glass at the text alpha (§4.3) with its 1 dpx line;
	# it stays porcelain on the Portal night instead of turning a grey slab.
	draw_style_box(UIKit.lux("banner"), plate)
	HeroIcons.paint(self, icon, Rect2(Vector2(0, (size.y - ic) * 0.5), Vector2(ic, ic)))
