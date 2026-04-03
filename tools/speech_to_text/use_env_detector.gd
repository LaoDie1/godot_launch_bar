#============================================================
#    Use Env Detector
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-03 15:43:24
# - version: 4.7.0.dev2
#============================================================
## 使用环境检测
extends Node

# 检测结果存储
var detection_result = {
	"python_ok": false,
	"libs_ok": false,
	"model_ok": false,
	"port_ok": false
}

func _ready() -> void:
	await get_tree().create_timer(0.2).timeout
	print("[ 开始检测使用环境 ]")
	await start_detection()
	print("[ 检测完成 ]")
	
	if not detection_result["port_ok"]:
		kill_port_28666_one_click()


func kill_port_28666_one_click() -> bool:
	var exit_code: int = 0
	exit_code = OS.execute("cmd.exe", [
		"/c", 
        "for /f \"tokens=5\" %a in ('netstat -ano ^| findstr \":28666\"') do taskkill /F /PID %a"
	], [])
	return exit_code == 0


# 主检测函数，调用后依次执行所有检测
func start_detection():
	detection_result = {
		"python_ok": false,
		"libs_ok": false,
		"model_ok": false,
		"port_ok": false
	}
	
	await check_python()
	await check_libraries()
	await check_whisper_model()
	await check_port()
	
	print(detection_result)
	return detection_result

# 1. 检测 Python 环境
func check_python():
	var output = []
	var exit_code = 0
	
	# 尝试运行 python --version（Windows 通常是 python，macOS/Linux 可能是 python3）
	var python_cmd = "python"
	if OS.get_name() == "Linux" or OS.get_name() == "macOS":
		python_cmd = "python3"
	
	OS.execute(python_cmd, ["--version"], output, exit_code)
	
	if exit_code == 0:
		print("[OK] Python 已安装: ", output[0])
		detection_result.python_ok = true
	else:
		print("[FAIL] 未检测到 Python")
	detection_result.python_ok = (exit_code == 0)

# 2. 检测依赖库（whisper, fastapi, uvicorn）
func check_libraries():
	var required_libs = ["openai-whisper", "fastapi", "uvicorn"]
	var all_ok = true
	
	for lib in required_libs:
		var output = []
		var exit_code = 0
		OS.execute("pip", ["show", lib], output, exit_code)
		if exit_code != 0:
			print("[FAIL] 缺少库: ", lib)
			all_ok = false
			OS.execute_with_pipe("pip", ["install", lib])
		else:
			print("[OK] 库已安装: ", lib)
	
	detection_result.libs_ok = all_ok

# 3. 检测 Whisper small 模型文件
func check_whisper_model():
	var model_path = ""
	
	# 根据操作系统拼接默认模型缓存路径
	if OS.get_name() == "Windows":
		# Windows: C:\Users\用户名\.cache\whisper\small.pt
		model_path = OS.get_environment("USERPROFILE") + "\\.cache\\whisper\\small.pt"
	else:
		# Linux/macOS: ~/.cache/whisper/small.pt
		model_path = OS.get_environment("HOME") + "/.cache/whisper/small.pt"
	
	var file = FileAccess.open(model_path, FileAccess.READ)
	if file:
		print("[OK] Whisper small 模型存在")
		detection_result.model_ok = true
		file.close()
	else:
		print("[FAIL] 未找到 Whisper small 模型，请先运行一次脚本自动下载，或手动放置到: ", model_path)
	detection_result.model_ok = (file != null)

# 4. 检测端口 28666 是否被占用
func check_port():
	var output = []
	var exit_code = 0
	var port_free = true
	
	if OS.get_name() == "Windows":
		# Windows: netstat -ano | findstr ":28666"
		OS.execute("cmd", ["/C", "netstat -ano | findstr \":28666\""], output, exit_code)
	else:
		# Linux/macOS: lsof -i :28666 或 netstat -tuln | grep :28666
		OS.execute("lsof", ["-i", ":28666"], output, exit_code)
	
	# 如果 exit_code 为 0，说明有输出（端口被占用）
	if exit_code == 0 and output.size() > 0:
		print("[FAIL] 端口 28666 已被占用")
		port_free = false
	else:
		print("[OK] 端口 28666 可用")
	
	detection_result.port_ok = port_free
