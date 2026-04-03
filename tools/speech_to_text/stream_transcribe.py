import sys
import uuid
import whisper
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
import io
import contextlib
import threading
import queue

app = FastAPI()

# 全局存储：任务ID -> 停止事件
tasks = {}
# 线程锁，保证 tasks 字典读写安全
tasks_lock = threading.Lock()

# 加载模型（静默加载）
with contextlib.redirect_stdout(io.StringIO()):
    model = whisper.load_model("small", device="cpu")

# 捕获输出 + 支持停止
def capture_whisper_output(video_path, q, stop_event):
    class StdoutCapture:
        def write(self, text):
            if stop_event.is_set():
                raise InterruptedError("Transcription stopped")
            if text.strip():
                q.put(text)
        def flush(self):
            pass

    old_stdout = sys.stdout
    sys.stdout = StdoutCapture()

    try:
        model.transcribe(
            video_path,
            language="zh",
            verbose=True,
            fp16=False,
            condition_on_previous_text=False,
            initial_prompt="请输出普通话简体中文"
        )
    except InterruptedError:
        pass
    finally:
        sys.stdout = old_stdout
        q.put(None)

# 流式生成器
def transcribe_stream(video_path, task_id, stop_event):
    q = queue.Queue()
    
    thread = threading.Thread(target=capture_whisper_output, args=(video_path, q, stop_event))
    thread.start()

    try:
        while True:
            line = q.get()
            if line is None:
                break
            if "-->" in line or ("[" in line and "]" in line):
                yield line
    except GeneratorExit:
        stop_event.set()
        thread.join(timeout=1)
    finally:
        # 任务结束后，从全局字典中移除
        with tasks_lock:
            if task_id in tasks:
                del tasks[task_id]
        # 清空队列
        while not q.empty():
            try:
                q.get_nowait()
            except queue.Empty:
                break

# 1. 开始识别接口（返回 Task ID）
@app.get("/transcribe")
def transcribe(path: str):
    # 生成唯一任务 ID
    task_id = str(uuid.uuid4())
    # 创建该任务专属的停止事件
    stop_event = threading.Event()
    
    # 存入全局字典
    with tasks_lock:
        tasks[task_id] = stop_event

    # 创建 StreamingResponse
    response = StreamingResponse(
        transcribe_stream(path, task_id, stop_event),
        media_type="text/plain"
    )
    
    # 🔥 关键：通过响应头把 Task ID 返回给客户端
    response.headers["X-Task-ID"] = task_id
    return response

# 2. 主动停止接口
@app.get("/stop")
def stop_task(task_id: str):
    with tasks_lock:
        stop_event = tasks.get(task_id)
    
    if not stop_event:
        raise HTTPException(status_code=404, detail="Task not found or already finished")
    
    # 设置停止标志
    stop_event.set()
    return {"status": "success", "message": f"Task {task_id} stopped"}

# 启动服务
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=28666,
        log_level="critical",
        access_log=False
    )
