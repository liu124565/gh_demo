extends "res://app/modules/BaseModule.gd"

func build_ui() -> void:
	add_child(make_title("\u4e0d\u6b62\u732b\u732b"))
	add_child(make_desc("\u5267\u60c5\u5411\u6e38\u620f\u5165\u53e3\uff0c\u7528\u4e8e\u7ba1\u7406\u7ae0\u8282\u3001\u7ebf\u7d22\u548c\u7ed3\u5c40\u5206\u652f\u3002"))

	var chapter_card := make_card("\u5267\u60c5\u7ae0\u8282", "\u53ef\u540e\u7eed\u7ed1\u5b9a\u5230\u72ec\u7acb\u573a\u666f\uff08Chapter_01.tscn \u7b49\uff09\u3002")
	add_child(chapter_card)
	var box := chapter_card.get_child(0) as VBoxContainer

	var chapter_list := ItemList.new()
	chapter_list.custom_minimum_size = Vector2(0, 260)
	chapter_list.add_item("\u5e8f\u7ae0\uff1a\u5de8\u5927\u663e\u793a\u5668\u4e0e\u5c0f\u732b")
	chapter_list.add_item("\u7b2c\u4e00\u7ae0\uff1a\u4f1a\u8bae\u5ba4\u91cc\u7684\u79d8\u5bc6")
	chapter_list.add_item("\u7b2c\u4e8c\u7ae0\uff1a\u591c\u73ed\u529e\u516c\u5ba4")
	chapter_list.add_item("\u7ec8\u7ae0\uff1a\u4e0d\u6b62\u732b\u732b")
	box.add_child(chapter_list)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	var run_btn := Button.new()
	run_btn.text = "\u8fdb\u5165\u9009\u4e2d\u7ae0\u8282"
	run_btn.pressed.connect(_enter_chapter.bind(chapter_list))
	row.add_child(run_btn)

	var save_btn := Button.new()
	save_btn.text = "\u5b58\u6863\u7b56\u7565"
	save_btn.pressed.connect(_open_save_plan)
	row.add_child(save_btn)

func _enter_chapter(list: ItemList) -> void:
	if list.get_selected_items().is_empty():
		print("[not-cat] no chapter selected")
		return
	var idx := list.get_selected_items()[0]
	print("[not-cat] TODO enter chapter index=", idx)

func _open_save_plan() -> void:
	print("[not-cat] TODO implement save slots and branch state")
