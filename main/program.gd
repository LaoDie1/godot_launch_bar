# application/run/main_loop_type 修改为 Program 循环类型
# 这里处理整个程序相关的核心基础配置，主窗口的一些配置，不参与其他节点的处理
class_name Program
extends SceneTree


var hot_key : WindowServer = null

func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(
		func():
			set_main_visible(false)
			#quit() # 点击关闭按钮或按 Alt + F4 进行关闭退出
	)
	root.focus_exited.connect(set_main_visible.bind(false))
	WindowServer.set_window_taskbar_icon_visible.call_deferred(root, false)
	
	# 热键
	hot_key = WindowServer.new()
	hot_key.register_hotkey(KEY_CTRL, KEY_SPACE)
	hot_key.hot_key_pressed.connect(
		func(): set_main_visible(not is_visible())
	)

func _finalize() -> void:
	hot_key.unregister_hotkey()


static func is_visible() -> bool:
	return Engine.get_meta("visible")

static func set_main_visible(status: bool) -> void:
	Engine.set_meta("visible", status)
	var _root : Window = Engine.get_main_loop().root
	if status:
		WindowServer.focus_window(_root)
		WindowServer.set_window_visible(_root, true)
		_root.grab_focus()
	else:
		WindowServer.release_focus(_root)
		WindowServer.set_window_visible(_root, false)
		_root.gui_release_focus()
	Engine.get_meta("GLOBAL").visibility_changed.emit()
