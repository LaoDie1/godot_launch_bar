extends Window

@onready var text_edit: TextEdit = %TextEdit

var stream_req: StreamRequest

func _ready():
	# 创建流式请求
	stream_req = StreamRequest.new()
	add_child(stream_req)
	
	# 绑定信号
	stream_req.responded.connect(_on_stream_chunk)
	stream_req.responded_error.connect(_on_error)
	stream_req.connected.connect(_on_connected)
	stream_req.connect_closed.connect(_on_closed)
	stream_req.received_headers.connect(_on_stream_request_received_headers)
	
	
	# 开始转写（换成你的视频路径）
	#start_transcribe(r"C:\Users\z\Videos\e1a50a7c8f55c1c80324a3a37c94a0b0_compressed.mp4")
	get_tree().root.files_dropped.connect(
		func(files):
			start_transcribe(files[0])
	)


# 开始请求
func start_transcribe(video_path: String):
	_current_task_id = ""
	var url = "http://127.0.0.1:28666/transcribe?path=" + video_path.replace("\\", "/")
	stream_req.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	text_edit.text = ""

# 实时接收流式文字（核心！）
func _on_stream_chunk(chunk: PackedByteArray):
	var text = chunk.get_string_from_utf8().strip_edges()
	if not text:
		return
	if _current_task_id:
		print("实时识别结果：", text)
		text_edit.text += text + "\n"
		text_edit.scroll_vertical = text_edit.get_v_scroll_bar().max_value

func _on_error(status):
	print("错误：", status)
	_current_task_id = ""

func _on_connected():
	print("连接成功，正在识别...")
	_current_task_id = ""

func _on_closed():
	print("转写完成！")
	_current_task_id = ""

func stop() -> void:
	stream_req.request("http://127.0.0.1:28666/stop?task_id=" + _current_task_id)
	print("✅ 已打断Python识别")
	_current_task_id = ""

var _current_task_id : String
func _on_stream_request_received_headers(headers: Dictionary):
	if headers.has("x-task-id"):
		_current_task_id = headers["x-task-id"]
		print("成功获取到 Task ID: ", _current_task_id)
