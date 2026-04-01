#============================================================
#    Program Buttons Container
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-01 17:21:32
# - version: 4.7.0.dev2
#============================================================
extends HFlowContainer

var button_group := ButtonGroup.new()

func _ready():
	var dir = "res://tools/"
	var files = FileUtil.scan_file(dir, true).filter(func(file): return file.ends_with(".gd"))  # 你已有的扫描结果
	
	print("加载扩展按钮: ")
	var buttons : Array[BaseButton] = []
	for file in files:
		var script : GDScript = load_user_script(file)
		if not script or script.is_abstract():
			continue
		
		var tmp_script : GDScript = script
		while tmp_script:
			tmp_script = script.get_base_script()
			if tmp_script == BaseProgramButton:
				break
		if tmp_script == BaseProgramButton:
			print("    > ", file)
			var button : BaseProgramButton = script.new()
			tmp_script.resource_name = button._get_tool_name()
			button.name = button._get_tool_name()
			button.text = button._get_tool_name()
			button.button_group = button_group
			buttons.append(button)
	
	# 添加按钮
	buttons.sort_custom(
		func(a: BaseProgramButton, b: BaseProgramButton):
			return a._get_order() < b._get_order()
	)
	for button: BaseProgramButton in buttons:
		button.toggle_mode = true
		add_child(button)  # 加到UI
		Global.config.bind_node(button, "tool_toggle_status_%s" % button.text, false) #绑定配置的值
		
		var window : Window = button.window
		if window:
			window.title = button.text
			window.hide()
			window.close_requested.connect(window.hide)
			window.window_input.connect(
				func(event):
					if event is InputEventKey:
						if event.keycode == KEY_ESCAPE:
							window.hide()
			)
			if not window.is_inside_tree():
				add_child(window)
		else:
			Log.warn("按钮未设置工具弹窗", button.text)

	# 启动条提交内容
	Global.input_text_box.submitted.connect(
		func(content):
			var button : BaseProgramButton = button_group.get_pressed_button()
			button._put_message(content)
			Program.set_main_visible(false)
	)


# 加载 user:// 下的脚本（稳定版）
func load_user_script(path: String) -> GDScript:
	var s = load(path)
	if s:
		return s
	
	var script = GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path)
	if script.reload() == OK:
		script.resource_path = path
		return script
	printerr("加载失败: ", path)
	return null
