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

var conversation_messages_file := DataFile.instance("user://conversation_messages.data")

@onready var send_text_box: TextEdit = %SendTextBox
@onready var model_button : OptionButton = %ModelsButton
@onready var send_button: Button = %SendButton
@onready var session_group_container: TabContainer = %SessionGroupContainer
@onready var session_item_name_container: ItemList = %SessionItemNameContainer
@onready var title_conversation: Conversation = $TitleConversation

const SESSION_DB_PATH = "user://session/session.db"
static var session_db : SQLite

var session_item_container: SessionItemContainer


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
				"session_id": {"data_type": "int", "not_null": true},  #自定义这组会话的 ID
				"role": {"data_type":"text", "not_null": true},
				"content": {"data_type":"text","not_null": true},
				"reasoning_content": {"data_type":"text",}, 
				"create_time": {"data_type":"timestamp"},
			})
		if not table_names.has("sessions"):
			# 会话数据表
			session_db.create_table("sessions", {
				"session_id": {"data_type":"int",  "primary_key": true, "not_null": true, "auto_increment": true},
				"title": {"data_type":"text",},
				"create_time": {"data_type": "timestamp"},
			})


func _ready() -> void:
	Global.config.bind_object(self, "session/window_size", null, "size", Callable(), func(_v): return mode == Window.MODE_WINDOWED)
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
	
	# 会话列表
	var session_list = session_db.select_rows("sessions", "", ["*"])
	for session_data in session_list:
		session_item_name_container.add_item(session_data["title"])
		session_item_name_container.set_item_metadata(session_item_name_container.item_count-1, session_data["session_id"])
	

const SESSION_ITEM_CONTAINER = preload("uid://bdlxen3jys4g2")
var last_session_item : SessionItem
func send_current_text() -> void:
	var text : String = send_text_box.text.strip_edges()
	if text:
		if session_item_container == null:
			session_item_container = SESSION_ITEM_CONTAINER.instantiate()
			session_group_container.add_child(session_item_container)
		session_item_container.send_current_text(text)
		send_text_box.clear()
		send_text_box.clear_undo_history()
	else:
		Log.warn("当前没有文字内容")


func _on_send_text_box_text_changed() -> void:
	send_button.disabled = (send_text_box.text.strip_edges() == "")

func _on_models_button_item_selected(index: int) -> void:
	var model_data : Dictionary = model_button.get_item_metadata(index)
	Global.config.set_value("session/model", model_data["model"])
	Global.config.set_value("session/base_url", model_data["base_url"])

var session_id_to_item_container: Dictionary[int, SessionItemContainer] = {}
func _on_session_item_name_container_item_activated(index: int) -> void:
	# 对应的会话列表
	var session_id : int = session_item_name_container.get_item_metadata(index)
	if session_id_to_item_container.has(session_id):
		session_item_container = session_id_to_item_container[session_id]
	else:
		session_item_container = SESSION_ITEM_CONTAINER.instantiate()
		session_group_container.add_child(session_item_container)
		session_id_to_item_container[session_id] = session_item_container
		session_item_container.session_id = session_id
		var messages : Array = session_db.select_rows("messages", "session_id=%s" % session_id, ["*"])
		session_item_container.load_messages(messages)
		session_item_container.sent_first_message.connect(
			func(message_data):
				title_conversation.send("提取出这部分内容的标题：%s \n\n输出格式为：%d = 标题名" % [message_data["content"], session_id])
		)
	session_item_container.show()




func create_session() -> void:
	const TITLE_NAME = "新的会话"
	if session_db.insert_row("sessions", {
		"title": TITLE_NAME,
	}):
		var session_id : int = session_db.last_insert_rowid
		session_item_container = SESSION_ITEM_CONTAINER.instantiate()
		session_group_container.add_child(session_item_container)
		session_id_to_item_container[session_id] = session_item_container
		session_item_container.session_id = session_id
		session_item_container.show()
		session_item_name_container.add_item(TITLE_NAME)
		var index : int = session_item_name_container.item_count-1
		session_item_name_container.set_item_metadata(index, session_id)
		Log.info("创建了新会话", "session_id", session_id)
		session_item_container.sent_first_message.connect(
			func(message_data):
				title_conversation.send("提取出这部分内容的标题：%s \n\n输出格式为：%d=标题名" % [message_data["content"], session_id])
				session_item_name_container.set_item_text(index, message_data)
		)
	else:
		Log.error("创建新会话失败", session_db.error_message)


func _on_title_conversation_responded_ed(message_data: Dictionary) -> void:
	print(message_data)


func _on_title_conversation_responded_message(message_data: Dictionary) -> void:
	print(message_data)
	var content : String = message_data["content"]
	var items = content.split("=")
	var session_id : int = int(items[0])
	var _title : String = items[1]
	for idx in session_item_name_container.item_count:
		if session_item_name_container.get_item_metadata(idx) == session_id:
			if session_db.update_rows("sessions", "session_id=%d" % session_id, {
				"title": _title,
			}):
				session_item_name_container.set_item_text(idx, _title.strip_edges())
			break
