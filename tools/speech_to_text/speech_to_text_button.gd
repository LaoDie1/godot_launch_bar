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
	var real_path : String = FileUtil.get_real_path(message)
	if FileUtil.file_exists(real_path):
		printerr("不存在 %s 文件" % real_path)
	else:
		window.popup()
		window.start_transcribe(real_path)

func _get_order() -> int:
	return 11

func _init() -> void:
	const SPEECH_TO_TEXT_WINDOW = preload("uid://botoseemjqqvq")
	window = SPEECH_TO_TEXT_WINDOW.instantiate()

func _pressed() -> void:
	if window.is_inside_tree():
		window.popup()
