class_name KitBox
extends StyleBox
## UI v3 "porcelain glass" StyleBox: the UIKit painted nine-patch, painted at DEVICE resolution
## (s = the canvas stretch scale, 1.5 on a 1080p phone) and drawn through a 1/s transform, so a
## ring of 1.0 is exactly one device pixel and nothing is bilinearly magnified (the v2 boxes were
## painted at 1x and stretched: 2-3 px soft gold bands). Same batching as a StyleBoxTexture (one
## texture, one nine-patch). UIKit.lux() builds and caches these; never create one inside _draw().

@export var tex: Texture2D
@export var margin_dev := 0.0     ## nine-patch margin, device px
@export var shadow_dev := 0.0     ## shadow room around the body, device px (drawn outside the rect)
@export var s := 1.0              ## canvas -> device scale the texture was painted for


func _draw(ci: RID, rect: Rect2) -> void:
	if tex == null:
		return
	var inv := 1.0 / s
	var p := (rect.position * s).round() - Vector2(shadow_dev, shadow_dev)
	var e := (rect.end * s).round() + Vector2(shadow_dev, shadow_dev)
	var sz := e - p
	# Too small for the nine-patch corners: shrink the margins (keeps the chamfer readable).
	var m := minf(margin_dev, floorf(minf(sz.x, sz.y) * 0.5))
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2(inv, inv), 0.0, Vector2.ZERO))
	RenderingServer.canvas_item_add_nine_patch(ci, Rect2(p, sz), Rect2(Vector2.ZERO, tex.get_size()), tex.get_rid(),
			Vector2(m, m), Vector2(m, m))
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(shadow_dev / s)
