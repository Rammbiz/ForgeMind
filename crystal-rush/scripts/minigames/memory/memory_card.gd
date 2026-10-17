class_name MgMemoryCard
extends Control
## One card of «Хто де?»: the shared porcelain back (MinigameUI.draw_card_back) or the character's gem card
## (KitGemCard with its card art and name). A flip is the quick 0.30 s turn (scale x 1 -> 0 -> 1); a found pair
## keeps its face and gets a small porcelain check badge in its top-right corner (no second gold frame). Tapping
## it (touch or mouse) emits `tapped(slot)`.

signal tapped(slot: int)

const FLIP := 0.30

var slot := 0
var char_id := ""
var face := false
var matched := false
var front: KitGemCard
var _frame: Control
var _tw: Tween


func setup(p_slot: int, p_id: String) -> void:
	slot = p_slot
	char_id = p_id


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	front = UIKit.gem_card(MinigameUI.char_gem(char_id), size)
	front.art.texture = HeroArt.card_texture(char_id)
	front.title = MinigameUI.char_name(char_id)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.visible = face
	add_child(front)
	_frame = _Frame.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	add_child(_frame)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


## Shows the face (true) or the back; `animate` = the 0.30 s turn, else at once.
func show_face(on: bool, animate := true) -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
		scale = Vector2.ONE
	if on == face:
		return
	if not animate or not is_inside_tree():
		_set_face(on)
		return
	_tw = create_tween()
	_tw.tween_property(self, "scale:x", 0.0, FLIP * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tw.tween_callback(_set_face.bind(on))
	_tw.tween_property(self, "scale:x", 1.0, FLIP * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func set_matched(on: bool) -> void:
	matched = on
	if _frame:
		_frame.visible = on
	if on:
		show_face(true, false)


func _set_face(on: bool) -> void:
	face = on
	if front:
		front.visible = on
	queue_redraw()


func _draw() -> void:
	if not face:
		MinigameUI.draw_card_back(self, Rect2(Vector2.ZERO, size))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(slot)
		accept_event()


## The found-pair badge: a porcelain disc with a 1 dpx deep-gold ring and a gold check, top right.
class _Frame:
	extends Control

	func _draw() -> void:
		var r := 15.0
		var c := Vector2(size.x - r - 7.0, r + 7.0)
		draw_circle(c, r, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.96))
		draw_arc(c, r, 0.0, TAU, 40, UITokens.LINE_GOLD_DEEP, UIKit.line_px(1.0), true)
		Icons.line(self, "check", Rect2(c - Vector2(10, 10), Vector2(20, 20)), UITokens.GOLD_TEXT_GLASS)
