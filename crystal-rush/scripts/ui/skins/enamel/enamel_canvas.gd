class_name EnamelCanvas
extends Control
## «Емаль і золото» immediate-mode element: _draw calls `painter(self)`.

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
