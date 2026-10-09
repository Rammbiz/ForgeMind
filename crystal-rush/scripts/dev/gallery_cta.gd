extends Control
## CTA study zoom: every KitCTA style (UITokens.CTA_STYLES) in normal / pressed / disabled, on the
## cream frost of the hub dock and on the Portal night. One PNG per style: cta_<style>[_tag].png.
##   xvfb-run -a -s "-screen 0 2600x2600x24" godot --path . --rendering-driver opengl3 --resolution 1440x2560 res://scenes/dev/gallery_cta.tscn [-- --out=DIR --tag=2x --styles=amber,ink]

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var tag := ""
var styles: Array[String] = []


func _ready() -> void:
	styles.assign(UITokens.CTA_STYLES)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out_dir = v
			"tag": tag = v
			"styles":
				styles.clear()
				for s in v.split(",", false):
					styles.append(s.strip_edges())
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Loc.set_language("uk", false)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in styles:
		KitCTA.style = st
		var page := _page()
		add_child(page)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		await _shot("cta_" + st)
		page.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


## Three state rows on cream frost (Play + coin price, Покращити with a sapphire hero + Відкрити),
## then the same three states of «Призвати ×1» on the Portal night.
func _page() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cream := ColorRect.new()
	cream.color = Color("#F4EEE3")
	cream.position = Vector2.ZERO
	cream.size = Vector2(720, 860)
	root.add_child(cream)
	var night := ColorRect.new()
	night.color = Color("#2A2552")
	night.position = Vector2(0, 860)
	night.size = Vector2(720, 420)
	root.add_child(night)
	var y := 24.0
	for state in ["normal", "pressed", "disabled"]:
		var play := UIKit.cta_button(Loc.t("PLAY").to_upper(), "Рівень 14", Vector2(420, 104), 46)
		_place(root, play, Vector2(24, y), Vector2(420, 104), state)
		var coin := UIKit.cta_button("250", "", Vector2(176, 72), 30)
		coin.gem_icon = "coin"
		_place(root, coin, Vector2(480, y + 16), Vector2(176, 72), state)
		y += 124.0
		var up := HeroPriceCTA.make("Покращити", "Рів. 12 → 13", 970, Vector2(420, 88), 30)
		up.ctx_gem = "sapphire"
		_place(root, up, Vector2(24, y), Vector2(420, 88), state)
		var op := UIKit.cta_button("Відкрити", "", Vector2(220, 78), 30)
		_place(root, op, Vector2(468, y + 5), Vector2(220, 78), state)
		y += 152.0
	y = 884.0
	for state in ["normal", "pressed", "disabled"]:
		var su := UIKit.cta_button("Призвати ×1", "1 маяк", Vector2(300, 104), 30)
		su.sub_size = 22
		su.topaz = false
		_place(root, su, Vector2(24, y), Vector2(300, 104), state)
		var su10 := UIKit.cta_button("Призвати ×10", "10 маяків", Vector2(340, 104), 30)
		su10.sub_size = 22
		su10.ctx_gem = "amethyst"
		_place(root, su10, Vector2(348, y), Vector2(340, 104), state)
		y += 128.0
	return root


func _place(root: Control, b: KitCTA, pos: Vector2, sz: Vector2, state: String) -> void:
	b.sweep = false
	b.position = pos
	b.size = sz
	b.disabled = state == "disabled"
	b.preview_down = state == "pressed"
	root.add_child(b)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var file := name + ("_" + tag if tag != "" else "") + ".png"
	img.save_png(out_dir.path_join(file))
	print("SHOT ", file)
