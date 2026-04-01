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

@onready var root : Window = get_tree().root
@onready var indicator_popup_menu: PopupMenu = $IndicatorPopupMenu


func _enter_tree() -> void:
	# 主题
	get_tree().root.theme = load("uid://jlwv6dkv62k3")
	

func _ready() -> void:
	indicator_popup_menu.add_item("退出")
	indicator_popup_menu.grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			Program.set_main_visible(false)


func _on_status_indicator_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		Program.set_main_visible(true)

func _on_indicator_popup_menu_id_pressed(id: int) -> void:
	var index : int = indicator_popup_menu.get_item_indent(id)
	var menu_name : String = indicator_popup_menu.get_item_text(index)
	if menu_name == "退出":
		get_tree().quit(0)

func _on_drag_move_control_moved(diff: Vector2) -> void:
	root.position += Vector2i(diff)
