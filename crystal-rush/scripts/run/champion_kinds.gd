class_name ChampionKinds
extends RefCounted
## Champion behaviour rules over a KindView (heroes design §4.2, §4.3, §10.4-10.5). Pure static,
## shared by Run and LevelSim like HeroKinds.
##
## Phase H0: the API only. KINDS is empty and every rule is a no-op, so nothing changes in a run
## until phase H2 (HeroKinds.champions_live()) fills it from WS-A's ChampionData.

## Slot names in the conflict order of §4.2 (front -> rear -> left -> right).
const FRONT := &"front"
const LEFT := &"left"
const RIGHT := &"right"
const REAR := &"rear"
const SLOT_ORDER: Array[StringName] = [FRONT, REAR, LEFT, RIGHT]

## Class -> preferred slots (§4.2: Guardian / Warrior front, Ranger / Mage rear then right,
## Healer left / right). Classes are WS-A's TeamData ids.
const CLASS_SLOTS := {
	"guardian": [FRONT], "warrior": [FRONT],
	"ranger": [REAR, RIGHT], "mage": [REAR, RIGHT],
	"healer": [LEFT, RIGHT],
}

## Champion id -> kind row {class, action, aura}. Empty until H2.
const KINDS := {}


## Places `members` ([{id, class}] in team order) on the slots: each takes its first free
## preferred slot, else the first free slot in SLOT_ORDER. Returns id -> slot. Empty while the
## champions phase is off or `count` is 0.
static func assign_slots(members: Array, count: int) -> Dictionary:
	var out := {}
	if not HeroKinds.champions_live() or count <= 0:
		return out
	var free: Array[StringName] = SLOT_ORDER.duplicate()
	for m: Dictionary in members.slice(0, count):
		var pick: StringName = &""
		for sl: StringName in CLASS_SLOTS.get(str(m.get("class", "")), []):
			if sl in free:
				pick = sl
				break
		if pick == &"" and not free.is_empty():
			pick = free[0]
		if pick != &"":
			free.erase(pick)
			out[str(m["id"])] = pick
	return out


## Offset of `slot` from the blob centre for a blob of radius `r` (§4.2 contract, `r' = max(r,
## 0.6)`; x = across the bridge, y = along the run, + = behind the centre).
static func slot_offset(slot: StringName, r: float) -> Vector2:
	var rr := maxf(r, 0.6)
	match slot:
		FRONT:
			return Vector2(0.0, -0.63 * rr)
		LEFT:
			return Vector2(-0.55 * rr, 0.1 * rr)
		RIGHT:
			return Vector2(0.55 * rr, 0.1 * rr)
		REAR:
			return Vector2(0.0, 0.69 * rr)
	return Vector2.ZERO


## One step of every living champion's Action / Aura (H2). No-op in H0.
static func step(_view: KindView, _members: Array, _dt: float) -> void:
	pass
