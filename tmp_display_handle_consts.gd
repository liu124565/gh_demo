extends SceneTree
func _init() -> void:
	for c in ClassDB.class_get_integer_constant_list("DisplayServer"):
		if c.find("HANDLE") != -1:
			print(c, "=", ClassDB.class_get_integer_constant("DisplayServer", c))
	quit()
