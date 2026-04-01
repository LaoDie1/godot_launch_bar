#============================================================
#    Session
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-01 18:18:33
# - version: 4.7.0.dev2
#============================================================
extends BaseProgramButton


func _get_tool_name() -> String:
	return "对话"

func _get_order() -> int:
	return 0

func _init() -> void:
	const SESSION_WINDOW = preload("uid://pc5fnpp8ycsl")
	window = SESSION_WINDOW.instantiate()

const SessionWindow = preload("uid://bdc0s3lx7ue17")

func _put_message(message: String):
	(window as SessionWindow).send_text_box.text = message
	(window as SessionWindow).send_current_text()
	window.popup()
