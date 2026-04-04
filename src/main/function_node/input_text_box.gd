class_name InputTextBox
extends TextEdit


func _ready() -> void:
	grab_focus()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ENTER and event.pressed:
			if not (event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed):
				submit_message()
			accept_event()

## 直接提交启动条中的文本内容
func submit_message():
	if text.strip_edges():
		Program.set_main_visible(false)
		Global.submitted_text.emit(text.strip_edges())
		clear()
		clear_undo_history()
