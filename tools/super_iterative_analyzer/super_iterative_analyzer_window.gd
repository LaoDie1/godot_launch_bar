#============================================================
#    Super Iterative Analyzer Window
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-13 01:33:37
# - version: 4.7.0.dev2
#============================================================
class_name SuperIterativeAnalyzerWindow
extends Window

const SessionItem = preload("uid://dm36yxyxatrrs")
const SESSION_ITEM = preload("uid://bf3io61e8ndic")
const SessionItemContainer = preload("uid://cc5f8fgc3spks")
const SESSION_ITEM_CONTAINER = preload("uid://brmmpf4g2jhh5")

@onready var session_items: Tree = %SessionItems
@onready var mul_session_container_panel: Control = %MulSessionContainerPanel
@onready var submit_message_box: TextEdit = %SubmitMessageBox

static var super_iterative_analyzer_db : SQLite


func _init() -> void:
	# 自动创建表
	const ITERATIVE_ANALYZER_DB_PATH = "user://super_iterative_analyzer/super_iterative_analyzer.db"
	FileUtil.make_dir_if_not_exists(ITERATIVE_ANALYZER_DB_PATH.get_base_dir())
	if super_iterative_analyzer_db == null:
		super_iterative_analyzer_db = SQLite.new()
		super_iterative_analyzer_db.path = ITERATIVE_ANALYZER_DB_PATH
		super_iterative_analyzer_db.verbosity_level = SQLite.VerbosityLevel.NORMAL
		super_iterative_analyzer_db.open_db()
		
		var table_names : Array = super_iterative_analyzer_db.select_rows("sqlite_master", "type='table' AND name IN ('messages', 'sessions')", ["name"]).map(
			func(item): return item["name"]
		)
		if not table_names.has("messages"):
			# 消息表
			super_iterative_analyzer_db.create_table("messages", {
				"uid": {"data_type":"int",  "primary_key": true, "not_null": true, "auto_increment": true},
				"id": {"data_type":"text"},  #大模型的唯一ID。保留这个名字的 key，方便不用再处理接收到的数据
				"session_id": {"data_type": "int", "not_null": true},  #自定义这组对话的 ID
				"child_uid": {"data_type": "text"}, #这个对话的 UID 列表
				"role": {"data_type":"text", "not_null": true},
				"content": {"data_type":"text","not_null": true},
				"reasoning_content": {"data_type":"text",}, 
				"create_time": {"data_type":"timestamp", "default":"CURRENT_TIMESTAMP"},
			})
		if not table_names.has("sessions"):
			# 对话数据表
			super_iterative_analyzer_db.create_table("sessions", {
				"session_id": {"data_type":"int",  "primary_key": true, "not_null": true, "auto_increment": true},
				"title": {"data_type":"text",},
				"create_time": {"data_type": "timestamp", "default":"CURRENT_TIMESTAMP"},
				"update_tile": {"data_type": "integer"},
			})
		super_iterative_analyzer_db = SQLite.new()


func _ready() -> void:
	ControlUtil.bind_textedit_submit_signal(submit_message_box, func():
		if submit_message_box.text.strip_edges() != "":
			put_message(submit_message_box.text.strip_edges())
			submit_message_box.text = ""
	)


func put_message(message: String):
	var item_container = SESSION_ITEM_CONTAINER.instantiate()
	%MulSessionContainerPanel.add_child(item_container)
	item_container.send_text(message)
