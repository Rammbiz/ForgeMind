extends RefCounted
## Self-test of «Хто де?» (run by scenes/dev/test_minigames.tscn): the deal, every rule and trick of MgMemoryBoard,
## stars and score, the view following the board, a real mouse tap through the viewport, and the bot's win rate.


func run(t: MinigameTest) -> void:
	_deal(t)
	_rules(t)
	_tricks(t)
	await _view(t)
	_bot_rate(t)


func _board(seed_n: int) -> MgMemoryBoard:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	return MgMemoryBoard.new(rng, MgMemoryBoard.pool(), "hohotun")


## A board with a fixed layout (slots 0..15).
func _fixed(layout: Array[String]) -> MgMemoryBoard:
	var b := _board(1)
	b.cards = layout.duplicate()
	return b


const LAYOUT: Array[String] = ["hohotun", "mila", "taras", "ivo", "mila", "hohotun", "ivo", "taras",
		"seer", "motyvator", "skovoroda", "otto", "otto", "skovoroda", "motyvator", "seer"]


func _deal(t: MinigameTest) -> void:
	var pool := MgMemoryBoard.pool()
	t.ok(pool.size() >= 30, "every character with art is in the pool (%d)" % pool.size())
	var b := _board(11)
	t.eq(b.size(), MgMemoryBoard.COLS * MgMemoryBoard.ROWS, "16 cards")
	var count := {}
	for id in b.cards:
		count[id] = int(count.get(id, 0)) + 1
	var pairs_ok := count.size() == MgMemoryBoard.PAIRS
	for id2 in count:
		pairs_ok = pairs_ok and int(count[id2]) == 2
	t.ok(pairs_ok, "8 characters, each twice")
	t.ok(count.has("hohotun"), "the host is on every board")
	var tricksters := 0
	for id3 in count:
		if MgMemoryBoard.TRICKS.has(id3):
			tricksters += 1
	t.ok(tricksters >= 2 and tricksters <= 3, "the host + 1-2 more tricksters (%d)" % tricksters)
	t.eq(_board(11).cards, b.cards, "same seed, same deal")
	var differ := 0
	for s in range(12, 22):
		if _board(s).cards != b.cards:
			differ += 1
	t.eq(differ, 10, "other seeds deal other boards")


func _rules(t: MinigameTest) -> void:
	var b := _fixed(LAYOUT)
	t.ok(b.flip(1) and b.first == 1, "first card up")
	t.ok(not b.flip(1), "the same card can not be turned twice")
	t.ok(b.flip(4), "second card up")
	t.ok(b.state[1] == MgMemoryBoard.MATCHED and b.state[4] == MgMemoryBoard.MATCHED and b.matched == 1 and b.tries == 1,
			"a pair is found and costs one try")
	t.ok(not b.flip(4), "a found card can not be turned")
	t.ok(b.flip(3) and b.flip(11), "a miss turns two different cards")
	t.ok(b.tries == 2 and b.pending.size() == 2 and b.state[3] == MgMemoryBoard.UP, "a miss costs a try and stays up")
	t.ok(b.flip(6) and b.state[3] == MgMemoryBoard.DOWN and b.state[11] == MgMemoryBoard.DOWN, "the next tap closes the miss first")
	t.ok(b.flip(3) and b.state[3] == MgMemoryBoard.MATCHED, "and the remembered partner matches")
	# Stars and score on a won board.
	var w := _fixed(LAYOUT)
	w.tries = MgMemoryBoard.STARS_3
	w.won = true
	w.matched = MgMemoryBoard.PAIRS
	t.eq(w.stars(), 3, "3 stars within STARS_3 tries")
	w.tries = MgMemoryBoard.STARS_2
	t.eq(w.stars(), 2, "2 stars within STARS_2 tries")
	w.tries = MgMemoryBoard.MAX_TRIES
	t.eq(w.stars(), 1, "1 star for any other win")
	t.eq(w.score(), MgMemoryBoard.PAIRS * 100 + w.tricks_fired * 10, "score: pairs + tries left + tricks")
	w.won = false
	t.eq(w.stars(), 0, "no stars without a win")
	# A loss: tries run out.
	var l := _fixed(LAYOUT)
	var guard := 0
	while not l.is_over() and guard < 100:
		guard += 1
		l.flip(2)
		l.flip(8 if l.cards[8] != l.cards[2] else 9)
		l.close_pending()
	t.ok(l.lost and not l.won and l.tries == l.limit, "tries run out: lost (%d of %d)" % [l.tries, l.limit])
	t.ok(not l.flip(0), "nothing turns after the end")


