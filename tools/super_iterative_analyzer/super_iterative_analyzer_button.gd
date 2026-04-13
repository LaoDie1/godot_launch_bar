#============================================================
#    Super Iterative Analyzer Button
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-13 01:36:01
# - version: 4.7.0.dev2
#============================================================
extends BaseProgramButton


func _init() -> void:
	const SUPER_ITERATIVE_ANALYZER_WINDOW = preload("uid://cbjps3yfu86kb")
	window = SUPER_ITERATIVE_ANALYZER_WINDOW.instantiate()


func _get_tool_name() -> String:
	return "超级迭代分析器"

func _put_message(message: String):
	pass
