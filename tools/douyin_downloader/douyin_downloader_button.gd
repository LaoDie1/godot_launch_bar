#============================================================
#    Douyin Downloader Button
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-12 03:38:43
# - version: 4.7.0.dev2
#============================================================
extends BaseProgramButton


func _init() -> void:
	const DOUYIN_DOWNLOADER_WINDOW = preload("uid://dcqcqv81llyj3")
	window = DOUYIN_DOWNLOADER_WINDOW.instantiate()

func _get_tool_name() -> String:
	return "抖音视频下载器"

func _put_message(message: String):
	window.link_text_edit.text = message
