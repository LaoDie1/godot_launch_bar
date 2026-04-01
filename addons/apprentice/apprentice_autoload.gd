#============================================================
#    Apprentice Autoload
#============================================================
# - author: zhangxuetu
# - datetime: 2025-05-26 22:28:26
# - version: 4.2.1
#============================================================
extends Node


func _init():
	# 设置所有继承 Autowired 类的脚本，初始化静态属性变量
	var dict = ScriptUtil.get_script_child_class_dict()
	for child_class in dict.get("Autowired", []):
		var script := ScriptUtil.get_script_class(child_class) as Script
		ScriptUtil.init_static_var(script, script._get_value)
	
	# 自动加载节点。自动添加到场景中
	for child_class in dict.get("Autoload", []):
		var script := ScriptUtil.get_script_class(child_class) as Script
		if script:
			var object := script.new() as Autoload
			object._instance = object
	
	# 日志等级
	var log_display_value = ProjectSettings.get_setting(ApprenticePlugin.LOG_DISPLAY_PATH)
	if log_display_value:
		Log.display = log_display_value
	else:
		ProjectSettings.set_setting(ApprenticePlugin.LOG_DISPLAY_PATH, Log.DefaultValue.DISPLAY)
	# 日志打印
	var log_print_value = ProjectSettings.get_setting(ApprenticePlugin.LOG_PRINT_PATH)
	if log_print_value:
		Log.print_path = log_print_value
	else:
		ProjectSettings.set_setting(ApprenticePlugin.LOG_PRINT_PATH, Log.DefaultValue.PRINT_PATH)
	
