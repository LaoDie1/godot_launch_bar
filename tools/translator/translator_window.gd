#============================================================
#    Translator Window
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-01 19:58:26
# - version: 4.7.0.dev2
#============================================================
extends Window

@export var translate_result_box: TextEdit
@export var conversation: Conversation
@export var scroll_container: ScrollContainer
@onready var send_text_box: TextEdit = %SendTextBox


func _enter_tree() -> void:
	Global.config.bind_object(self, "translator/window_size", null, "size", func(pre, new_value): 
		return new_value if mode == Window.MODE_WINDOWED else pre
	)
	Global.config.bind_object(conversation, "translator/api_key", "", "api_key")
	Global.config.bind_object(conversation, "translator/model", "", "model")
	Global.config.bind_object(conversation, "translator/base_url", "", "base_url")
	%HistoryButton.toggled.connect( func(toggle_on):  %ResultContainer.collapsed = not toggle_on )
	Global.config.bind_object(%HistoryButton, "translator/show_history", false, "button_pressed")
	Global.config.bind_object(%ResultContainer, "translator/split_offsets", null, "split_offsets")


## 翻译
func translate(message: String) -> void:
	if conversation.is_running():
		printerr("正在执行中，请稍后")
		return
	message = message.strip_edges()
	if message:
		%TransTargetTextBox.text = message
		conversation.send( "" + message)
	send_text_box.text = ""

func _on_conversation_responded_stream_data(delta_data: Dictionary) -> void:
	if delta_data["content"]:
		translate_result_box.text = delta_data["content"]
		translate_result_box.show()
	scroll_container.set_deferred("scroll_vertical", scroll_container.get_v_scroll_bar().max_value)


func _on_conversation_requested(message_data: Dictionary) -> void:
	%ResultItemList.add_item(str(message_data.get("content", "")))
	%ResultItemList.get_v_scroll_bar().value = %ResultItemList.get_v_scroll_bar().max_value
	translate_result_box.text = ""
	translate_result_box.hide()

func _on_conversation_responded_stream_end(message_data: Dictionary) -> void:
	Log.debug("消息结果", message_data)
	var id = %ResultItemList.item_count - 1
	%ResultItemList.set_item_metadata(id, message_data["content"])
	%ResultItemList.set_item_tooltip(id, "翻译结果：%s" % message_data["content"])

func _on_conversation_responded_error(error_data) -> void:
	Log.error("连接出现错误", error_data)
	%TransResultBox.text = "(执行出现错误)"

func _on_translator_button_pressed() -> void:
	translate(send_text_box.text)

func _on_send_text_box_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# 按回车发送消息
		if event.keycode == KEY_ENTER and not (event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed):
			if event.pressed:
				translate(send_text_box.text)
			send_text_box.accept_event()
