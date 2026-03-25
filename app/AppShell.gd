extends Control

const MODULE_ORDER := [
	"app_launcher",
	"mini_games",
	"ai_office",
	"cat_diary",
]

const LAUNCHER_STORE_PATH := "user://launcher_apps.json"
const LAUNCHER_LOGIN_EXE_PATH := "res://login/dist/login.exe"
const LAUNCHER_LOGIN_PY_PATH := "res://login/start_test.py"
const LAUNCHER_USE_PY_DEBUG := false
const LAUNCHER_AUTO_START_DELAY := 1.0

var MODULE_META := {
	"app_launcher": {
		"title": "\u4e00\u952e\u5e94\u7528\u542f\u52a8",
		"script_path": "res://app/modules/AppLauncherModule.gd",
	},
	"mini_games": {
		"title": "\u5c0f\u6e38\u620f",
		"script_path": "res://app/modules/MiniGamesModule.gd",
	},
	"ai_office": {
		"title": "\u4ee3\u7406\u914d\u7f6e",
		"script_path": "res://app/modules/AIOfficeModule.gd",
	},
	"cat_diary": {
		"title": "\u732b\u732b\u65e5\u8bb0",
		"script_path": "res://app/modules/NotCatModule.gd",
		"disabled": true,
	},
}

const WARM_BG := Color(1.0, 0.95, 0.88, 0.98)
const WARM_PANEL := Color(0.98, 0.89, 0.76, 0.98)
const WARM_ACCENT := Color(0.85, 0.45, 0.20, 1.0)
const WARM_TEXT := Color(0.28, 0.18, 0.12, 1.0)
const CAT_SHELL_SIZE := Vector2(64, 64)
const CAT_INITIAL_RIGHT_MARGIN := 36.0
const CAT_INITIAL_TOP_RATIO := 0.28
const CAT_IDLE_FRAME_TEMPLATE := "res://image/\u5f85\u673a\u52a8\u4f5c/%d.png"
const CAT_IDLE_FALLBACK_TEMPLATE := "res://image/\u5f85\u673a/%d.png"
const CAT_IDLE_FRAME_COUNT := 4
const CAT_KEYFRAME_HOLD := 0.3
const CAT_KEYFRAME_BLEND := 0.1
const CAT_USE_CROSSFADE := false
const POPUP_DEFAULT_SIZE := Vector2(360, 340)
const POPUP_APP_LAUNCHER_SIZE := Vector2(360, 340)
const POPUP_MINI_GAMES_SIZE := Vector2(530, 400)
const POPUP_MINI_GAMES_MENU_SIZE := Vector2(265, 400)
const MENU_POPUP_OVERLAP := 18.0
const MOUSE_PASSTHROUGH_PADDING := 2.0
const USE_TRAY_ONLY_ON_WINDOWS := true
const START_HIDDEN_TO_TRAY_ON_WINDOWS := false
const SKIP_WINDOW_FLAGS_IN_EDITOR := false
const TRAY_MENU_ID_TOGGLE_WINDOW := 1001
const TRAY_MENU_ID_AUTOSTART := 1002
const TRAY_MENU_ID_QUIT := 1003
const TRAY_MENU_ID_PROXY_TOGGLE := 1004
const TRAY_MENU_ID_BOARD_OPACITY := 2001
const TRAY_MENU_ID_BLOCK_OPACITY := 2002
const TRAY_MENU_ID_UI_OPACITY := 2003
const TRAY_ICON_PATH := "res://image/待机动作/1.png"
const TRAY_ICON_FALLBACK := "res://icon.svg"
const AUTOSTART_BAT_NAME := "demo_test_autostart.bat"
const TASKBAR_GDEXT_PATH := "res://addons/taskbar_hide/taskbar_hide.gdextension"
const START_MINIMIZED_FOR_TASKBAR_HIDE := true
const START_MINIMIZED_RESTORE_DELAY := 0.6
const START_MINIMIZED_SKIP_IN_EDITOR := true
const WINAPI_RETRY_DELAY := 0.05
const WINAPI_RETRY_MAX_ATTEMPTS := 120
const TASKBAR_FORCE_APPLY_DELAY := 0.25
const TASKBAR_FORCE_APPLY_TICKS := 40
const TASKBAR_FORCE_WINAPI_INTERVAL := 2

var _module_instances: Dictionary = {}
var _game_popup_window: PanelContainer = null
var _game_window_bg_opacity := 0.99
var _board_opacity := 1.0
var _block_opacity := 1.0
var _ui_opacity := 1.0
var _cat_shell: Panel
var _cat_sprite_a: TextureRect
var _cat_sprite_b: TextureRect
var _cat_fallback_label: Label
var _menu_panel: PanelContainer
var _menu_nav: VBoxContainer
var _popup_window: PanelContainer
var _popup_title: Label
var _popup_content: VBoxContainer
var _menu_tween: Tween
var _popup_tween: Tween
var _tray_menu_rid := RID()
var _tray_indicator_id := -1
var _autostart_enabled := false
var _board_opacity_submenu_rid := RID()
var _block_opacity_submenu_rid := RID()
var _ui_opacity_submenu_rid := RID()

var _is_cat_hovered := false
var _is_menu_hovered := false
var _active_module_id := ""
var _menu_size_ready := false
var _menu_locked_size := Vector2.ZERO
var _cat_dragging := false
var _suppress_menu_until_leave := false
var _window_dragging := false
var _window_hidden_to_tray := false
var _cat_drag_offset := Vector2.ZERO
var _window_drag_offset := Vector2.ZERO
var _cat_base_position := Vector2.ZERO
var _cat_anim_time := 0.0
var _cat_frames: Array[Texture2D] = []
var _cat_frame_index := 0
var _cat_phase_time := 0.0
var _cat_phase_duration := CAT_KEYFRAME_HOLD + CAT_KEYFRAME_BLEND
var _winapi_retry_attempts := 0
var _winapi_retry_pending := false
var _taskbar_force_apply_left := 0
var _taskbar_force_apply_pending := false
var _taskbar_hide_ext: Object = null
var _taskbar_hide_ext_attempted := false
var _taskbar_hide_ext_failed := false
var _taskbar_hide_applied := false
var _startup_minimize_active := false
var _startup_restore_pending := false
var _cat_user_positioned := false

func _ready() -> void:
	var blend := CAT_KEYFRAME_BLEND if CAT_USE_CROSSFADE else 0.0
	_cat_phase_duration = maxf(CAT_KEYFRAME_HOLD + blend, 0.05)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_begin_startup_minimize()
	_setup_windows_shell()
	_build_cat_shell()
	_load_cat_idle_frames()
	_build_hover_menu()
	_build_popup_window()
	_setup_status_indicator()
	_apply_warm_theme(self)
	call_deferred("_initialize_menu_size")
	call_deferred("_refresh_initial_cat_position")
	set_process(true)
	if _startup_minimize_active:
		_cancel_taskbar_force_apply()
	else:
		_start_taskbar_force_apply()
	call_deferred("_log_window_shell_diagnostics")
	var main_window := get_window()
	if main_window != null and not main_window.close_requested.is_connected(_on_window_close_requested):
		main_window.close_requested.connect(_on_window_close_requested)
	if _should_start_hidden_to_tray():
		_hide_main_window()
	_schedule_auto_start_launcher_apps()

func _schedule_auto_start_launcher_apps() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(LAUNCHER_AUTO_START_DELAY)
	timer.timeout.connect(_auto_start_launcher_apps, CONNECT_ONE_SHOT)

