#============================================================
#    Copy Button
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-02 04:23:57
# - version: 4.7.0.dev2
#============================================================
class_name CopyButton
extends Button

@export var target: Node
@export var copy_property: String


func _pressed() -> void:
	var value = str(target.get(copy_property)).strip_edges()
	if value:
		DisplayServer.clipboard_set(value)
		Log.prompt("复制内容到剪贴板", value)
