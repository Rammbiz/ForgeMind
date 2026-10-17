class_name MgMemoryBoard
extends RefCounted
## Rules of «Хто де? Пам’ять із витівками» (side_content_ideas.md Group 3 #3): pairs of character cards on a 4 x 4
## board; a try = two cards turned up. Some characters play a trick (TRICKS). Pure and deterministic: every random
## choice uses the game's RandomNumberGenerator. The view and the bot read `events` (appended in order, never
## removed during a play): {t: "flip", i, id} · {t: "match", a, b, id} · {t: "miss", a, b} · {t: "close", slots} ·
## {t: "trick", kind, id, ...} (swap {a, b} · open_pair {a, b, pair} · peek {slots, ids} · bonus {add} · slip {a, b}).

const COLS := 4
const ROWS := 4
const PAIRS := 8
const MAX_TRIES := 20
## Tries (at most) for 3 and 2 stars; any other win is 1 star. Measured with the bot's perfect memory (selftest,
## 120 seeds): 9-14 tries, median 11, so 3 stars ask for a perfect memory and some luck with the deal, 2 stars
## for a careful player; 20 tries (+2 from Мотиватор) leave room for a child or a tired evening.
const STARS_3 := 11
const STARS_2 := 14
## Character id -> trick. swap: the first time each of its cards turns up, two other face-down cards swap places
## (in plain sight); open_pair: its pair found -> one more pair is found for free; peek: its pair found -> the
## face-down cards next to both open for a moment; bonus: its pair found -> +BONUS_TRIES tries; slip: the first
## miss that turns its card up does not count.
const TRICKS := {"hohotun": "swap", "taras": "open_pair", "seer": "peek", "motyvator": "bonus", "skovoroda": "slip"}
const BONUS_TRIES := 2
## Tricksters on a board besides the host (whose trick is always on the board).
const EXTRA_TRICKSTERS := Vector2i(1, 2)

enum { DOWN, UP, MATCHED }

var cards: Array[String] = []    ## character id per slot (COLS x ROWS)
var state: Array[int] = []       ## DOWN | UP | MATCHED per slot
var turned: Array[bool] = []     ## the slot was ever turned up (a swap trick fires on a first turn)
var tries := 0
var limit := MAX_TRIES
var matched := 0
var first := -1                  ## the first card of the try in progress (-1 none)
var pending: Array[int] = []     ## a missed pair still face up (closed by close_pending() or the next flip)
var events: Array[Dictionary] = []
var tricks_fired := 0
var found := {}                  ## character id -> 1 for every pair found this play
var won := false
var lost := false
var _rng: RandomNumberGenerator
var _slip_used := false


## Deals PAIRS characters from `pool` (the host first, 1-2 more tricksters, the rest plain), shuffled with `rng`.
func _init(rng: RandomNumberGenerator, pool: Array[String], host := "hohotun") -> void:
	_rng = rng
	var chosen: Array[String] = []
	if host in pool:
		chosen.append(host)
	var tricksters: Array[String] = []
	var plain: Array[String] = []
	for id in pool:
		if id in chosen:
			continue
		if TRICKS.has(id):
			tricksters.append(id)
		else:
			plain.append(id)
	_shuffle(tricksters)
	_shuffle(plain)
	var n_tricks := _rng.randi_range(EXTRA_TRICKSTERS.x, EXTRA_TRICKSTERS.y)
	for i in mini(n_tricks, tricksters.size()):
		chosen.append(tricksters[i])
	for id2 in plain:
		if chosen.size() >= PAIRS:
			break
		chosen.append(id2)
	for id3 in tricksters:
		if chosen.size() >= PAIRS:
			break
		if not id3 in chosen:
			chosen.append(id3)
	cards.clear()
	for id4 in chosen:
		cards.append(id4)
		cards.append(id4)
	_shuffle(cards)
	state.clear()
	turned.clear()
	for _i in cards.size():
		state.append(DOWN)
		turned.append(false)


## Every character id with card art, in collector order (heroes, then champions).
static func pool() -> Array[String]:
	var out: Array[String] = []
	for id in HeroData.HERO_ORDER:
		if HeroArt.card_texture(id) != null:
			out.append(id)
	for id2 in ChampionData.CHAMPION_ORDER:
		if HeroArt.card_texture(id2) != null:
			out.append(id2)
	return out


func size() -> int:
	return cards.size()


func is_over() -> bool:
	return won or lost