func _auto_start_launcher_apps() -> void:
	if not FileAccess.file_exists(LAUNCHER_STORE_PATH):
		return
	var f := FileAccess.open(LAUNCHER_STORE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Array:
		return
	for item in parsed:
		if item is Dictionary and item.has("path"):
			var auto_start := bool(item.get("auto_start", false))
			if auto_start:
				var path := str(item.get("path", ""))
				var account := str(item.get("account", ""))
				var password := str(item.get("password", ""))
				_launch_app(path, account, password)

func _launch_app(target: String, account: String = "", password: String = "") -> void:
	var launch_target := target.strip_edges()
	if launch_target.is_empty():
		return
	if launch_target.begins_with("\"") and launch_target.ends_with("\"") and launch_target.length() > 1:
		launch_target = launch_target.substr(1, launch_target.length() - 2)
	if launch_target.begins_with("http://") or launch_target.begins_with("https://") or launch_target.begins_with("mailto:"):
		OS.shell_open(launch_target)
		return
	var args: PackedStringArray
	if LAUNCHER_USE_PY_DEBUG:
		var py_path := ProjectSettings.globalize_path(LAUNCHER_LOGIN_PY_PATH)
		if FileAccess.file_exists(py_path):
			args = [py_path, launch_target, account, password]
			OS.create_process("python", args)
			return
	var login_exe := ProjectSettings.globalize_path(LAUNCHER_LOGIN_EXE_PATH)
	if not FileAccess.file_exists(login_exe):
		OS.shell_open(launch_target)
		return
	args = [launch_target, account, password]
	OS.create_process(login_exe, args)

func _exit_tree() -> void:
	if _tray_indicator_id != -1 and DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		DisplayServer.delete_status_indicator(_tray_indicator_id)
		_tray_indicator_id = -1
	if _board_opacity_submenu_rid.is_valid():
		NativeMenu.free_menu(_board_opacity_submenu_rid)
		_board_opacity_submenu_rid = RID()
	if _block_opacity_submenu_rid.is_valid():
		NativeMenu.free_menu(_block_opacity_submenu_rid)
		_block_opacity_submenu_rid = RID()
	if _ui_opacity_submenu_rid.is_valid():
		NativeMenu.free_menu(_ui_opacity_submenu_rid)
		_ui_opacity_submenu_rid = RID()
	if _tray_menu_rid.is_valid():
		NativeMenu.free_menu(_tray_menu_rid)
		_tray_menu_rid = RID()

func _setup_windows_shell() -> void:
	if _should_skip_window_flags():
		return
	_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_fit_window_to_current_screen()
	if OS.get_name() != "Windows":
		return
	_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	_apply_tray_only_window_flags()
	if DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY):
		_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
		get_viewport().transparent_bg = true

func _begin_startup_minimize() -> void:
	if not _should_bootstrap_minimize():
		return
	if _startup_minimize_active:
		return
	_startup_minimize_active = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	_cancel_taskbar_force_apply()
	_schedule_startup_restore()

func _schedule_startup_restore() -> void:
	if _startup_restore_pending:
		return
	var tree := get_tree()
	if tree == null:
		return
	_startup_restore_pending = true
	var timer := tree.create_timer(START_MINIMIZED_RESTORE_DELAY)
	timer.timeout.connect(_finish_startup_minimize, CONNECT_ONE_SHOT)

func _finish_startup_minimize() -> void:
	_startup_restore_pending = false
	if not _startup_minimize_active:
		return
	_startup_minimize_active = false
	_show_main_window()
	_start_taskbar_force_apply()

func _fit_window_to_current_screen() -> void:
	if _should_skip_window_flags():
		return
	var screen := DisplayServer.window_get_current_screen()
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	DisplayServer.window_set_position(screen_pos)
	DisplayServer.window_set_size(screen_size)

func _apply_tray_only_window_flags() -> void:
	if not _should_apply_tray_only_flags():
		return
	_winapi_retry_attempts = 0
	_winapi_retry_pending = false
	# WM hint can be reset when window mode/state changes; apply twice.
	_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT, true)
	_apply_winapi_toolwindow_style()
	call_deferred("_apply_tray_only_window_flags_deferred")

func _start_taskbar_force_apply() -> void:
	if not _should_force_taskbar_hide():
		return
	_taskbar_hide_applied = false
	_taskbar_force_apply_left = TASKBAR_FORCE_APPLY_TICKS
	_taskbar_force_apply_pending = false
	_schedule_taskbar_force_apply()

func _schedule_taskbar_force_apply() -> void:
	if _taskbar_force_apply_pending:
		return
	if _taskbar_force_apply_left <= 0:
		return
	var tree := get_tree()
	if tree == null:
		return
	_taskbar_force_apply_pending = true
	var timer := tree.create_timer(TASKBAR_FORCE_APPLY_DELAY)
	timer.timeout.connect(_on_taskbar_force_apply_tick, CONNECT_ONE_SHOT)

func _on_taskbar_force_apply_tick() -> void:
	_taskbar_force_apply_pending = false
	if _taskbar_force_apply_left <= 0:
		return
	if not _should_force_taskbar_hide():
		_cancel_taskbar_force_apply()
		return
	_taskbar_force_apply_left -= 1
	_apply_taskbar_hide_flags_once()
	if _taskbar_force_apply_left > 0:
		_schedule_taskbar_force_apply()

func _apply_taskbar_hide_flags_once() -> void:
	if not _should_force_taskbar_hide():
		_cancel_taskbar_force_apply()
		return
	if _taskbar_hide_applied:
		_cancel_taskbar_force_apply()
		return
	_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT, true)

	var need_winapi := (_taskbar_force_apply_left % TASKBAR_FORCE_WINAPI_INTERVAL) == 0
	if not need_winapi:
		need_winapi = not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT)
	if need_winapi:
		_apply_winapi_toolwindow_style()
	if _taskbar_hide_applied:
		_cancel_taskbar_force_apply()

func _apply_tray_only_window_flags_deferred() -> void:
	if not _should_apply_tray_only_flags():
		return
	if _taskbar_hide_applied and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT):
		return
	_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT, true)
	_apply_winapi_toolwindow_style()

func _apply_winapi_toolwindow_style() -> bool:
	if not _should_apply_tray_only_flags():
		return false
	var hwnd := int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
	if hwnd == 0:
		_schedule_winapi_toolwindow_retry()
		return false
	_winapi_retry_attempts = 0
	_winapi_retry_pending = false
	var ext := _get_taskbar_hide_ext()
	if ext == null:
		return false
	var ok := bool(ext.call("apply_toolwindow", hwnd))
	if not ok:
		push_warning("TaskbarHide.apply_toolwindow failed.")
	else:
		_taskbar_hide_applied = true
		if _startup_minimize_active:
			call_deferred("_finish_startup_minimize")
	return ok

func _schedule_winapi_toolwindow_retry() -> void:
	if _winapi_retry_pending:
		return
	if _winapi_retry_attempts >= WINAPI_RETRY_MAX_ATTEMPTS:
		return
	var tree := get_tree()
	if tree == null:
		return
	_winapi_retry_pending = true
	_winapi_retry_attempts += 1
	var timer := tree.create_timer(WINAPI_RETRY_DELAY)
	timer.timeout.connect(func() -> void:
		_winapi_retry_pending = false
		_apply_winapi_toolwindow_style()
	, CONNECT_ONE_SHOT)

func _log_window_shell_diagnostics() -> void:
	if OS.get_name() != "Windows":
		return
	print(
		"[shell] editor=",
		OS.has_feature("editor"),
		" hwnd=",
		int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),
		" mode=",
		DisplayServer.window_get_mode(),
		" popup_wm_hint=",
		DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT),
		" borderless=",
		DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
		" transparent=",
		DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT)
	)

