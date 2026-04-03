#============================================================
#    Stream Request
#============================================================
# - author: zhangxuetu
# - datetime: 2025-01-06 17:47:33
# - version: 4.3.0.stable
#============================================================
## 流式获取数据请求
class_name StreamRequest
extends Node


signal responded(body_chunk: PackedByteArray)
signal responded_error(status: HTTPClient.Status)
signal connected  ## 已连接
signal connect_closed  ##连接关闭
signal received_headers(headers: Dictionary) # 收到响应头

var http_client : HTTPClient = HTTPClient.new()
var is_connected : bool = false
var has_received_headers : bool = false

func request(url: String, headers: PackedStringArray = PackedStringArray(), method: HTTPClient.Method = 0, request_body: String = "") -> void:
	print_debug(url)
	var url_parts = url.split("://")
	var protocol : String = url_parts[0]  # "https" 或 "http"
	var host_and_path = url_parts[1].split("/", true, 1)
	var host_and_port = host_and_path[0].split(":")  # "api.deepseek.com"
	var host : String = host_and_port[0]
	var path : String = ("/" + host_and_path[1] if host_and_path.size() > 1 else "/")  # "/chat/completions"
	
	# 设置端口和 SSL
	var port : int = 443 if protocol == "https" else 80
	if host_and_port.size() > 1:
		port = int(host_and_port[1])
	var tls_options = TLSOptions.client() if protocol == "https" else null
	
	# 连接到主机
	var error : int = http_client.connect_to_host(host, port, tls_options)
	if error != OK:
		push_error("Failed to connect to host: ", error)
		responded_error.emit(http_client.get_status())
		return

	# 等待连接完成
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		#await get_tree().process_frame
		OS.delay_msec(100)

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("Failed to connect to host. Status: ", http_client.get_status())
		responded_error.emit(http_client.get_status())
		return
	
	error = http_client.request(method, path, headers, request_body)
	if error != OK:
		push_error("Failed to send request: ", error, "  ", error_string(error))
		responded_error.emit(http_client.get_status())
		return
	
	# 开始读取流式响应
	has_received_headers = false
	is_connected = true
	set_process(true)
	connected.emit()

func _init() -> void:
	name = "StreamRequest"

func _ready() -> void:
	set_process(false)

func _process(delta):
	if not is_connected:
		return
	
	http_client.poll()
	match http_client.get_status():
		HTTPClient.STATUS_BODY:
			# 🔥 修正逻辑：如果还没读取过 Header，先读取 Header
			if not has_received_headers:
				has_received_headers = true
				var headers = http_client.get_response_headers_as_dictionary()
				received_headers.emit(headers)
			
			# 读取流式数据
			var chunk = http_client.read_response_body_chunk()
			if chunk.size() > 0:
				responded.emit(chunk)
		
		HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTED:
			close()
		
		HTTPClient.STATUS_REQUESTING:
			pass
		
		_:
			print_debug(http_client.get_status())
			responded_error.emit(http_client.get_status())
			close()


func close():
	# 连接关闭
	if is_connected:
		is_connected = false
		connect_closed.emit()
	http_client.close()
