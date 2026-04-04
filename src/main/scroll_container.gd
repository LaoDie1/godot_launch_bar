#============================================================
#    Scroll Container
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-04 12:50:21
# - version: 4.7.0.dev2
#============================================================
extends ScrollContainer

@export var text_edit: TextEdit
@export var child_container: HBoxContainer

func _ready() -> void:
	child_container.resized.connect(update_width, Object.CONNECT_DEFERRED)
	update_width.call_deferred()

func update_width():
	var max_width : float = get_parent_area_size().x - text_edit.custom_minimum_size.x
	self.custom_minimum_size.x = minf(max_width, child_container.size.x)