func _setup_status_indicator() -> void:
	if OS.get_name() != "Windows":
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		return

	var icon := load(TRAY_ICON_PATH) as Texture2D
	if icon == null:
		icon = load(TRAY_ICON_FALLBACK) as Texture2D
	if icon == null:
		return

	_tray_indicator_id = DisplayServer.create_status_indicator(icon, "悬浮助手", Callable(self, "_on_tray_icon_activated"))
	if _tray_indicator_id == -1:
		return

	_tray_menu_rid = NativeMenu.create_menu()
	if not _tray_menu_rid.is_valid():
		return

	NativeMenu.add_item(
		_tray_menu_rid,
		"",
		Callable(self, "_on_tray_menu_id_pressed"),
		Callable(),
		TRAY_MENU_ID_TOGGLE_WINDOW
	)
	NativeMenu.add_check_item(
		_tray_menu_rid,
		"",
		Callable(self, "_on_tray_menu_id_pressed"),
		Callable(),
		TRAY_MENU_ID_AUTOSTART
	)
	NativeMenu.add_check_item(
		_tray_menu_rid,
		"",
		Callable(self, "_on_tray_menu_id_pressed"),
		Callable(),
		TRAY_MENU_ID_PROXY_TOGGLE
	)
	NativeMenu.add_separator(_tray_menu_rid)
	_board_opacity_submenu_rid = _create_opacity_submenu(TRAY_MENU_ID_BOARD_OPACITY)
	NativeMenu.add_submenu_item(_tray_menu_rid, "棋盘透明度", _board_opacity_submenu_rid)
	_block_opacity_submenu_rid = _create_opacity_submenu(TRAY_MENU_ID_BLOCK_OPACITY)
	NativeMenu.add_submenu_item(_tray_menu_rid, "方块透明度", _block_opacity_submenu_rid)
	_ui_opacity_submenu_rid = _create_opacity_submenu(TRAY_MENU_ID_UI_OPACITY)
	NativeMenu.add_submenu_item(_tray_menu_rid, "界面透明度", _ui_opacity_submenu_rid)
	NativeMenu.add_separator(_tray_menu_rid)
	NativeMenu.add_item(
		_tray_menu_rid,
		"退出",
		Callable(self, "_on_tray_menu_id_pressed"),
		Callable(),
		TRAY_MENU_ID_QUIT
	)

	DisplayServer.status_indicator_set_menu(_tray_indicator_id, _tray_menu_rid)
	DisplayServer.status_indicator_set_tooltip(_tray_indicator_id, "悬浮助手")

	_autostart_enabled = _is_autostart_enabled()
	_refresh_tray_menu()
	_refresh_opacity_submenu_checks()

func _should_start_hidden_to_tray() -> bool:
	return START_HIDDEN_TO_TRAY_ON_WINDOWS and OS.get_name() == "Windows" and _tray_indicator_id != -1

func _on_tray_menu_id_pressed(id: Variant = null) -> void:
	var action_id := int(id)
	match action_id:
		TRAY_MENU_ID_TOGGLE_WINDOW:
			if _is_main_window_visible():
				_hide_main_window()
			else:
				_show_main_window()
		TRAY_MENU_ID_AUTOSTART:
			_set_autostart_enabled(not _autostart_enabled)
		TRAY_MENU_ID_PROXY_TOGGLE:
			_toggle_proxy_from_tray()
		TRAY_MENU_ID_QUIT:
			get_tree().quit()

func _on_tray_icon_activated(arg0: Variant = null, arg1: Variant = null) -> void:
	if typeof(arg1) == TYPE_BOOL and not bool(arg1):
		return
	if typeof(arg0) == TYPE_INT:
		var button := int(arg0)
		if button != MOUSE_BUTTON_LEFT and button != MOUSE_BUTTON_RIGHT:
			return
	if _is_main_window_visible():
		_hide_main_window()
	else:
		_show_main_window()

func _on_window_close_requested() -> void:
	if _tray_indicator_id != -1:
		_hide_main_window()
		return
	_shutdown_proxy_before_window_close("app_quit")
	get_tree().quit()

func _hide_main_window() -> void:
	_hide_menu_immediate()
	_close_popup()
	_shutdown_proxy_before_window_close("window_hide")
	_window_hidden_to_tray = true
	if _should_skip_window_flags():
		_refresh_tray_menu()
		return
	if OS.get_name() == "Windows" and _hide_native_window_to_tray():
		_cancel_taskbar_force_apply()
	else:
		_taskbar_hide_applied = false
		_apply_tray_only_window_flags()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		if OS.get_name() == "Windows":
			_apply_hidden_mouse_passthrough()
		_start_taskbar_force_apply()
		call_deferred("_reapply_hidden_tray_state")
	_refresh_tray_menu()

func _show_main_window() -> void:
	_window_hidden_to_tray = false
	_taskbar_hide_applied = false
	if _should_skip_window_flags():
		_refresh_tray_menu()
		return
	if OS.get_name() == "Windows" and _show_native_window_from_tray():
		_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		_apply_tray_only_window_flags()
		_start_taskbar_force_apply()
		_fit_window_to_current_screen()
		call_deferred("_refresh_initial_cat_position")
		_update_mouse_passthrough()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		_apply_tray_only_window_flags()
		_start_taskbar_force_apply()
		_fit_window_to_current_screen()
		call_deferred("_refresh_initial_cat_position")
		_update_mouse_passthrough()
	_refresh_tray_menu()

func _reapply_hidden_tray_state() -> void:
	if not _window_hidden_to_tray:
		return
	if _should_skip_window_flags():
		return
	_taskbar_hide_applied = false
	_apply_tray_only_window_flags()
	_start_taskbar_force_apply()
	if OS.get_name() == "Windows":
		_apply_hidden_mouse_passthrough()

func _hide_native_window_to_tray() -> bool:
	var ext := _get_taskbar_hide_ext()
	if ext == null:
		return false
	var hwnd := int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
	if hwnd == 0:
		return false
	_taskbar_hide_applied = false
	_set_window_flag_if_needed(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT, true)
	_apply_winapi_toolwindow_style()
	return bool(ext.call("hide_window", hwnd))

func _show_native_window_from_tray() -> bool:
	var ext := _get_taskbar_hide_ext()
	if ext == null:
		return false
	var hwnd := int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
	if hwnd == 0:
		return false
	var shown := bool(ext.call("show_window", hwnd))
	if shown and ext.has_method("force_activate_window"):
		ext.call("force_activate_window", hwnd)
	return shown

func _is_main_window_visible() -> bool:
	if _window_hidden_to_tray:
		return false
	return DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED

func _refresh_tray_menu() -> void:
	if not _tray_menu_rid.is_valid():
		return
	var toggle_text := "隐藏主窗口"
	if not _is_main_window_visible():
		toggle_text = "显示主窗口"
	_set_tray_menu_item_text(TRAY_MENU_ID_TOGGLE_WINDOW, toggle_text)
	var autostart_text := "开机自启动：关"
	if _autostart_enabled:
		autostart_text = "开机自启动：开"
	_set_tray_menu_item_text(TRAY_MENU_ID_AUTOSTART, autostart_text)
	_set_tray_menu_item_checked(TRAY_MENU_ID_AUTOSTART, _autostart_enabled)
	_set_tray_menu_item_text(TRAY_MENU_ID_PROXY_TOGGLE, "代理启动")
	_set_tray_menu_item_checked(TRAY_MENU_ID_PROXY_TOGGLE, _is_proxy_enabled())

func _set_tray_menu_item_text(id: int, text: String) -> void:
	if not _tray_menu_rid.is_valid():
		return
	var idx := NativeMenu.find_item_index_with_tag(_tray_menu_rid, id)
	if idx >= 0:
		NativeMenu.set_item_text(_tray_menu_rid, idx, text)

func _set_tray_menu_item_checked(id: int, checked: bool) -> void:
	if not _tray_menu_rid.is_valid():
		return
	var idx := NativeMenu.find_item_index_with_tag(_tray_menu_rid, id)
	if idx >= 0:
		NativeMenu.set_item_checked(_tray_menu_rid, idx, checked)

