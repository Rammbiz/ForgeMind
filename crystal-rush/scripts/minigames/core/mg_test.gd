class_name MinigameTest
extends RefCounted
## Helpers for a game's selftest.gd and bot.gd (docs/design/minigames/README.md «Tests»). test_minigames.tscn
## makes one per game and calls `await <selftest.gd>.new().run(t)`; the game's bot is run through run_bot().
##
##   func run(t: MinigameTest) -> void:
##       var g := t.make_game(7)                  # seed 7, free mode, manual time, started, in the tree
##       t.ok(g.status_text() != "", "status line")
##       t.tap(Vector2(100, 300))                 # a mouse press + release through the viewport (touch = mouse)
##       g.advance(1.0)                           # one game second
##       t.free_game(g)

## The play area the shell gives a game (720 wide, under its top bar); tests use the same rect.
const AREA := Rect2(0.0, MinigameShell.TOP_H, 720.0, 1280.0 - MinigameShell.TOP_H)

var game_id := ""
var host: Node                 ## a node in the tree (the test scene)
var passes := 0
var fails := 0
var _holder: Control


func _init(p_id := "", p_host: Node = null) -> void:
	game_id = p_id
	host = p_host


func ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		print("  FAIL [%s]: %s" % [game_id, what])


func eq(a: Variant, b: Variant, what: String) -> void:
	ok(typeof(a) == typeof(b) and a == b, "%s (got %s, want %s)" % [what, var_to_str(a), var_to_str(b)])


## A fresh game of `game_id`: set up with `seed` / `mode` and manual time (nothing moves until you tick it),
## added to the tree in the shell's play area, and started unless `start` is false.
func make_game(seed_n := 1, mode := "free", start := true) -> MinigameGame:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Control.new()
		_holder.theme = UIKit.theme()
		_holder.position = AREA.position
		_holder.size = AREA.size
		_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(_holder)
	var g := MinigameRegistry.instance(game_id)
	if g == null:
		ok(false, "MinigameRegistry.instance(%s)" % game_id)
		return null
	g.setup({"id": game_id, "seed": seed_n, "mode": mode, "host": str(MinigameRegistry.game(game_id).get("host", "")),
			"manual_time": true})
	_holder.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if start:
		g.start()
	return g


func free_game(g: MinigameGame) -> void:
	if g and is_instance_valid(g):
		g.get_parent().remove_child(g)
		g.free()


## A left-button press and release at `pos` (canvas coordinates, 720 x 1280) through the viewport, the way a
## finger tap arrives (touch is emulated as mouse).
func tap(pos: Vector2) -> void:
	var vp := host.get_viewport()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev, true)


## tap() at the centre of control `c`.
func tap_control(c: Control) -> void:
	tap(c.get_global_rect().get_center())


## Runs the game's bot.gd on a fresh game: `want_win` true must win, false must lose. Returns the finished result
## ({} when the bot did not finish).
func run_bot(seed_n: int, want_win: bool, mode := "free") -> Dictionary:
	var path := str(MinigameRegistry.game(game_id).get("dir", "")) + "bot.gd"
	if not ResourceLoader.exists(path):
		ok(false, "%s exists" % path)
		return {}
	var bot: Object = (load(path) as GDScript).new()
	var g := make_game(seed_n, mode)
	if g == null:
		return {}
	await bot.call("play", g, want_win)
	var res := g.result.duplicate(true)
	free_game(g)
	return res
