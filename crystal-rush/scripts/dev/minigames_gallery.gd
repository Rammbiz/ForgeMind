extends Node
## Dev launcher and shot taker of the Fair's mini-games (docs/design/minigames/README.md «Gallery»). The save is
## never touched: the account is a synthetic dev one (level 20, expected profile).
##   godot --path crystal-rush --resolution 720x1280 res://scenes/dev/minigames_gallery.tscn
##       -> the list of every registered game; tap one to play it in the real shell (intro, play, result).
##   ... -- --game=memory --seed=7                 play one game straight away (fixed board)
##   ... -- --game=memory --out=DIR --tag=720 --shots=intro,play,board,result_win
##       -> DIR/memory_<shot>_720.png (windowed only; a headless run builds everything and saves nothing)
##   godot --headless --path crystal-rush res://scenes/dev/minigames_gallery.tscn -- --autotest
##       -> every game: the shell, its bot's win, the result panel, «Назад»; exit code = failures.
## Shots: list · intro · play · pause · result_win · result_lose · result_free (today's rewards used, no ad) ·
## result_ad (today's rewards used, an ad ready) · plus each game's INFO.shots (e.g. board, trick, near_win).
## Other args: --mode=free|rewarded · --lang=uk|en · --hold (keep the window after the shots) · --ads=dev (a dev ad
## is always ready when playing by hand).
## Run windowed builds on the hidden desktop: bash /c/Usmishka3D/tools/hidden_godot.sh <log> <timeout> <args>.

const LEVEL := 21
const FRAMEWORK_SHOTS: Array[String] = ["list", "intro", "play", "pause", "result_win", "result_lose", "result_free", "result_ad"]

var out_dir := ""
var tag := ""
var game_id := ""
var seed_n := 0
var mode := ""
var hold := false
var autotest := false
var shots: Array[String] = []
var _layer: CanvasLayer
var _root: Control
var _shell: MinigameShell
var _fails := 0


func _ready() -> void:
	var lang := "uk"
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out_dir = v
			"tag": tag = v
			"game": game_id = v
			"seed": seed_n = int(v)
			"mode": mode = v
			"lang": lang = v
			"hold": hold = true
			"autotest": autotest = true
			"ads": Ads.provider = Ads.DevProvider.new() if v == "dev" else null
			"shots":
				for s in v.split(",", false):
					shots.append(s.strip_edges())
	Save.readonly = true
	Loc.set_language(lang, false)
	Save.level = LEVEL
	Meta.account = Meta.synthetic_account(LEVEL, "expected")
	_layer = CanvasLayer.new()
	add_child(_layer)
	_root = Control.new()
	_root.theme = UIKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_root)
	await get_tree().process_frame
	if autotest:
		await _autotest()
		return
	if not shots.is_empty():
		if out_dir == "":
			push_error("minigames_gallery: pass --out=<dir> (outside the repo) with --shots")
			get_tree().quit(1)
			return
		DirAccess.make_dir_recursive_absolute(out_dir)
		var ids: Array = [game_id] if game_id != "" else Array(MinigameRegistry.ids())
		for s in shots:
			if s == "list":
				_show_list()
				await _wait(0.8)
				await _shot("list")
				continue
			for id in ids:
				await _shot_step(str(id), s)
		if not hold:
			get_tree().quit(0)
		return
	if game_id != "":
		_play(game_id)
	else:
		_show_list()


# ------------------------------------------------------------------ list (dev launcher)

