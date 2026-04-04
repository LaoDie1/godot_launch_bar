#============================================================
#    Conversation
#============================================================
# - author: zhangxuetu
# - datetime: 2025-01-06 14:49:17
# - version: 4.3.0.stable
#============================================================
## Chat 聊天的对话
##
##处理对话内容，并处理数据
class_name Conversation
extends Node

signal requested(message_data: Dictionary) ##已发出请求
signal responded_message(message_data: Dictionary) ##已响应请求结果
signal responded_stream_data(delta_data: Dictionary) ##每帧的流数据
signal responded_stream_end(message_data: Dictionary) ##数据流结束
signal responded_error(error_data)
signal saved ##已保存


const Role = {
	SYSTEM = "system",
	ASSISTANT = "assistant",
	USER = "user",
}
const ResponseFormat = {
	TEXT = "text",
	JSON_OBJECT = "json_object",
}

static var propertys : PackedStringArray = []

@export var base_url : String = ""
@export var api_key: String = ""
@export var model: String = ""
@export var stream: bool = false ##是否开启流输出
@export var tool_mode : bool = false ## 如果为工具模式，则没有上下文，只有第一个消息和最后一个消息会被发送
@export_multiline var tool_message: String ##工具模式的提示词
@export var messages: Array = []  ##所有消息
@export var message_memory_limit: int = 25 ##最大记忆消息数。在发送的时候，不会把所有的消息都发送给系统，而是只选取最后一段时间的内容进行使用。

var file_path: String

var _http_request: HTTPRequest
var _stream_request: StreamRequest
var _delta_datas : Dictionary = {}


func _init() -> void:
	_http_request = HTTPRequest.new()
	_http_request.request_completed.connect(_request_completed)
	
	_stream_request = StreamRequest.new()
	_stream_request.responded.connect(_response_stream_data)
	_stream_request.connect_closed.connect(_response_stream_end)
	_stream_request.responded_error.connect(
		func(status):
			_response_stream_end()
			push_error("连接出现异常：%d" % status)
			printerr("连接出现异常：%d" % status)
	)
	
	# 添加http请求节点
	var root: SceneTree = Engine.get_main_loop()
	if root.current_scene:
		root.current_scene.add_child.call_deferred(_http_request)
		root.current_scene.add_child.call_deferred(_stream_request)
	else:
		root.process_frame.connect(
			func(): 
				if is_instance_valid(self):
					root.current_scene.add_child(_http_request)
					root.current_scene.add_child(_stream_request)
				,
			Object.CONNECT_ONE_SHOT
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_stream_request):
			_stream_request.queue_free()
			_http_request.queue_free()


## 发送请求
func send(message: String) -> void:
	if is_running():
		push_error("正在运行中，在此期间不能发送")
		return
	if base_url.is_empty():
		push_error("没有设置 Model 的类型")
		return
	
	_delta_datas = {
		"role": "",
		"content": "",
		"reasoning_content": "",
	}
	message = message.strip_edges()
	assert(message != "", "消息数据不能为空")
	while not _http_request or not _http_request.is_inside_tree():
		await Engine.get_main_loop().process_frame
	
	# 当前数据
	var message_data : Dictionary = {
		"role": Role.USER,
		"content": message,
	}
	messages.push_back(message_data)
	
	# 数据列表
	var temp_messages : Array = []
	if tool_mode:
		# 工具模式.无上下文
		temp_messages.push_back({
			"role": Role.SYSTEM,
			"content": tool_message,
		})
		temp_messages.push_back(message_data)
	
	# 带有上下文
	var last_role = ""
	var temp_list :Array = []
	var count : int = 0
	for idx in range(messages.size()-1, -1, -1):
		var item = messages[idx]
		# 倒着向上查找
		if last_role != item["role"] and item["role"]:
			last_role = item["role"]
			temp_list.push_back({
				"role": item["role"],
				"content": item["content"],
			})
			count += 1
		if idx == -1 or count == message_memory_limit * 2: #乘以2是代表两个消息是一次对话，一问一答。
			break
	temp_list.reverse()
	temp_messages.append_array(temp_list)
	
	# 发出时的数据
	var body : Dictionary = {
		"messages": temp_messages,
		"model": model,
		"stream": stream,
	}
	requested.emit(message_data)
	
	# 开始正式请求数据
	var body_json : String = JSON.stringify(body)
	var headers : Array = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	]
	if stream:
		_stream_request.close()
		_stream_request.request(base_url, headers, HTTPClient.METHOD_POST, body_json)
	else:
		if _http_request.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
			_http_request.cancel_request()
		_http_request.request(base_url, headers, HTTPClient.METHOD_POST, body_json)


## 停止响应
func stop() -> void:
	if stream:
		_stream_request.close()
	else:
		if _http_request.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
			_http_request.cancel_request()


