## Global.gd
## 这里专注于处理程序运行之后的节点、配置等持续性的功能处理操作
extends Node

signal visibility_changed

var config : DataFile = DataFile.instance("user://program_global.data", DataFile.STRING)

var launch_bar: LaunchBar
var input_text_box: InputTextBox


func _enter_tree() -> void:
	Engine.set_meta("GLOBAL", self)
	
	get_tree().node_added.connect(
		func(node):
			if node is Control:
				if node is LaunchBar:
					launch_bar = node
				elif node is InputTextBox:
					input_text_box = node
	)
	visibility_changed.connect(
		func():
			if input_text_box:
				if Program.is_visible():
					input_text_box.grab_focus()
				else:
					input_text_box.release_focus()
	, Object.CONNECT_DEFERRED)
	
	# 自动保存 按分钟保存
	var minue : int = Global.config.get_value("program/auto_save_interval", 5)
	Global.config.set_value("program/auto_save_interval", minue)
	var auto_save_timer := Timer.new()
	auto_save_timer.wait_time = 60 * minue
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(
		func():
			LaunchBar.show_prompt("自动保存数据")
			config.save()
	)
	add_child(auto_save_timer)
	Global.config.value_changed.connect(
		func(key, _pre, curr):
			if key == "program/auto_save_interval":
				auto_save_timer.wait_time = curr
	)


func _exit_tree() -> void:
	config.update_data_by_bind_nodes()
	var save_status = config.save()
	Log.print_json(config.get_data(), "\t")
	Log.debug("退出程序保存数据", save_status)
