#============================================================
#    Tool Buttons Container
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-01 17:21:32
# - version: 4.7.0.dev2
#============================================================
## 启动条的按钮容器
extends HFlowContainer


func _ready():
	# 开始扫描目录，自动添加工具按钮和对应功能
	scan_load("res://tools/")
	if not OS.has_feature("editor"):
		FileUtil.make_dir_if_not_exists("./tools")
		if FileUtil.dir_exists("./tools"):
			scan_load(FileUtil.get_real_path("./tools"))
	
	# INFO 启动条提交内容,进入这个窗口
	Global.submitted_text.connect(
		func(content):
			var button : BaseProgramButton = button_group.get_pressed_button()
			if not button.window.is_inside_tree():
				button.add_child(button.window)
			button._put_message(content)
			# 通过这个方式进入的将主窗口隐藏
			if LaunchBar.instance:
				LaunchBar.instance.set_main_visible(false)
	)


var button_group := ButtonGroup.new()
## 扫描加载这个目录的 BaseProgramButton 脚本
func scan_load(dir: String) -> void:
	print()
	print("开始扫描目录：", dir)
	var files = FileUtil.scan_file(dir, true) \
		.filter(func(file:String): return file.ends_with(".gd"))  # 你已有的扫描结果
	print("扫描到文件：", files)
	print("扫描加载扩展工具: ")
	var buttons : Array[BaseProgramButton] = []
	for file in files:
		var script : GDScript = load_user_script(file)
		if not script or script.is_abstract():
			continue
		print("    > ", file)
		var button : BaseProgramButton = script.new()
		script.resource_name = button._get_tool_name()
		button.name = button._get_tool_name()
		button.text = button._get_tool_name()
		button.button_group = button_group
		buttons.append(button)
	
	# 添加按钮
	buttons.sort_custom( func(a, b): return a._get_order() < b._get_order())
	for button: BaseProgramButton in buttons:
		button.toggle_mode = true
		add_child(button)
		Global.config.bind_object(button, "tool_toggle_status_%s" % button.text, false) #绑定配置的值
		# 配置这些工具按钮的应窗口的处理
		var window : Window = button.window
		if window:
			window.hide()
			window.title = "%s - Launch Bar" % button.text
			window.close_requested.connect(window.hide)
			window.window_input.connect(
				func(event):
					# 默认按 ESC 关掉窗口
					if event is InputEventKey:
						if event.keycode == KEY_ESCAPE:
							window.hide()
			)
			window.focus_exited.connect(
				func():
					# 焦点丢失则隐藏
					if Global.config.get_value("program/loss_focus_hide_sub_window", false):
						window.hide()
			)
			# INFO 再次点击使用时
			button.entered.connect(LaunchBar.instance.submit_message)
		else:
			Log.warn("按钮未设置工具弹窗", button.text)
	# 更新按钮大小
	get_tree().create_timer(0.1).timeout.connect(
		func():
			for button in buttons:
				button.custom_minimum_size = button.size + Vector2(32, 12)
	)


var _verification_script_reg : RegEx
# 加载脚本（稳定版）
func load_user_script(path: String) -> GDScript:
	if OS.has_feature("editor") or ResourceLoader.exists(path):
		var script := load(path) as Script
		if ScriptUtil.is_extends_of(script, BaseProgramButton):
			return script
	else:
		if not _verification_script_reg:
			_verification_script_reg = RegEx.new()
			_verification_script_reg.compile("extends\\s+BaseProgramButton")
		var code : String = FileAccess.get_file_as_string(path)
		if code and _verification_script_reg.search(code):
			var script := load(path) as Script
			if ScriptUtil.is_extends_of(script, BaseProgramButton):
				return script
		else:
			printerr(path, "不存在 extends BaseProgramButton 代码")
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode >= KEY_F1 and event.keycode <= KEY_F35 and event.pressed:
			var index : int = event.keycode - KEY_F1
			if index < button_group.get_buttons().size():
				var button_index : int = -1
				for child in get_children():
					if child is BaseProgramButton:
						button_index += 1
						if button_index == index:
							var button : BaseProgramButton = child
							if not button.button_pressed:
								button.button_pressed = true
							else:
								button.toggled.emit(true)
							return