func _get_or_create_module_instance(module_id: String) -> Control:
	if _module_instances.has(module_id):
		return _module_instances[module_id]
	if not MODULE_META.has(module_id):
		return null
	var meta: Dictionary = MODULE_META[module_id]
	var script_path: String = meta["script_path"]
	var script_ref: GDScript = load(script_path) as GDScript
	if script_ref == null:
		return null
	var module := script_ref.new() as Control
	if module == null:
		return null
	module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_popup_content.add_child(module)
	module.visible = false
	_module_instances[module_id] = module
	return module

func _get_proxy_module() -> Control:
	return _get_or_create_module_instance("ai_office")

func _is_proxy_enabled() -> bool:
	var module := _get_proxy_module()
	if module != null and module.has_method("is_proxy_enabled"):
		return bool(module.call("is_proxy_enabled"))
	return false

func _toggle_proxy_from_tray() -> void:
	var module := _get_proxy_module()
	if module == null or not module.has_method("set_proxy_enabled"):
		_refresh_tray_menu()
		return
	module.call("set_proxy_enabled", not _is_proxy_enabled())
	_refresh_tray_menu()

func _shutdown_proxy_before_window_close(reason: String) -> void:
	var module := _get_proxy_module()
	if module == null:
		return
	if module.has_method("shutdown_proxy_before_window_close"):
		module.call("shutdown_proxy_before_window_close", reason)

func _create_opacity_submenu(base_id: int) -> RID:
	var submenu := NativeMenu.create_menu()
	if not submenu.is_valid():
		return submenu
	var presets := [0.0, 0.25, 0.5, 0.75, 1.0]
	var labels := ["0%", "25%", "50%", "75%", "100%"]
	for i in range(presets.size()):
		var item_id := base_id + i + 1
		NativeMenu.add_item(
			submenu,
			labels[i],
			Callable(self, "_on_opacity_menu_pressed"),
			Callable(),
			item_id
		)
	return submenu

func _on_opacity_menu_pressed(id: Variant = null) -> void:
	var item_id := int(id)
	var opacity_value := 0.0
	if item_id >= TRAY_MENU_ID_BOARD_OPACITY + 1 and item_id <= TRAY_MENU_ID_BOARD_OPACITY + 5:
		opacity_value = float(item_id - TRAY_MENU_ID_BOARD_OPACITY - 1) * 0.25
		_board_opacity = opacity_value
		_apply_board_opacity(opacity_value)
	elif item_id >= TRAY_MENU_ID_BLOCK_OPACITY + 1 and item_id <= TRAY_MENU_ID_BLOCK_OPACITY + 5:
		opacity_value = float(item_id - TRAY_MENU_ID_BLOCK_OPACITY - 1) * 0.25
		_block_opacity = opacity_value
		_apply_block_opacity(opacity_value)
	elif item_id >= TRAY_MENU_ID_UI_OPACITY + 1 and item_id <= TRAY_MENU_ID_UI_OPACITY + 5:
		opacity_value = float(item_id - TRAY_MENU_ID_UI_OPACITY - 1) * 0.25
		_ui_opacity = opacity_value
		_apply_ui_opacity_global(opacity_value)
	_refresh_opacity_submenu_checks()

func _apply_board_opacity(value: float) -> void:
	var module: Control = _module_instances.get("mini_games", null)
	if module != null and module.has_method("set_board_opacity"):
		module.set_board_opacity(value)

func _apply_block_opacity(value: float) -> void:
	var module: Control = _module_instances.get("mini_games", null)
	if module != null and module.has_method("set_block_opacity"):
		module.set_block_opacity(value)

func _apply_ui_opacity_global(value: float) -> void:
	_game_window_bg_opacity = value
	if _game_popup_window != null:
		_apply_warm_theme(_game_popup_window)
		_apply_ui_opacity(_game_popup_window, value)

func _refresh_opacity_submenu_checks() -> void:
	_refresh_submenu_check(_board_opacity_submenu_rid, TRAY_MENU_ID_BOARD_OPACITY, _board_opacity)
	_refresh_submenu_check(_block_opacity_submenu_rid, TRAY_MENU_ID_BLOCK_OPACITY, _block_opacity)
	_refresh_submenu_check(_ui_opacity_submenu_rid, TRAY_MENU_ID_UI_OPACITY, _ui_opacity)

func _refresh_submenu_check(submenu_rid: RID, base_id: int, current_value: float) -> void:
	if not submenu_rid.is_valid():
		return
	var presets := [0.0, 0.25, 0.5, 0.75, 1.0]
	for i in range(presets.size()):
		var idx := NativeMenu.find_item_index_with_tag(submenu_rid, base_id + i + 1)
		if idx >= 0:
			var is_checked := absf(presets[i] - current_value) < 0.01
			NativeMenu.set_item_checked(submenu_rid, idx, is_checked)

func _get_startup_dir() -> String:
	var appdata := OS.get_environment("APPDATA")
	if appdata.is_empty():
		return ""
	return appdata.path_join("Microsoft").path_join("Windows").path_join("Start Menu").path_join("Programs").path_join("Startup")

func _get_autostart_bat_path() -> String:
	var startup_dir := _get_startup_dir()
	if startup_dir.is_empty():
		return ""
	return startup_dir.path_join(AUTOSTART_BAT_NAME)

func _is_autostart_enabled() -> bool:
	var bat_path := _get_autostart_bat_path()
	return not bat_path.is_empty() and FileAccess.file_exists(bat_path)

func _set_autostart_enabled(enabled: bool) -> void:
	var bat_path := _get_autostart_bat_path()
	if bat_path.is_empty():
		_autostart_enabled = false
		_refresh_tray_menu()
		return

	if enabled:
		var startup_dir := bat_path.get_base_dir()
		var mk_err := DirAccess.make_dir_recursive_absolute(startup_dir)
		if mk_err != OK:
			_autostart_enabled = false
			_refresh_tray_menu()
			return
		var f := FileAccess.open(bat_path, FileAccess.WRITE)
		if f == null:
			_autostart_enabled = false
			_refresh_tray_menu()
			return
		f.store_string(_build_autostart_bat_script())
		_autostart_enabled = true
	else:
		if FileAccess.file_exists(bat_path):
			DirAccess.remove_absolute(bat_path)
		_autostart_enabled = false
	_refresh_tray_menu()

func _build_autostart_bat_script() -> String:
	var launch := _resolve_launch_target()
	var exe := str(launch.get("exe", ""))
	var args: PackedStringArray = launch.get("args", PackedStringArray())
	var cmd := "start \"\" %s" % _quote_cmd_arg(exe)
	for arg in args:
		cmd += " %s" % _quote_cmd_arg(arg)
	return "@echo off\n%s\n" % cmd

func _resolve_launch_target() -> Dictionary:
	var exe_path := OS.get_executable_path()
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		var exported_exe := ProjectSettings.globalize_path("res://demo_test.exe")
		if FileAccess.file_exists(exported_exe):
			exe_path = exported_exe
		else:
			args = PackedStringArray([
				"--path",
				ProjectSettings.globalize_path("res://"),
			])
	return {"exe": exe_path, "args": args}

func _quote_cmd_arg(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\"\"")

