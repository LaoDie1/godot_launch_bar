#============================================================
#    Data File
#============================================================
# - author: zhangxuetu
# - datetime: 2024-04-28 11:52:24
# - version: 4.2.1
#============================================================
## 用于保存数据。可以通过 [method bind_object] 进行快速绑定节点进行数据的存储。
##
##绑定节点的配置到数据里。在下次加载的时候，自动加载数据到这个节点中。
##[codeblock]
##data_file.bind_object($Button, "key_toggle_status")
##data_file.bind_object($LineEdit, "key_input_text", "这个对象的自定义默认值，也可以不传入保持缺省状态")
##[/codeblock]
##
##添加一个配置节点 [b]config.gd[/b] 脚本，添加到 [b]自动加载[/b] 中，即可快速创建程序的配置数据
##[codeblock]
##extends Node
##
##var data_file : DataFile = DataFile.instance(data_file_path)
##var exclude_config_propertys : Array[String] = ["exclude_config_propertys", "data_file"]
##
### Custom data
##var files: Array
##var current_path: String
##
##func _init():
##    # 加载 Config 数据
##    data_file.update_object_property(self, exclude_config_propertys)
##
##func _exit_tree() -> void:
##    # 保存 Config 数据
##    data_file.set_value_by_object(self, exclude_config_propertys)
##    data_file.save()
##[/codeblock]
##
##设置配置当前程序数据文件的方法：
##[codeblock]
#### 获取当前的配置文件
##static func get_config_file() -> DataFile:
##    var dir = OS.get_executable_path().get_base_dir()
##    var file_path = dir.path_join("config.data")
##    return DataFile.instance(file_path)
##[/codeblock]
##
class_name DataFile
extends RefCounted


signal value_changed(key, previous_value, value)


enum {
	BYTES,   ## 原始数据
	STRING,  ## 字符串类型数据。但对部分数据类型转换后会出现转换错误问题
}

## 文件所在路径
var file_path : String
## 数据
var data : Dictionary
## 保存的文件的数据格式
var data_format : int = BYTES


## 实例化数据文件
##[br]
##[br]如果有这个文件，则会自动读取这个文件的数据，这个文件必须是 [Dictionary] 类型的数据
static func instance(file_path: String, data_format : int = BYTES, default_data: Dictionary = {}) -> DataFile:
	make_dir_if_not_exists(file_path.get_base_dir())
	
	const KEY = &"DataFile_singlton_dict"
	if not Engine.has_meta(KEY):
		Engine.set_meta(KEY, {})
	var data_file_dict : Dictionary = Engine.get_meta(KEY)
	if not data_file_dict.has(file_path): # 相同的文件路径返回的是单例对象
		var data_file = DataFile.new()
		data_file.file_path = file_path
		data_file.data_format = data_format
		if FileAccess.file_exists(file_path):
			match data_format:
				BYTES:
					data_file.data = read_as_bytes_to_var(file_path)
				STRING:
					data_file.data = read_as_str_var(file_path)
		data_file.data.merge(default_data, false)
		data_file_dict[file_path] = data_file
	return data_file_dict[file_path]


## 是否存在有这个 key 的数据
func has_value(key) -> bool:
	return data.has(key)

## 获取数据值
func get_value(key, default = null):
	if not data.has(key):
		data[key] = default
	return data[key]

## 设置数据
func set_value(key, value):
	if data.has(key):
		var previous = data[key]
		if typeof(previous) != typeof(value) or previous != value:
			data[key] = value
			# 更新绑定的对象的属性
			if _bind_node_data_dict.has(key):
				var item : Array = _bind_node_data_dict[key]
				var object : Object = item[0]
				if is_instance_valid(object):
					var property : String = item[1]
					var handle_callback : Callable = item[3]
					if (typeof(object.get(property)) != typeof(value) or object.get(property) != value):
						object.set(property, handle_callback.call(get_value(key), value) if handle_callback.is_valid() else value)
			# 更新绑定值的方法
			if _binded_method_dict.has(key):
				for callback: Callable in _binded_method_dict[key]:
					callback.call(value)
			value_changed.emit(key, null, value)
	else:
		data[key] = value
		value_changed.emit(key, null, value)

## 移除这个 key 的值
func remove_value(key) -> bool:
	return data.erase(key)

## 获取数据
func get_data() -> Dictionary:
	return data

## 获取数据的所有的 key
func get_keys() -> Array:
	return data.keys()

## 设置到对象这些属性
func update_object_property(object: Object, exclude_propertys: Array = []):
	for key in data:
		if (not exclude_propertys.has(key) 
			and key in object
		):
			object.set(key, data[key])

