#============================================================
#    Session Window
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-02 00:36:38
# - version: 4.7.0.dev2
#============================================================
class_name SessionWindow
extends Window

const SESSION_ITEM = preload("uid://d4ft7r0p0pskd")
const SESSION_DB_PATH = "user://session/session.db"

@onready var send_text_box: TextEdit = %SendTextBox
@onready var model_button : OptionButton = %ModelsButton
@onready var send_button: Button = %SendButton
@onready var session_group_container: TabContainer = %SessionGroupContainer
@onready var session_title_container: ItemList = %SessionTitleContainer
@onready var title_conversation: Conversation = $TitleConversation
@onready var session_title_label: Label = %SessionTitleLabel

static var session_db : SQLite

var conversation_messages_file := DataFile.instance("user://conversation_messages.data")
var current_session_item_container: SessionItemContainer


func _init() -> void:
	# 自动创建表
	FileUtil.make_dir_if_not_exists(SESSION_DB_PATH.get_base_dir())
	if session_db == null:
		session_db = SQLite.new()
		session_db.path = SESSION_DB_PATH
		session_db.verbosity_level = SQLite.VerbosityLevel.NORMAL
		session_db.open_db()
		
		var table_names : Array = session_db.select_rows("sqlite_master", "type='table' AND name IN ('messages', 'sessions')", ["name"]).map(
			func(item): return item["name"]
		)
		if not table_names.has("messages"):
			# 消息表
			session_db.create_table("messages", {
				"uid": {"data_type":"int",  "primary_key": true, "not_null": true, "auto_increment": true},
				"id": {"data_type":"text"},  #大模型的唯一ID。保留这个名字的 key，方便不用再处理接收到的数据
				"session_id": {"data_type": "int", "not_null": true},  #自定义这组对话的 ID
				"role": {"data_type":"text", "not_null": true},
				"content": {"data_type":"text","not_null": true},
				"reasoning_content": {"data_type":"text",}, 
				"create_time": {"data_type":"timestamp", "default":"CURRENT_TIMESTAMP"},
			})
		if not table_names.has("sessions"):
			# 对话数据表
			session_db.create_table("sessions", {
				"session_id": {"data_type":"int",  "primary_key": true, "not_null": true, "auto_increment": true},
				"title": {"data_type":"text",},
				"create_time": {"data_type": "timestamp", "default":"CURRENT_TIMESTAMP"},
				"update_tile": {"data_type": "integer"},
			})


func _ready() -> void:
	Global.config.bind_object(self, "session/window_size", null, "size", Callable(), func(_v): return mode == Window.MODE_WINDOWED)
	Global.config.bind_object(%MessagesContainer, "session/message_area_split_offset", null, "split_offsets")
	#Global.config.bind_object(send_text_box, "session/last_text", null, "text")
	Global.config.bind_object(title_conversation, "session/title_api_key", "", "api_key")
	Global.config.bind_object(title_conversation, "session/title_base_url", "", "base_url")
	Global.config.bind_object(title_conversation, "session/title_model", "", "model")
	
	# 模型按钮
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
	Global.config.bind_object(model_button, "session/model_idx", 0, "", func(_pre, idx):
		if idx is int:
			model_button.select(idx)
			var model_data = model_button.get_item_metadata(idx)
			Global.config.set_value("session/model", model_data["model"], true)
		return idx
	)
	
	# 输入内容，按下 enter 键提交
	ControlUtil.bind_textedit_submit_signal(send_text_box, func():
		if send_text_box.text:
			send_current_text()
			send_text_box.accept_event()
	)
	
	send_button.disabled = (send_text_box.text.strip_edges() == "")
	
	var session_title_menu_wrapper := MenuWrapper.new(%SessionTitlePopupMenu)
	session_title_menu_wrapper.init_item([
		"删除这条对话"
	])
	session_title_menu_wrapper.menu_pressed.connect(
		func(_id, menu_path):
			if menu_path == "/删除这条对话":
				var items = session_title_container.get_selected_items()
				if not items.is_empty():
					var session_data : Dictionary = session_title_container.get_item_metadata(items[0])
					if session_db.delete_rows("sessions", "session_id=%d" % session_data["session_id"]):
						session_db.delete_rows("messages", "session_id=%d" % session_data["session_id"])
						session_title_container.remove_item(items[0])
						var session_item_container : SessionItemContainer = session_id_to_item_container[session_data["session_id"]]
						session_item_container.queue_free()
						session_id_to_item_container.erase(session_data["session_id"])
						create_new_session()
	)
	session_title_container.item_clicked.connect(
		func(index: int, _at_position: Vector2, mouse_button_index: int):
			if mouse_button_index == MOUSE_BUTTON_RIGHT:
				%SessionTitlePopupMenu.popup(Rect2(Vector2(self.position) + get_mouse_position(), Vector2()))
				session_title_container.select(index)
	)
	
	# 对话列表
	var session_list = session_db.select_rows("sessions", "", ["*"])
	for session_data: Dictionary in session_list:
		session_title_container.add_item(session_data["title"])
		session_title_container.set_item_metadata(session_title_container.item_count-1, session_data)


