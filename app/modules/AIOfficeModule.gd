extends "res://app/modules/BaseModule.gd"

const DEBUG_TICK_SECONDS := 2.5
const MAX_DEBUG_LINES := 120
const TOKEN_STORE_PATH := "user://proxy_tokens.json"
const GH_LOGIN_EXE_PATH := "res://gh/dist/codespaces_login.exe"
const GH_CLOSE_EXE_PATH := "res://gh/dist/codespaces_close.exe"
const GH_SESSION_LOG_PATHS := [
	"res://gh/dist/logs/codespaces_session.log",
	"res://gh/logs/codespaces_session.log",
]
var _proxy_enabled := false
var _tokens: Array[Dictionary] = []
var _selected_token_index := -1
var _editing_token_index := -1

var _proxy_switch: CheckButton
var _status_value: Label
var _token_count_label: Label
var _name_input: LineEdit
var _token_input: LineEdit
var _show_token_toggle: CheckBox
var _save_token_btn: Button
var _cancel_edit_btn: Button
var _token_list: VBoxContainer
var _debug_output: RichTextLabel
var _debug_timer: Timer
var _log_lines: Array[String] = []
var _external_log_path := ""
var _external_log_position := 0
var _process_pipes: Array[Dictionary] = []
var _debug_auto_follow := true
var _debug_scroll_syncing := false
var _debug_view_active := false
var _allow_external_log_fallback := false

func build_ui() -> void:
	_load_tokens()

	var proxy_box := _add_section()
	var proxy_row := HBoxContainer.new()
	proxy_row.add_theme_constant_override("separation", 12)
	proxy_box.add_child(proxy_row)

	var proxy_label := Label.new()
	proxy_label.text = "代理"
	proxy_row.add_child(proxy_label)

	_proxy_switch = CheckButton.new()
	_proxy_switch.toggled.connect(_on_proxy_toggled)
	proxy_row.add_child(_proxy_switch)

	_status_value = Label.new()
	_status_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	proxy_row.add_child(_status_value)

	var token_box := _add_section()
	var token_header := HBoxContainer.new()
	token_header.add_theme_constant_override("separation", 8)
	token_box.add_child(token_header)

	var token_title := Label.new()
	token_title.text = "Token"
	token_header.add_child(token_title)

	_token_count_label = Label.new()
	_token_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	token_header.add_child(_token_count_label)

	_show_token_toggle = CheckBox.new()
	_show_token_toggle.text = "显示"
	_show_token_toggle.toggled.connect(_on_show_token_toggled)
	token_header.add_child(_show_token_toggle)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "输入名称"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_token_input_style(_name_input)
	if _selected_token_index >= 0 and _selected_token_index < _tokens.size():
		_name_input.text = _get_token_name(_selected_token_index)
	token_box.add_child(_name_input)

	_token_input = LineEdit.new()
	_token_input.placeholder_text = "输入 token"
	_token_input.secret = true
	_token_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_token_input_style(_token_input)
	if _selected_token_index >= 0 and _selected_token_index < _tokens.size():
		_token_input.text = _get_token_value(_selected_token_index)
	token_box.add_child(_token_input)

	var token_action_row := HBoxContainer.new()
	token_action_row.add_theme_constant_override("separation", 8)
	token_box.add_child(token_action_row)

	_save_token_btn = Button.new()
	_save_token_btn.pressed.connect(_on_save_token)
	token_action_row.add_child(_save_token_btn)

	_cancel_edit_btn = Button.new()
	_cancel_edit_btn.text = "取消"
	_cancel_edit_btn.visible = false
	_cancel_edit_btn.pressed.connect(_on_cancel_token_edit)
	token_action_row.add_child(_cancel_edit_btn)

	var token_scroll := ScrollContainer.new()
	token_scroll.custom_minimum_size = Vector2(0, 150)
	token_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	token_box.add_child(token_scroll)

	_token_list = VBoxContainer.new()
	_token_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_list.add_theme_constant_override("separation", 6)
	token_scroll.add_child(_token_list)

	var debug_box := _add_section()
	var debug_header := HBoxContainer.new()
	debug_header.add_theme_constant_override("separation", 8)
	debug_box.add_child(debug_header)

	var debug_title := Label.new()
	debug_title.text = "Debug"
	debug_header.add_child(debug_title)

	var clear_log_btn := Button.new()
	clear_log_btn.text = "清空"
	clear_log_btn.pressed.connect(_on_clear_logs)
	debug_header.add_child(clear_log_btn)
	var local_log_toggle := CheckBox.new()
	local_log_toggle.text = "本地日志"
	local_log_toggle.button_pressed = _allow_external_log_fallback
	local_log_toggle.toggled.connect(_on_external_log_fallback_toggled)
	debug_header.add_child(local_log_toggle)

	var log_shell := PanelContainer.new()
	log_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_shell.custom_minimum_size = Vector2(0, 220)
	log_shell.add_theme_stylebox_override("panel", _make_log_panel_style())
	debug_box.add_child(log_shell)

	var log_margin := MarginContainer.new()
	log_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_margin.add_theme_constant_override("margin_left", 10)
	log_margin.add_theme_constant_override("margin_top", 10)
	log_margin.add_theme_constant_override("margin_right", 10)
	log_margin.add_theme_constant_override("margin_bottom", 10)
	log_shell.add_child(log_margin)

	_debug_output = RichTextLabel.new()
	_debug_output.fit_content = false
	_debug_output.scroll_following = false
	_debug_output.selection_enabled = true
	_debug_output.bbcode_enabled = false
	_debug_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_output.add_theme_color_override("default_color", Color(0.70, 1.00, 0.78, 1.0))
	log_margin.add_child(_debug_output)
	call_deferred("_setup_debug_scroll_tracking")

	_debug_timer = Timer.new()
	_debug_timer.wait_time = DEBUG_TICK_SECONDS
	_debug_timer.one_shot = false
	_debug_timer.timeout.connect(_on_debug_tick)
	add_child(_debug_timer)

	_refresh_proxy_ui()
	_refresh_token_ui()
	_rebuild_token_list()
	call_deferred("_focus_name_input")

