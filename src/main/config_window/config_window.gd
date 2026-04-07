#============================================================
#    Config Window
#============================================================
# - author: zhangxuetu
# - datetime: 2026-04-02 15:59:39
# - version: 4.7.0.dev2
#============================================================
extends Window

@onready var type_tree: Tree = %TypeTree
@onready var value_tree_container: Container = %ValueTreeContainer
@onready var stylebox_color_picker: ColorPicker = %StyleBoxColorPicker
@onready var select_color_window: Window = %SelectColorWindow
@onready var model_type_selector: ItemList = $ModelTypeSelector


func _init() -> void:
	close_requested.connect(hide)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			hide()


## 调用 TreeItem.set_metadata 时的键名
enum ValueMetaKey {
	PROPERTY_KEY, ##属性所属key
	VALUE_TYPE, ##属性值的类型
}

var type_key_to_value_tree_dict: Dictionary = {}
var key_to_value_item_dict : Dictionary = {}
var current_edit_value_item: TreeItem
func get_value_tree(type_key: String) -> Tree:
	type_key = type_key.strip_edges()
	if not type_key_to_value_tree_dict.has(type_key):
		var value_tree := Tree.new()
		type_key_to_value_tree_dict[type_key] = value_tree
		value_tree.columns = 2
		value_tree.column_titles_visible = true
		value_tree.select_mode =Tree.SELECT_ROW 
		value_tree.set_column_clip_content(0, false)
		value_tree.set_column_expand(1, true)
		#value_tree.set_column_custom_minimum_width(0, 200)
		value_tree.set_column_title(0, "键名")
		value_tree.set_column_title(1, "属性值")
		value_tree.name = type_key.validate_node_name()
		value_tree_container.add_child(value_tree, true)
		value_tree.hide_root = true
		value_tree.create_item()
		value_tree.visible = false
		value_tree.clip_contents = false
		value_tree.item_mouse_selected.connect(
			func(_mouse_pos, _mouse_button_index):
				var value_item : TreeItem = value_tree.get_selected()
				if value_item:
					var key : String = value_item.get_metadata(ValueMetaKey.PROPERTY_KEY)
					if key.ends_with("/model"):
						# INFO 弹出大模型列表选项
						current_edit_value_item = value_item
						model_type_selector.top_level = true
						model_type_selector.show()
						model_type_selector.grab_focus.call_deferred()
						#model_type_selector.global_position = model_type_selector.get_global_mouse_position()
						var item_rect = value_tree.get_item_area_rect(value_item, 1)
						model_type_selector.global_position = value_tree.global_position + item_rect.position + Vector2(0, 24)
						value_item.set_editable(1, false)
		)
		value_tree.item_edited.connect(
			func():
				current_edit_value_item = null
				var value_item : TreeItem = value_tree.get_edited()
				if value_item:
					var key : String = value_item.get_metadata(ValueMetaKey.PROPERTY_KEY)
					match value_item.get_metadata(ValueMetaKey.VALUE_TYPE):
						TYPE_STRING:
							Global.config.set_value(key, value_item.get_text(1))
						TYPE_INT:
							Global.config.set_value(key, int(value_item.get_range(1)))
						TYPE_FLOAT:
							Global.config.set_value(key, value_item.get_range(1))
						TYPE_BOOL:
							Global.config.set_value(key, value_item.is_checked(1))
						TYPE_COLOR:
							pass
						_:
							Log.warn(ScriptUtil.get_info(self), "错误的数据类型", key, value_item.get_cell_mode(1))
		)
		value_tree.custom_item_clicked.connect(
			func(mouse_button_index: int):
				var item : TreeItem = value_tree.get_selected()
				if mouse_button_index == MOUSE_BUTTON_LEFT:
					# INFO 修改选中的颜色
					if item.get_metadata(ValueMetaKey.VALUE_TYPE) == TYPE_COLOR:
						var key : String = item.get_metadata(ValueMetaKey.PROPERTY_KEY)
						stylebox_color_picker.color = Global.config.get_value(key, Color.WHITE)
						stylebox_color_picker.set_meta("item", item)
						stylebox_color_picker.set_meta("style_box", item.get_meta("custom_data"))
						var callback : Callable = func(color, target_item):
							if target_item == item:
								var style_box : StyleBoxFlat = stylebox_color_picker.get_meta("style_box")
								style_box.bg_color = color
								Global.config.set_value(key, color)
						stylebox_color_picker.color_changed.connect(callback.bind(item))
						select_color_window.popup(Rect2(DisplayServer.mouse_get_position(), Vector2()))
		)
	return type_key_to_value_tree_dict[type_key]


