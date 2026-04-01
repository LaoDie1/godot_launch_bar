#============================================================
#    Autoload
#============================================================
# - author: zhangxuetu
# - datetime: 2025-12-30 21:53:40
# - version: 4.5.1.stable
#============================================================
## 自动加载这个对象。自动调用
class_name Autoload
extends Object


static var _instance: Autoload:
	set(v):
		if _instance == null:
			_instance = v
			_instance._load()


static func _load() -> void:
	pass
