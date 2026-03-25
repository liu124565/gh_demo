extends "res://app/modules/BaseModule.gd"

const STORE_PATH := "user://launcher_apps.json"
const INPUT_WIDTH_RATIO := 0.8
const INPUT_MIN_WIDTH := 180.0
const LOGIN_EXE_PATH := "res://login/dist/login.exe"
const LOGIN_PY_PATH := "res://login/start_test.py"
const USE_PY_DEBUG := false
const LEGACY_DEFAULT_KEYS := {
	"\u90ae\u7bb1|mailto:": true,
	"\u8bb0\u4e8b\u672c|notepad.exe": true,
	"\u6d4f\u89c8\u5668|C:/Program Files/Google/Chrome/Application/chrome.exe": true,
}

var _apps: Array[Dictionary] = []

var _list_container: VBoxContainer
var _list_scroll: ScrollContainer
var _layout_root: VBoxContainer
var _name_edit: LineEdit
var _path_edit: LineEdit
var _account_edit: LineEdit
var _password_edit: LineEdit
var _show_password_toggle: CheckBox
var _save_btn: Button
var _cancel_btn: Button
var _editing_index := -1

func build_ui() -> void:
	_load_custom_apps()

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	_layout_root = VBoxContainer.new()
	_layout_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_layout_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_layout_root.add_theme_constant_override("separation", 8)
	center.add_child(_layout_root)

	var add_card := make_card("\u6dfb\u52a0\u542f\u52a8\u9879", "")
	add_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card_padding(add_card, 10.0)
	_layout_root.add_child(add_card)
	var add_box := add_card.get_child(0) as VBoxContainer

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "\u5e94\u7528\u540d\u79f0"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_input_style(_name_edit)
	add_box.add_child(_name_edit)

	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "\u5e94\u7528\u8def\u5f84"
	_path_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_path_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_input_style(_path_edit)
	add_box.add_child(_path_edit)

	_account_edit = LineEdit.new()
	_account_edit.placeholder_text = "\u8d26\u6237\u8f93\u5165\uff08\u53ef\u9009\uff09"
	_account_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_account_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_input_style(_account_edit)
	add_box.add_child(_account_edit)

	_password_edit = LineEdit.new()
	_password_edit.placeholder_text = "\u5bc6\u7801\u8f93\u5165\uff08\u53ef\u9009\uff09"
	_password_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_password_edit.secret = false
	_password_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_input_style(_password_edit)
	add_box.add_child(_password_edit)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	add_box.add_child(action_row)

	_show_password_toggle = CheckBox.new()
	_show_password_toggle.text = "\u663e\u793a\u5bc6\u7801"
	_show_password_toggle.button_pressed = true
	_show_password_toggle.toggled.connect(_on_password_toggle)
	action_row.add_child(_show_password_toggle)

	_save_btn = Button.new()
	_save_btn.text = "\u6dfb\u52a0"
	_save_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_save_btn.pressed.connect(_on_add_app)
	action_row.add_child(_save_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "\u53d6\u6d88"
	_cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel_edit)
	action_row.add_child(_cancel_btn)

	var launch_card := make_card("\u5df2\u914d\u7f6e\u542f\u52a8\u9879", "")
	launch_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card_padding(launch_card, 10.0)
	_layout_root.add_child(launch_card)
	_layout_root.move_child(launch_card, 0)
	var launch_box := launch_card.get_child(0) as VBoxContainer

	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.custom_minimum_size = Vector2(0, 120)
	launch_box.add_child(_list_scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(_list_container)
	_rebuild_list()

	resized.connect(_update_compact_layout)
	call_deferred("_update_compact_layout")
	call_deferred("_focus_name_input")

func _on_add_app() -> void:
	var app_name := _name_edit.text.strip_edges()
	var path := _path_edit.text.strip_edges()
	var account := _account_edit.text.strip_edges()
	var password := _password_edit.text.strip_edges()
	if app_name.is_empty() or path.is_empty():
		return
	var record: Dictionary = {
		"name": app_name,
		"path": path,
		"account": account,
		"password": password,
		"auto_start": false
	}
	if _editing_index >= 0 and _editing_index < _apps.size():
		_apps[_editing_index] = record
		_finish_edit()
	else:
		_apps.append(record)
	_save_custom_apps()
	_rebuild_list()
	_name_edit.clear()
	_path_edit.clear()
	_account_edit.clear()
	_password_edit.clear()
	_focus_name_input()

func _rebuild_list() -> void:
	for idx in range(0, _list_container.get_child_count()):
		_list_container.get_child(idx).queue_free()
	if _apps.is_empty():
		return

	for i in _apps.size():
		var item := _apps[i]
		var app_name := str(item.get("name", ""))
		var account := str(item.get("account", ""))
		var password := str(item.get("password", ""))
		var auto_start := bool(item.get("auto_start", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = app_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		row.add_child(label)

		var auto_start_toggle := CheckBox.new()
		auto_start_toggle.text = "\u81ea\u542f"
		auto_start_toggle.button_pressed = auto_start
		auto_start_toggle.toggled.connect(_on_auto_start_toggle.bind(i))
		row.add_child(auto_start_toggle)

		var launch_btn := Button.new()
		launch_btn.text = "\u542f\u52a8"
		launch_btn.custom_minimum_size = Vector2(20, 0)
		launch_btn.pressed.connect(_launch.bind(str(item.get("path", "")), account, password))
		row.add_child(launch_btn)

		var remove_btn := Button.new()
		remove_btn.text = "\u5220\u9664"
		remove_btn.custom_minimum_size = Vector2(20, 0)
		remove_btn.pressed.connect(_remove_item.bind(i))
		row.add_child(remove_btn)

		var edit_btn := Button.new()
		edit_btn.text = "\u4fee\u6539"
		edit_btn.custom_minimum_size = Vector2(20, 0)
		edit_btn.pressed.connect(_begin_edit.bind(i))
		row.add_child(edit_btn)

		_list_container.add_child(row)

func _update_compact_layout() -> void:
	if _layout_root == null:
		return
	var target_w := maxf(260.0, size.x * 0.67 - 36.0)
	var target_h := maxf(140.0, size.y * 0.5)
	var input_w := maxf(INPUT_MIN_WIDTH, target_w * INPUT_WIDTH_RATIO)
	_layout_root.custom_minimum_size = Vector2(target_w, target_h)
	if _name_edit != null:
		_name_edit.custom_minimum_size = Vector2(input_w, 0)
	if _path_edit != null:
		_path_edit.custom_minimum_size = Vector2(input_w, 0)
	if _account_edit != null:
		_account_edit.custom_minimum_size = Vector2(input_w, 0)
	if _password_edit != null:
		_password_edit.custom_minimum_size = Vector2(input_w, 0)
	if _list_scroll != null:
		_list_scroll.custom_minimum_size = Vector2(0, maxf(90.0, target_h * 0.44))

func _apply_input_style(edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.97, 0.93, 1.0)
	normal.border_color = Color(0.89, 0.67, 0.50, 0.92)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	edit.add_theme_stylebox_override("normal", normal)

	var focus := normal.duplicate()
	focus.border_color = Color(0.86, 0.46, 0.23, 1.0)
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	edit.add_theme_stylebox_override("focus", focus)

	var read_only := normal.duplicate()
	read_only.bg_color = Color(0.98, 0.94, 0.88, 1.0)
	edit.add_theme_stylebox_override("read_only", read_only)
	edit.add_theme_constant_override("minimum_character_width", 1)
	edit.add_theme_constant_override("outline_size", 0)
	edit.add_theme_color_override("font_color", Color(0.20, 0.15, 0.12, 1.0))
	edit.add_theme_color_override("font_placeholder_color", Color(0.52, 0.43, 0.36, 0.90))

func _apply_card_padding(card: PanelContainer, padding: float) -> void:
	var style := card.get_theme_stylebox("panel")
	if style == null:
		return
	var style_copy := style.duplicate()
	style_copy.content_margin_left = padding
	style_copy.content_margin_top = padding
	style_copy.content_margin_right = padding
	style_copy.content_margin_bottom = padding
	card.add_theme_stylebox_override("panel", style_copy)

func _remove_item(idx: int) -> void:
	if idx < 0 or idx >= _apps.size():
		return
	_apps.remove_at(idx)
	_save_custom_apps()
	_rebuild_list()

func _begin_edit(idx: int) -> void:
	if idx < 0 or idx >= _apps.size():
		return
	var item := _apps[idx]
	_editing_index = idx
	_name_edit.text = str(item.get("name", ""))
	_path_edit.text = str(item.get("path", ""))
	_account_edit.text = str(item.get("account", ""))
	_password_edit.text = str(item.get("password", ""))
	if _save_btn != null:
		_save_btn.text = "\u4fdd\u5b58"
	if _cancel_btn != null:
		_cancel_btn.visible = true
	_focus_name_input()

func _finish_edit() -> void:
	_editing_index = -1
	if _save_btn != null:
		_save_btn.text = "\u6dfb\u52a0"
	if _cancel_btn != null:
		_cancel_btn.visible = false

func _on_cancel_edit() -> void:
	_finish_edit()
	_name_edit.clear()
	_path_edit.clear()
	_account_edit.clear()
	_password_edit.clear()
	_focus_name_input()

func _on_password_toggle(pressed: bool) -> void:
	if _password_edit != null:
		_password_edit.secret = not pressed

func _on_auto_start_toggle(pressed: bool, idx: int) -> void:
	if idx < 0 or idx >= _apps.size():
		return
	_apps[idx]["auto_start"] = pressed
	_save_custom_apps()

func _focus_name_input() -> void:
	if _name_edit != null:
		_name_edit.grab_focus()

func focus_default_input() -> void:
	_focus_name_input()

func _load_custom_apps() -> void:
	if not FileAccess.file_exists(STORE_PATH):
		return
	var f := FileAccess.open(STORE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for item in parsed:
			if item is Dictionary and item.has("name") and item.has("path"):
				var key := "%s|%s" % [str(item["name"]), str(item["path"])]
				if LEGACY_DEFAULT_KEYS.has(key):
					continue
				_apps.append(item)

func _save_custom_apps() -> void:
	var f := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_apps))

func _launch(target: String, account: String = "", password: String = "") -> void:
	var launch_target := target.strip_edges()
	if launch_target.is_empty():
		return

	if launch_target.begins_with("\"") and launch_target.ends_with("\"") and launch_target.length() > 1:
		launch_target = launch_target.substr(1, launch_target.length() - 2)

	if launch_target.begins_with("http://") or launch_target.begins_with("https://") or launch_target.begins_with("mailto:"):
		OS.shell_open(launch_target)
		request_close_popup.emit()
		return

	var args: PackedStringArray
	if USE_PY_DEBUG:
		var py_path := ProjectSettings.globalize_path(LOGIN_PY_PATH)
		if FileAccess.file_exists(py_path):
			args = [py_path, launch_target, account, password]
			OS.create_process("python", args)
			request_close_popup.emit()
			return

	var login_exe := ProjectSettings.globalize_path(LOGIN_EXE_PATH)
	if not FileAccess.file_exists(login_exe):
		push_warning("Login exe not found: %s" % login_exe)
		OS.shell_open(launch_target)
		request_close_popup.emit()
		return

	args = [launch_target, account, password]
	OS.create_process(login_exe, args)
	request_close_popup.emit()