var _cache_type_keys: Array = []
func create_value_item(key: String) -> TreeItem:
	key = key.trim_prefix("/").trim_suffix("/")
	if key_to_value_item_dict.has(key):
		return key_to_value_item_dict[key]
	var items : PackedStringArray = key.rsplit("/")
	if str(items[0]).strip_edges() == "":
		items.remove_at(0)
	if items.size() == 1:
		items.insert(0, "misc")
	var type_key : String = str(items[0]).to_lower()
	if not _cache_type_keys.has(type_key):
		_cache_type_keys.append(type_key)
		var type_root : TreeItem = type_tree.get_root()
		var type_item : TreeItem = type_root.create_child()
		type_item.set_text(0, type_key.get_file().capitalize())
		type_item.set_metadata(0, type_key)
		type_item.set_tooltip_text(0, type_key)
		if type_key == "misc":
			type_item.visible = false
	
	var value_tree : Tree = get_value_tree(type_key)
	var value_root : TreeItem = value_tree.get_root()
	var value_item : TreeItem = value_root.create_child()
	
	var value_key : String = items[1]
	value_item.set_text(0, value_key.capitalize())
	value_item.set_tooltip_text(0, key)
	value_item.set_metadata(ValueMetaKey.PROPERTY_KEY, key) # 记录这个数据的完整路径 key
	
	var value : Variant = Global.config.get_value(key)
	_set_item_value(value_item, value)
	key_to_value_item_dict[key] = value_item
	return value_item

func _ready() -> void:
	Global.config.bind_object(self, "config_window_size", null, "size", Callable(), func(_v): return mode == Window.MODE_WINDOWED)
	
	await visibility_changed
	
	# 配置展示
	type_tree.hide_root = true
	type_tree.create_item()
	for key: String in Global.config.get_data():
		create_value_item(key)
	
	# 大模型
	Global.models_table.bind_method(
		func(models_table: Array):
			model_type_selector.clear()
			for model in models_table:
				for model_data: Dictionary in model["models"]:
					# 加载模型信息到选项列表
					model_type_selector.add_item("%s: %s" % [model.get("name", ""), model_data["model"]])
					model_type_selector.set_item_metadata(model_type_selector.item_count - 1, model_data)
	, true)
	model_type_selector.item_selected.connect(
		func(index):
			if current_edit_value_item:
				var data = model_type_selector.get_item_metadata(index)
				model_type_selector.hide()
				# 更新模型
				var key : String = current_edit_value_item.get_metadata(ValueMetaKey.PROPERTY_KEY)
				Global.config.set_value(key, data["model"])
				current_edit_value_item.set_text(1, data["model"])
				# 更新对应 base url 地址
				var base_url_key = key.get_base_dir().path_join("base_url")
				var base_url_item = key_to_value_item_dict.get(base_url_key)
				if base_url_item:
					base_url_item.set_text(1, data["base_url"])
					Global.config.set_value(base_url_key, data["base_url"])
	)
	model_type_selector.focus_exited.connect(model_type_selector.hide)
	
	# 同步更新数据。如果有值发生改变，则更新 item 数据
	Global.config.value_changed.connect(
		func(key, _previous_value, value):
			if key_to_value_item_dict.has(key):
				var value_item : TreeItem = key_to_value_item_dict[key]
				if is_instance_valid(value_item):
					# 更新这个 TreeItem 的值
					_set_item_value(value_item, value)
			elif typeof(_previous_value) == TYPE_NIL:
				create_value_item(key)
	)
	
	# 默认选中第一个
	for child in type_tree.get_root().get_children():
		if child.visible:
			child.select(0)
			get_tree().create_timer(1).timeout.connect(child.select.bind(0))
			break


# 根据数据类型设置显示的状态
func _set_item_value(item: TreeItem, value: Variant) -> void:
	item.visible = true
	item.set_metadata(ValueMetaKey.VALUE_TYPE, typeof(value))
	var key : String = item.get_metadata(ValueMetaKey.PROPERTY_KEY)
	match typeof(value):
		TYPE_STRING:
			item.set_cell_mode(1, TreeItem.CELL_MODE_STRING)
			if str(value).length() > 30:
				item.custom_minimum_height = 45
				item.set_edit_multiline(1, true)
				item.set_autowrap_mode(1, TextServer.AUTOWRAP_ARBITRARY)
			item.set_text(1, value)
			item.set_editable(1, true)
		TYPE_INT, TYPE_FLOAT:
			item.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
			item.set_range(1, value)
			if Global.config_item_hint.has_value(key):
				var hint_string : String = Global.config_item_hint.get_value(key)
				var hints : PackedStringArray = hint_string.split(",")
				if hints[0].is_valid_float() or hints[0].is_valid_int():
					item.set_range_config( 1, float(hints[0]), float(hints[1]), float(hints[2]) )
				else:
					item.set_text(1, hint_string)
			else:
				if value is int:
					item.set_range_config(1, 0, 999, 1)
				else:
					item.set_range_config(1, 0, 999, 0.001)
			item.set_editable(1, true)
		TYPE_BOOL:
			item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
			item.set_checked(1, value)
			item.set_editable(1, true)
		TYPE_COLOR:
			item.set_cell_mode(1, TreeItem.CELL_MODE_CUSTOM)
			item.set_editable(1, true)
			var style_box: StyleBoxFlat
			if item.has_meta("custom_data"):
				style_box = item.get_meta("custom_data")
			else:
				style_box = StyleBoxFlat.new()
				item.set_meta("custom_data",  style_box)
				item.set_custom_stylebox(1, style_box)
			style_box.bg_color = value
		
		_:
			item.visible = false
			item.set_editable(1, false)


# 展示不同的 Value 的 Tree
func _on_type_tree_item_selected() -> void:
	var type_item = type_tree.get_selected()
	var type_key = type_item.get_metadata(0)
	for tree in value_tree_container.get_children():
		tree.hide()
	var value_tree : Tree = type_key_to_value_tree_dict.get(type_key)
	if value_tree:
		value_tree.show()