## 是否正在运行
func is_running() -> bool:
	if stream:
		return _stream_request.is_connected
	else:
		return _http_request.get_http_client_status() == HTTPClient.STATUS_REQUESTING


## 保存会话资源。不传入 path 参数，则默认按照当前 file_path 的路径进行保存 
func save(path: String = "") -> String:
	assert(path != "" or file_path != "", "文件名不能为空")
	if path != "":
		self.file_path = path
	
	# 导出的数据
	if propertys.is_empty():
		const EXPORT_USAGE = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_DEFAULT
		var property : String
		for item in get_script().get_script_property_list():
			if item['usage'] & EXPORT_USAGE == EXPORT_USAGE:
				property = item["name"]
				propertys.push_back(property)
	
	# 属性数据
	var data : Dictionary = {}
	for property in propertys:
		data[property] = get(property)
	
	# 保存
	if FileUtil.write_as_var(file_path, JSON.stringify(data, "    ")):
		saved.emit()
	else:
		Global.popup_prompt("写入失败：%s" % error_string(FileAccess.get_open_error()))
	return file_path


## 加载会话文件
static func load(path: String) -> Conversation:
	var res: Conversation = Conversation.new()
	res.file_path = path
	if FileUtil.file_exists(path):
		# 属性数据
		var data = FileUtil.read_as_var(path)
		if data is String:
			data = JSON.parse_string(data)
		assert(data is Dictionary, "数据必须是字典类型")
		for property in data:
			if property in res:
				res[property] = data[property]
	return res


func _handle_data(data: Dictionary) -> Dictionary:
	if data:
		var choices : Dictionary = data["choices"][0]
		if choices.has("message"):
			return choices["message"]
		elif choices.has("delta"):
			return choices["delta"]
	return {}


# #响应结果结构：https://api-docs.deepseek.com/zh-cn/api/create-chat-completion
#{
#  "id": "30230b91-db94-4e74-bd24-8ca4ab13b4fa",
#  "object": "chat.completion",
#  "created": 1736317458,
#  "model": "deepseek-chat",
#  "choices": [
#    {
#      "index": 0,
#      "message": {
#        "role": "assistant",
#        "content": "Hello! How can I assist you today? 😊"
#      },
#      "logprobs": null,
#      "finish_reason": "stop"
#    }
#  ],
#  "usage": {
#    "prompt_tokens": 9,
#    "completion_tokens": 11,
#    "total_tokens": 20,
#    "prompt_cache_hit_tokens": 0,
#    "prompt_cache_miss_tokens": 9
#  },
#  "system_fingerprint": "fp_3a5770e1b4"
#}
func _request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var v : String = body.get_string_from_utf8()
	var json : JSON = JSON.new()
	if json.parse(v) == OK:
		var data = json.data
		if data.has("error"):
			responded_error.emit(data["error"])
		else:
			var message : Dictionary = _handle_data(data)
			messages.push_back(message)
			responded_message.emit(message)


#{
#	"choices": [
#		{
#			"delta": {
#				"content": "",
#				"reasoning_content": "",
#				"role": "assistant"
#			},
#			"finish_reason": null,
#			"index": 0.0,
#			"logprobs": null
#		}
#	],
#	"created": 1736317939.0,
#	"id": "3e454c66-8805-4563-a807-e7e2aebfdece",
#	"model": "deepseek-chat",
#	"object": "chat.completion.chunk",
#	"system_fingerprint": "fp_3a5770e1b4"
#}
func _response_stream_data(body_chunk: PackedByteArray):
	var text : String = body_chunk.get_string_from_utf8().strip_edges()
	var items : PackedStringArray = text.split("data: ") # 可能一次返回多段文字内容
	var json : JSON = JSON.new()
	for item: String in items:
		if item != "" and not item.ends_with("[DONE]"):
			if json.parse(item) == OK: #解析这个JSON文字块
				var data : Dictionary = json.data
				if data.has("choices"):
					var delta = _handle_data(data)
					if not _delta_datas.has("id"):
						_delta_datas["id"] = data["id"]
						_delta_datas["role"] = delta["role"]
					if delta.has("content") and typeof(delta["content"]) != TYPE_NIL and delta["content"] != "":
						_delta_datas["content"] += delta["content"]
					elif delta.has("reasoning_content") and typeof(delta["reasoning_content"]) != TYPE_NIL and delta["reasoning_content"] != "":
						_delta_datas["reasoning_content"] += delta["reasoning_content"]
					#else:
						#continue
					responded_stream_data.emit(_delta_datas)
				else:
					responded_error.emit(data)
					return
			else:
				if str(item).contains(": keep-alive"):
					print("保持监听中，请等待...")


func _response_stream_end():
	if not _delta_datas.is_empty():
		messages.push_back(_delta_datas)
	else:
		_delta_datas["role"] = ""
		_delta_datas["content"] = ""
		_delta_datas["reasoning_content"] = ""
	responded_stream_end.emit(_delta_datas)