## The player turns card `i` up. Returns false when that is not allowed (over, matched, already up). A missed pair
## still face up is closed first, so a quick player never waits.
func flip(i: int) -> bool:
	if is_over() or i < 0 or i >= cards.size():
		return false
	if pending.size() == 2 and not i in pending:
		close_pending()
	if state[i] != DOWN or i == first:
		return false
	state[i] = UP
	var first_turn := not turned[i]
	turned[i] = true
	events.append({"t": "flip", "i": i, "id": cards[i]})
	if first_turn and str(TRICKS.get(cards[i], "")) == "swap":
		_trick_swap(i)
	if first < 0:
		first = i
		return true
	var a := first
	first = -1
	if cards[a] == cards[i]:
		state[a] = MATCHED
		state[i] = MATCHED
		matched += 1
		tries += 1
		found[cards[i]] = 1
		events.append({"t": "match", "a": a, "b": i, "id": cards[i]})
		_on_match(cards[i], a, i)
	else:
		var slip := not _slip_used and (str(TRICKS.get(cards[a], "")) == "slip" or str(TRICKS.get(cards[i], "")) == "slip")
		if slip:
			_slip_used = true
			tricks_fired += 1
			events.append({"t": "trick", "kind": "slip", "id": cards[a] if str(TRICKS.get(cards[a], "")) == "slip" else cards[i],
					"a": a, "b": i})
		else:
			tries += 1
		pending = [a, i]
		events.append({"t": "miss", "a": a, "b": i})
	_check_end()
	return true


## Turns a missed pair face down again.
func close_pending() -> void:
	if pending.is_empty():
		return
	var closed: Array[int] = []
	for s in pending:
		if state[s] == UP:
			state[s] = DOWN
			closed.append(s)
	pending.clear()
	events.append({"t": "close", "slots": closed})


func tries_left() -> int:
	return maxi(0, limit - tries)


## 3 / 2 / 1 stars for a win by tries (STARS_3, STARS_2); 0 when not won.
func stars() -> int:
	if not won:
		return 0
	if tries <= STARS_3:
		return 3
	if tries <= STARS_2:
		return 2
	return 1


## 100 per pair; a win adds 25 per try left and 10 per trick seen.
func score() -> int:
	var s := matched * 100
	if won:
		s += tries_left() * 25 + tricks_fired * 10
	return s


func _check_end() -> void:
	if matched >= PAIRS:
		won = true
	elif tries >= limit:
		lost = true


func _on_match(id: String, a: int, b: int) -> void:
	match str(TRICKS.get(id, "")):
		"open_pair":
			var left: Array[String] = []
			for s in cards.size():
				if state[s] == DOWN and not cards[s] in left and s != first:
					left.append(cards[s])
			if left.is_empty():
				return
			var pid := left[_rng.randi_range(0, left.size() - 1)]
			var slots: Array[int] = []
			for s2 in cards.size():
				if cards[s2] == pid and state[s2] == DOWN:
					slots.append(s2)
			if slots.size() != 2:
				return
			state[slots[0]] = MATCHED
			state[slots[1]] = MATCHED
			turned[slots[0]] = true
			turned[slots[1]] = true
			matched += 1
			found[pid] = 1
			tricks_fired += 1
			events.append({"t": "trick", "kind": "open_pair", "id": id, "a": slots[0], "b": slots[1], "pair": pid})
		"peek":
			var near: Array[int] = []
			for s3 in [a, b]:
				for n in _neighbours(s3):
					if state[n] == DOWN and not n in near:
						near.append(n)
			near.sort()
			var ids: Array[String] = []
			for n2 in near:
				ids.append(cards[n2])
			tricks_fired += 1
			events.append({"t": "trick", "kind": "peek", "id": id, "slots": near, "ids": ids})
		"bonus":
			limit += BONUS_TRIES
			tricks_fired += 1
			events.append({"t": "trick", "kind": "bonus", "id": id, "add": BONUS_TRIES})


func _trick_swap(i: int) -> void:
	var cand: Array[int] = []
	for s in cards.size():
		if s != i and s != first and state[s] == DOWN and not s in pending:
			cand.append(s)
	if cand.size() < 2:
		return
	# Prefer cards the player has already seen: the trick is about memory.
	var seen: Array[int] = []
	for s2 in cand:
		if turned[s2]:
			seen.append(s2)
	var from: Array[int] = seen if seen.size() >= 2 else cand
	var a := from[_rng.randi_range(0, from.size() - 1)]
	var rest: Array[int] = []
	for s3 in cand:
		if s3 != a and cards[s3] != cards[a]:
			rest.append(s3)
	if rest.is_empty():
		return
	var b := rest[_rng.randi_range(0, rest.size() - 1)]
	var t := cards[a]
	cards[a] = cards[b]
	cards[b] = t
	tricks_fired += 1
	events.append({"t": "trick", "kind": "swap", "id": cards[i], "a": a, "b": b})


func _neighbours(s: int) -> Array[int]:
	var out: Array[int] = []
	var x := s % COLS
	var y := s / COLS
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var nx := x + d.x
		var ny := y + d.y
		if nx >= 0 and nx < COLS and ny >= 0 and ny < ROWS:
			out.append(ny * COLS + nx)
	return out


## Fisher-Yates with the game's rng (never Array.shuffle: it uses the global generator).
func _shuffle(arr: Array) -> void:
	for k in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var t: Variant = arr[k]
		arr[k] = arr[j]
		arr[j] = t
