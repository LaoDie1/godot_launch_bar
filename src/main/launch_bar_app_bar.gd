#============================================================
#    Launch Bar App Bar
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-04 10:37:04
# - version: 4.7.0.dev2
#============================================================
extends Window

@onready var message_box: TextEdit = %MessageBox
@onready var tool_buttons_container: HBoxContainer = %tool_buttons_container

var button_group := ButtonGroup.new()


func _enter_tree() -> void:
	hide()

func _ready() -> void:
	if LaunchBar.instance:
		for child in LaunchBar.instance.tool_buttons_container.get_children():
			if child is BaseProgramButton:
				var button : Button = child.duplicate(0)
				button.toggle_mode = true
				button.button_group = button_group
				button.pressed.connect(
					func():
						child.button_pressed = true
						get_tree().create_timer(0.3).timeout.connect(
							func():
								child.toggled.emit(true)
						)
				)
				button.gui_input.connect(
					func(event):
						if event is InputEventMouseButton:
							if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
								child.button_pressed = true
								button.button_pressed = true
				)
				tool_buttons_container.add_child(button)
	
	Global.config.bind_method("program/show_topbar", func(status):
		if status:
			popup()
			WindowServer.register_app_bar(self, 2, 50)
		else:
			WindowServer.unregister_app_bar(self)
	, true, false)
	
	get_tree().create_timer(1).timeout.connect(
		func(): WindowServer.set_window_taskbar_icon_visible(self, false)
	)
	
	focus_entered.connect(
		func():
			WindowServer.focus_window(self)
			message_box.grab_focus()
			message_box.select_all()
	)
	focus_exited.connect(message_box.release_focus)
	window_input.connect(
		func(event):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
					var text = DisplayServer.clipboard_get()
					if text:
						var line_column = message_box.get_line_column_at_pos( Vector2i(message_box.get_local_mouse_pos()) )
						var column = line_column.x
						var line = line_column.y
						message_box.insert_text(text, line, column)
						message_box.set_caret_line(line)
						message_box.set_caret_column(column, true)
						message_box.deselect()
						message_box.select(line, column, line, column + text.length())
	)
	files_dropped.connect(
		func(files):
			message_box.text += files[0]
	)

func _exit_tree() -> void:
	WindowServer.unregister_app_bar(self)

func _on_message_box_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			if event.pressed and message_box.text.strip_edges():
				Program.set_main_visible(false)
				Global.submitted_text.emit(message_box.text.strip_edges())
				message_box.clear()
			message_box.accept_event()
