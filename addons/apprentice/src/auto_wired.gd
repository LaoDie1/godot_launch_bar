#============================================================
#    Auto Wired
#============================================================
# - author: zhangxuetu
# - datetime: 2025-05-19 15:19:11
# - version: 4.2.1
#============================================================
## 继承这个节点。开启 Apprentice 插件，在项目启动后会自动注入属性到这个脚本里的静态变量里
class_name Autowired
extends Object


## 在自动注入时，对变量进行赋值的值。可重写更改赋值的内容
##[br]
##[br]- [param script]  注入的脚本对象
##[br]- [param path]  注入的类的路径。在这个脚本中的内部类的层级
##[br]- [param property_name]  要注入静态属性名
##[br]- [param return]  返回要注入的值
static func _get_value(script: Script, path: String, property_name: String) -> Variant:
	return StringName(property_name.to_lower())
