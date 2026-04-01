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


func _ready() -> void:
	visibility_changed.connect(
		func():
			if visible:
				await get_tree().create_timer(0.1).timeout
				self.grab_focus()
				send_text_box.grab_focus()
	)
	
	Global.config.bind_node(self, "session_window_size", null, "size")
	
	# 会话列表
	conversation_messages_file.bind_node(conversation, "session_history_messages", null, "messages")
	get_tree().root.tree_exiting.connect(conversation_messages_file.save)
	
	# 更新历史会话列表
	for idx in range(0, conversation.messages.size(), 2):
		var item = SESSION_ITEM.instantiate()
		session_item_list.add_child(item)
		var user_message_data : Dictionary = conversation.messages[idx]
		var assistant_message_data : Dictionary = {}
		if idx + 1 < conversation.messages.size():
			assistant_message_data = conversation.messages[idx + 1]
		item.update_message(user_message_data, assistant_message_data)
	visibility_changed.connect(_scroll_down, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	
	
	# 来消息时，自动滚动到底部方便查看
	var end_resp = func(_data):
		if not auto_scroll_timer.is_stopped():
			auto_scroll_timer.stop()
			message_scroll_container.scroll_vertical = int(message_scroll_container.get_v_scroll_bar().max_value)
	conversation.responded_stream_end.connect(end_resp)
	conversation.responded_message.connect(end_resp)
	conversation.responded_error.connect(end_resp)
	conversation.requested.connect(
		func(__): auto_scroll_timer.start()
	)
	
	# 拖拽容器滚动条则不会自动向下滑动
	message_scroll_container.get_v_scroll_bar().gui_input.connect(
		func(event):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					auto_scroll_timer.stop()
	)


func send_current_text() -> void:
	var text : String = send_text_box.text.strip_edges()
	if text:
		var item = SESSION_ITEM.instantiate()
		session_item_list.add_child(item)
		item.bind_once_conversation(conversation)
		conversation.send(text)
		get_tree().create_timer(0.1).timeout.connect(
			func(): send_text_box.text = ""
		)
	else:
		Log.warn("当前没有文字内容")


func _scroll_down() -> void:
	message_scroll_container.scroll_vertical = int(message_scroll_container.get_v_scroll_bar().max_value)


func _on_send_text_box_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		# 按回车发送消息
		if event.keycode == KEY_ENTER and not (event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed):
			send_current_text()


func _on_send_text_box_text_changed() -> void:
	send_button.disabled = (send_text_box.text.strip_edges() == "")