func _build_cat_shell() -> void:
	_cat_shell = Panel.new()
	_cat_shell.name = "CatShell"
	_cat_shell.size = CAT_SHELL_SIZE
	_cat_shell.position = _compute_initial_cat_position()
	_cat_shell.clip_contents = true
	_cat_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_cat_shell.mouse_entered.connect(_on_cat_entered)
	_cat_shell.mouse_exited.connect(_on_cat_exited)
	_cat_shell.gui_input.connect(_on_cat_input)
	add_child(_cat_shell)

	_cat_sprite_a = TextureRect.new()
	_cat_sprite_a.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cat_sprite_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cat_sprite_a.stretch_mode = TextureRect.STRETCH_SCALE
	_cat_shell.add_child(_cat_sprite_a)

	_cat_sprite_b = TextureRect.new()
	_cat_sprite_b.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cat_sprite_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cat_sprite_b.stretch_mode = TextureRect.STRETCH_SCALE
	_cat_sprite_b.modulate = Color(1, 1, 1, 0)
	_cat_shell.add_child(_cat_sprite_b)

	_cat_fallback_label = Label.new()
	_cat_fallback_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cat_fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cat_fallback_label.text = "(=^_^=)"
	_cat_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cat_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cat_fallback_label.visible = false
	var side := minf(CAT_SHELL_SIZE.x, CAT_SHELL_SIZE.y)
	var face_font := int(clampf(side * 0.20, 8.0, 24.0))
	_cat_fallback_label.add_theme_font_size_override("font_size", face_font)
	_cat_shell.add_child(_cat_fallback_label)

func _compute_initial_cat_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var x := maxf(0.0, viewport_size.x - CAT_SHELL_SIZE.x - CAT_INITIAL_RIGHT_MARGIN)
	var y := clampf(
		viewport_size.y * CAT_INITIAL_TOP_RATIO,
		8.0,
		maxf(0.0, viewport_size.y - CAT_SHELL_SIZE.y - 8.0)
	)
	return Vector2(x, y)

func _refresh_initial_cat_position() -> void:
	if _cat_shell == null:
		return
	if not _cat_user_positioned:
		_cat_shell.position = _compute_initial_cat_position()
		_cat_base_position = _cat_shell.position
	_reposition_menu()
	if _popup_window != null and _popup_window.visible:
		_popup_window.position = _compute_popup_position(_popup_window.size)
	if _game_popup_window != null and _game_popup_window.visible:
		_game_popup_window.position = _compute_popup_position(_game_popup_window.size)
	_update_mouse_passthrough()

func _load_cat_idle_frames() -> void:
	_cat_frames.clear()
	for i in range(1, CAT_IDLE_FRAME_COUNT + 1):
		var p := CAT_IDLE_FRAME_TEMPLATE % i
		# Prefer imported textures to preserve alpha fix/border settings.
		var tex := load(p) as Texture2D
		if tex == null:
			var fallback_import := CAT_IDLE_FALLBACK_TEMPLATE % i
			tex = load(fallback_import) as Texture2D
		if tex == null:
			tex = _load_png_runtime(p)
		if tex == null:
			var fallback := CAT_IDLE_FALLBACK_TEMPLATE % i
			tex = _load_png_runtime(fallback)
		if tex != null:
			_cat_frames.append(tex)

	if _cat_frames.is_empty():
		_cat_sprite_a.visible = false
		_cat_sprite_b.visible = false
		_cat_fallback_label.visible = true
		return

	_cat_fallback_label.visible = false
	_cat_sprite_a.visible = true
	_cat_sprite_b.visible = true
	_cat_frame_index = 0
	_cat_phase_time = 0.0
	_update_cat_frame_blend()

func _load_png_runtime(res_path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

func _update_cat_frame_blend() -> void:
	if _cat_frames.is_empty():
		return
	if _cat_frames.size() == 1:
		_cat_sprite_a.texture = _cat_frames[0]
		_cat_sprite_a.modulate = Color(1, 1, 1, 1)
		_cat_sprite_b.modulate = Color(1, 1, 1, 0)
		return

	var current_idx := _cat_frame_index % _cat_frames.size()
	var next_idx := (current_idx + 1) % _cat_frames.size()
	if not CAT_USE_CROSSFADE or CAT_KEYFRAME_BLEND <= 0.0:
		_cat_sprite_a.texture = _cat_frames[current_idx]
		_cat_sprite_a.modulate = Color(1, 1, 1, 1)
		_cat_sprite_b.modulate = Color(1, 1, 1, 0)
		return
	var smooth_t := 0.0
	if _cat_phase_time > CAT_KEYFRAME_HOLD:
		var blend_t := (_cat_phase_time - CAT_KEYFRAME_HOLD) / maxf(CAT_KEYFRAME_BLEND, 0.001)
		var t := clampf(blend_t, 0.0, 1.0)
		# SmootherStep, softer than SmoothStep.
		smooth_t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

	_cat_sprite_a.texture = _cat_frames[current_idx]
	_cat_sprite_b.texture = _cat_frames[next_idx]
	_cat_sprite_a.modulate = Color(1, 1, 1, 1.0 - smooth_t)
	_cat_sprite_b.modulate = Color(1, 1, 1, smooth_t)

func _build_hover_menu() -> void:
	_menu_panel = PanelContainer.new()
	_menu_panel.name = "HoverMenu"
	_menu_panel.visible = false
	_menu_panel.modulate = Color(1, 1, 1, 0)
	_menu_panel.scale = Vector2(0.96, 0.96)
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_panel.mouse_entered.connect(_on_menu_entered)
	_menu_panel.mouse_exited.connect(_on_menu_exited)
	add_child(_menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_menu_panel.add_child(margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	_menu_nav = VBoxContainer.new()
	_menu_nav.add_theme_constant_override("separation", 7)
	_menu_nav.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_menu_nav)

	for module_id in MODULE_ORDER:
		var meta: Dictionary = MODULE_META[module_id]
		var title_text: String = str(meta["title"])
		var btn := Button.new()
		btn.text = title_text
		btn.custom_minimum_size = Vector2(188, 34)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var is_disabled := bool(meta.get("disabled", false))
		if is_disabled:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			btn.pressed.connect(_on_menu_item_pressed.bind(module_id))
		_menu_nav.add_child(btn)

func _build_popup_window() -> void:
	_popup_window = PanelContainer.new()
	_popup_window.name = "PopupWindow"
	_popup_window.visible = false
	_popup_window.custom_minimum_size = POPUP_DEFAULT_SIZE
	_popup_window.size = POPUP_DEFAULT_SIZE
	_popup_window.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_popup_window)

	var frame_margin := MarginContainer.new()
	frame_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.add_theme_constant_override("margin_left", 8)
	frame_margin.add_theme_constant_override("margin_top", 8)
	frame_margin.add_theme_constant_override("margin_right", 8)
	frame_margin.add_theme_constant_override("margin_bottom", 8)
	_popup_window.add_child(frame_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 44)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_window_header_input)
	root.add_child(header)

	_popup_title = Label.new()
	_popup_title.text = "\u5c0f\u7a97\u53e3"
	_popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_popup_title)

	var close_btn := Button.new()
	close_btn.text = "\u5173\u95ed"
	var close_base_size := close_btn.get_combined_minimum_size()
	close_btn.custom_minimum_size = Vector2(
		ceil(close_base_size.x * 1.10),
		ceil(close_base_size.y * 0.80)
	)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close_popup)
	header.add_child(close_btn)

	var divider := ColorRect.new()
	divider.color = Color(0.86, 0.62, 0.44, 0.55)
	divider.custom_minimum_size = Vector2(0, 1)
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_popup_content = VBoxContainer.new()
	_popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_popup_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_popup_content)

func _on_menu_item_pressed(module_id: String) -> void:
	if _popup_window.visible and _active_module_id == module_id:
		_close_popup()
		return
	_open_module_window(module_id)

func _close_popup() -> void:
	if _popup_tween != null:
		_popup_tween.kill()
	_popup_window.visible = false
	_popup_window.modulate = Color(1, 1, 1, 1)
	if _game_popup_window != null:
		_game_popup_window.visible = false
	_active_module_id = ""
	_update_mouse_passthrough()