func _on_proxy_toggled(pressed: bool) -> void:
	var previous_state := _proxy_enabled
	_proxy_enabled = pressed
	if _proxy_enabled:
		if _run_proxy_login():
			_append_sys_line("proxy.start token=%s" % _current_token_summary())
		else:
			_proxy_enabled = false
			if previous_state:
				_append_sys_line("proxy.start.cancelled")
	else:
		_run_proxy_close()
		_append_sys_line("proxy.stop token=%s" % _current_token_summary())
	_refresh_proxy_ui()
	_notify_tray_proxy_state_changed()

func set_proxy_enabled(enabled: bool) -> bool:
	_on_proxy_toggled(enabled)
	return _proxy_enabled

func is_proxy_enabled() -> bool:
	return _proxy_enabled

func shutdown_proxy_before_window_close(reason: String = "window_close") -> bool:
	if not _proxy_enabled:
		_append_sys_line("proxy.shutdown.skip reason=already_stopped source=%s" % reason)
		_refresh_proxy_ui()
		_notify_tray_proxy_state_changed()
		return false
	_proxy_enabled = false
	var closed := _run_proxy_close()
	_append_sys_line("proxy.shutdown reason=%s token=%s" % [reason, _current_token_summary()])
	_refresh_proxy_ui()
	_notify_tray_proxy_state_changed()
	return closed

func _notify_tray_proxy_state_changed() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_refresh_tray_menu"):
			node.call("_refresh_tray_menu")
			return
		node = node.get_parent()

func _on_debug_tick() -> void:
	if not _debug_view_active:
		return
	_sync_process_pipes()
	if _process_pipes.is_empty():
		_sync_external_log()

func _on_show_token_toggled(pressed: bool) -> void:
	if _token_input != null:
		_token_input.secret = not pressed

func _on_external_log_fallback_toggled(pressed: bool) -> void:
	_allow_external_log_fallback = pressed
	if not pressed:
		_external_log_path = ""
		_external_log_position = 0
	_append_sys_line("debug.local_log_fallback %s" % ("on" if pressed else "off"))

