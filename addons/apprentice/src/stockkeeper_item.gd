@abstract
class_name StockkeeperItem
extends RefCounted

var _value: Variant


func _init(value):
	self._value = value

func _get_value() -> Variant:
	return _value

@abstract
func _get_id() -> Variant

@abstract
func _equals(value) -> bool

@abstract
func _merge(value) -> void