func _tricks(t: MinigameTest) -> void:
	# swap: the first time a Гоготун card turns up, two other face-down cards swap.
	var b := _fixed(LAYOUT)
	var before := b.cards.duplicate()
	b.flip(0)
	var sw := _trick(b, "swap")
	t.ok(not sw.is_empty() and b.cards[int(sw["a"])] == before[int(sw["b"])] and b.cards[int(sw["b"])] == before[int(sw["a"])],
			"Гоготун swaps two face-down cards in plain sight")
	t.ok(int(sw.get("a", 0)) != 0 and int(sw.get("b", 0)) != 0, "the swap never moves his own card")
	b.flip(b.cards.find("hohotun", 1))
	var swaps := 0
	for e in b.events:
		if str(e["t"]) == "trick" and str(e["kind"]) == "swap":
			swaps += 1
	t.eq(swaps, 2, "his second card swaps once more (the first turn of each of his cards)")
	# open_pair: Тарас found -> one more pair for free.
	var o := _fixed(LAYOUT)
	o.flip(2)
	o.flip(7)
	var op := _trick(o, "open_pair")
	t.ok(not op.is_empty() and o.matched == 2 and o.tries == 1, "Тарас opens one more pair without a try")
	# peek: Мейра found -> her neighbours show (ids in the event).
	var p := _fixed(LAYOUT)
	p.flip(8)
	p.flip(15)
	var pk := _trick(p, "peek")
	t.ok(not pk.is_empty() and (pk["slots"] as Array).has(4) and (pk["slots"] as Array).has(11), "Мейра peeks at her neighbours")
	t.ok((pk["ids"] as Array).size() == (pk["slots"] as Array).size(), "the peek tells what is there")
	# bonus: Мотиватор found -> +2 tries.
	var m := _fixed(LAYOUT)
	m.flip(9)
	m.flip(14)
	t.eq(m.limit, MgMemoryBoard.MAX_TRIES + MgMemoryBoard.BONUS_TRIES, "Мотиватор adds two tries")
	# slip: the first miss with Сковорода does not count, the second does.
	var s := _fixed(LAYOUT)
	s.flip(10)
	s.flip(11)
	t.ok(s.tries == 0 and not _trick(s, "slip").is_empty(), "Сковорода slips away once")
	s.close_pending()
	s.flip(13)
	s.flip(12)
	t.eq(s.tries, 1, "only once a play")


func _trick(b: MgMemoryBoard, kind: String) -> Dictionary:
	for e in b.events:
		if str(e["t"]) == "trick" and str(e["kind"]) == kind:
			return e
	return {}


func _view(t: MinigameTest) -> void:
	var g := t.make_game(5)
	await g.get_tree().process_frame
	var b: MgMemoryBoard = g.get("board")
	t.ok(g.status_text() != "" and not g.status_text().contains("%"), "status line: %s" % g.status_text())
	# A real mouse tap through the viewport turns the card under it.
	var slot := 0
	for i in b.size():
		if not MgMemoryBoard.TRICKS.has(b.cards[i]):
			slot = i
			break
	t.tap(g.call("slot_center", slot))
	t.ok(b.state[slot] == MgMemoryBoard.UP, "a mouse tap on a card turns it (touch arrives as mouse)")
	var cards: Array = g.get("_cards")
	t.ok((cards[slot] as MgMemoryCard).face, "the card shows its face")
	var other := -1
	for j in b.size():
		if j != slot and b.cards[j] != b.cards[slot] and not MgMemoryBoard.TRICKS.has(b.cards[j]):
			other = j
			break
	g.call("tap_card", other)
	t.ok(b.pending.size() == 2, "a miss is open")
	g.advance(1.0)
	t.ok(b.pending.is_empty() and not (cards[slot] as MgMemoryCard).face, "the miss closes after a moment")
	g.set_paused(true)
	g.call("tap_card", slot)
	t.ok(b.state[slot] == MgMemoryBoard.DOWN, "no taps while paused")
	g.set_paused(false)
	t.free_game(g)
	# Shot states build without errors.
	for shot in ["board", "trick", "near_win"]:
		var gs := t.make_game(9, "free", false)
		await gs.prepare_shot(shot)
		var bs: MgMemoryBoard = gs.get("board")
		t.ok(not bs.is_over() and bs.matched >= 1, "shot %s: a board in play (%d pairs)" % [shot, bs.matched])
		t.free_game(gs)


## The honest bot's wins and stars over many seeds (printed; the bar keeps the game fair, not trivial).
func _bot_rate(t: MinigameTest) -> void:
	var bot: Object = load("res://scripts/minigames/memory/bot.gd").new()
	var wins := 0
	var stars := [0, 0, 0, 0]
	var tries := {}
	var n := 120
	for sd in range(1000, 1000 + n):
		var g := t.make_game(sd)
		bot.call("play", g, true)
		var r: Dictionary = g.result
		if bool(r.get("won", false)):
			wins += 1
		stars[int(r.get("stars", 0))] += 1
		var k := int((r.get("stats", {}) as Dictionary).get("tries", -1))
		tries[k] = int(tries.get(k, 0)) + 1
		t.free_game(g)
	var keys := tries.keys()
	keys.sort()
	var hist := ""
	for k2 in keys:
		hist += "%d:%d " % [k2, tries[k2]]
	print("    memory bot: %d / %d wins, stars 0/1/2/3 = %s, tries %s" % [wins, n, str(stars), hist])
	t.ok(wins == n, "a perfect memory always wins (%d / %d)" % [wins, n])
	t.ok(stars[3] > 0 and stars[3] < n, "3 stars are possible but not certain (%d / %d)" % [stars[3], n])
