#============================================================
#    Session Item
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-02 00:21:28
# - version: 4.7.0.dev2
#============================================================
class_name SessionItem
extends MarginContainer

@onready var user_message_box: TextEdit = %UserMessageBox
@onready var prompt: RichTextLabel = %Prompt
@onready var assistant_message_box: MarkdownLabel = %AssistantMessageBox
@onready var fold_button: Button = %FoldButton
@onready var reload_button: Button = %ReloadButton

var item_data: Dictionary = {}
var _conversation: Conversation

func _enter_tree() -> void:
	hide()


func bind_once_conversation(conversation: Conversation) -> void:
	if conversation != null:
		_conversation = conversation
		_conversation.requested.connect(_requested)
		_conversation.responded_message.connect(_responded_end)
		_conversation.responded_stream_data.connect(_responded_stream_data)
		_conversation.responded_stream_end.connect(_responded_end)
		_conversation.responded_error.connect(_responded_error)
	else:
		_conversation.requested.disconnect(_requested)
		_conversation.responded_message.disconnect(_responded_end)
		_conversation.responded_stream_data.disconnect(_responded_stream_data)
		_conversation.responded_stream_end.disconnect(_responded_end)
		_conversation.responded_error.disconnect(_responded_error)

func update_message(user_message_data: Dictionary, assistant_message_data: Dictionary) -> void:
	if user_message_data:
		item_data["user"] = user_message_data
	if assistant_message_data:
		item_data["assistant"] = assistant_message_data
	user_message_box.text = user_message_data.get("content", "")
	prompt.text = assistant_message_data.get("reasoning_content", "")
	assistant_message_box.markdown_text = assistant_message_data.get("content", "")
	assistant_message_box.show()
	show()
	fold_button.get_parent().visible = not assistant_message_data.get("reasoning_content", "").is_empty()
	fold_button.button_pressed = false

func copy_user_message() -> void:
	DisplayServer.clipboard_set(user_message_box.text)
	Log.info(ScriptUtil.get_info(self), "已复制：", user_message_box.text)

func copy_assistant_message() -> void:
	DisplayServer.clipboard_set(assistant_message_box.text)
	Log.info(ScriptUtil.get_info(self), "已复制：", assistant_message_box.markdown_text)


func delete() -> void:
	_conversation.messages.erase(item_data.get("user"))
	_conversation.messages.erase(item_data.get("assistant"))
	self.queue_free()


func _requested(message_data: Dictionary):
	show()
	item_data[message_data["role"]] = message_data
	user_message_box.text = message_data["content"]
	fold_button.get_parent().visible = false

func _responded_stream_data(delta_data: Dictionary):
	# 流式输出
	prompt.text = delta_data.get("reasoning_content", "")
	fold_button.get_parent().visible = delta_data.get("reasoning_content", "") != ""
	if delta_data["content"]:
		assistant_message_box.markdown_text = delta_data["content"]
		assistant_message_box.show()


func _responded_end(message_data: Dictionary):
	#Log.debug("回复结束：", message_data)
	item_data[message_data["role"]] = message_data
	bind_once_conversation(null)
	fold_button.get_parent().visible = message_data.get("reasoning_content", "") != ""
	if message_data.get("reasoning_content") != "":
		fold_button.button_pressed = false


func _responded_error(error_data):
	assistant_message_box.markdown_text = str(error_data)
	assistant_message_box.modulate = Color(0.7, .3, .3)
	Log.error("回复出现错误", error_data)


func _on_fold_button_toggled(toggled_on: bool) -> void: 
	prompt.visible = toggled_on
	fold_button.text = fold_button.text.strip_edges().trim_prefix("＞ ").trim_prefix("∨ ")
	fold_button.text = ("∨ " if toggled_on else "＞ ") + fold_button.text
