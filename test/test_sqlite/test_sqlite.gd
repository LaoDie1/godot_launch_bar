extends Node2D


func _ready() -> void:
	var sql_db = SQLite.new()
	sql_db.path = "user://test.db"
	sql_db.open_db()
	
	var tables = sql_db.select_rows("sqlite_master", "type='table' AND name='%s'" % ["test"], ["name"]).map(func(v): return v["name"])
	print(tables)
	
	#sql_db.create_table("test", {
		#"id": {"data_type": "int", "primary_key": true, "not_null": true, "auto_increment": true},
		#"name": {"data_type": "text"},
	#})
	#
	#var status = sql_db.insert_row("test", {
		#"name": "jack",
	#})
	#var id = sql_db.last_insert_rowid
	#print("ok = %s, id = %d" % [status, id])
	
	print("id = %d " % sql_db.last_insert_rowid)
