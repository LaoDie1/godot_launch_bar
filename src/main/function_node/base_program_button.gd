## 所有继承这个脚本的按钮，都会自动被扫描到，且添加功能到目录里
@abstract
class_name BaseProgramButton
extends Button

signal actived
signal entered  ## 再次点击进入这个窗口


var _last_status: bool 
var _last_pressed_ticks : int
var window: Window:  ## 扩展这个脚本并重写 [method _init] 方法设置这个属性要加载的 [Window] 对象
	set(v):
		window = v
		toggled.connect(
			func(toggle_on: bool):
				# 再次点击按钮时弹出窗口
				if _last_status != toggle_on:
					if toggle_on:
						_last_pressed_ticks = Time.get_ticks_msec()
						actived.emit()
				else:
					if Time.get_ticks_msec() - _last_pressed_ticks > 200:
						entered.emit()
						if not window.is_inside_tree():
							add_child(window)
						window.popup()
						get_tree().create_timer(0.1).timeout.connect(window.grab_focus) #需要稍微间隔时间才能获取焦点，直接调用无效
						_last_pressed_ticks = Time.get_ticks_msec()
				_last_status = toggle_on
		)


## 获取这个工具的名称
@abstract func _get_tool_name() -> String
## 主窗口的输入条按下回车后，如果当前按钮是触发状态，则调用个方法
@abstract func _put_message(message: String) 

func _get_order() -> int: 
	## 获取排序。默认为 10，数字越小越靠前
	return 10