## 根据对象的脚本的属性设置值
func set_value_by_object(object: Object, exclude_propertys: Array = []):
	var script = object.get_script() as GDScript
	if script == null:
		return
	var p_name : String
	for p_data in script.get_script_property_list():
		p_name = p_data["name"]
		if not p_name in exclude_propertys and p_name in object:
			set_value(p_name, object[p_name])


var _bind_node_data_dict: Dictionary = {}

## 绑定这个节点，自动更新属性。他会自动绑定不同类型的 [Control] 节点的属性和信号。
func bind_object(object: Object, key, default_value = null, property : String = "", handle_callback : Callable = Callable()) -> void:
	if not object is Node and property.is_empty():
		const MESSAGE = "如果绑定的对象不是 Node 类型，则需要传入要同步绑定修改的 property 参数"
		push_error(MESSAGE)
		printerr(MESSAGE)
	
	if not has_value(key):
		if typeof(default_value) == TYPE_NIL:
			default_value = object.get(property)
		set_value(key, default_value)
	
	if property:
		_set_object_value(object, property, key, default_value)
		_bind_node_data_dict[key] = [object, property, key, handle_callback]
		if object is Window:
			object.close_requested.connect(
				func(): set_value(key, object.get(property))
			)
	
	# 自动绑定节点的信号
	if object is Control and not property:
		var value_changed_callback : Callable = func(v):
			set_value(key, handle_callback.call(get_value(key), v) if handle_callback.is_valid() else v)
		# 绑定信号
		if object is BaseButton:
			_set_object_value(object, "button_pressed", key, default_value)
			object.toggled.connect(value_changed_callback)
		elif object is Range:
			_set_object_value(object, "value", key, default_value)
			object.value_changed.connect(value_changed_callback)
		elif object is LineEdit:
			_set_object_value(object, "text", key, default_value)
			object.text_changed.connect(value_changed_callback)
			object.text_submitted.connect(value_changed_callback)
		elif object is TextEdit:
			_set_object_value(object, "text", key, default_value)
			object.text_changed.connect(
				func(): set_value(key, object.text)
			)
		elif object is SplitContainer:
			_set_object_value(object, "split_offsets", key, default_value)
			object.dragged.connect(value_changed_callback)

var _binded_method_dict: Dictionary = {}
## 绑定值对象，属性改变时触发这个方法回调，这个回调方法需要有一个参数接收改变的 value 值
func bind_method(key, callback: Callable, first_call: bool = false) -> void:
	var callbacks : Array = _binded_method_dict.get_or_add(key, [])
	callbacks.append(callback)
	if first_call and has_value(key):
		callback.call(get_value(key))


func _set_object_value(object: Object, property: String, key, default = null):
	if has_value(key) or default:
		object.set(property, get_value(key, default))

## 更新所有有关于绑定的节点的数据内容，从绑定的节点上获取数据，记录到当前数据缓存中。在退出程序前最好调用一次
func update_data_by_bind_nodes() -> void:
	for item in _bind_node_data_dict.values():
		var object : Object = item[0]
		var property : String = item[1]
		var key = item[2]
		var handle_callback : Callable = item[3]
		var v : Variant = object.get(property)
		set_value(key, handle_callback.call(get_value(key), v) if handle_callback.is_valid() else v)

## 保存数据
func save() -> bool:
	make_dir_if_not_exists(file_path.get_base_dir())
	match data_format:
		BYTES:
			return write_as_bytes(file_path, data)
		STRING:
			return write_as_str_var(file_path, data)
	return false



#============================================================
#  文件操作
#============================================================
## 如果目录不存在，则进行创建
##[br]
##[br][code]return[/code] 如果不存在则进行创建并返回 [code]true[/code]，否则返回 [code]false[/code]
static func make_dir_if_not_exists(dir_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir_path):
		if DirAccess.make_dir_recursive_absolute(dir_path) == OK:
			return true
	return false

## 读取字节数据
static func read_as_bytes(file_path: String) -> PackedByteArray:
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			return file.get_file_as_bytes(file_path)
	return PackedByteArray()

## 读取字节数据，并转为原来的数据
static func read_as_bytes_to_var(file_path: String):
	var bytes = read_as_bytes(file_path)
	if not bytes.is_empty():
		return bytes_to_var_with_objects(bytes)
	return null

## 读取字符串并转为变量数据
static func read_as_str_var(file_path: String):
	var text = FileAccess.get_file_as_string(file_path)
	return str_to_var(text)


## 写入为二进制文件
static func write_as_bytes(file_path: String, data) -> bool:
	var bytes = var_to_bytes_with_objects(data)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file.flush()
		return true
	return false

## 写入字符串变量数据
static func write_as_str_var(file_path: String, data) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var text = var_to_str(data)
		file.store_string(text)
		file.flush()
		return true
	return false
