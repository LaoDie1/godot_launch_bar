#============================================================
#    Message Scroll Container
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-07 21:46:48
# - version: 4.6.2.stable
#============================================================
## 这个对话场景容器
extends ScrollContainer

const SESSION_ITEM = preload("uid://d4ft7r0p0pskd")
const SessionItem = preload("uid://dm36yxyxatrrs")

@onready var conversation: Conversation = %Conversation
@onready var item_group: HSplitContainer = %ItemGroup

var session_id: int = -1 # 本次会话的唯一ID
static var super_iterative_analyzer_db: SQLite:
	get: return SuperIterativeAnalyzerWindow.super_iterative_analyzer_db


func _ready() -> void:
	# 聊天对话
	Global.config.bind_object(conversation, "super_iterative_analyzer/model", "", "model")
	Global.config.bind_object(conversation, "super_iterative_analyzer/base_url", "", "base_url")
	Global.config.bind_object(conversation, "super_iterative_analyzer/api_key", "", "api_key")
	Global.config.bind_object(conversation, "super_iterative_analyzer/message_memory_limit", null, "message_memory_limit")
	Global.config.bind_object(conversation, "super_iterative_analyzer/prompt_enabled", null, "tool_mode")
	Global.config.bind_object(conversation, "super_iterative_analyzer/prompt_content", null, "tool_message")
	
	var end_resp : Callable = func(data, status):
		if status == OK:
			# 插入助手的消息
			var assistant_data : Dictionary = data
			assistant_data["session_id"] = session_id
			#if not super_iterative_analyzer_db.insert_row("messages", assistant_data):
				#Log.error("插入消息失败", super_iterative_analyzer_db.error_message)
				#breakpoint
			#assistant_data["uid"] = super_iterative_analyzer_db.last_insert_rowid
			#Log.info("添加新的消息：",  "uid =", assistant_data["uid"])
	conversation.responded_message.connect(end_resp.bind(-1), Object.CONNECT_DEFERRED)
	conversation.responded_error.connect(end_resp.bind(FAILED), Object.CONNECT_DEFERRED)
	conversation.responded_stream_end.connect(end_resp.bind(OK), Object.CONNECT_DEFERRED)


## 发送当前文字
func send_text(text: String, _uid = -1) -> void:
	%UserMessageBox.text = text
	conversation.send("""
请你分析一下用户的这个问题，然后梳理出这个问题的核心要点，梳理用户在问什么，然后给出问题的几种解决方案的方向的类型和提示词用于接下来的大模型的多线程使用分析。
请按以下的 JSON 格式化输出：
{
  "用户问题分析": {
    "原始意图": "",
    "深层需求": ""
  },
  "核心要点梳理": [
    "1. xxx",
    ...
  ],
  "问题本质定义": "",
  "解决方案方向类型与对应提示词": [
    {
      "方向类型": "",
      "说明": "",
      "提示词示例": ""
    },
    ...
  ]
}

问题内容：
""" + text)


func _on_conversation_responded_stream_data(delta_data: Dictionary) -> void:
	%MessageHeadBox.text = delta_data["content"]


func _on_conversation_responded_stream_end(message_data: Dictionary) -> void:
	%MessageHeadBox.hide()
	var content : String = message_data["content"]
	var data = JSON.parse_string(content)
	if data is Dictionary:
		
		var label = %用户问题分析
		
		label.text += "用户问题分析:\n"
		for key in data["用户问题分析"]:
			label.text += "%s: %s\n" % [key, data["用户问题分析"][key]]
		
		label.text += "\n"
		label.text += "核心要点梳理:\n"
		label.text += "\n".join(data["核心要点梳理"])
		
		label.text += "\n"
		label.text += "问题本质定义:\n%s\n" % data["问题本质定义"]
		
		for item in data["解决方案方向类型与对应提示词"]:
			var session_item = SESSION_ITEM.instantiate()
			item_group.add_child(session_item)
			item_group.split_offsets[item_group.split_offsets.size() - 1] = item_group.split_offsets.size() * 800
			item_group.custom_minimum_size.x = item_group.split_offsets.size() * 800
			session_item.custom_minimum_size.x = 800
			
			var conv := Conversation.new()
			conv.base_url = conversation.base_url
			conv.api_key = conversation.api_key
			conv.model = conversation.model
			conv.stream = true
			session_item.bind_once_conversation(conv)
			session_item.add_child(conv)
			var prompt_content : String = "我现在需要你根据以下数据的内容需求，将结果返还给我，结果需要是理性、有逻辑的： {提示词示例} \n\n 说明：{说明}".format(item)
			conv.send(prompt_content)
			await conv.responded_stream_end
			
	else:
		printerr("错误的数据格式：", data)
	