func _on_save_token() -> void:
	var token_name := _name_input.text.strip_edges()
	var token := _token_input.text.strip_edges()
	if token_name.is_empty() or token.is_empty():
		return

	var duplicate_name_index := _find_token_name_index(token_name)
	if duplicate_name_index != -1 and duplicate_name_index != _editing_token_index:
		_editing_token_index = duplicate_name_index

	var duplicate_index := _find_token_index(token)
	if duplicate_index != -1 and duplicate_index != _editing_token_index:
		_append_sys_line("token.exists slot=%d" % (duplicate_index + 1))
		return

	var keep_active := _editing_token_index >= 0 and _selected_token_index == _editing_token_index
	if _editing_token_index >= 0 and _editing_token_index < _tokens.size():
		_tokens[_editing_token_index] = _make_token_entry(token_name, token)
		_selected_token_index = _editing_token_index
		_append_sys_line("token.update slot=%d" % (_editing_token_index + 1))
	else:
		_tokens.append(_make_token_entry(token_name, token))
		_selected_token_index = _tokens.size() - 1
		_append_sys_line("token.save slot=%d" % _tokens.size())
	if keep_active or _selected_token_index >= 0:
		_append_sys_line("token.active %s" % _current_token_summary())

	_editing_token_index = -1
	_save_tokens()
	_name_input.clear()
	_token_input.clear()
	_refresh_token_ui()
	_rebuild_token_list()
	_focus_name_input()

func _on_cancel_token_edit() -> void:
	_editing_token_index = -1
	if _selected_token_index >= 0 and _selected_token_index < _tokens.size():
		_name_input.text = _get_token_name(_selected_token_index)
		_token_input.text = _get_token_value(_selected_token_index)
	else:
		_name_input.clear()
		_token_input.clear()
	_refresh_token_ui()
	_focus_name_input()

func _on_use_token(index: int) -> void:
	if index < 0 or index >= _tokens.size():
		return
	_selected_token_index = index
	_editing_token_index = -1
	_save_tokens()
	_name_input.text = _get_token_name(index)
	_token_input.text = _get_token_value(index)
	_refresh_token_ui()
	_rebuild_token_list()
	_append_sys_line("token.use slot=%d" % (index + 1))
	_focus_name_input()

func _on_edit_token(index: int) -> void:
	if index < 0 or index >= _tokens.size():
		return
	_editing_token_index = index
	_name_input.text = _get_token_name(index)
	_token_input.text = _get_token_value(index)
	_refresh_token_ui()
	_rebuild_token_list()
	_append_sys_line("token.edit slot=%d" % (index + 1))
	call_deferred("_focus_name_input")

func _on_remove_token(index: int) -> void:
	if index < 0 or index >= _tokens.size():
		return

	_tokens.remove_at(index)

	if _selected_token_index == index:
		_selected_token_index = -1
		_name_input.clear()
		_token_input.clear()
	elif _selected_token_index > index:
		_selected_token_index -= 1

	if _editing_token_index == index:
		_editing_token_index = -1
		_name_input.clear()
		_token_input.clear()
	elif _editing_token_index > index:
		_editing_token_index -= 1

	_save_tokens()
	_refresh_token_ui()
	_rebuild_token_list()
	_append_sys_line("token.remove remaining=%d" % _tokens.size())

func _on_clear_logs() -> void:
	_reset_debug_output_to_latest()

func prepare_debug_view_for_open() -> void:
	_debug_view_active = true
	_reset_debug_output_to_latest()
	if _debug_timer != null and _debug_timer.is_stopped():
		_debug_timer.start()

