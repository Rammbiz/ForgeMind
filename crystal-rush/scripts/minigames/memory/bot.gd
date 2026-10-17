extends RefCounted
## The bot of «Хто де?» (test_minigames runs it from fixed seeds). It plays through game.tap_card (the same path
## as a finger) and game.advance (game time), synchronously.
## - want_win: an honest player with a perfect memory. It knows only what the board showed (flips, peeks, swaps
##   done in plain sight) and never reads face-down cards.
## - lose: turns up two DIFFERENT characters every try (it may read the board: its job is to prove a loss ends
##   the game), so the tries run out.

const STEP := 0.9          ## game seconds between taps (a missed pair closes after 0.8 s)
const MAX_TAPS := 400


func play(game: MinigameGame, want_win: bool) -> void:
	var b: MgMemoryBoard = game.get("board")
	var known := {}        # slot -> character id seen there
	var cursor := 0
	var taps := 0
	while not game.is_done() and taps < MAX_TAPS:
		cursor = _learn(b, known, cursor)
		if b.is_over():
			game.advance(1.0)
			continue
		var s := _pick_win(b, known) if want_win else _pick_lose(b)
		if s < 0:
			game.advance(STEP)
			continue
		game.call("tap_card", s)
		taps += 1
		if b.pending.size() == 2 or b.first < 0:
			game.advance(STEP)
	game.advance(1.0)


## Reads the new board events into `known` (what a player could have seen). Returns the new cursor.
func _learn(b: MgMemoryBoard, known: Dictionary, cursor: int) -> int:
	while cursor < b.events.size():
		var e: Dictionary = b.events[cursor]
		cursor += 1
		match str(e["t"]):
			"flip":
				known[int(e["i"])] = str(e["id"])
			"trick":
				match str(e["kind"]):
					"swap":
						var a := int(e["a"])
						var c := int(e["b"])
						var ka: Variant = known.get(a)
						var kc: Variant = known.get(c)
						known.erase(a)
						known.erase(c)
						if kc != null:
							known[a] = kc
						if ka != null:
							known[c] = ka
					"peek":
						var slots: Array = e["slots"]
						var ids: Array = e["ids"]
						for i in slots.size():
							known[int(slots[i])] = str(ids[i])
	return cursor


func _pick_win(b: MgMemoryBoard, known: Dictionary) -> int:
	if b.first >= 0:
		var want := str(known.get(b.first, b.cards[b.first]))
		for s in known:
			if int(s) != b.first and b.state[int(s)] == MgMemoryBoard.DOWN and str(known[s]) == want:
				return int(s)
		return _unknown(b, known, b.first)
	# A known pair face down: take it.
	var by_id := {}
	for s2 in known:
		if b.state[int(s2)] != MgMemoryBoard.DOWN:
			continue
		var id := str(known[s2])
		if by_id.has(id):
			return int(by_id[id])
		by_id[id] = int(s2)
	return _unknown(b, known, -1)


## The first face-down slot not seen yet (else any face-down slot but `skip`).
func _unknown(b: MgMemoryBoard, known: Dictionary, skip: int) -> int:
	for s in b.size():
		if s != skip and b.state[s] == MgMemoryBoard.DOWN and not known.has(s):
			return s
	for s2 in b.size():
		if s2 != skip and b.state[s2] == MgMemoryBoard.DOWN:
			return s2
	return -1


func _pick_lose(b: MgMemoryBoard) -> int:
	if b.first < 0:
		for s in b.size():
			if b.state[s] == MgMemoryBoard.DOWN:
				return s
		return -1
	for s2 in b.size():
		if s2 != b.first and b.state[s2] == MgMemoryBoard.DOWN and b.cards[s2] != b.cards[b.first]:
			return s2
	return -1
