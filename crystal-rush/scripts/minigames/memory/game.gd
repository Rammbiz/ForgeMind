extends MinigameGame
## «Хто де? Пам’ять із витівками»: the view and input of MgMemoryBoard (the rules). A 4 x 4 grid of character
## cards in the play area, the tries / pairs line in the shell's status, a porcelain plate under the grid that
## names a trick when one fires. Every timer runs on tick(), so a bot or a test drives the game frame by frame.

const MISS_SHOW := 0.8     ## a missed pair stays up this long (the next tap closes it at once)
const PEEK_SHOW := 1.0     ## Мейра's peek keeps the neighbours open this long
const END_WAIT := 0.5      ## the last pair is seen before the result panel
const TOAST_SHOW := 1.8
const CARD := Vector2(156, 208)
const GAP := 14.0
const SLIDE := 0.35        ## a swap glides in the quick moment

var board: MgMemoryBoard
var _cards: Array[MgMemoryCard] = []   ## slot -> card view
var _grid: Control
var _toast: PanelContainer
var _ev := 0                            ## events of the board already shown
var _miss_t := -1.0
var _peek := {}                         ## slot -> seconds left open
var _end_t := -1.0
var _toast_t := 0.0
var _instant := false                   ## shots: no animation


func _on_setup() -> void:
	board = MgMemoryBoard.new(rng, MgMemoryBoard.pool(), str(params.get("host", "hohotun")))


func _on_build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.size = grid_size()
	add_child(_grid)
	for s in board.size():
		var c := MgMemoryCard.new()
		c.setup(s, board.cards[s])
		c.size = CARD
		c.tapped.connect(_on_tapped)
		_grid.add_child(c)
		_cards.append(c)
	_toast = MinigameUI.plate("", 24, UITokens.INK, 640.0)
	_toast.visible = false
	add_child(_toast)
	resized.connect(_layout)
	_layout()


static func grid_size() -> Vector2:
	return Vector2(MgMemoryBoard.COLS * CARD.x + (MgMemoryBoard.COLS - 1) * GAP, MgMemoryBoard.ROWS * CARD.y + (MgMemoryBoard.ROWS - 1) * GAP)


## Top-left of slot `s` inside the grid.
static func slot_pos(s: int) -> Vector2:
	return Vector2(float(s % MgMemoryBoard.COLS) * (CARD.x + GAP), float(s / MgMemoryBoard.COLS) * (CARD.y + GAP))


func _layout() -> void:
	var gs := grid_size()
	var room := 150.0     # the trick plate under the grid
	var y := maxf(8.0, floorf((size.y - gs.y - room) * 0.5))
	_grid.position = Vector2(floorf((size.x - gs.x) * 0.5), y)
	for s in _cards.size():
		_cards[s].position = slot_pos(s)
	_place_toast()


func _place_toast() -> void:
	if not _toast:
		return
	_toast.size = _toast.get_combined_minimum_size()
	_toast.position = Vector2(floorf((size.x - _toast.size.x) * 0.5), _grid.position.y + grid_size().y + 34.0)


## The screen position of slot `s` (centre), for tests that tap like a finger.
func slot_center(s: int) -> Vector2:
	return _grid.get_global_rect().position + slot_pos(s) + CARD * 0.5


## Turns card `s` the way a finger tap does (the bot and tests use this; a real tap arrives via MgMemoryCard).
func tap_card(s: int) -> void:
	_on_tapped(s)


func _on_tapped(s: int) -> void:
	if not started or paused or is_done() or _end_t >= 0.0:
		return
	if board.flip(s):
		Audio.play("click", -6.0)
		_show_events()
		status_changed.emit()


func _anim() -> bool:
	return not manual_time and not _instant


func _show_events() -> void:
	while _ev < board.events.size():
		var e: Dictionary = board.events[_ev]
		_ev += 1
		match str(e["t"]):
			"flip":
				_peek.erase(int(e["i"]))
				_cards[int(e["i"])].show_face(true, _anim())
			"match":
				_cards[int(e["a"])].set_matched(true)
				_cards[int(e["b"])].set_matched(true)
				if not manual_time:
					Audio.chord(5, true, -8.0)
			"miss":
				_miss_t = MISS_SHOW
			"close":
				_miss_t = -1.0
				for s in (e["slots"] as Array):
					_cards[int(s)].show_face(false, _anim())
			"trick":
				_show_trick(e)
	if board.is_over() and _end_t < 0.0:
		_end_t = END_WAIT


