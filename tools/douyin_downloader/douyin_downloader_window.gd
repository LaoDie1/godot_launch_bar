#============================================================
#    Douyin Downloader Window
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-12 03:38:12
# - version: 4.7.0.dev2
#============================================================
extends Window

@onready var link_text_edit: TextEdit = %LinkTextEdit
@onready var http_request: HTTPRequest = %HTTPRequest
@onready var stream_request: StreamRequest = %StreamRequest


func _ready() -> void:
	if get_tree().current_scene == self:
		close_requested.connect(
			func():
				get_tree().quit()
		)
	
	# 按 Enter 键开始下载视频
	TextEditSubmitWrapper.create(link_text_edit).text_submitted.connect(
		func(text: String):
			if not text.strip_edges().is_empty():
				var link_url = parse_douyin_short_link(text)
				Log.info(self, "短视频链接：", link_url)
				if link_url:
					request_video_html_page(link_url)
					link_text_edit.text = ""
			set_input_as_handled()
	)
	
	_last_text = DisplayServer.clipboard_get()
	
	Global.config.bind_object(self, "douyin_downloader/window_size", null, "size", Callable(), func(__): return mode == Window.MODE_WINDOWED)
	Global.config.bind_object(self, "douyin_downloader/window_position", null, "position", Callable(), func(__): return mode == Window.MODE_WINDOWED)
	Global.config.bind_object(link_text_edit, "douyin_downloader/text")
	Global.config.bind_object(%CheckClipboardButton, "douyin_downloader/auto_check_clipboard_link")


var _last_text
func _process(delta: float) -> void:
	if Engine.get_process_frames() % 10 == 0 and %CheckClipboardButton.button_pressed:
		if DisplayServer.clipboard_has():
			var text : String = DisplayServer.clipboard_get()
			if text and _last_text != text:
				_last_text = text
				Log.info(self, "解析抖音分享的视频短链接")
				var link_url = parse_douyin_short_link(text)
				if link_url:
					request_video_html_page(link_url)


# 解析视频短链接
var _parse_url_regex: RegEx:
	get:
		if _parse_url_regex == null:
			_parse_url_regex = RegEx.new()
			_parse_url_regex.compile(r"https?://v.douyin.com/[A-Za-z0-9_-]+/?")
		return _parse_url_regex
func parse_douyin_short_link(text: String) -> String:
	var result = _parse_url_regex.search(text)
	if result:
		return result.get_string()
	return ""


var _request_download_queue: Array = []
# 发送GET请求获取页面内容
func request_video_html_page(page_url: String) -> void:
	if stream_request.is_connecting() or http_request.get_http_client_status():
		_request_download_queue.push_back(page_url)
		return
	
	%StopButton.disabled = false
	Log.info("获取视频页面内容")
	var headers : Dictionary = {
		"User-Agent": 'Mozilla/5.0 (Linux; Android 8.0.0; SM-G955U Build/R16NW) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
		"Referer": "https://www.douyin.com/",
		"Accept": "*/*",
	}
	var error = http_request.request(page_url, headers.keys().map(func(key): return "%s: %s" % [key, headers[key]]))
	Log.info(self, "请求结果：", error, error_string(error))
	if error == OK:
		%DownloadInfoLabel.text = "正在请求视频下载地址..."
	else:
		%DownloadInfoLabel.text = "请求视频下载地址失败！"


# 解析请求返回的结果
var _parse_douyin_html_vido_json : RegEx:
	get:
		if _parse_douyin_html_vido_json == null:
			_parse_douyin_html_vido_json = RegEx.new()
			_parse_douyin_html_vido_json.compile('window\\._ROUTER_DATA\\s*=\\s*(.*?)</script>')
		return _parse_douyin_html_vido_json
