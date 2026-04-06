#============================================================
#    Session Window
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-02 00:36:38
# - version: 4.7.0.dev2
#============================================================
extends Window

const SESSION_ITEM = preload("uid://d4ft7r0p0pskd")

var conversation_messages_file := DataFile.instance("user://conversation_messages.data")

@onready var session_item_list: VBoxContainer = %SessionItemList
@onready var send_text_box: TextEdit = %SendTextBox
@onready var conversation: Conversation = %Conversation
@onready var send_button: Button = %SendButton
@onready var message_scroll_container: ScrollContainer = %MessageScrollContainer
@onready var auto_scroll_timer: Timer = %AutoScrollTimer
@onready var model_button : OptionButton = %ModelsButton


func _ready() -> void:
	Global.config.bind_object(self, "session/window_size", null, "size", func(pre, new_value): return new_value if mode == Window.MODE_WINDOWED else pre)
	Global.config.bind_object(conversation, "session/model", "", "model")
	Global.config.bind_object(conversation, "session/base_url", "", "base_url")
	Global.config.bind_object(conversation, "session/api_key", "", "api_key")
	Global.config.bind_object(conversation, "session/message_memory_limit", null, "message_memory_limit")
	Global.config.bind_object(model_button, "session/model", null, "text")
	Global.config.bind_object(conversation, "session/prompt_enabled", null, "tool_mode")
	Global.config.bind_object(conversation, "session/prompt_content", null, "tool_message")
	
	model_button.item_selected.connect(
		func(index):
			var model_data = model_button.get_item_metadata(index)
			Global.config.set_value("session/model", model_data["model"])
	)
	Global.models_table.bind_method(
		func(models_table):
			model_button.clear()
			for model_data in models_table:
				var model_name = model_data["name"]
				for model in model_data["models"]:
					model_button.add_item("%s: %s" % [model_name, model["model"]])
					model_button.set_item_metadata(model_button.item_count - 1, {
						"name": model_name,
						"model": model["model"],
						"base_url": model["base_url"],
					})
	, true)
	
	# 会话列表
	conversation_messages_file.bind_object(conversation, "session_history_messages", null, "messages")
	get_tree().root.tree_exiting.connect(conversation_messages_file.save)
	
	# 更新历史会话列表
	for idx in range(0, conversation.messages.size(), 2):
		# 添加会话项
		var item : SessionItem = SESSION_ITEM.instantiate()
		session_item_list.add_child(item)
		var user_message_data : Dictionary = conversation.messages[idx]
		var assistant_message_data : Dictionary = {}
		if idx + 1 < conversation.messages.size():
			assistant_message_data = conversation.messages[idx + 1]
		item.update_message(user_message_data, assistant_message_data)
		item.reload_button.pressed.connect(_reload_pressed.bind(item))
		item._conversation = conversation
		
	visibility_changed.connect(_scroll_down, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	
	# 来消息时，自动滚动到底部方便查看
	var end_resp = func(_data, status: Error):
		if not auto_scroll_timer.is_stopped():
			auto_scroll_timer.stop()
			message_scroll_container.scroll_vertical = int(message_scroll_container.get_v_scroll_bar().max_value)
		if status == OK:
			last_session_item = null
	conversation.requested.connect(
		func(__): auto_scroll_timer.start()
	)
	conversation.responded_stream_end.connect(end_resp.bind(OK))
	conversation.responded_message.connect(end_resp.bind(OK))
	conversation.responded_error.connect(end_resp.bind(FAILED))
	
	# 拖拽容器滚动条则不会自动向下滑动
	message_scroll_container.get_v_scroll_bar().gui_input.connect(
		func(event):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					auto_scroll_timer.stop()
	)
	get_tree().create_timer(0.1).timeout.connect(_scroll_down)



var last_session_item : SessionItem
func send_current_text() -> void:
	var text : String = send_text_box.text.strip_edges()
	if text:
		if last_session_item == null:
			# 添加单次会话项
			last_session_item = SESSION_ITEM.instantiate()
			session_item_list.add_child(last_session_item)
			var item : SessionItem = last_session_item
			last_session_item.reload_button.pressed.connect(_reload_pressed.bind(item))
		last_session_item.bind_once_conversation(conversation)
		conversation.send(text)
		send_text_box.clear()
		send_text_box.clear_undo_history()
	else:
		Log.warn("当前没有文字内容")


# 重新加载这条会话
func _reload_pressed(item: SessionItem):
	var user_message_data : Dictionary = item.item_data.get("user", {})
	send_text_box.text = user_message_data["content"]
	if not item.item_data.get("assistant"):
		last_session_item = item
	else:
		last_session_item = SESSION_ITEM.instantiate()
		session_item_list.add_child(last_session_item)
		item.delete()
	send_current_text()


func _scroll_down() -> void:
	if visible:
		message_scroll_container.scroll_vertical = int(message_scroll_container.get_v_scroll_bar().max_value)


func _on_send_text_box_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# 按回车发送消息
		if event.keycode == KEY_ENTER and event.pressed and not (event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed):
			send_current_text()
			


func _on_send_text_box_text_changed() -> void:
	send_button.disabled = (send_text_box.text.strip_edges() == "")


func _on_models_button_item_selected(index: int) -> void:
	var model_data : Dictionary = model_button.get_item_metadata(index)
	Global.config.set_value("session/model", model_data["model"])
	Global.config.set_value("session/base_url", model_data["base_url"])