func _open_module_window(module_id: String) -> void:
	if not MODULE_META.has(module_id):
		return
	for child in _popup_content.get_children():
		child.visible = false

	var module: Control
	if _module_instances.has(module_id):
		module = _module_instances[module_id]
	else:
		var meta: Dictionary = MODULE_META[module_id]
		var script_path: String = meta["script_path"]
		var script_ref: GDScript = load(script_path) as GDScript
		module = script_ref.new() as Control
		module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		module.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_popup_content.add_child(module)
		_module_instances[module_id] = module

	module.visible = true
	_active_module_id = module_id
	if module.has_method("prepare_debug_view_for_open"):
		module.call("prepare_debug_view_for_open")
	var picked_meta: Dictionary = MODULE_META[module_id]
	_popup_title.text = str(picked_meta["title"])
	if module.has_signal("request_close_popup") and not module.is_connected("request_close_popup", _close_popup):
		module.connect("request_close_popup", _close_popup)
	var popup_size: Vector2
	if module_id == "mini_games":
		_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if module.has_signal("open_game_window") and not module.is_connected("open_game_window", _on_mini_games_open_game):
			module.connect("open_game_window", _on_mini_games_open_game)
		if module.has_signal("close_game_window") and not module.is_connected("close_game_window", _on_mini_games_close_game):
			module.connect("close_game_window", _on_mini_games_close_game)
		if module.has_signal("window_bg_opacity_changed") and not module.is_connected("window_bg_opacity_changed", _on_window_bg_opacity_changed):
			module.connect("window_bg_opacity_changed", _on_window_bg_opacity_changed)
		_apply_board_opacity(_board_opacity)
		_apply_block_opacity(_block_opacity)
		_apply_ui_opacity_global(_ui_opacity)
		popup_size = POPUP_MINI_GAMES_MENU_SIZE
	else:
		_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if module_id == "app_launcher":
			popup_size = POPUP_APP_LAUNCHER_SIZE
		else:
			popup_size = POPUP_DEFAULT_SIZE
	_popup_window.custom_minimum_size = popup_size
	_popup_window.size = popup_size
	var final_pos := _compute_popup_position(_popup_window.size)
	if _popup_tween != null:
		_popup_tween.kill()
	_popup_window.visible = true
	_popup_window.modulate = Color(1, 1, 1, 0)
	var reveal_start := final_pos
	if _menu_panel.visible:
		if final_pos.x >= _menu_panel.position.x + _menu_panel.size.x:
			reveal_start.x -= 16
		else:
			reveal_start.x += 16
	else:
		reveal_start.x -= 12
	_popup_window.position = reveal_start
	_popup_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_popup_tween.parallel().tween_property(_popup_window, "position", final_pos, 0.16)
	_popup_tween.parallel().tween_property(_popup_window, "modulate:a", 1.0, 0.16)
	_popup_tween.finished.connect(_update_mouse_passthrough)
	_apply_warm_theme(_popup_window)
	_update_mouse_passthrough()

func _on_mini_games_open_game(_p_game_id: String, p_size: Vector2) -> void:
	_popup_window.visible = false
	if _game_popup_window == null:
		_game_popup_window = _create_game_popup_window()
		add_child(_game_popup_window)
		_move_module_to_game_window.call_deferred()
	else:
		_move_module_to_game_window()
	_game_popup_window.custom_minimum_size = p_size
	_game_popup_window.size = p_size
	_game_popup_window.position = _compute_popup_position(p_size)
	_game_popup_window.visible = true
	_apply_warm_theme(_game_popup_window)
	_update_mouse_passthrough()
	_game_popup_window.reset_size()

func _move_module_to_game_window() -> void:
	if _game_popup_window == null:
		return
	var module: Control = _module_instances.get("mini_games", null)
	if module == null:
		return
	var content := _game_popup_window.find_child("GameContent", true, false)
	if content == null:
		return
	if module.get_parent() == content:
		return
	if module.get_parent() != null:
		module.get_parent().remove_child(module)
	content.add_child(module)

func _on_mini_games_close_game() -> void:
	if _game_popup_window != null:
		_game_popup_window.visible = false
	_restore_mini_games_popup.call_deferred()
	_popup_window.visible = true
	_update_mouse_passthrough()

func _on_window_bg_opacity_changed(value: float) -> void:
	_game_window_bg_opacity = clampf(value, 0.0, 1.0)
	if _game_popup_window != null:
		_apply_warm_theme(_game_popup_window)
		_apply_ui_opacity(_game_popup_window, _game_window_bg_opacity)

func _apply_ui_opacity(node: Node, opacity: float) -> void:
	if node is Button or node is Label:
		node.modulate = Color(1, 1, 1, opacity)
	elif node is HSlider or node is CheckBox:
		node.modulate = Color(1, 1, 1, opacity)
	elif node is ColorRect:
		var color_rect := node as ColorRect
		if color_rect.name != "TetrisBoard":
			color_rect.modulate = Color(1, 1, 1, opacity)
	for child in node.get_children():
		var child_name: StringName = child.name
		if child_name != "TetrisBoard" and child_name != "SnakeBoard":
			_apply_ui_opacity(child, opacity)

func _move_module_to_popup_window() -> void:
	if _game_popup_window == null:
		return
	var module: Control = _module_instances.get("mini_games", null)
	if module == null:
		return
	var content := _game_popup_window.find_child("GameContent", true, false)
	if content == null:
		return
	if module.get_parent() != content:
		return
	content.remove_child(module)
	_popup_content.add_child(module)

func _restore_mini_games_popup() -> void:
	_move_module_to_popup_window()
	var module: Control = _module_instances.get("mini_games", null)
	if module != null:
		module.visible = true
		if module.has_method("_show_menu_view"):
			module.call("_show_menu_view")
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_title.text = str(MODULE_META["mini_games"]["title"])
	_popup_window.custom_minimum_size = POPUP_MINI_GAMES_MENU_SIZE
	_popup_window.size = POPUP_MINI_GAMES_MENU_SIZE
	_popup_window.position = _compute_popup_position(_popup_window.size)
	_apply_warm_theme(_popup_window)

func _create_game_popup_window() -> PanelContainer:
	var popup := PanelContainer.new()
	popup.name = "GamePopupWindow"
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 100

	var frame_margin := MarginContainer.new()
	frame_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.add_theme_constant_override("margin_left", 8)
	frame_margin.add_theme_constant_override("margin_top", 8)
	frame_margin.add_theme_constant_override("margin_right", 8)
	frame_margin.add_theme_constant_override("margin_bottom", 8)
	popup.add_child(frame_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 44)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_game_window_header_input)
	root.add_child(header)

	var title := Label.new()
	title.text = "游戏"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "\u5173\u95ed"
	var close_base_size := close_btn.get_combined_minimum_size()
	close_btn.custom_minimum_size = Vector2(
		ceil(close_base_size.x * 1.10),
		ceil(close_base_size.y * 0.80)
	)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_game_popup)
	header.add_child(close_btn)

	var divider := ColorRect.new()
	divider.color = Color(0.86, 0.62, 0.44, 0.55)
	divider.custom_minimum_size = Vector2(0, 1)
	root.add_child(divider)

	var content := VBoxContainer.new()
	content.name = "GameContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	root.add_child(content)

	return popup

func _on_close_game_popup() -> void:
	if _game_popup_window != null:
		_game_popup_window.visible = false
	var module: Control = _module_instances.get("mini_games", null)
	if module != null:
		if module.has_method("_stop_all_games"):
			module.call("_stop_all_games")
		if module.has_method("_show_menu_view"):
			module.call("_show_menu_view")
	_move_module_to_popup_window.call_deferred()
	_active_module_id = ""
	_update_mouse_passthrough()

func _on_game_window_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_window_dragging = event.pressed
		if _window_dragging:
			_window_drag_offset = get_global_mouse_position() - _game_popup_window.global_position
		else:
			_update_mouse_passthrough()
	elif event is InputEventMouseMotion and _window_dragging:
		var target := get_global_mouse_position() - _window_drag_offset
		_game_popup_window.global_position = _clamp_to_viewport(target, _game_popup_window.size)
		_update_mouse_passthrough()

