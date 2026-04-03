#============================================================
#    Speed To Text Button
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-03 14:33:02
# - version: 4.7.0.dev2
#============================================================
extends BaseProgramButton

func _get_tool_name() -> String:
	return "音视频转文字"

func _put_message(message: String):
	window.popup()

func _get_order() -> int:
	return 11

func _init() -> void:
	const SPEECH_TO_TEXT_WINDOW = preload("uid://botoseemjqqvq")
	window = SPEECH_TO_TEXT_WINDOW.instantiate()

func _pressed() -> void:
	window.popup()
