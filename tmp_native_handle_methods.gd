extends SceneTree
func _init() -> void:
	for m in DisplayServer.get_method_list():
		var n := String(m.name)
		if n.find("native_handle") != -1 or n.find("window_get_title") != -1:
			print(n)
	quit()