func _on_cat_entered() -> void:
	_is_cat_hovered = true
	if _cat_dragging or _suppress_menu_until_leave:
		return
	if _menu_size_ready:
		_menu_panel.size = _menu_locked_size
	else:
		_fit_hover_menu()
	_show_menu_smooth()
	_reposition_menu()

func _on_cat_exited() -> void:
	_is_cat_hovered = false
	if _suppress_menu_until_leave:
		_suppress_menu_until_leave = false
	_schedule_menu_hide()

func _on_menu_entered() -> void:
	_is_menu_hovered = true

func _on_menu_exited() -> void:
	_is_menu_hovered = false
	_schedule_menu_hide()

func _schedule_menu_hide() -> void:
	await get_tree().create_timer(0.28).timeout
	if not _is_cat_hovered and not _is_menu_hovered and not _is_pointer_in_cat_or_menu():
		_hide_menu_smooth()

func _on_cat_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_cat_dragging = event.pressed
		if _cat_dragging:
			_suppress_menu_until_leave = true
			_hide_menu_immediate()
			_cat_drag_offset = get_global_mouse_position() - _cat_shell.global_position
		else:
			_cat_user_positioned = true
			_cat_base_position = _cat_shell.position
			_update_mouse_passthrough()
	elif event is InputEventMouseMotion and _cat_dragging:
		_hide_menu_immediate()
		var target := get_global_mouse_position() - _cat_drag_offset
		_cat_shell.global_position = _clamp_to_viewport(target, _cat_shell.size)
		_cat_user_positioned = true
		_cat_base_position = _cat_shell.position
		_reposition_menu()
		if _popup_window.visible:
			_popup_window.position = _compute_popup_position(_popup_window.size)
		_update_mouse_passthrough()

func _process(delta: float) -> void:
	if _cat_shell == null:
		return

	if not _cat_frames.is_empty():
		_cat_phase_time += delta
		while _cat_phase_time >= _cat_phase_duration:
			_cat_phase_time -= _cat_phase_duration
			_cat_frame_index = (_cat_frame_index + 1) % _cat_frames.size()
		_update_cat_frame_blend()

	if _cat_dragging:
		return

	_cat_anim_time += delta
	var bob := sin(_cat_anim_time * 2.2) * 1.4
	var target_pos := _cat_base_position + Vector2(0, bob)
	_cat_shell.position = _clamp_to_viewport(target_pos, _cat_shell.size)
	if _menu_panel.visible:
		_reposition_menu()

func _on_window_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_window_dragging = event.pressed
		if _window_dragging:
			_window_drag_offset = get_global_mouse_position() - _popup_window.global_position
		else:
			_update_mouse_passthrough()
	elif event is InputEventMouseMotion and _window_dragging:
		var target := get_global_mouse_position() - _window_drag_offset
		_popup_window.global_position = _clamp_to_viewport(target, _popup_window.size)
		_update_mouse_passthrough()

func _reposition_menu() -> void:
	_menu_panel.position = _compute_menu_position(_menu_panel.size)
	_menu_panel.pivot_offset = _menu_panel.size * 0.5
	_update_mouse_passthrough()

func _show_menu_smooth() -> void:
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_panel.visible = true
	_menu_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_menu_tween.parallel().tween_property(_menu_panel, "modulate:a", 1.0, 0.16)
	_menu_tween.parallel().tween_property(_menu_panel, "scale", Vector2.ONE, 0.16)
	_update_mouse_passthrough()

func _hide_menu_smooth() -> void:
	if not _menu_panel.visible:
		return
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_menu_tween.parallel().tween_property(_menu_panel, "modulate:a", 0.0, 0.18)
	_menu_tween.parallel().tween_property(_menu_panel, "scale", Vector2(0.96, 0.96), 0.18)
	_menu_tween.finished.connect(func() -> void:
		if not _is_cat_hovered and not _is_menu_hovered and not _is_pointer_in_cat_or_menu():
			_menu_panel.visible = false
			_update_mouse_passthrough()
	)

func _hide_menu_immediate() -> void:
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_panel.visible = false
	_menu_panel.modulate = Color(1, 1, 1, 0)
	_menu_panel.scale = Vector2(0.96, 0.96)
	_update_mouse_passthrough()

func _initialize_menu_size() -> void:
	await get_tree().process_frame
	_fit_hover_menu()
	await get_tree().process_frame
	_fit_hover_menu()
	_menu_locked_size = _menu_panel.size
	_menu_size_ready = true
	_reposition_menu()

func _fit_hover_menu() -> void:
	if _menu_panel == null:
		return
	if _menu_size_ready and _menu_locked_size != Vector2.ZERO:
		_menu_panel.size = _menu_locked_size
		return
	var menu_min := _menu_panel.get_combined_minimum_size()
	var target_size := menu_min + Vector2(18, 14)
	_menu_panel.custom_minimum_size = target_size
	_menu_panel.size = target_size
	_reposition_menu()

func _is_pointer_in_cat_or_menu() -> bool:
	var mouse_pos := get_global_mouse_position()
	var cat_rect := Rect2(_cat_shell.global_position, _cat_shell.size)
	if cat_rect.has_point(mouse_pos):
		return true
	if _menu_panel.visible:
		var menu_rect := Rect2(_menu_panel.global_position, _menu_panel.size)
		if menu_rect.has_point(mouse_pos):
			return true
	return false

func _is_pointer_in_popup() -> bool:
	if _popup_window == null or not _popup_window.visible:
		return false
	var mouse_pos := get_global_mouse_position()
	var popup_rect := Rect2(_popup_window.global_position, _popup_window.size)
	return popup_rect.has_point(mouse_pos)

func _is_pointer_in_menu() -> bool:
	if _menu_panel == null or not _menu_panel.visible:
		return false
	var mouse_pos := get_global_mouse_position()
	var menu_rect := Rect2(_menu_panel.global_position, _menu_panel.size)
	return menu_rect.has_point(mouse_pos)

func _is_pointer_in_popup_or_menu() -> bool:
	return _is_pointer_in_popup() or _is_pointer_in_menu()

func _update_mouse_passthrough() -> void:
	if OS.get_name() != "Windows":
		return
	if _cat_shell == null:
		return

	var hit_rect := Rect2(_cat_shell.position, _cat_shell.size)
	var popup_fully_visible := _popup_window != null and _popup_window.visible and _popup_window.modulate.a >= 0.95
	if _game_popup_window != null and _game_popup_window.visible:
		hit_rect = hit_rect.merge(Rect2(_game_popup_window.position, _game_popup_window.size))
	elif popup_fully_visible:
		hit_rect = hit_rect.merge(Rect2(_popup_window.position, _popup_window.size))
	elif _menu_panel != null and _menu_panel.visible:
		hit_rect = hit_rect.merge(Rect2(_menu_panel.position, _menu_panel.size))

	hit_rect = hit_rect.grow(MOUSE_PASSTHROUGH_PADDING)
	var viewport_size := get_viewport_rect().size
	var left := clampf(hit_rect.position.x, 0.0, viewport_size.x)
	var top := clampf(hit_rect.position.y, 0.0, viewport_size.y)
	var right := clampf(hit_rect.position.x + hit_rect.size.x, 0.0, viewport_size.x)
	var bottom := clampf(hit_rect.position.y + hit_rect.size.y, 0.0, viewport_size.y)

	if right - left < 1.0:
		right = minf(viewport_size.x, left + 1.0)
	if bottom - top < 1.0:
		bottom = minf(viewport_size.y, top + 1.0)

	var region := PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom),
	])
	DisplayServer.window_set_mouse_passthrough(region)

