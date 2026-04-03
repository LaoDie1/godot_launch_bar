#============================================================
#    Speech To Text
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-03 10:27:05
# - version: 4.7.0.dev2
#============================================================
extends Window

@onready var file_path_label: Label = %FilePathLabel
@onready var result_text_box: TextEdit = %ResultTextBox
@onready var stream_req: StreamRequest = %StreamRequest

var python_server_pid: int 

var _current_task_id : String:
	set(v):
		_current_task_id = v
		if _current_task_id:
			%RunningTextTimer.start()
		else:
			%RunningTextTimer.stop()
			%RunningLabel.text = "(完成)"

func _ready() -> void:
	# 绑定信号
	stream_req.responded.connect(_on_stream_chunk)
	stream_req.connected.connect(_on_connected)
	stream_req.responded_error.connect(_on_error)
	stream_req.connect_closed.connect(_on_closed)
	stream_req.received_headers.connect(_on_stream_request_received_headers)
	
	# 创建 python 服务器脚本
	var python_script_path : String = FileUtil.get_real_path("./tools/speech_to_text/stream_transcribe.py")
	if not FileUtil.file_exists(python_script_path):
		print("python 服务器脚本: 不存在 %s 文件，开始自动创建" % python_script_path)
		var code : String = FileUtil.read_as_string("res://tools/speech_to_text/stream_transcribe.py")
		FileUtil.make_dir_if_not_exists(python_script_path.get_base_dir())
		FileUtil.write_as_string(python_script_path, code)
	
	var python_executable_path = FileUtil.find_program_path("python")
	prints("开始运行语音识别服务：", python_executable_path, python_script_path)
	python_server_pid = OS.create_process(python_executable_path, [python_script_path], false)
	print(" 已运行服务:", python_server_pid)
	
	# 开始转写（换成你的视频路径）
	files_dropped.connect(
		func(files):
			start_transcribe(files[0])
	)

func _exit_tree() -> void:
	if python_server_pid != 0:
		OS.kill(python_server_pid)

# 开始请求
func start_transcribe(video_path: String):
	print("  开始识别文件：%s" % video_path)
	%FilePathLabel.text = video_path.get_file()
	%FilePathLabel.tooltip_text = video_path
	_current_task_id = ""
	var url = "http://127.0.0.1:28666/transcribe?path=" + video_path.replace("\\", "/")
	stream_req.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	result_text_box.text = ""

func stop() -> void:
	stream_req.request("http://127.0.0.1:28666/stop?task_id=" + _current_task_id)
	print("✅ 已打断Python识别")
	_current_task_id = ""

func _on_stream_request_received_headers(headers: Dictionary):
	if headers.has("x-task-id"):
		_current_task_id = headers["x-task-id"]
		print("成功获取到 Task ID: ", _current_task_id)

# 实时接收流式文字（核心！）
func _on_stream_chunk(chunk: PackedByteArray):
	var text = chunk.get_string_from_utf8().strip_edges()
	if not text:
		return
	if _current_task_id:
		print("   ", text)
		result_text_box.text += text + "\n"
		result_text_box.scroll_vertical = result_text_box.get_v_scroll_bar().max_value

func _on_error(status):
	print("错误：", status)
	_current_task_id = ""

func _on_connected():
	print("连接成功，正在识别...")

func _on_closed():
	print("转写完成！")
	_current_task_id = ""

const RUNNING_TEXT_LIST = ["识别中", "识别中.", "识别中..", "识别中...", "识别中....", ]
var _running_number: int = 0
func _on_running_text_timer_timeout() -> void:
	%RunningLabel.text = RUNNING_TEXT_LIST[_running_number % RUNNING_TEXT_LIST.size()]
	_running_number += 1
	%RunningLabel.modulate.a = 1.0
