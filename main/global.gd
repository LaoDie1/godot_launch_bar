## Global.gd
## 这里专注于处理程序运行之后的节点、配置等持续性的功能处理操作
extends Node

signal visibility_changed

var config : DataFile = DataFile.instance("user://program_global.data", DataFile.STRING)

var main: Main
var input_text_box: InputTextBox


func _enter_tree() -> void:
	Engine.set_meta("GLOBAL", self)
	get_tree().node_added.connect(
		func(node):
			if node is Control:
				if node is Main:
					main = node
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
	config.bind_node(get_tree().root, "window_pos", null, "position")
	
	# 退出保存
	get_tree().root.tree_exiting.connect(config.save)
	
	# 自动保存
	const AUTO_SAVE_TIME = 60 * 10
	var auto_save_timer := Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_TIME
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(config.save)
	add_child(auto_save_timer)
