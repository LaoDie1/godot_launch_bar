## Global.gd
## 这里专注于处理程序运行之后的节点、配置等持续性的功能处理操作
extends Node

signal visibility_changed
signal submitted_text(content: String)
signal event(ename, params: Array)

enum ThemeType {
	SYSTEM,
	DARK,
	WHITE,
}

var models_table: BindPropertyItem = BindPropertyItem.new("models_table", [])
var config : DataFile = DataFile.instance("user://program_global.data", DataFile.STRING)
var config_item_hint: DataFile = DataFile.instance("")

var windows: Array[Window] = []


func _enter_tree() -> void:
	Engine.set_meta("GLOBAL", self)
	
	get_tree().node_added.connect(
		func(node):
			if node is Window:
				windows.append(node)
				node.theme = _get_theme()
	)
	windows.append(get_tree().root)
	
	# 自动保存 按分钟保存
	config_item_hint.set_value("program/auto_save_interval", "1,999,1")
	var minue : int = config.get_value("program/auto_save_interval", 5)
	config.set_value("program/auto_save_interval", minue)
	var auto_save_timer := Timer.new()
	auto_save_timer.wait_time = 60 * minue
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(
		func():
			if LaunchBar.instance:
				LaunchBar.instance.show_prompt("自动保存数据", FileUtil.get_real_path(config.file_path))
			config.save()
	)
	add_child(auto_save_timer)
	config.value_changed.connect(
		func(key, _pre, curr):
			if key == "program/auto_save_interval":
				auto_save_timer.wait_time = curr
	)
	
	# 大模型配置
	var real_path : String = FileUtil.get_real_path("./model_names.txt")
	var modules_text: String = ""
	if not FileUtil.file_exists(real_path):
		# 文件数据格式
		modules_text = FileUtil.read_as_string("res://model_names.txt")
		FileUtil.write_as_string(real_path, modules_text)
	else:
		modules_text = FileUtil.read_as_string(real_path)
	Log.debug("读取到 %s 中的数据字符长度:" % real_path, modules_text.length())
	var tmp_model_list = JSON.parse_string(modules_text)
	if tmp_model_list:
		models_table.set_value(tmp_model_list)
	
	# 程序主题
	config_item_hint.set_value("program/theme_type", "跟随系统,黑色,白色")
	config.bind_method("program/theme_type", func(_v):
		var thread := Thread.new()
		thread.start(
			func():
				var theme : Theme = _get_theme()
				for window in windows:
					if is_instance_valid(window):
						window.set_thread_safe("theme", theme)
		)
		thread.wait_to_finish()
	, true, ThemeType.SYSTEM)
	DisplayServer.set_system_theme_change_callback(func():
		var thread := Thread.new()
		thread.start(
			func():
				var theme : Theme = _get_theme()
				for window in windows:
					if is_instance_valid(window):
						window.set_thread_safe("theme", theme)
		)
		thread.wait_to_finish()
	)

const WHITE_THEME = preload("uid://deub2nqe8hbwl")
const DARK_THEME = preload("uid://c03l6vtdyxy32")
func _get_theme() -> Theme:
	var theme: Theme = WHITE_THEME
	match config.get_value("program/theme_type", ThemeType.SYSTEM):
		ThemeType.SYSTEM:
			if DisplayServer.is_dark_mode_supported():
				theme = DARK_THEME if DisplayServer.is_dark_mode() else WHITE_THEME
			else:
				theme = WHITE_THEME  # 不支持的系统里，默认显示 white 主题
		ThemeType.WHITE: theme = WHITE_THEME
		ThemeType.DARK: theme = DARK_THEME
	return theme

func _exit_tree() -> void:
	config.update_data_by_bind_nodes()
	var save_status = config.save()
	Log.print_json(config.get_data(), "\t")
	Log.debug("退出程序保存数据", save_status)


## 发送事件消息
func send_event(ename, ...params) -> void:
	event.emit(ename, params)