func _show_list() -> void:
	_clear()
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(page)
	page.add_child(MinigameUI.backdrop())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = UITokens.GUTTER
	v.offset_right = -UITokens.GUTTER
	v.offset_top = 40.0
	v.offset_bottom = -24.0
	v.add_theme_constant_override("separation", 12)
	page.add_child(v)
	var title := UIKit.heading(Loc.t("MG_GALLERY_TITLE"), 40, UIKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(MinigameUI.body(Loc.t("MG_GALLERY_NOTE"), 22, UIKit.INK_DIM_GLASS))
	var dv := UIKit.divider(560.0)
	dv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(dv)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	sc.add_child(list)
	for g in MinigameRegistry.list():
		list.add_child(_row(g))


func _row(g: Dictionary) -> Control:
	var id := str(g["id"])
	var p := UIKit.panel("card", Vector2(16, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var host := str(g["host"])
	var card := UIKit.gem_card(MinigameUI.char_gem(host), Vector2(112, 150))
	card.art.texture = HeroArt.card_texture(host)
	card.title = MinigameUI.char_name(host)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(card)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	h.add_child(col)
	col.add_child(UIKit.caps("%s · %s · %d" % [id, str(g["kind"]), int(g["order"])], 18))
	var t := UIKit.heading(Loc.t(str(g["title"])), 28, UIKit.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	col.add_child(MinigameUI.body(Loc.t(str(g["tent"])), 22, UIKit.INK_DIM_GLASS, HORIZONTAL_ALIGNMENT_LEFT))
	var st := Meta.fair_status(id)
	col.add_child(MinigameUI.body(MinigameIntroCard.mode_line(st, str(st["mode"])), 20, UIKit.INK_DIM_GLASS, HORIZONTAL_ALIGNMENT_LEFT))
	var b := UIKit.secondary_button(Loc.t("MG_PLAY"), "", Vector2(150, 72), 24)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: _play(id))
	h.add_child(b)
	return p


func _play(id: String, extra: Dictionary = {}) -> MinigameShell:
	_clear()
	var opts := {"no_auto_pause": true}
	if seed_n > 0:
		opts["seed"] = seed_n
	if mode != "":
		opts["mode"] = mode
	opts.merge(extra, true)
	_shell = MinigameShell.open(id, opts)
	_shell.closed.connect(func(_b: Dictionary) -> void:
		_shell = null
		if game_id == "" and shots.is_empty():
			_show_list.call_deferred()
		elif shots.is_empty():
			get_tree().quit(0))
	_root.add_child(_shell)
	return _shell


func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_shell = null


# ------------------------------------------------------------------ shots

func _shot_step(id: String, s: String) -> void:
	var e := MinigameRegistry.game(id)
	if e.is_empty():
		push_warning("minigames_gallery: unknown game " + id)
		return
	if not s in FRAMEWORK_SHOTS and not (e["shots"] as Array).has(s):
		push_warning("minigames_gallery: unknown shot %s for %s" % [s, id])
		return
	_reset_day(id, s in ["result_free", "result_ad"])
	Ads.provider = Ads.DevProvider.new() if s == "result_ad" else null
	var manual := s.begins_with("result_")
	var sh := _play(id, {"seed": seed_n if seed_n > 0 else 7, "manual_time": manual, "keep_on_close": true})
	await _wait(0.6)
	match s:
		"intro":
			await _wait(0.3)
		"play":
			_start(sh)
			await _wait(0.5)
		"pause":
			_start(sh)
			await _wait(0.2)
			sh.pause()
			await _wait(0.5)
		"result_win", "result_free", "result_ad", "result_lose":
			_start(sh)
			var bot: Object = (load(str(e["dir"]) + "bot.gd") as GDScript).new()
			await bot.call("play", sh.game, s != "result_lose")
			await _wait(1.6)
		_:
			_start(sh)
			await _wait(0.2)
			await sh.game.prepare_shot(s)
			sh.call("_sync_status")
			await _wait(0.8)
	await _shot(id + "_" + s)
	Ads.provider = null


func _start(sh: MinigameShell) -> void:
	if sh.overlay is MinigameIntroCard:
		(sh.overlay as MinigameIntroCard).play_pressed.emit()


## Fresh Fair state for the shot; `used` = today's rewarded wins already used (the free / ad result).
func _reset_day(id: String, used: bool) -> void:
	var f: Dictionary = MinigamesMeta.section(Meta.account)
	f["games"] = {}
	f["ads"] = {}
	f["cosmetics"] = []
	f["day"] = MinigamesMeta.local_day(int(Time.get_unix_time_from_system()), MinigamesMeta.system_bias())
	f["today"] = {id: int(EconData.FAIR["rewarded_per_day"])} if used else {}
	f["xp_day"] = 0


## Waits `s` seconds of game time (headless: a few frames only).
func _wait(s: float) -> void:
	var t := 0.0
	var frames := 0
	var headless := DisplayServer.get_name() == "headless"
	while t < s and not (headless and frames >= 6):
		await get_tree().process_frame
		t += get_process_delta_time()
		frames += 1


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT ", name, " (headless, not saved)")
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var file := name + ("_" + tag if tag != "" else "") + ".png"
	img.save_png(out_dir.path_join(file))
	print("SHOT ", file)


# ------------------------------------------------------------------ autotest

func _autotest() -> void:
	var n := 0
	for id in MinigameRegistry.ids():
		_reset_day(id, false)
		var e := MinigameRegistry.game(id)
		var sh := _play(id, {"seed": 11, "manual_time": true, "skip_intro": true, "keep_on_close": true})
		await get_tree().process_frame
		var ok := sh.state == "play" and sh.game != null
		var bot: Object = (load(str(e["dir"]) + "bot.gd") as GDScript).new()
		await bot.call("play", sh.game, true)
		await get_tree().process_frame
		ok = ok and sh.state == "result" and sh.overlay is MinigameResultPanel and bool(sh.bundle.get("won", false))
		var closed := [false]
		sh.closed.connect(func(_b: Dictionary) -> void: closed[0] = true)
		if sh.overlay is MinigameResultPanel:
			(sh.overlay as MinigameResultPanel).back_pressed.emit()
		ok = ok and closed[0]
		print("  %s %s" % [id, "ok" if ok else "FAIL"])
		if not ok:
			_fails += 1
		n += 1
		_clear()
		await get_tree().process_frame
	print("MINIGAMES_GALLERY_AUTOTEST %s: %d games, %d failed" % ["PASS" if _fails == 0 else "FAIL", n, _fails])
	get_tree().quit(_fails)
