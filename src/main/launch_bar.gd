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

@export var input_text_box: TextEdit
@export var tool_buttons_container: HFlowContainer
@export var config_window: Window

static var instance: LaunchBar

func _init() -> void:
	instance = self

func _enter_tree() -> void:
	get_tree().root.always_on_top = true
	get_tree().root.wrap_controls = true
	get_tree().root.extend_to_title = true
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

func _ready() -> void:
	if not OS.has_feature("editor") and WindowServer.create_program_single():
		# 如果存在已经启动的程序则退出
		get_tree().quit()
		return 
	
	get_tree().root.focus_entered.connect(input_text_box.grab_focus)
	input_text_box.grab_focus()
	input_text_box.gui_input.connect(
		func(event):
			if event is InputEventKey:
				if event.keycode == KEY_ENTER and event.pressed:
					# 按下单个 Enter 键进行发送
					if not (event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed):
						submit_message()
					input_text_box.accept_event()
	)
	
	# 绑定节点配置
	Global.config.bind_object(%LaunchBarNameLabel, "program/launch_bar_name", "<启动条>", "text")
	Global.config.bind_object(%LaunchBarNameLabel.get_parent(), "program/show_launch_bar_name", true, "visible")
	Global.config.bind_object(get_tree().root, "program/window_pos", null, "position")
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
	
	# 任务状态栏菜单
	var right_menu := MenuWrapper.new()
	right_menu.root_menu = %IndicatorPopupMenu
	right_menu.init_item(["设置", "-", "退出"])
	right_menu.menu_pressed.connect(_press_right_menu)
	theme_changed.connect(
		func():
			#right_menu.set_icon("/设置", get_tree().root.theme.get_icon("GDScript", "EditorIcons"))
			var theme_type = Global.config.get_value("program/theme_type")
			var style : StyleBoxFlat = %Shadow.get_theme_stylebox("panel")
			match theme_type:
				Global.ThemeType.SYSTEM: 
					if DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode():
						style.shadow_color = Color(0,0,0,0.6)
					else:
						style.shadow_color = Color(1,1,1,0.6)
				Global.ThemeType.WHITE: style.shadow_color = Color(1,1,1,0.6)
				Global.ThemeType.DARK:  style.shadow_color = Color(0,0,0,0.6)
	)


func _exit_tree() -> void:
	WindowServer.release_program_single()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			Program.set_main_visible(false)
		elif event.keycode == KEY_Q and event.ctrl_pressed:
			get_tree().quit()

## 直接提交启动条中的文本内容
func submit_message() -> void:
	if input_text_box.text.strip_edges():
		Program.set_main_visible(false)
		Global.submitted_text.emit(input_text_box.text.strip_edges())
		input_text_box.clear()
		input_text_box.clear_undo_history()


## 显示提示信息
func show_prompt(...content: Array) -> void:
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
	if get_tree().root.position.y < -16:
		get_tree().root.position.y = -16
	if get_tree().root.position.x < 0:
		get_tree().root.position.x = 0

func _press_right_menu(_id, menu_path):
	match menu_path:
		"/设置":
			%ConfigWindow.popup()
		"/退出":
			get_tree().quit(0)