func _show_trick(e: Dictionary) -> void:
	var who := MinigameUI.char_name(str(e["id"]))
	var act := Loc.t("ACT_" + str(e["id"]).to_upper())
	var text := ""
	match str(e["kind"]):
		"swap":
			var a := int(e["a"])
			var b := int(e["b"])
			var ca := _cards[a]
			_cards[a] = _cards[b]
			_cards[b] = ca
			_cards[a].slot = a
			_cards[b].slot = b
			for s in [a, b]:
				if _anim():
					_cards[s].create_tween().tween_property(_cards[s], "position", slot_pos(s), SLIDE) \
							.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				else:
					_cards[s].position = slot_pos(s)
			text = Loc.f("MG_MEMORY_TRICK_SWAP", [who, act])
		"open_pair":
			_cards[int(e["a"])].set_matched(true)
			_cards[int(e["b"])].set_matched(true)
			text = Loc.f("MG_MEMORY_TRICK_OPEN", [who, act])
		"peek":
			for s2 in (e["slots"] as Array):
				_cards[int(s2)].show_face(true, _anim())
				_peek[int(s2)] = PEEK_SHOW
			text = Loc.f("MG_MEMORY_TRICK_PEEK", [who])
		"bonus":
			text = Loc.f("MG_MEMORY_TRICK_BONUS", [who, act])
		"slip":
			text = Loc.f("MG_MEMORY_TRICK_SLIP", [who])
	_say(text)


func _say(text: String) -> void:
	if text == "" or not _toast:
		return
	(_toast.get_meta("label") as Label).text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_t = TOAST_SHOW
	_place_toast()
	if _anim():
		UIKit.pop_in(_toast, 0.0, MinigameUI.POP)


func _on_tick(dt: float) -> void:
	if _miss_t >= 0.0:
		_miss_t -= dt
		if _miss_t < 0.0 and board.pending.size() == 2:
			board.close_pending()
			_show_events()
	for s in _peek.keys():
		_peek[s] = float(_peek[s]) - dt
		if float(_peek[s]) <= 0.0:
			_peek.erase(s)
			if board.state[int(s)] == MgMemoryBoard.DOWN:
				_cards[int(s)].show_face(false, _anim())
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0 and _toast:
			_toast.visible = false
	if _end_t >= 0.0:
		_end_t -= dt
		if _end_t < 0.0:
			finish(board.won, board.score(), board.stars(), {"tries": board.tries, "tricks": board.tricks_fired,
					"found": board.found.duplicate()})


func status_text() -> String:
	if board == null:
		return ""
	return Loc.f("MG_MEMORY_STATUS", [Loc.num(board.tries), Loc.num(board.limit), Loc.num(board.matched),
			Loc.num(MgMemoryBoard.PAIRS)])


## Shot states (INFO.shots), set at once without animation: board (a few pairs found, one card up), trick
## (Гоготун just swapped two cards), near_win (one pair left, one of its cards up).
func prepare_shot(shot: String) -> void:
	if not _built:
		_built = true
		_on_build()
	if not started:
		start()
	_instant = true
	match shot:
		"board":
			_match_pairs(3)
			_miss_once()
			tap_card(_first_down())
		"trick":
			_match_pairs(1)
			var h := -1
			for s in board.size():
				if board.state[s] == MgMemoryBoard.DOWN and str(MgMemoryBoard.TRICKS.get(board.cards[s], "")) == "swap":
					h = s
					break
			if h >= 0:
				tap_card(h)
		"near_win":
			_match_pairs(MgMemoryBoard.PAIRS - 1)
			tap_card(_first_down())
	if shot != "trick" and _toast:
		_toast_t = 0.0
		_toast.visible = false
	_instant = false


## Shots only: finds pairs straight away until `n` are found (reads the board; a player never can). Plain pairs
## first; Тарас's free pair only while it does not overshoot `n`.
func _match_pairs(n: int) -> void:
	var guard := 0
	while board.matched < n and not board.is_over() and guard < 64:
		guard += 1
		var a := _pair_start(n)
		if a < 0:
			return
		tap_card(a)
		var b := -1
		for s in board.size():
			if s != a and board.state[s] == MgMemoryBoard.DOWN and board.cards[s] == board.cards[a]:
				b = s
				break
		if b < 0:
			return
		tap_card(b)


func _pair_start(n: int) -> int:
	var plain := _first_plain_down()
	if plain >= 0:
		return plain
	for s in board.size():
		if board.state[s] != MgMemoryBoard.DOWN:
			continue
		var kind := str(MgMemoryBoard.TRICKS.get(board.cards[s], ""))
		if kind != "open_pair" or board.matched + 2 <= n:
			return s
	return -1


## Shots only: one missed try that closes again (two cards seen).
func _miss_once() -> void:
	var a := _first_plain_down()
	for s in board.size():
		if board.state[s] == MgMemoryBoard.DOWN and s != a and board.cards[s] != board.cards[a] \
				and str(MgMemoryBoard.TRICKS.get(board.cards[s], "")) == "":
			tap_card(a)
			tap_card(s)
			board.close_pending()
			_show_events()
			return


func _first_down() -> int:
	for s in board.size():
		if board.state[s] == MgMemoryBoard.DOWN:
			return s
	return -1


func _first_plain_down() -> int:
	for s in board.size():
		if board.state[s] == MgMemoryBoard.DOWN and str(MgMemoryBoard.TRICKS.get(board.cards[s], "")) == "":
			return s
	return -1
