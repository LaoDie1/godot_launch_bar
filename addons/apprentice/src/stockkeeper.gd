class_name Stockkeeper
extends Node

signal newly_item(item: StockkeeperItem)
signal removed_item(item: StockkeeperItem)
signal item_changed(item: StockkeeperItem)

@export var item_script: GDScript

var _id_to_item : Dictionary[Variant, StockkeeperItem] = {}


func add(value) -> StockkeeperItem:
	assert(item_script != null, "必须要设置继承自 StockkeeperItem 的脚本")
	for item:StockkeeperItem in _id_to_item.values():
		if item._equals(value):
			item._merge(value)
			item_changed.emit(item)
			return item
	var item = item_script.new(value) as StockkeeperItem
	var id = item._get_id()
	_id_to_item[id] = item
	newly_item.emit(item)
	return item

func remove(value) -> StockkeeperItem:
	for item:StockkeeperItem in _id_to_item.values():
		if item._equals(value):
			var id = item._get_id()
			_id_to_item.erase(id)
			removed_item.emit(item)
			return item
	return null

func find_item(value) -> StockkeeperItem:
	for item:StockkeeperItem in _id_to_item.values():
		if item._equals(value):
			return item
	return null

func get_item(id) -> StockkeeperItem:
	return _id_to_item.get(id)

func get_items() -> Array[StockkeeperItem]:
	return Array(_id_to_item.values(), TYPE_OBJECT, "RefCounted", StockkeeperItem)

func get_values() -> Array:
	var list := []
	for item:StockkeeperItem in _id_to_item.values():
		list.append(item._get_value())
	return list
