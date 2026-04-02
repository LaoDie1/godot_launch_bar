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

## 调用 TreeItem.set_metadata 时的键名
enum ValueMetaKey {
	PROPERTY_KEY, ##属性所属key
	VALUE_TYPE, ##属性值的类型
}

func _init() -> void:
	close_requested.connect(hide)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			hide()


var type_key_to_value_tree_dict: Dictionary = {}
var key_to_value_item_dict : Dictionary = {}

func get_value_tree(type_key: String) -> Tree:
	type_key = type_key.strip_edges()
	if not type_key_to_value_tree_dict.has(type_key):
		var value_tree := Tree.new()
		type_key_to_value_tree_dict[type_key] = value_tree
		value_tree.columns = 2
		value_tree.column_titles_visible = true
		value_tree.select_mode =Tree.SELECT_ROW 
		value_tree.set_column_expand(0, false)
		value_tree.set_column_custom_minimum_width(0, 200)
		value_tree.set_column_title(0, "键名")
		value_tree.set_column_title(1, "属性值")
		value_tree.name = type_key.validate_node_name()
		value_tree_container.add_child(value_tree, true)
		value_tree.hide_root = true
		value_tree.create_item()
		value_tree.visible = false
		value_tree.clip_contents = false
		value_tree.item_edited.connect(
			func():
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
						_:
							Log.warn(ScriptUtil.get_info(self), "错误的数据类型", key, value_item.get_cell_mode(1))
		)
	return type_key_to_value_tree_dict[type_key]


func _ready() -> void:
	Global.config.bind_node(self, "config_window_size", null, "size")
	Global.config.bind_node(self, "config_window_pos", null, "position")
	
	await visibility_changed
	
	type_tree.hide_root = true
	var cache_type_keys: Array = []
	var data : Dictionary = Global.config.get_data()
	for key:String in data:
		var item = key.rsplit("/")
		if item.size() == 1:
			item.insert(0, "misc")
		var type_key : String = str(item[0]).to_lower()
		if not cache_type_keys.has(type_key):
			cache_type_keys.append(type_key)
		
		var value_tree : Tree = get_value_tree(type_key)
		var value_root : TreeItem = value_tree.get_root()
		var value_item : TreeItem = value_root.create_child()
		
		var value_key : String = item[1]
		value_item.set_text(0, value_key)
		value_item.set_tooltip_text(0, key)
		value_item.set_metadata(ValueMetaKey.PROPERTY_KEY, key) # 记录这个数据的完整路径 key
		var value : Variant = data[key]
		_set_item_value(value_item, value)
		key_to_value_item_dict[key] = value_item
	
	cache_type_keys.sort()
	var type_root : TreeItem = type_tree.create_item()
	for type_key in cache_type_keys:
		var type_item = type_root.create_child()
		type_item.set_text(0, type_key.get_file().capitalize())
		type_item.set_metadata(0, type_key)
		type_item.set_tooltip_text(0, type_key)
		if type_key == "misc":
			type_item.visible = false
	
	Global.config.value_changed.connect(
		func(key, _previous_value, value):
			if key_to_value_item_dict.has(key):
				var value_item : TreeItem = key_to_value_item_dict[key]
				if is_instance_valid(value_item):
					# 更新这个 TreeItem 的值
					_set_item_value(value_item, value)
	)


# 根据数据类型设置显示的状态
func _set_item_value(item: TreeItem, value: Variant) -> void:
	item.visible = true
	item.set_metadata(ValueMetaKey.VALUE_TYPE, typeof(value))
	match typeof(value):
		TYPE_STRING:
			item.set_text(1, str(value))
			item.set_editable(1, true)
		TYPE_INT, TYPE_FLOAT:
			item.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
			item.set_range(1, value)
			if value is int:
				item.set_range_config(1, 1, 999, 1)
			else:
				item.set_range_config(1, 1, 999, 0.001)
			item.set_editable(1, true)
		TYPE_BOOL:
			item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
			item.set_checked(0, value)
			item.set_editable(1, true)
		#TYPE_VECTOR2, TYPE_VECTOR2I:
			#item.set_text(1, str(value))
			#item.set_editable(1, false)
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