func _compute_menu_position(menu_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var pos := _cat_shell.position + Vector2(_cat_shell.size.x + 4, 0)
	if pos.x + menu_size.x > viewport_size.x - 8:
		pos.x = max(8.0, _cat_shell.position.x - menu_size.x - 4.0)
	if pos.y + menu_size.y > viewport_size.y - 8:
		pos.y = viewport_size.y - menu_size.y - 8
	if pos.y < 8:
		pos.y = 8
	return pos

func _compute_popup_position(window_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	if _menu_panel != null and _menu_panel.visible:
		var right_x := _menu_panel.position.x + _menu_panel.size.x - MENU_POPUP_OVERLAP
		var left_x := _menu_panel.position.x - window_size.x + MENU_POPUP_OVERLAP
		var pos := Vector2(right_x, _menu_panel.position.y)
		if pos.x + window_size.x > viewport_size.x - 8:
			pos.x = max(8.0, left_x)
		if pos.y + window_size.y > viewport_size.y - 8:
			pos.y = viewport_size.y - window_size.y - 8
		if pos.y < 8:
			pos.y = 8
		return pos

	var fallback_pos := _cat_shell.position + Vector2(_cat_shell.size.x + 14, -24)
	if fallback_pos.x + window_size.x > viewport_size.x - 8:
		fallback_pos.x = max(8.0, _cat_shell.position.x - window_size.x - 14.0)
	if fallback_pos.y + window_size.y > viewport_size.y - 8:
		fallback_pos.y = viewport_size.y - window_size.y - 8
	if fallback_pos.y < 8:
		fallback_pos.y = 8
	return fallback_pos

func _should_apply_tray_only_flags() -> bool:
	return OS.get_name() == "Windows" and USE_TRAY_ONLY_ON_WINDOWS and not _should_skip_window_flags()

func _should_bootstrap_minimize() -> bool:
	if OS.get_name() != "Windows":
		return false
	if not USE_TRAY_ONLY_ON_WINDOWS:
		return false
	if not START_MINIMIZED_FOR_TASKBAR_HIDE:
		return false
	if START_MINIMIZED_SKIP_IN_EDITOR and OS.has_feature("editor"):
		return false
	return true

func _should_force_taskbar_hide() -> bool:
	return _should_apply_tray_only_flags()

func _cancel_taskbar_force_apply() -> void:
	_taskbar_force_apply_left = 0
	_taskbar_force_apply_pending = false

func _apply_hidden_mouse_passthrough() -> void:
	var region := PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(0, 1),
	])
	DisplayServer.window_set_mouse_passthrough(region)


func _should_skip_window_flags() -> bool:
	return SKIP_WINDOW_FLAGS_IN_EDITOR and OS.has_feature("editor")

func _set_window_flag_if_needed(flag: int, enabled: bool) -> void:
	if DisplayServer.window_get_flag(flag) == enabled:
		return
	DisplayServer.window_set_flag(flag, enabled)

func _clamp_to_viewport(target: Vector2, node_size: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var clamped_x := clampf(target.x, 0.0, max(0.0, viewport_size.x - node_size.x))
	var clamped_y := clampf(target.y, 0.0, max(0.0, viewport_size.y - node_size.y))
	return Vector2(clamped_x, clamped_y)

func _get_taskbar_hide_ext() -> Object:
	if _taskbar_hide_ext != null:
		return _taskbar_hide_ext
	if not ClassDB.class_exists("TaskbarHide"):
		if not _taskbar_hide_ext_attempted:
			_taskbar_hide_ext_attempted = true
			_try_load_taskbar_hide_extension()
	if not ClassDB.class_exists("TaskbarHide"):
		if not _taskbar_hide_ext_failed:
			_taskbar_hide_ext_failed = true
			push_warning("TaskbarHide extension not available.")
		return null
	_taskbar_hide_ext = ClassDB.instantiate("TaskbarHide")
	return _taskbar_hide_ext

func _try_load_taskbar_hide_extension() -> void:
	if not ClassDB.class_exists("GDExtensionManager"):
		push_warning("GDExtensionManager not available; cannot load TaskbarHide.")
		return
	var abs_path := ProjectSettings.globalize_path(TASKBAR_GDEXT_PATH)
	if not FileAccess.file_exists(abs_path):
		var exe_dir := OS.get_executable_path().get_base_dir()
		var alt_path := exe_dir.path_join("addons").path_join("taskbar_hide").path_join("taskbar_hide.gdextension")
		if FileAccess.file_exists(alt_path):
			abs_path = alt_path
		else:
			push_warning("TaskbarHide extension file not found: %s (alt=%s)" % [abs_path, alt_path])
			return
	var status := GDExtensionManager.load_extension(abs_path)
	if status == GDExtensionManager.LOAD_STATUS_OK or status == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		return
	push_warning(
		"TaskbarHide load status: %s (path=%s)" % [_gdextension_status_to_string(status), abs_path]
	)

func _gdextension_status_to_string(status: int) -> String:
	match status:
		GDExtensionManager.LOAD_STATUS_OK:
			return "OK"
		GDExtensionManager.LOAD_STATUS_FAILED:
			return "FAILED"
		GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			return "ALREADY_LOADED"
		GDExtensionManager.LOAD_STATUS_NOT_LOADED:
			return "NOT_LOADED"
		GDExtensionManager.LOAD_STATUS_NEEDS_RESTART:
			return "NEEDS_RESTART"
		_:
			return str(status)

func _apply_warm_theme(node: Node) -> void:
	if node == _cat_shell or node == _menu_panel or node == _popup_window or node == _game_popup_window:
		var panel := node as Control
		var style: StyleBoxFlat
		if panel == _cat_shell:
			style = _panel_style(
				Color(1, 1, 1, 0),
				Color(1, 1, 1, 0),
				Color(0, 0, 0, 0),
				0,
				Vector2.ZERO,
				32
			)
		elif panel == _menu_panel:
			style = _panel_style(
				WARM_BG,
				Color(0.95, 0.72, 0.52, 0.85),
				Color(0.32, 0.21, 0.14, 0.24),
				16,
				Vector2(1, 6),
				12
			)
		elif panel == _popup_window:
			style = _panel_style(
				Color(1.0, 0.97, 0.91, 0.99),
				Color(0.93, 0.66, 0.45, 0.90),
				Color(0.26, 0.16, 0.10, 0.28),
				26,
				Vector2(3, 10),
				14
			)
		elif panel == _game_popup_window:
			style = _panel_style(
				Color(1.0, 0.97, 0.91, _game_window_bg_opacity),
				Color(0.93, 0.66, 0.45, 0.90 * _game_window_bg_opacity),
				Color(0.26, 0.16, 0.10, 0.28 * _game_window_bg_opacity),
				26,
				Vector2(3, 10),
				14
			)
		else:
			style = _panel_style(
				WARM_BG,
				WARM_ACCENT,
				Color(0.30, 0.20, 0.12, 0.20),
				12,
				Vector2(1, 4),
				12
			)
		panel.add_theme_stylebox_override("panel", style)

	if node is Label:
		(node as Label).add_theme_color_override("font_color", WARM_TEXT)
	elif node is Button:
		var btn := node as Button
		btn.add_theme_color_override("font_color", WARM_TEXT)
		btn.add_theme_stylebox_override("normal", _button_style(Color(0.98, 0.89, 0.76, 1.0)))
		btn.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.93, 0.82, 1.0)))
		btn.add_theme_stylebox_override("pressed", _button_style(Color(0.95, 0.80, 0.64, 1.0)))

	for child in node.get_children():
		_apply_warm_theme(child)

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.45, 0.20, 0.70)
	return style

func _panel_style(
	bg_color: Color,
	border_color: Color,
	shadow_color: Color,
	shadow_size: int,
	shadow_offset: Vector2,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.1
	style.border_blend = true
	return style
