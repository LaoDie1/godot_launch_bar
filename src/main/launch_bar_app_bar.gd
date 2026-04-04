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

func _enter_tree() -> void:
	hide()

var button_group := ButtonGroup.new()
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
				tool_buttons_container.add_child(button)
	focus_exited.connect(message_box.release_focus)
	
	Global.config.bind_method("program/show_topbar", func(status):
		if status:
			popup()
			WindowServer.register_app_bar(self, 2, 50)
		else:
			WindowServer.unregister_app_bar(self)
			self.visible = false
	, true, false)
	
	get_tree().create_timer(1).timeout.connect(
		func():
			WindowServer.set_window_taskbar_icon_visible(self, false)
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
