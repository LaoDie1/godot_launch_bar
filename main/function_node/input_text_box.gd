class_name InputTextBox
extends TextEdit

signal submitted(content: String)

func _enter_tree() -> void:
	Global.visibility_changed.connect(
		func():
			if Program.is_visible():
				clear()
	)

func _ready() -> void:
	grab_focus()

func _unhandled_key_input(event) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ENTER and not (event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed):
			if text.strip_edges():
				Program.set_main_visible(false)
				submitted.emit(text.strip_edges())
				clear()
				clear_undo_history()
