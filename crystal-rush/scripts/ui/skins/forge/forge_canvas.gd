class_name ForgeCanvas
extends Control
## «Кришталева кузня» immediate-mode element: _draw calls `painter(self)`.

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