func _reset_debug_output_to_latest() -> void:
	_log_lines.clear()
	_debug_auto_follow = true
	if _debug_output != null:
		_debug_output.clear()
		_debug_output.text = ""
		call_deferred("_scroll_debug_output_to_top")
	_attach_external_log(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_debug_view_active = false
		if _debug_timer != null:
			_debug_timer.stop()

func _refresh_proxy_ui() -> void:
	if _proxy_switch != null:
		_proxy_switch.button_pressed = _proxy_enabled
		_proxy_switch.text = "开启" if _proxy_enabled else "关闭"
	if _status_value == null:
		return
	if _proxy_enabled:
		_status_value.text = "运行中"
		_status_value.add_theme_color_override("font_color", Color(0.18, 0.48, 0.24, 1.0))
	else:
		_status_value.text = "已停止"
		_status_value.add_theme_color_override("font_color", TEXT_COLOR)

func _refresh_token_ui() -> void:
	if _token_count_label != null:
		_token_count_label.text = "%d" % _tokens.size()
	if _save_token_btn != null:
		_save_token_btn.text = "更新" if _editing_token_index >= 0 else "保存"
	if _cancel_edit_btn != null:
		_cancel_edit_btn.visible = _editing_token_index >= 0

func _rebuild_token_list() -> void:
	if _token_list == null:
		return

	for child in _token_list.get_children():
		child.queue_free()

	if _tokens.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_token_list.add_child(empty_label)
		return

	for i in range(_tokens.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var token_label := Label.new()
		token_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		token_label.text = _format_token_label(i)
		if i == _selected_token_index:
			token_label.add_theme_color_override("font_color", Color(0.18, 0.48, 0.24, 1.0))
		else:
			token_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		row.add_child(token_label)

		var use_btn := Button.new()
		use_btn.text = "使用"
		_apply_list_button_style(use_btn)
		use_btn.pressed.connect(_on_use_token.bind(i))
		row.add_child(use_btn)

		var edit_btn := Button.new()
		edit_btn.text = "编辑"
		_apply_list_button_style(edit_btn)
		edit_btn.pressed.connect(_on_edit_token.bind(i))
		row.add_child(edit_btn)

		var remove_btn := Button.new()
		remove_btn.text = "删除"
		_apply_list_button_style(remove_btn)
		remove_btn.pressed.connect(_on_remove_token.bind(i))
		row.add_child(remove_btn)

		_token_list.add_child(row)

func _format_token_label(index: int) -> String:
	var prefix := "● " if index == _selected_token_index else ""
	return "%s%s  %s" % [prefix, _get_token_name(index), _mask_token(_get_token_value(index))]

func _mask_token(token: String) -> String:
	var text := token.strip_edges()
	if text.is_empty():
		return "empty"
	if text.length() <= 8:
		return "%s...%s" % [text.left(2), text.right(2)]
	return "%s...%s" % [text.left(4), text.right(4)]

func _find_token_index(token: String) -> int:
	for i in range(_tokens.size()):
		if _get_token_value(i) == token:
			return i
	return -1

func _find_token_name_index(token_name: String) -> int:
	for i in range(_tokens.size()):
		if _get_token_name(i) == token_name:
			return i
	return -1

func _current_token_summary() -> String:
	var token := _get_active_token()
	if token.is_empty():
		return "empty"
	var source_label := "unselected"
	if _selected_token_index >= 0 and _selected_token_index < _tokens.size():
		source_label = "slot=%d" % (_selected_token_index + 1)
	return "%s token=%s len=%d" % [source_label, _mask_token(token), token.length()]

func _get_active_token() -> String:
	if _selected_token_index >= 0 and _selected_token_index < _tokens.size():
		return _get_token_value(_selected_token_index)
	return ""

func _attach_external_log(reset_to_end: bool) -> void:
	if not _allow_external_log_fallback:
		_external_log_path = ""
		_external_log_position = 0
		return
	_external_log_path = ""
	_external_log_position = 0
	for candidate in GH_SESSION_LOG_PATHS:
		var global_path := ProjectSettings.globalize_path(candidate)
		if FileAccess.file_exists(global_path):
			_external_log_path = global_path
			break
	if _external_log_path.is_empty():
		return
	if reset_to_end:
		var f := FileAccess.open(_external_log_path, FileAccess.READ)
		if f != null:
			_external_log_position = f.get_length()

func _sync_external_log() -> void:
	if not _allow_external_log_fallback:
		return
	if not _process_pipes.is_empty():
		return
	if _external_log_path.is_empty():
		_attach_external_log(false)
		if _external_log_path.is_empty():
			return
	var f := FileAccess.open(_external_log_path, FileAccess.READ)
	if f == null:
		return
	var file_length := f.get_length()
	if _external_log_position > file_length:
		_external_log_position = 0
	if _external_log_position > 0:
		f.seek(_external_log_position)
	var chunk := f.get_as_text()
	_external_log_position = f.get_position()
	if chunk.is_empty():
		return
	for line in chunk.split("\n", false):
		var text := line.strip_edges()
		if text.is_empty():
			continue
		_append_external_sys_line(text)

func _run_proxy_login() -> bool:
	var token := _get_active_token()
	if token.is_empty():
		_append_sys_line("proxy.login.skip reason=no_token")
		return false
	_append_sys_line("proxy.login.prepare token=%s" % _current_token_summary())
	var exe_path := ProjectSettings.globalize_path(GH_LOGIN_EXE_PATH)
	if not FileAccess.file_exists(exe_path):
		_append_sys_line("proxy.login.skip reason=missing_exe path=%s" % GH_LOGIN_EXE_PATH)
		return false
	var args := PackedStringArray(["--token", token, "--no-keepalive"])
	var pid := _start_process_with_pipe(exe_path, args, "login")
	if pid <= 0:
		pid = OS.create_process(exe_path, args, false)
	if pid <= 0:
		_append_sys_line("proxy.login.fail code=%d" % pid)
		return false
	_append_sys_line("proxy.login.exec pid=%d token=%s" % [pid, _current_token_summary()])
	return true

func _run_proxy_close() -> bool:
	var token := _get_active_token()
	if token.is_empty():
		_append_sys_line("proxy.close.skip reason=no_token")
		return false
	var exe_path := ProjectSettings.globalize_path(GH_CLOSE_EXE_PATH)
	if not FileAccess.file_exists(exe_path):
		_append_sys_line("proxy.close.skip reason=missing_exe path=%s" % GH_CLOSE_EXE_PATH)
		return false
	_append_sys_line("proxy.close.prepare token=%s" % _current_token_summary())
	var args := PackedStringArray(["--token", token])
	var pid := OS.create_process(exe_path, args, false)
	if pid <= 0:
		_append_sys_line("proxy.close.fail code=%d" % pid)
		return false
	_append_sys_line("proxy.close.exec pid=%d token=%s" % [pid, _current_token_summary()])
	return true

func _start_process_with_pipe(exe_path: String, args: PackedStringArray, label: String) -> int:
	if not OS.has_method("execute_with_pipe"):
		return -1
	var pipe_result: Variant = OS.execute_with_pipe(exe_path, args, false)
	if not pipe_result is Dictionary:
		return -1
	var pipe_dict := pipe_result as Dictionary
	if pipe_dict.is_empty():
		return -1
	var pid := int(pipe_dict.get("pid", -1))
	var stdio: Variant = pipe_dict.get("stdio", null)
	var stderr: Variant = pipe_dict.get("stderr", null)
	if not stdio is FileAccess and not stderr is FileAccess:
		return -1
	_process_pipes.append({
		"label": label,
		"pid": pid,
		"stdout": stdio,
		"stderr": stderr,
		"stdout_pending": "",
		"stderr_pending": "",
	})
	return pid

func _sync_process_pipes() -> void:
	if _process_pipes.is_empty():
		return
	var stale_indexes: Array[int] = []
	for i in range(_process_pipes.size()):
		var pipe_info: Dictionary = _process_pipes[i]
		var had_output := false
		had_output = _read_pipe_stream(pipe_info, "stdout", false) or had_output
		had_output = _read_pipe_stream(pipe_info, "stderr", true) or had_output
		_process_pipes[i] = pipe_info
		if not had_output and _is_pipe_finished(pipe_info):
			stale_indexes.append(i)
	for i in range(stale_indexes.size() - 1, -1, -1):
		_process_pipes.remove_at(stale_indexes[i])

func _read_pipe_stream(pipe_info: Dictionary, key: String, is_error_stream: bool) -> bool:
	var stream: Variant = pipe_info.get(key, null)
	if not stream is FileAccess:
		return false
	var file := stream as FileAccess
	if not file.is_open():
		return false
	var chunk := file.get_as_text()
	var err := file.get_error()
	if chunk.is_empty():
		return err == OK
	var pending_key := "%s_pending" % key
	var pending := str(pipe_info.get(pending_key, "")) + chunk
	var normalized := pending.replace("\r\n", "\n").replace("\r", "\n")
	var parts := normalized.split("\n", false)
	if not normalized.ends_with("\n") and not normalized.ends_with("\r"):
		if not parts.is_empty():
			pipe_info[pending_key] = parts[parts.size() - 1]
			parts.resize(parts.size() - 1)
		else:
			pipe_info[pending_key] = normalized
	else:
		pipe_info[pending_key] = ""
	for line in parts:
		var text := str(line).strip_edges()
		if text.is_empty():
			continue
		_append_pipe_line(text, is_error_stream)
	return true

func _is_pipe_finished(pipe_info: Dictionary) -> bool:
	var stdout_done := _stream_is_finished(pipe_info.get("stdout", null))
	var stderr_done := _stream_is_finished(pipe_info.get("stderr", null))
	return stdout_done and stderr_done

func _stream_is_finished(stream: Variant) -> bool:
	if not stream is FileAccess:
		return true
	var file := stream as FileAccess
	if not file.is_open():
		return true
	var err := file.get_error()
	return err != OK

func _load_tokens() -> void:
	_tokens.clear()
	_selected_token_index = -1
	if not FileAccess.file_exists(TOKEN_STORE_PATH):
		return
	var f := FileAccess.open(TOKEN_STORE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var need_resave := false
	var token_items: Array = []
	var selected_token_value := ""
	if parsed is Dictionary:
		var selected_index := int(parsed.get("selected_token_index", -1))
		selected_token_value = str(parsed.get("selected_token_value", "")).strip_edges()
		var stored_tokens: Variant = parsed.get("tokens", [])
		if stored_tokens is Array:
			token_items = stored_tokens
		else:
			need_resave = true
		_selected_token_index = selected_index
	elif parsed is Array:
		token_items = parsed
		need_resave = true
	if token_items is Array:
		for item in token_items:
			if item is Dictionary:
				var token := str(item.get("token", "")).strip_edges()
				if token.is_empty():
					continue
				var token_name := str(item.get("name", "")).strip_edges()
				if token_name.is_empty():
					token_name = _default_token_name(_tokens.size())
					need_resave = true
				_tokens.append(_make_token_entry(token_name, token))
			else:
				var legacy_token := str(item).strip_edges()
				if legacy_token.is_empty():
					continue
				_tokens.append(_make_token_entry(_default_token_name(_tokens.size()), legacy_token))
				need_resave = true
	if _selected_token_index < 0 or _selected_token_index >= _tokens.size():
		_selected_token_index = -1
		if not _tokens.is_empty():
			need_resave = true
	if not selected_token_value.is_empty():
		var restored_index := _find_token_index(selected_token_value)
		if restored_index != -1:
			_selected_token_index = restored_index
		else:
			need_resave = true
	if need_resave:
		_save_tokens()

func _save_tokens() -> void:
	var f := FileAccess.open(TOKEN_STORE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var payload := {
		"tokens": _tokens,
		"selected_token_index": _selected_token_index,
		"selected_token_value": _get_active_token(),
	}
	f.store_string(JSON.stringify(payload))

func _make_token_entry(token_name: String, token: String) -> Dictionary:
	return {
		"name": token_name.strip_edges(),
		"token": token.strip_edges(),
	}

func _default_token_name(index: int) -> String:
	return "Token %d" % (index + 1)

func _get_token_name(index: int) -> String:
	if index < 0 or index >= _tokens.size():
		return ""
	return str(_tokens[index].get("name", ""))

func _get_token_value(index: int) -> String:
	if index < 0 or index >= _tokens.size():
		return ""
	return str(_tokens[index].get("token", ""))

func _append_sys_line(message: String) -> void:
	_log_lines.append("[%s] [sys] %s" % [_timestamp(), message])
	while _log_lines.size() > MAX_DEBUG_LINES:
		_log_lines.pop_front()
	_refresh_debug_output()

func _append_external_sys_line(message: String) -> void:
	_log_lines.append("[sys] %s" % message)
	while _log_lines.size() > MAX_DEBUG_LINES:
		_log_lines.pop_front()
	_refresh_debug_output()

func _append_pipe_line(message: String, is_error_stream: bool) -> void:
	var prefix := "[sys][stderr]" if is_error_stream else "[sys]"
	_log_lines.append("%s %s" % [prefix, message])
	while _log_lines.size() > MAX_DEBUG_LINES:
		_log_lines.pop_front()
	_refresh_debug_output()

func _refresh_debug_output() -> void:
	if _debug_output == null:
		return
	var scrollbar := _debug_output.get_v_scroll_bar()
	var previous_value := 0.0
	if scrollbar != null and not _debug_auto_follow:
		previous_value = scrollbar.value
	_debug_output.text = "\n".join(_log_lines)
	if _debug_auto_follow:
		call_deferred("_scroll_debug_output_to_bottom")
	elif scrollbar != null:
		call_deferred("_restore_debug_scroll_value", previous_value)

func _setup_debug_scroll_tracking() -> void:
	if _debug_output == null:
		return
	var scrollbar := _debug_output.get_v_scroll_bar()
	if scrollbar == null:
		return
	if not scrollbar.value_changed.is_connected(_on_debug_scroll_value_changed):
		scrollbar.value_changed.connect(_on_debug_scroll_value_changed)

func _on_debug_scroll_value_changed(_value: float) -> void:
	if _debug_scroll_syncing or _debug_output == null:
		return
	var scrollbar := _debug_output.get_v_scroll_bar()
	if scrollbar == null:
		return
	var bottom_threshold := maxf(4.0, scrollbar.page * 0.1)
	var distance_to_bottom := scrollbar.max_value - (scrollbar.value + scrollbar.page)
	_debug_auto_follow = distance_to_bottom <= bottom_threshold

func _scroll_debug_output_to_bottom() -> void:
	if _debug_output == null:
		return
	var scrollbar := _debug_output.get_v_scroll_bar()
	if scrollbar == null:
		return
	_debug_scroll_syncing = true
	scrollbar.value = scrollbar.max_value
	_debug_scroll_syncing = false

func _scroll_debug_output_to_top() -> void:
	if _debug_output == null:
		return
	var scrollbar := _debug_output.get_v_scroll_bar()
	if scrollbar == null:
		return
	_debug_scroll_syncing = true
	scrollbar.value = 0.0
	_debug_scroll_syncing = false

func _restore_debug_scroll_value(previous_value: float) -> void:
	if _debug_output == null:
		return
	var scrollbar := _debug_output.get_v_scroll_bar()
	if scrollbar == null:
		return
	_debug_scroll_syncing = true
	scrollbar.value = clampf(previous_value, 0.0, scrollbar.max_value)
	_debug_scroll_syncing = false

func _timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0)),
	]

func _add_section() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_section_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	return box

func _focus_name_input() -> void:
	if _name_input != null:
		_name_input.grab_focus()

func focus_default_input() -> void:
	_focus_name_input()

func _apply_token_input_style(edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
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
	read_only.bg_color = Color(0.97, 0.97, 0.97, 1.0)
	edit.add_theme_stylebox_override("read_only", read_only)

	edit.add_theme_constant_override("minimum_character_width", 1)
	edit.add_theme_constant_override("outline_size", 0)
	edit.add_theme_color_override("font_color", Color(0.20, 0.15, 0.12, 1.0))
	edit.add_theme_color_override("font_placeholder_color", Color(0.52, 0.43, 0.36, 0.90))

func _apply_list_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.98, 0.89, 0.76, 1.0)
	normal.border_color = Color(0.86, 0.61, 0.43, 0.70)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.93, 0.82, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.95, 0.80, 0.64, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate()
	disabled.bg_color = normal.bg_color
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.20, 0.15, 0.12, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.20, 0.15, 0.12, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.20, 0.15, 0.12, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.20, 0.15, 0.12, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.20, 0.15, 0.12, 1.0))

func _make_section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.87, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.86, 0.61, 0.43, 0.65)
	return style

func _make_log_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.10, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.55, 0.36, 0.90)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
