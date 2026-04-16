#============================================================
#    Time Stopwatch
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-14 14:50:28
# - version: 4.6.2.stable
#============================================================
##秒表
class_name TimeStopwatch

static var _time_dict: Dictionary = {}

var _time : int = -1

func _init() -> void:
	start()

func start() -> void:
	_time = Time.get_ticks_msec()

func get_time() -> float:
	return (Time.get_ticks_msec() - _time) / 1000.0

func get_tick_msec() -> int:
	return Time.get_ticks_msec() - _time

func reset() -> void:
	_time = Time.get_ticks_msec()