func _douyin_html_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var html : String = body.get_string_from_utf8()
	var json_string_result = _parse_douyin_html_vido_json.search(html)
	Log.info(self, "抖音视频 html json 结果", json_string_result)
	var router_data = _parse_douyin_html_vido_json.search(html)
	if router_data:
		var json = JSON.parse_string(router_data.get_string(1))
		var video_info_res : Dictionary = json["loaderData"]["video_(id)/page"]["videoInfoRes"]
		var item_info = video_info_res["item_list"][0]
		var play_addr = item_info["video"]["play_addr"]
		var url_list = play_addr["url_list"]
		Log.info(self, "视频清晰度播放列表：", url_list)
		var video_url : String = url_list[0]
		video_url = video_url.replace("playwm", "play") #去水印
		var downloads_path : String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		var author = str(item_info["author"]["nickname"]).validate_filename()
		var desc = str(item_info["desc"]).validate_filename().replace("\n", "_")
		var create_time = str(item_info["create_time"]).replace(".", "")
		var video_path : String = downloads_path.path_join("@%s_%s_%s.mp4" % [author, desc, create_time])
		Log.info(self, "开始下载视频: url =", video_url, ", 文件路径 =", video_path)
		download_video(video_url, video_path)
	else:
		Log.error(self, "未解析到视频内容，html =", html)


# 开始下载
var _download_file: FileAccess = null
var _downloaded_bytes: int = 0  # 已下载大小（断点位置）
func download_video(download_url: String, save_path: String):
	# 1. 读取已存在的文件大小 = 断点位置
	if FileAccess.file_exists(save_path):
		var f = FileAccess.open(save_path, FileAccess.READ)
		_downloaded_bytes = f.get_length()
		f.close()
		%DownloadInfoLabel.text = "续传模式，已下载: %s 字节" % _downloaded_bytes
		print("续传模式，已下载: %s 字节" % _downloaded_bytes)
	else:
		print("全新下载")
		_downloaded_bytes = 0

	# 2. 以 追加模式 打开文件
	_download_file = FileAccess.open(save_path, FileAccess.WRITE_READ)  # 关键：支持续写
	_download_file.seek_end()  # 跳到文件末尾
	# 3. 连接服务器
	
	var headers = {
		"User-Agent": 'Mozilla/5.0 (Linux; Android 8.0.0; SM-G955U Build/R16NW) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
		"Referer": "https://www.douyin.com/",
		"Origin": "https://www.douyin.com",
		"Sec-Fetch-Site": "same-site",
		"Sec-Fetch-Mode": "cors",
		"Sec-Fetch-Dest": "empty",
		"Accept": "*/*",
		"Accept-Language": "zh-CN,zh;q=0.9",
		"Connection": "keep-alive",
		"Range": "bytes=%d-" % _downloaded_bytes,
	}
	var err = stream_request.request(download_url, headers.keys().map(func(key): return "%s: %s" % [ key, headers[key]]))
	if err != OK:
		%DownloadInfoLabel.text = "连接失败:%s" % err
		return


# 手动调用可模拟断开后重连
func stop_download():
	if stream_request.is_connecting():
		if _download_file:
			_download_file.close()
		http_request.cancel_request()
		stream_request.close()
		%DownloadInfoLabel.text = "下载中断。"
		%DownloadInfoLabel.tooltip_text = ""


var _content_length: float
func _on_stream_request_received_headers(headers: Dictionary) -> void:
	pass # Replace with function body.
	#Log.prompt(self, "头信息：", JSON.stringify(headers, "\t"))
	var value = DataUtil.find_first_key_value(headers, "content-length")
	if value:
		_content_length = int(value) / 1024.0 / 1024.0
	else:
		_content_length = 0

func _on_stream_request_responded(chunk: PackedByteArray) -> void:
	if chunk.size() > 0:
		_download_file.store_buffer(chunk)
		_downloaded_bytes += chunk.size()
		%DownloadInfoLabel.text = "下载中: %.2f MB，总长度：%s KB" % [_downloaded_bytes / 1024.0 / 1024.0, _content_length]

func _on_stream_request_connect_closed() -> void:
	_download_file.flush()
	_download_file.close()
	Log.info(self, "下载结束")
	%DownloadInfoLabel.text = "下载结束"
	%StopButton.disabled = true
	%DownloadInfoLabel.tooltip_text = ""

func _on_stream_request_responded_error(status: HTTPClient.Status) -> void:
	Log.error(self, "响应时出现错误", status)
	%DownloadInfoLabel.text = "响应时出现错误"
	%DownloadInfoLabel.tooltip_text = ""

func _on_stream_request_redirected(redirect_url: String) -> void:
	Log.info(self, "重定向到链接", redirect_url)
	%DownloadInfoLabel.text = "重定向到链接 %s" % redirect_url
	%DownloadInfoLabel.tooltip_text = redirect_url
