#============================================================
#    Message Scroll Container
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-07 21:46:48
# - version: 4.6.2.stable
#============================================================
## 这个对话场景容器
class_name SessionItemContainer
extends ScrollContainer

const SESSION_ITEM = preload("uid://d4ft7r0p0pskd")

@onready var session_item_list: VBoxContainer = %SessionItemList
@onready var conversation: Conversation = %Conversation
@onready var auto_scroll_timer: Timer = %AutoScrollTimer

var session_id: int = -1 # 本次会话的唯一ID
static var session_db: SQLite:
	get: return SessionWindow.session_db


func _ready() -> void:
	# 聊天对话
	Global.config.bind_object(conversation, "session/model", "", "model")
	Global.config.bind_object(conversation, "session/base_url", "", "base_url")
	Global.config.bind_object(conversation, "session/api_key", "", "api_key")
	Global.config.bind_object(conversation, "session/message_memory_limit", null, "message_memory_limit")
	Global.config.bind_object(conversation, "session/prompt_enabled", null, "tool_mode")
	Global.config.bind_object(conversation, "session/prompt_content", null, "tool_message")
	
	var end_resp : Callable = func(data, status):
		if not auto_scroll_timer.is_stopped():
			# 停止自动滚动
			auto_scroll_timer.stop()
			self.scroll_vertical = int(self.get_v_scroll_bar().max_value)
		if status == OK:
			# 插入助手的消息
			var assistant_data : Dictionary = data
			assistant_data["session_id"] = session_id
			if not session_db.insert_row("messages", assistant_data):
				Log.error("插入消息失败", session_db.error_message)
				breakpoint
			assistant_data["uid"] = session_db.last_insert_rowid
			Log.info("添加新的消息：",  "uid =", assistant_data["uid"])
	conversation.requested.connect(func(_data): auto_scroll_timer.start()) # 来消息时，自动滚动到底部方便查看
	conversation.responded_message.connect(end_resp.bind(-1), Object.CONNECT_DEFERRED)
	conversation.responded_error.connect(end_resp.bind(FAILED), Object.CONNECT_DEFERRED)
	conversation.responded_stream_end.connect(end_resp.bind(OK), Object.CONNECT_DEFERRED)
	auto_scroll_timer.timeout.connect(scroll_to_down)
	# 拖拽容器滚动条则不会自动向下滑动
	self.get_v_scroll_bar().gui_input.connect(
		func(event):
			if event is InputEventMouseButton:
				if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_WHEEL_UP]:
					auto_scroll_timer.stop()
	)
	if not visible:
		visibility_changed.connect(scroll_to_down, Object.CONNECT_ONE_SHOT | Object.CONNECT_DEFERRED)
	else:
		get_tree().create_timer(0.1).timeout.connect(scroll_to_down)


## 滚动到底部
func scroll_to_down() -> void:
	if visible:
		self.scroll_vertical = int(self.get_v_scroll_bar().max_value)

func load_messages(messages: Array):
	conversation.messages = messages
	for idx in range(0, messages.size(), 2):
		# 添加会话项
		var item : SessionItem = _create_new_session_item()
		var user_message_data : Dictionary = messages[idx]
		var assistant_message_data : Dictionary = {}
		if idx + 1 < messages.size():
			assistant_message_data = messages[idx + 1]
		item.update_message(user_message_data, assistant_message_data)
		item._conversation = conversation
	get_tree().create_timer(0.1).timeout.connect(scroll_to_down)


func _create_new_session_item() -> SessionItem:
	var session_item : SessionItem = SESSION_ITEM.instantiate()
	session_item_list.add_child(session_item)
	session_item.delete_button.pressed.connect(
		func():
			# INFO 删除这两条消息
			var user_data : Dictionary = session_item.item_data.get("user", {})
			if user_data:
				var uid : int = user_data["uid"]
				session_db.delete_rows("messages", "uid=%d" % uid)
				conversation.messages.erase(user_data)
			var assistant_data : Dictionary = session_item.item_data.get("assistant", {})
			if assistant_data:
				var uid : int = assistant_data["uid"]
				session_db.delete_rows("messages", "uid=%d" % uid)
				conversation.messages.erase(assistant_data)
			session_item.queue_free()
	)
	return session_item


## 发送当前文字
func send_current_text(text: String, uid = -1) -> void:
	assert(session_id != -1, "会话的ID不能为 -1！")
	text = text.strip_edges()
	assert(not text.is_empty(), "传入的字符不能为空")
	# INFO 新的消息添加到数据库
	var user_data : Dictionary = {
		"session_id": session_id,
		"role": "user",
		"content": text,
	}
	session_db.insert_row("messages", user_data)
	uid = session_db.last_insert_rowid
	user_data["uid"] = uid
	var session_item : SessionItem = _create_new_session_item()
	session_item.update_message(user_data, {
		"role": "assistant",
		"content": "",
	})
	session_item.bind_once_conversation(conversation)
	conversation.send(text)
