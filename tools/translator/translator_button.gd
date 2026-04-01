#============================================================
#    Translator
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-01 17:31:51
# - version: 4.7.0.dev2
#============================================================
extends BaseProgramButton


func _get_tool_name() -> String:
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "翻译"
		_:
			return "Translator"


func _put_message(message: String):
	window.translate(message)
	window.popup()


func _init() -> void:
	const WINDOW_SCENE = preload("uid://4w5nkfvmfsud")
	window = WINDOW_SCENE.instantiate()
