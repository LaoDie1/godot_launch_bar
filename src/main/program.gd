# application/run/main_loop_type 修改为 Program 循环类型
# 这里处理整个程序相关的核心基础配置，主窗口的一些配置，不参与其他节点的处理
class_name Program
extends SceneTree


var hot_key : WindowServer = null

func _initialize() -> void:
	auto_accept_quit = false
	WindowServer.set_window_taskbar_icon_visible.call_deferred(root, false)
	
	# 热键
	hot_key = WindowServer.new()
	hot_key.register_hotkey(KEY_CTRL, KEY_SPACE)
	hot_key.hot_key_pressed.connect(
		func(): 
			set_main_visible(true)
	)

func _finalize() -> void:
	hot_key.unregister_hotkey()


## 这个窗口屏幕是否可见的
static func is_visible() -> bool:
	return Engine.get_meta("visible")

static func set_main_visible(status: bool) -> void:
	Engine.set_meta("visible", status)
	var _root : Window = Engine.get_main_loop().root
	# 必须要用计时器等待一点点时间才能成功处理焦点，否则可能刚显示出来系统还没处理结束，直接就处理焦点有时会失效
	if status:
		WindowServer.set_window_visible(_root, true)
		Engine.get_main_loop().create_timer(0.2).timeout.connect(
			func():
				WindowServer.focus_window.call_deferred(_root)
				_root.grab_focus()
		)
	else:
		WindowServer.set_window_visible(_root, false)
		_root.gui_release_focus()

	Engine.get_meta("GLOBAL").visibility_changed.emit()
