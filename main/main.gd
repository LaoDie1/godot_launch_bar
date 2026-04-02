#============================================================
#    Main
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-01 18:23:02
# - version: 4.7.0.dev2
#============================================================
class_name Main
extends Control

@export var input_node: TextEdit

var right_menu := MenuWrapper.new()

func _enter_tree() -> void:
	# 主题
	get_tree().root.theme = load("uid://jlwv6dkv62k3")
	

func _ready() -> void:
	right_menu.root_menu = %IndicatorPopupMenu
	right_menu.init_item(["设置", "-", "退出"])
	right_menu.menu_pressed.connect(_press_right_menu)
	input_node.grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			Program.set_main_visible(false)


static func show_prompt(...content: Array) -> void:
	const DURATION = 5.0
	var label = Label.new()
	label.text = " ".join(content)
	var root : Window = Engine.get_main_loop().root
	label.position = Vector2(20, root.get_viewport().get_visible_rect().position.y)
	root.add_child(label)
	root.create_tween().tween_property(label, "position:y", -50, DURATION).finished.connect(label.queue_free)
	root.create_tween().tween_property(label, "modulate:a", 0, 0.5).set_delay(DURATION - 0.5)


func _on_status_indicator_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		Program.set_main_visible(true)

func _on_drag_move_control_moved(diff: Vector2) -> void:
	get_tree().root.position += Vector2i(diff)

func _press_right_menu(_id, menu_path):
	match menu_path:
		"/设置":
			%ConfigWindow.popup()
		"/退出":
			get_tree().quit(0)