const SESSION_ITEM_CONTAINER = preload("uid://bdlxen3jys4g2")
var last_session_item : SessionItem
func send_current_text() -> void:
	var text : String = send_text_box.text.strip_edges()
	if text:
		if current_session_item_container == null:
			current_session_item_container = SESSION_ITEM_CONTAINER.instantiate()
			session_group_container.add_child(current_session_item_container)
		current_session_item_container.send_current_text(text)
		send_text_box.clear()
		send_text_box.clear_undo_history()
	else:
		Log.warn("当前没有文字内容")


func _create_session_container(session_id: int) -> SessionItemContainer:
	var session_item_container : SessionItemContainer = SESSION_ITEM_CONTAINER.instantiate()
	session_item_container.session_id = session_id
	session_group_container.add_child(session_item_container)
	session_id_to_item_container[session_id] = session_item_container
	session_item_container.conversation.requested.connect(
		func(message_data):
			var results = session_db.select_rows("sessions", "session_id=%s" % session_id, ["update_title"])
			if results.size() > 0 and not results[0].get("update_title", false):
				title_conversation.send("分析这部分内容的类型描述作为标题：%s \n\n输出格式为：%d=标题名" % [message_data["content"], session_id])
	)
	return session_item_container


## 开启新的对话
func create_new_session() -> void:
	const TITLE_NAME = "新的对话"
	if session_db.insert_row("sessions", { "title": TITLE_NAME }):
		# 添加消息容器
		var session_id : int = session_db.last_insert_rowid
		current_session_item_container = _create_session_container(session_id)
		current_session_item_container.show()
		# 添加对话标题记录
		session_title_container.add_item(TITLE_NAME)
		var index : int = session_title_container.item_count-1
		session_title_container.select(session_title_container.item_count - 1)
		var session_data : Array = session_db.select_rows("sessions", "session_id=%d" % session_id, ["*"])
		session_title_container.set_item_metadata(index, session_data[0])
		Log.info("创建了新对话", "session_id", session_id)
		# 当前打开的对话标题
		session_title_label.text = TITLE_NAME
		session_title_label.set_meta("session_id", session_id)
	else:
		Log.error("创建新对话失败", session_db.error_message)


func show_session_messages(session_id: int):
	if session_id_to_item_container.has(session_id):
		current_session_item_container = session_id_to_item_container[session_id]
		current_session_item_container.show()
	else:
		# 添加打开的对话的容器
		current_session_item_container = _create_session_container(session_id)
		current_session_item_container.show()
		var messages : Array = session_db.select_rows("messages", "session_id=%s" % session_id, ["*"])
		current_session_item_container.load_messages(messages)
		# 更新打开的对话标题
		session_title_label.set_meta("session_id", session_id)
	var result : Array = session_db.select_rows("sessions", "session_id=%d" % session_id, ["*"])
	var session_data : Dictionary = result[0]
	session_title_label.text = str(session_data["title"])


var session_id_to_item_container: Dictionary[int, SessionItemContainer] = {}
func _on_session_item_name_container_item_activated(index: int) -> void:
	# 显示对应的对话列表
	var session_data : Dictionary = session_title_container.get_item_metadata(index)
	var session_id : int = session_data["session_id"]
	show_session_messages(session_id)

func _on_title_conversation_responded_end(message_data: Dictionary) -> void:
	Log.info("标题请求结果", message_data)


func _on_title_conversation_responded_message(message_data: Dictionary) -> void:
	Log.info("标题请求结果", message_data)
	var content : String = message_data["content"]
	var items : PackedStringArray = content.split("=")
	var session_id : int = int(items[0])
	var _title : String = items[1].strip_edges()
	for idx in session_title_container.item_count:
		var session_data : Dictionary = session_title_container.get_item_metadata(idx)
		if session_data["session_id"] == session_id:
			if session_db.update_rows("sessions", "session_id=%d" % session_id, { "title": _title, "update_title": 1}):
				session_data["title"] = _title
				session_title_container.set_item_text(idx, _title)
				if session_title_label.get_meta("session_id") == session_id:
					session_title_label.text = _title
			return
	Log.error("没有这个数据", "session id = ", session_id)

func _on_send_text_box_text_changed() -> void:
	send_button.disabled = (send_text_box.text.strip_edges() == "")

func _on_models_button_item_selected(index: int) -> void:
	var model_data : Dictionary = model_button.get_item_metadata(index)
	Global.config.set_value("session/model", model_data["model"])
	Global.config.set_value("session/base_url", model_data["base_url"])
