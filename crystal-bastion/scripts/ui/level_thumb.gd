class_name LevelThumb
extends Control
## Small painted preview of a level theme for the level-select cards.

var theme_colors: Dictionary
var locked := false


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var top: Color = theme_colors.get("sky_top", Color(0.3, 0.5, 0.8))
	var hor: Color = theme_colors.get("sky_horizon", Color(0.8, 0.9, 1.0))
	var grass: Color = theme_colors.get("grass_a", Color(0.4, 0.7, 0.3))
	var dirt: Color = theme_colors.get("dirt", Color(0.5, 0.35, 0.2))
	var rock: Color = theme_colors.get("deep", Color(0.3, 0.25, 0.3))
	var steps := 12
	for i in steps:
		var y0 := r.size.y * i / steps
		var c := top.lerp(hor, float(i) / (steps - 1))
		draw_rect(Rect2(0, y0, r.size.x, r.size.y / steps + 1.0), c)
	# Floating island silhouette.
	var w := r.size.x
	var h := r.size.y
	var island := PackedVector2Array([
		Vector2(w * 0.12, h * 0.62), Vector2(w * 0.88, h * 0.62), Vector2(w * 0.8, h * 0.74),
		Vector2(w * 0.66, h * 0.82), Vector2(w * 0.55, h * 0.95), Vector2(w * 0.42, h * 0.84), Vector2(w * 0.25, h * 0.76),
	])
	draw_colored_polygon(island, rock)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12, h * 0.62), Vector2(w * 0.88, h * 0.62), Vector2(w * 0.84, h * 0.68), Vector2(w * 0.16, h * 0.68)]), dirt)
	draw_rect(Rect2(w * 0.12, h * 0.56, w * 0.76, h * 0.07), grass)
	# Crystal
	Icons.draw_icon(self, "crystal", Rect2(w * 0.62, h * 0.18, h * 0.38, h * 0.38))
	# Little tower
	draw_rect(Rect2(w * 0.28, h * 0.36, w * 0.08, h * 0.2), Color(0.62, 0.6, 0.58))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.26, h * 0.37), Vector2(w * 0.38, h * 0.37), Vector2(w * 0.32, h * 0.25)]), Color(0.85, 0.3, 0.25))
	if locked:
		draw_rect(r, Color(0.03, 0.04, 0.08, 0.7))
		Icons.draw_icon(self, "lock", Rect2(r.get_center() - Vector2(28, 30), Vector2(56, 56)), Color(0.85, 0.86, 0.9))
