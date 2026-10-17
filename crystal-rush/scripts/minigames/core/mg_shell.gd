class_name MinigameShell
extends Control
## Runs one Fair mini-game end to end (docs/design/minigames/README.md «Shell»): the still porcelain backdrop, a
## top bar (pause disc, the game's title, its status line), the game in the play area, the intro card, the pause
## panel and the result panel. The shell, never the game, talks to Meta: Meta.fair_begin() deals the seed and the
## mode, Meta.fair_book() books and SAVES the result before the result panel shows, Meta.fair_book_ad() pays the
## one ad reward of the day after Ads.show() reports the ad was watched.
##
##   var shell := MinigameShell.open("memory")          # the Fair (part 1) adds it full-screen
##   shell.closed.connect(func(bundle): ...)            # the player left; the shell frees itself
## opts (dev / tests): seed (fixed board), mode ("free" | "rewarded"), skip_intro, manual_time (nothing moves
## unless the caller ticks the game), keep_on_close (do not free on close), no_auto_pause (a hidden dev window
## loses focus: do not pause on it).

signal closed(bundle: Dictionary)   ## the player left (the last booked bundle, {} when nothing was booked)
signal state_changed(state: String) ## "intro" | "play" | "pause" | "result" | "closed"

const TOP_H := 164.0                ## top bar under the safe inset: pause disc, title, status line
## The title's room in the top bar (720 minus the pause disc on each side); a title must fit it on one line at 28 px
## (MinigameRegistry.errors checks both languages).
const TITLE_W := 720.0 - 2.0 * 112.0

var game_id := ""
var entry := {}
var opts := {}
var game: MinigameGame
var mode := "free"
var play_seed := 0
var bundle := {}
var state := ""
var overlay: Control                ## the intro card, pause panel or result panel on top
var _ins := Vector4.ZERO
var _title: Label
var _status: Label
var _pause_btn: Control
var _holder: Control


static func open(id: String, p_opts: Dictionary = {}) -> MinigameShell:
	var s := MinigameShell.new()
	s.game_id = id
	s.opts = p_opts.duplicate(true)
	return s


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entry = MinigameRegistry.game(game_id)
	_ins = UIKit.safe_insets(get_viewport())
	add_child(MinigameUI.backdrop())
	_holder = Control.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.offset_top = _ins.y + TOP_H
	_holder.offset_bottom = -_ins.w
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_build_top()
	if entry.is_empty():
		push_error("MinigameShell: unknown game %s" % game_id)
		return
	begin()


