#============================================================
#    LaunchBar
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-01 18:23:02
# - version: 4.7.0.dev2
#============================================================
## 启动条界面
class_name LaunchBar
extends MarginContainer

@export var input_node: TextEdit


func _enter_tree() -> void:
	get_tree().root.wrap_controls = true
	get_tree().root.extend_to_title = true
	get_tree().root.theme = preload("uid://jlwv6dkv62k3")
	get_tree().root.close_requested.connect(
		func():
			Program.set_main_visible(false)
			#quit() # 点击关闭按钮或按 Alt + F4 进行关闭退出
	)
	get_tree().root.focus_exited.connect(
		func():
			if Global.config.get_value("program/lose_focus_to_hide", true):
				Program.set_main_visible(false)
	)


var right_menu := MenuWrapper.new()
func _ready() -> void:
	if not OS.has_feature("editor") and WindowServer.create_program_single():
		# 如果存在已经启动的程序则退出
		get_tree().quit()
		return 
	
	get_tree().root.focus_entered.connect(input_node.grab_focus)
	
	# 绑定节点配置
	Global.config.bind_object(%LaunchBarNameLabel, "program/launch_bar_name", "<启动条>", "text")
	Global.config.bind_object(%LaunchBarNameLabel.get_parent(), "program/show_launch_bar_name", true, "visible")
	Global.config.bind_object(get_tree().root, "program/window_pos", null, "position")
	var background_style : StyleBoxFlat = %BackgroundPanel.get_theme_stylebox("panel")
	Global.config.bind_object(background_style, "program/background_color", null, "bg_color")
	if not OS.has_feature("editor"):
		# 开机自启动
		Global.config.bind_method("program/autostart_on_boot", func(status):
			var exe_path : String = OS.get_executable_path()
			if status:
				if not WindowServer.is_startup_program(exe_path):
					WindowServer.add_to_startup(exe_path)
			else:
				if WindowServer.is_startup_program(exe_path):
					WindowServer.remove_from_startup(exe_path)
		, true)
		if not Global.config.has_value("program/autostart_on_boot"):
			Global.config.set_value("program/autostart_on_boot", false)
	
	input_node.grab_focus()
	
	# 任务状态栏菜单
	right_menu.root_menu = %IndicatorPopupMenu
	right_menu.init_item(["设置", "-", "退出"])
	right_menu.menu_pressed.connect(_press_right_menu)
	right_menu.set_shortcut("/退出", "Ctrl+Q")

func _exit_tree() -> void:
	WindowServer.release_program_single()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			Program.set_main_visible(false)
		elif event.keycode == KEY_Q and event.ctrl_pressed:
			get_tree().quit()


## 显示提示信息
static func show_prompt(...content: Array) -> void:
	print(content)
	#const DURATION = 5.0
	#var label = Label.new()
	#label.text = " ".join(content)
	#var root : Window = Engine.get_main_loop().root
	#label.position = Vector2(20, root.get_viewport().get_visible_rect().position.y)
	#root.add_child(label)
	#root.create_tween().tween_property(label, "position:y", -50, DURATION).finished.connect(label.queue_free)
	#root.create_tween().tween_property(label, "modulate:a", 0, 0.5).set_delay(DURATION - 0.5)


func _on_status_indicator_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		Program.set_main_visible(true)

func _on_drag_move_control_moved(diff: Vector2) -> void:
	get_tree().root.position += Vector2i(diff)

func _press_right_menu(_id, menu_path):
	match menu_path:
		"/设置":
			%ConfigWindow.popup()
		"/退出":
			get_tree().quit(0)