func _build_top() -> void:
	var top := Control.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = _ins.y
	top.offset_bottom = _ins.y + TOP_H
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var t := Loc.t(str(entry.get("title", game_id)))
	_title = UIKit.heading(t, UIKit.fit_size(t, TITLE_W, 40, 28), UIKit.INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 112.0
	_title.offset_right = -112.0
	_title.offset_top = 22.0
	_title.offset_bottom = 78.0
	top.add_child(_title)
	_status = UIKit.label("", 24, UIKit.INK_DIM_GLASS)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_left = 40.0
	_status.offset_right = -40.0
	_status.offset_top = 84.0
	_status.offset_bottom = 120.0
	top.add_child(_status)
	var dv := UIKit.divider(560.0)
	dv.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	dv.offset_left = -280.0
	dv.offset_right = 280.0
	dv.offset_top = TOP_H - 26.0
	dv.offset_bottom = TOP_H - 12.0
	top.add_child(dv)
	var pb := UIKit.edge_button("pause", 38.0)
	pb.position = Vector2(UITokens.GUTTER, 16.0)
	pb.pressed.connect(pause)
	top.add_child(pb)
	_pause_btn = pb


## Deals a new play: seed and mode from Meta.fair_begin (or opts), a fresh game node, the intro card.
func begin() -> void:
	_close_overlay()
	if game and is_instance_valid(game):
		game.queue_free()
	game = null
	bundle = {}
	var b := {}
	if opts.has("seed"):
		b = {"seed": int(opts["seed"]), "mode": str(Meta.fair_status(game_id)["mode"])}
	else:
		b = Meta.fair_begin(game_id)
	if opts.has("mode"):
		b["mode"] = str(opts["mode"])
	mode = str(b["mode"])
	play_seed = int(b["seed"])
	game = MinigameRegistry.instance(game_id)
	if game == null:
		push_error("MinigameShell: %s does not instance" % game_id)
		_leave()
		return
	game.setup({"id": game_id, "seed": play_seed, "mode": mode, "host": str(entry.get("host", "")),
			"manual_time": bool(opts.get("manual_time", false))})
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(game)
	game.finished.connect(_on_finished)
	game.status_changed.connect(_sync_status)
	_sync_status()
	if bool(opts.get("skip_intro", false)):
		_start_game()
	else:
		_show_intro()


func _show_intro() -> void:
	_set_state("intro")
	var card := MinigameIntroCard.new()
	card.setup(entry, Meta.fair_status(game_id), mode)
	card.play_pressed.connect(func() -> void:
		_close_overlay()
		_start_game())
	card.back_pressed.connect(_leave)
	_show_overlay(card)


func _start_game() -> void:
	_set_state("play")
	game.start()


func _sync_status() -> void:
	if game and is_instance_valid(game):
		_status.text = game.status_text()


func _on_finished(res: Dictionary) -> void:
	_set_state("booking")
	bundle = Meta.fair_book(game_id, res, mode)
	if not bool(bundle.get("ok", false)):
		# The write failed and Meta rolled back: show the outcome, nothing paid.
		bundle = {"ok": false, "won": bool(res.get("won", false)), "stars": int(res.get("stars", 0)),
				"score": int(res.get("score", 0)), "best_score": int(res.get("score", 0)), "reason": "free"}
	_sync_status()
	if not game.manual_time and is_inside_tree():
		await get_tree().create_timer(0.6).timeout
	if state == "booking":
		_show_result()


func _show_result() -> void:
	_set_state("result")
	var rp := MinigameResultPanel.new()
	rp.setup(bundle)
	rp.retry_pressed.connect(begin)
	rp.back_pressed.connect(_leave)
	rp.ad_pressed.connect(func() -> void: _watch_ad(rp))
	_show_overlay(rp)


func _watch_ad(rp: MinigameResultPanel) -> void:
	var res := game.result.duplicate(true)
	var n := int(bundle.get("play_n", 0))
	if rp.ad_button:
		rp.ad_button.disabled = true
	Ads.show(func(ok: bool) -> void:
		if not is_instance_valid(rp):
			return
		if not ok:
			if rp.ad_button:
				rp.ad_button.disabled = false
			return
		rp.show_ad_bundle(Meta.fair_book_ad(game_id, res, n)))


## Pauses the play (the pause disc, Android back, the app going to the background).
func pause() -> void:
	if state != "play":
		return
	_set_state("pause")
	game.set_paused(true)
	var m := UIKit.modal(Loc.t("MG_PAUSE"), resume, 600.0)
	var body: VBoxContainer = m.get_meta("body")
	body.add_theme_constant_override("separation", 16)
	body.add_child(MinigameUI.body(Loc.t("MG_QUIT_NOTE"), 24, UIKit.INK_DIM_GLASS))
	var go := UIKit.cta_button(Loc.t("MG_RESUME"), "", Vector2(460, 96), 32)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(resume)
	body.add_child(go)
	var quit := UIKit.plate_link(Loc.t("MG_QUIT"), "back", Vector2(360, 64), 24)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(_leave)
	body.add_child(quit)
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, UITokens.SCRIM_MODAL)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(scrim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(cc)
	cc.add_child(m)
	UIKit.pop_in(m, 0.0, MinigameUI.POP)
	_show_overlay(wrap)


func resume() -> void:
	if state != "pause":
		return
	_close_overlay()
	game.set_paused(false)
	_set_state("play")


## The player leaves (intro «Назад», pause «Вийти з гри», result «Назад»): an unfinished play books nothing.
func _leave() -> void:
	_set_state("closed")
	closed.emit(bundle)
	if not bool(opts.get("keep_on_close", false)):
		queue_free()


func _show_overlay(c: Control) -> void:
	_close_overlay()
	overlay = c
	add_child(c)


func _close_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _set_state(s: String) -> void:
	state = s
	if _pause_btn:
		_pause_btn.visible = s == "play" or s == "pause"
	state_changed.emit(s)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			match state:
				"play":
					pause()
				"pause":
					resume()
				"intro", "result":
					_leave()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not bool(opts.get("no_auto_pause", false)):
				pause()
