extends "res://app/modules/BaseModule.gd"

signal open_game_window
signal close_game_window
signal window_bg_opacity_changed(value: float)

const SCORE_STORE_PATH := "user://mini_games_scores.json"
const DIFFICULTIES := [
	{"id": "easy", "label": "简单", "tetris": 0.85, "snake": 0.28},
	{"id": "normal", "label": "普通", "tetris": 0.60, "snake": 0.20},
	{"id": "hard", "label": "困难", "tetris": 0.38, "snake": 0.14},
]
const TETRIS_BOARD_SIZE := Vector2(260, 340)
const TETRIS_PREVIEW_GRID_W := 8
const TETRIS_PREVIEW_GRID_H := 6
var _scores: Dictionary = {}

var _menu_view: VBoxContainer
var _game_view: VBoxContainer
var _game_title_label: Label
var _tetris_view: Control
var _snake_view: Control
var _active_game_id := ""

var _tetris_board: TetrisBoard
var _tetris_score_label: Label
var _tetris_high_label: Label
var _tetris_preview: TetrisNextPreview
var _tetris_level_label: Label
var _tetris_lines_label: Label
var _tetris_pause_btn: Button
var _tetris_quit_btn: Button
var _tetris_diff_id := "normal"

var _snake_board: SnakeBoard
var _snake_score_label: Label
var _snake_high_label: Label
var _snake_diff_id := "normal"

func build_ui() -> void:
	_load_scores()

	_menu_view = VBoxContainer.new()
	_menu_view.name = "MenuView"
	_menu_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_view.add_theme_constant_override("separation", 10)
	add_child(_menu_view)

	_game_view = VBoxContainer.new()
	_game_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game_view.visible = false
	_game_view.add_theme_constant_override("separation", 8)
	add_child(_game_view)

	var game_header := HBoxContainer.new()
	game_header.add_theme_constant_override("separation", 8)
	_game_view.add_child(game_header)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(_exit_game)
	game_header.add_child(back_btn)

	_game_title_label = Label.new()
	_game_title_label.text = ""
	_game_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_header.add_child(_game_title_label)

	_tetris_view = _build_tetris_view()
	_tetris_view.visible = false
	_game_view.add_child(_tetris_view)

	_snake_view = _build_snake_view()
	_snake_view.visible = false
	_game_view.add_child(_snake_view)

	_build_menu_cards()

func _build_menu_cards() -> void:
	var tetris_card := make_card("俄罗斯方块", "键盘控制，经典方块消除。支持难度速度切换。")
	tetris_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_view.add_child(tetris_card)
	var tetris_box := tetris_card.get_child(0) as VBoxContainer
	var tetris_row := HBoxContainer.new()
	tetris_row.add_theme_constant_override("separation", 8)
	tetris_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tetris_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tetris_box.add_child(tetris_row)
	var tetris_btn := Button.new()
	tetris_btn.text = "进入游戏"
	tetris_btn.pressed.connect(func() -> void:
		_enter_game("tetris")
	)
	tetris_row.add_child(tetris_btn)

	var snake_card := make_card("贪吃蛇", "鼠标跟随，吃到食物增长。支持难度速度切换。")
	snake_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_view.add_child(snake_card)
	var snake_box := snake_card.get_child(0) as VBoxContainer
	var snake_row := HBoxContainer.new()
	snake_row.add_theme_constant_override("separation", 8)
	snake_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snake_row.alignment = BoxContainer.ALIGNMENT_CENTER
	snake_box.add_child(snake_row)
	var snake_btn := Button.new()
	snake_btn.text = "进入游戏"
	snake_btn.pressed.connect(func() -> void:
		_enter_game("snake")
	)
	snake_row.add_child(snake_btn)

func _build_tetris_view() -> Control:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var diff_label := Label.new()
	diff_label.text = "难度"
	header.add_child(diff_label)

	var diff_select := OptionButton.new()
	diff_select.focus_mode = Control.FOCUS_NONE
	for diff in DIFFICULTIES:
		diff_select.add_item(str(diff["label"]))
	diff_select.selected = _find_diff_index(_tetris_diff_id)
	diff_select.item_selected.connect(_apply_tetris_difficulty)
	header.add_child(diff_select)

	var restart_btn := Button.new()
	restart_btn.text = "开始游戏"
	restart_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.pressed.connect(func() -> void:
		_start_tetris_game(diff_select.selected)
	)
	header.add_child(restart_btn)

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 12)
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_row)

	var board_wrap := CenterContainer.new()
	board_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(board_wrap)

	var side_panel := VBoxContainer.new()
	side_panel.add_theme_constant_override("separation", 8)
	side_panel.custom_minimum_size = Vector2(160, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(side_panel)

	var next_label := Label.new()
	next_label.text = "下一个"
	side_panel.add_child(next_label)

	_tetris_preview = TetrisNextPreview.new()
	_tetris_preview.set_grid(TETRIS_PREVIEW_GRID_W, TETRIS_PREVIEW_GRID_H, 4.0)
	side_panel.add_child(_tetris_preview)

	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 4)
	side_panel.add_child(stats_box)

	_tetris_score_label = Label.new()
	_tetris_score_label.text = "分数: 0"
	stats_box.add_child(_tetris_score_label)

	_tetris_level_label = Label.new()
	_tetris_level_label.text = "级别: 1"
	stats_box.add_child(_tetris_level_label)

	_tetris_lines_label = Label.new()
	_tetris_lines_label.text = "行数: 0"
	stats_box.add_child(_tetris_lines_label)

	_tetris_high_label = Label.new()
	_tetris_high_label.text = "最高分: 0"
	stats_box.add_child(_tetris_high_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(spacer)

	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 6)
	side_panel.add_child(settings_box)

	var board_opacity_label := Label.new()
	board_opacity_label.text = "棋盘透明度"
	settings_box.add_child(board_opacity_label)

	var board_opacity_slider := HSlider.new()
	board_opacity_slider.min_value = 0.0
	board_opacity_slider.max_value = 1.0
	board_opacity_slider.step = 0.05
	board_opacity_slider.value = 1.0
	board_opacity_slider.value_changed.connect(func(value: float) -> void:
		if _tetris_board != null:
			_tetris_board.set_board_opacity(value)
	)
	board_opacity_slider.drag_ended.connect(func(_changed: bool) -> void:
		if _tetris_board != null:
			_tetris_board.grab_focus()
	)
	settings_box.add_child(board_opacity_slider)

	var block_opacity_label := Label.new()
	block_opacity_label.text = "方块透明度"
	settings_box.add_child(block_opacity_label)

	var block_opacity_slider := HSlider.new()
	block_opacity_slider.min_value = 0.0
	block_opacity_slider.max_value = 1.0
	block_opacity_slider.step = 0.05
	block_opacity_slider.value = 1.0
	block_opacity_slider.value_changed.connect(func(value: float) -> void:
		if _tetris_board != null:
			_tetris_board.set_block_opacity(value)
	)
	block_opacity_slider.drag_ended.connect(func(_changed: bool) -> void:
		if _tetris_board != null:
			_tetris_board.grab_focus()
	)
	settings_box.add_child(block_opacity_slider)

	var grid_toggle := CheckBox.new()
	grid_toggle.text = "显示网格"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(pressed: bool) -> void:
		if _tetris_board != null:
			_tetris_board.set_show_grid(pressed)
			_tetris_board.grab_focus()
	)
	settings_box.add_child(grid_toggle)

	var ui_opacity_label := Label.new()
	ui_opacity_label.text = "界面透明度"
	settings_box.add_child(ui_opacity_label)

	var ui_opacity_slider := HSlider.new()
	ui_opacity_slider.min_value = 0.0
	ui_opacity_slider.max_value = 1.0
	ui_opacity_slider.step = 0.05
	ui_opacity_slider.value = 1.0
	ui_opacity_slider.value_changed.connect(func(value: float) -> void:
		emit_signal("window_bg_opacity_changed", value)
	)
	ui_opacity_slider.drag_ended.connect(func(_changed: bool) -> void:
		if _tetris_board != null:
			_tetris_board.grab_focus()
	)
	settings_box.add_child(ui_opacity_slider)

	var button_box := VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 6)
	side_panel.add_child(button_box)

	_tetris_pause_btn = Button.new()
	_tetris_pause_btn.text = "暂停"
	_tetris_pause_btn.focus_mode = Control.FOCUS_NONE
	_tetris_pause_btn.pressed.connect(func() -> void:
		_toggle_tetris_pause()
	)
	button_box.add_child(_tetris_pause_btn)

	_tetris_quit_btn = Button.new()
	_tetris_quit_btn.text = "退出"
	_tetris_quit_btn.focus_mode = Control.FOCUS_NONE
	_tetris_quit_btn.pressed.connect(_exit_game)
	button_box.add_child(_tetris_quit_btn)

	_tetris_board = TetrisBoard.new()
	_tetris_board.custom_minimum_size = TETRIS_BOARD_SIZE
	_tetris_board.score_changed.connect(_on_tetris_score)
	_tetris_board.game_over.connect(_on_tetris_game_over)
	_tetris_board.lines_changed.connect(_on_tetris_lines_changed)
	_tetris_board.next_piece_changed.connect(func(shape: Array, color: Color) -> void:
		if _tetris_preview != null:
			_tetris_preview.set_piece(shape, color)
	)
	board_wrap.add_child(_tetris_board)
	_tetris_board.resized.connect(func() -> void:
		_sync_tetris_preview_size()
	)
	_sync_tetris_preview_size()

	return root

func _build_snake_view() -> Control:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var diff_label := Label.new()
	diff_label.text = "难度"
	header.add_child(diff_label)

	var diff_select := OptionButton.new()
	diff_select.focus_mode = Control.FOCUS_NONE
	for diff in DIFFICULTIES:
		diff_select.add_item(str(diff["label"]))
	diff_select.selected = _find_diff_index(_snake_diff_id)
	diff_select.item_selected.connect(_apply_snake_difficulty)
	header.add_child(diff_select)

	var restart_btn := Button.new()
	restart_btn.text = "重新开始"
	restart_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.pressed.connect(func() -> void:
		_apply_snake_difficulty(diff_select.selected)
	)
	header.add_child(restart_btn)

	var hint := Label.new()
	hint.text = "鼠标跟随"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hint)

	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 12)
	root.add_child(score_row)

	_snake_score_label = Label.new()
	_snake_score_label.text = "当前分: 0"
	score_row.add_child(_snake_score_label)

	_snake_high_label = Label.new()
	_snake_high_label.text = "最高分: 0"
	score_row.add_child(_snake_high_label)

	var board_wrap := CenterContainer.new()
	board_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board_wrap)

	_snake_board = SnakeBoard.new()
	_snake_board.custom_minimum_size = Vector2(400, 400)
	_snake_board.score_changed.connect(_on_snake_score)
	_snake_board.game_over.connect(_on_snake_game_over)
	board_wrap.add_child(_snake_board)

	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 6)
	root.add_child(settings_box)

	var board_opacity_label := Label.new()
	board_opacity_label.text = "棋盘透明度"
	settings_box.add_child(board_opacity_label)

	var board_opacity_slider := HSlider.new()
	board_opacity_slider.min_value = 0.0
	board_opacity_slider.max_value = 1.0
	board_opacity_slider.step = 0.05
	board_opacity_slider.value = 1.0
	board_opacity_slider.value_changed.connect(func(value: float) -> void:
		if _snake_board != null:
			_snake_board.set_board_opacity(value)
	)
	board_opacity_slider.drag_ended.connect(func(_changed: bool) -> void:
		if _snake_board != null:
			_snake_board.grab_focus()
	)
	settings_box.add_child(board_opacity_slider)

	var block_opacity_label := Label.new()
	block_opacity_label.text = "方块透明度"
	settings_box.add_child(block_opacity_label)

	var block_opacity_slider := HSlider.new()
	block_opacity_slider.min_value = 0.0
	block_opacity_slider.max_value = 1.0
	block_opacity_slider.step = 0.05
	block_opacity_slider.value = 1.0
	block_opacity_slider.value_changed.connect(func(value: float) -> void:
		if _snake_board != null:
			_snake_board.set_block_opacity(value)
	)
	block_opacity_slider.drag_ended.connect(func(_changed: bool) -> void:
		if _snake_board != null:
			_snake_board.grab_focus()
	)
	settings_box.add_child(block_opacity_slider)

	var grid_toggle := CheckBox.new()
	grid_toggle.text = "显示网格"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(pressed: bool) -> void:
		if _snake_board != null:
			_snake_board.set_show_grid(pressed)
			_snake_board.grab_focus()
	)
	settings_box.add_child(grid_toggle)

	var ui_opacity_label := Label.new()
	ui_opacity_label.text = "界面透明度"
	settings_box.add_child(ui_opacity_label)

	var ui_opacity_slider := HSlider.new()
	ui_opacity_slider.min_value = 0.0
	ui_opacity_slider.max_value = 1.0
	ui_opacity_slider.step = 0.05
	ui_opacity_slider.value = 1.0
	ui_opacity_slider.value_changed.connect(func(value: float) -> void:
		emit_signal("window_bg_opacity_changed", value)
	)
	ui_opacity_slider.drag_ended.connect(func(_changed: bool) -> void:
		if _snake_board != null:
			_snake_board.grab_focus()
	)
	settings_box.add_child(ui_opacity_slider)

	return root

func _start_tetris_game(index: int) -> void:
	_apply_tetris_difficulty(index)
	_tetris_board.start_game()
	if _tetris_board != null:
		_tetris_board.grab_focus()
	if _tetris_pause_btn != null:
		_tetris_pause_btn.text = "暂停"

func _apply_tetris_difficulty(index: int) -> void:
	var idx: int = clampi(index, 0, DIFFICULTIES.size() - 1)
	var diff: Dictionary = DIFFICULTIES[idx]
	_tetris_diff_id = str(diff["id"])
	var was_running := _tetris_board.is_running()
	_tetris_board.set_drop_interval(float(diff["tetris"]))
	if not was_running:
		_tetris_board.prepare_game()
	_update_tetris_high_label()

func _toggle_tetris_pause() -> void:
	if _tetris_board == null:
		return
	_tetris_board.toggle_pause()
	if _tetris_pause_btn != null:
		_tetris_pause_btn.text = "继续" if _tetris_board.is_paused() else "暂停"

func _sync_tetris_preview_size() -> void:
	if _tetris_board == null or _tetris_preview == null:
		return
	var cell := _tetris_board.get_cell_size() * 0.5
	_tetris_preview.set_grid(TETRIS_PREVIEW_GRID_W, TETRIS_PREVIEW_GRID_H, cell)

func _apply_snake_difficulty(index: int) -> void:
	var idx: int = clampi(index, 0, DIFFICULTIES.size() - 1)
	var diff: Dictionary = DIFFICULTIES[idx]
	_snake_diff_id = str(diff["id"])
	_snake_board.set_step_interval(float(diff["snake"]))
	_snake_board.start_game()
	_update_snake_high_label()

func _enter_game(game_id: String) -> void:
	_active_game_id = game_id
	_menu_view.visible = false
	_game_view.visible = true
	var window_size: Vector2
	if game_id == "tetris":
		_game_title_label.text = ""
		_tetris_view.visible = true
		_snake_view.visible = false
		_apply_tetris_difficulty(_find_diff_index(_tetris_diff_id))
		window_size = Vector2(530, 600)
	elif game_id == "snake":
		_game_title_label.text = "贪吃蛇"
		_tetris_view.visible = false
		_snake_view.visible = true
		_apply_snake_difficulty(_find_diff_index(_snake_diff_id))
		window_size = Vector2(530, 740)
	else:
		_exit_game()
		return
	emit_signal("open_game_window", game_id, window_size)

func _exit_game() -> void:
	_active_game_id = ""
	_game_view.visible = false
	_menu_view.visible = true
	_tetris_view.visible = false
	_snake_view.visible = false
	_stop_all_games()
	_release_game_focus()
	emit_signal("close_game_window")

func _stop_all_games() -> void:
	if _tetris_board != null:
		_tetris_board.stop_game()
	if _snake_board != null:
		_snake_board.stop_game()
	_release_game_focus()

func _release_game_focus() -> void:
	if _tetris_board != null:
		_tetris_board.release_focus()
	if _snake_board != null:
		_snake_board.release_focus()

func set_board_opacity(value: float) -> void:
	if _tetris_board != null:
		_tetris_board.set_board_opacity(value)
	if _snake_board != null:
		_snake_board.set_board_opacity(value)

func set_block_opacity(value: float) -> void:
	if _tetris_board != null:
		_tetris_board.set_block_opacity(value)
	if _snake_board != null:
		_snake_board.set_block_opacity(value)

func get_board_opacity() -> float:
	if _tetris_board != null:
		return _tetris_board.get_board_opacity()
	return 1.0

func get_block_opacity() -> float:
	if _tetris_board != null:
		return _tetris_board.get_block_opacity()
	return 1.0

func _show_menu_view() -> void:
	_active_game_id = ""
	_game_view.visible = false
	_menu_view.visible = true
	_tetris_view.visible = false
	_snake_view.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			if _menu_view != null and _active_game_id == "":
				_exit_game()
		else:
			_stop_all_games()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _active_game_id != "":
				_exit_game()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _active_game_id == "tetris":
				_start_tetris_game(_find_diff_index(_tetris_diff_id))
				get_viewport().set_input_as_handled()
			elif _active_game_id == "snake":
				_apply_snake_difficulty(_find_diff_index(_snake_diff_id))
				get_viewport().set_input_as_handled()

func _on_tetris_score(score: int) -> void:
	_tetris_score_label.text = "分数: %d" % score
	_maybe_update_high("tetris", _tetris_diff_id, score)
	_update_tetris_high_label()

func _on_tetris_lines_changed(lines: int) -> void:
	if _tetris_lines_label != null:
		_tetris_lines_label.text = "行数: %d" % lines
	if _tetris_level_label != null:
		var level := int(lines / 10) + 1
		_tetris_level_label.text = "级别: %d" % level

func _on_snake_score(score: int) -> void:
	_snake_score_label.text = "当前分: %d" % score
	_maybe_update_high("snake", _snake_diff_id, score)
	_update_snake_high_label()

func _on_tetris_game_over(score: int) -> void:
	_maybe_update_high("tetris", _tetris_diff_id, score)
	_update_tetris_high_label()

func _on_snake_game_over(score: int) -> void:
	_maybe_update_high("snake", _snake_diff_id, score)
	_update_snake_high_label()

func _update_tetris_high_label() -> void:
	var high := _get_high("tetris", _tetris_diff_id)
	_tetris_high_label.text = "最高分: %d" % high

func _update_snake_high_label() -> void:
	var high := _get_high("snake", _snake_diff_id)
	_snake_high_label.text = "最高分: %d" % high

func _find_diff_index(diff_id: String) -> int:
	for i in range(DIFFICULTIES.size()):
		if str(DIFFICULTIES[i]["id"]) == diff_id:
			return i
	return 1

func _load_scores() -> void:
	_scores.clear()
	if FileAccess.file_exists(SCORE_STORE_PATH):
		var f := FileAccess.open(SCORE_STORE_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_scores = parsed
	if not _scores.has("tetris"):
		_scores["tetris"] = {}
	if not _scores.has("snake"):
		_scores["snake"] = {}
	for diff in DIFFICULTIES:
		var diff_id := str(diff["id"])
		if not _scores["tetris"].has(diff_id):
			_scores["tetris"][diff_id] = 0
		if not _scores["snake"].has(diff_id):
			_scores["snake"][diff_id] = 0
	_save_scores()

func _save_scores() -> void:
	var f := FileAccess.open(SCORE_STORE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_scores))

func _get_high(game_id: String, diff_id: String) -> int:
	if not _scores.has(game_id):
		return 0
	return int(_scores[game_id].get(diff_id, 0))

func _maybe_update_high(game_id: String, diff_id: String, score: int) -> void:
	var current := _get_high(game_id, diff_id)
	if score > current:
		_scores[game_id][diff_id] = score
		_save_scores()


class TetrisNextPreview:
	extends Control

	var _shape: Array = []
	var _color := Color(1, 1, 1, 1)
	var _grid_w := 16
	var _grid_h := 13
	var _cell_size := 8.0

	func set_grid(grid_w: int, grid_h: int, cell: float) -> void:
		_grid_w = maxi(1, grid_w)
		_grid_h = maxi(1, grid_h)
		_cell_size = maxf(cell, 1.0)
		custom_minimum_size = Vector2(_grid_w * _cell_size, _grid_h * _cell_size)
		queue_redraw()

	func set_piece(shape: Array, color: Color) -> void:
		_shape = shape
		_color = color
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.10, 0.12, 1.0))
		var cell := _cell_size
		var board_size := Vector2(_grid_w * cell, _grid_h * cell)
		var origin := (size - board_size) * 0.5
		if _shape.is_empty():
			return
		var min_x: int = 999
		var min_y: int = 999
		var max_x: int = -999
		var max_y: int = -999
		for c in _shape:
			var v: Vector2i = c
			min_x = mini(min_x, v.x)
			min_y = mini(min_y, v.y)
			max_x = maxi(max_x, v.x)
			max_y = maxi(max_y, v.y)
		var cells_w: int = maxi(1, max_x - min_x + 1)
		var cells_h: int = maxi(1, max_y - min_y + 1)
		var shape_origin := origin + Vector2((float(_grid_w - cells_w) * 0.5 - float(min_x)) * cell, (float(_grid_h - cells_h) * 0.5 - float(min_y)) * cell)
		for c in _shape:
			var v: Vector2i = c
			var rect := Rect2(shape_origin + Vector2(v.x * cell, v.y * cell), Vector2(cell, cell))
			draw_rect(rect.grow(-1), _color)


class TetrisBoard:
	extends Control
	signal score_changed(score: int)
	signal game_over(score: int)
	signal lines_changed(lines: int)
	signal next_piece_changed(shape: Array, color: Color)

	const GRID_W := 13
	const GRID_H := 16

	const TETROMINOS := [
		{
			"color": Color(0.25, 0.72, 0.85, 1.0),
			"rots": [
				[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
				[Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
			],
		},
		{
			"color": Color(0.95, 0.82, 0.25, 1.0),
			"rots": [
				[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			],
		},
		{
			"color": Color(0.62, 0.35, 0.82, 1.0),
			"rots": [
				[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
				[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0)],
				[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1)],
				[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 0)],
			],
		},
		{
			"color": Color(0.95, 0.55, 0.20, 1.0),
			"rots": [
				[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
				[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, -1)],
				[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
				[Vector2i(-1, 1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)],
			],
		},
		{
			"color": Color(0.25, 0.55, 0.90, 1.0),
			"rots": [
				[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)],
				[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
				[Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
				[Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)],
			],
		},
		{
			"color": Color(0.35, 0.80, 0.45, 1.0),
			"rots": [
				[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
				[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
			],
		},
		{
			"color": Color(0.85, 0.35, 0.35, 1.0),
			"rots": [
				[Vector2i(-1, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0)],
				[Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1)],
			],
		},
	]

	var _board: Array = []
	var _rng := RandomNumberGenerator.new()
	var _timer: Timer
	var _drop_interval := 0.6
	var _score := 0
	var _lines := 0
	var _running := false
	var _paused := false

	var _current_index := 0
	var _current_rot := 0
	var _current_pos := Vector2i()
	var _next_index := -1

	var _board_opacity := 1.0
	var _block_opacity := 1.0
	var _show_grid := true

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		_timer = Timer.new()
		_timer.one_shot = false
		_timer.timeout.connect(_on_drop_tick)
		add_child(_timer)
		_reset_board()
		resized.connect(func() -> void:
			queue_redraw()
		)
		gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				grab_focus()
		)

	func set_drop_interval(seconds: float) -> void:
		_drop_interval = maxf(seconds, 0.05)
		if _timer != null:
			_timer.wait_time = _drop_interval

	func is_running() -> bool:
		return _running

	func prepare_game() -> void:
		_running = false
		if _timer != null:
			_timer.stop()
		_reset_board()
		_score = 0
		_lines = 0
		_paused = false
		emit_signal("score_changed", _score)
		emit_signal("lines_changed", _lines)
		_current_index = 0
		_current_rot = 0
		_current_pos = Vector2i()
		_next_index = _rng.randi_range(0, TETROMINOS.size() - 1)
		_emit_next_preview()
		queue_redraw()

	func start_game() -> void:
		_reset_board()
		_score = 0
		_lines = 0
		_paused = false
		emit_signal("score_changed", _score)
		emit_signal("lines_changed", _lines)
		_running = true
		_next_index = _rng.randi_range(0, TETROMINOS.size() - 1)
		_spawn_piece()
		_timer.wait_time = _drop_interval
		_timer.start()
		grab_focus()
		queue_redraw()

	func stop_game() -> void:
		_running = false
		_paused = false
		if _timer != null:
			_timer.stop()

	func toggle_pause() -> void:
		if not _running:
			return
		_paused = not _paused
		if _paused:
			if _timer != null:
				_timer.stop()
		else:
			if _timer != null:
				_timer.start()

	func set_board_opacity(value: float) -> void:
		_board_opacity = clampf(value, 0.0, 1.0)
		queue_redraw()

	func set_block_opacity(value: float) -> void:
		_block_opacity = clampf(value, 0.0, 1.0)
		queue_redraw()

	func set_show_grid(value: bool) -> void:
		_show_grid = value
		queue_redraw()

	func get_board_opacity() -> float:
		return _board_opacity

	func get_block_opacity() -> float:
		return _block_opacity

	func is_showing_grid() -> bool:
		return _show_grid

	func is_paused() -> bool:
		return _paused

	func _reset_board() -> void:
		_board.clear()
		for y in range(GRID_H):
			var row: Array = []
			for x in range(GRID_W):
				row.append(-1)
			_board.append(row)

	func _spawn_piece() -> void:
		if _next_index < 0:
			_next_index = _rng.randi_range(0, TETROMINOS.size() - 1)
		_current_index = _next_index
		_next_index = _rng.randi_range(0, TETROMINOS.size() - 1)
		_emit_next_preview()
		_current_rot = 0
		_current_pos = Vector2i(int(GRID_W / 2), 1)
		if _collides(_current_pos, _current_rot):
			_running = false
			_timer.stop()
			emit_signal("game_over", _score)
		queue_redraw()

	func _emit_next_preview() -> void:
		if _next_index < 0 or _next_index >= TETROMINOS.size():
			return
		var rots: Array = TETROMINOS[_next_index]["rots"]
		if rots.is_empty():
			return
		var shape: Array = rots[0]
		emit_signal("next_piece_changed", shape, TETROMINOS[_next_index]["color"])

	func _on_drop_tick() -> void:
		if not _running or _paused:
			return
		if not _try_move(Vector2i(0, 1)):
			_lock_piece()
			_clear_lines()
			_spawn_piece()

	func _try_move(delta: Vector2i) -> bool:
		var next_pos := _current_pos + delta
		if _collides(next_pos, _current_rot):
			return false
		_current_pos = next_pos
		queue_redraw()
		return true

	func _try_rotate(dir: int) -> void:
		var rots: Array = TETROMINOS[_current_index]["rots"]
		var next_rot := (_current_rot + dir + rots.size()) % rots.size()
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if not _collides(_current_pos + offset, next_rot):
				_current_pos += offset
				_current_rot = next_rot
				queue_redraw()
				return

	func _hard_drop() -> void:
		var moved := false
		while _try_move(Vector2i(0, 1)):
			moved = true
		if moved:
			_score += 2
			emit_signal("score_changed", _score)
		_lock_piece()
		_clear_lines()
		_spawn_piece()

	func _lock_piece() -> void:
		var cells: Array = _current_cells(_current_pos, _current_rot)
		for cell in cells:
			if cell.y >= 0 and cell.y < GRID_H and cell.x >= 0 and cell.x < GRID_W:
				_board[cell.y][cell.x] = _current_index
		queue_redraw()

	func _clear_lines() -> void:
		var cleared := 0
		var y := GRID_H - 1
		while y >= 0:
			var full := true
			for x in range(GRID_W):
				if _board[y][x] == -1:
					full = false
					break
			if full:
				_board.remove_at(y)
				var new_row: Array = []
				for x in range(GRID_W):
					new_row.append(-1)
				_board.insert(0, new_row)
				cleared += 1
				continue
			y -= 1
		if cleared > 0:
			_lines += cleared
			emit_signal("lines_changed", _lines)
			var add := 0
			match cleared:
				1:
					add = 100
				2:
					add = 300
				3:
					add = 500
				_:
					add = 800
			_score += add
			emit_signal("score_changed", _score)

	func _collides(pos: Vector2i, rot: int) -> bool:
		var cells: Array = _current_cells(pos, rot)
		for cell in cells:
			if cell.x < 0 or cell.x >= GRID_W or cell.y >= GRID_H:
				return true
			if cell.y >= 0 and _board[cell.y][cell.x] != -1:
				return true
		return false

	func _current_cells(pos: Vector2i, rot: int) -> Array:
		var rots: Array = TETROMINOS[_current_index]["rots"]
		var shape: Array = rots[rot]
		var out: Array = []
		for c in shape:
			out.append(pos + c)
		return out

	func _gui_input(event: InputEvent) -> void:
		if not _running:
			return
		if event is InputEventKey and event.pressed:
			if _paused and event.keycode != KEY_P:
				return
			var handled := true
			match event.keycode:
				KEY_LEFT:
					_try_move(Vector2i(-1, 0))
				KEY_RIGHT:
					_try_move(Vector2i(1, 0))
				KEY_DOWN:
					_hard_drop()
				KEY_UP, KEY_X:
					_try_rotate(1)
				KEY_Z:
					_try_rotate(-1)
				KEY_SPACE:
					_hard_drop()
				KEY_R:
					start_game()
				KEY_P:
					toggle_pause()
				_:
					handled = false
			if handled:
				accept_event()

	func get_cell_size() -> float:
		var board_size := size
		if board_size.x <= 0.0 or board_size.y <= 0.0:
			board_size = custom_minimum_size
		var cell: float = min(board_size.x / GRID_W, board_size.y / GRID_H)
		return maxf(cell, 1.0)

	func _draw() -> void:
		var layout: Dictionary = _get_board_layout(GRID_W, GRID_H)
		var cell: float = float(layout["cell"])
		var origin: Vector2 = layout["origin"]
		var board_size: Vector2 = layout["size"]
		var bg_color := Color(0.10, 0.10, 0.12, _board_opacity)
		draw_rect(Rect2(origin, board_size), bg_color)
		if _show_grid:
			for x in range(GRID_W + 1):
				var start := origin + Vector2(x * cell, 0)
				var end := origin + Vector2(x * cell, board_size.y)
				draw_line(start, end, Color(0.3, 0.3, 0.35, _board_opacity * 0.5))
			for y in range(GRID_H + 1):
				var start := origin + Vector2(0, y * cell)
				var end := origin + Vector2(board_size.x, y * cell)
				draw_line(start, end, Color(0.3, 0.3, 0.35, _board_opacity * 0.5))
		for y in range(GRID_H):
			for x in range(GRID_W):
				var idx: int = int(_board[y][x])
				if idx != -1:
					var block_color: Color = TETROMINOS[idx]["color"]
					block_color.a = _block_opacity
					_draw_cell(origin, cell, Vector2i(x, y), block_color)
		if _running:
			var cells: Array = _current_cells(_current_pos, _current_rot)
			for cell_pos in cells:
				if cell_pos.y >= 0:
					var block_color: Color = TETROMINOS[_current_index]["color"]
					block_color.a = _block_opacity
					_draw_cell(origin, cell, cell_pos, block_color)

	func _draw_cell(origin: Vector2, cell: float, pos: Vector2i, color: Color) -> void:
		var rect := Rect2(origin + Vector2(pos.x * cell, pos.y * cell), Vector2(cell, cell))
		draw_rect(rect.grow(-1), color)

	func _get_board_layout(w: int, h: int) -> Dictionary:
		var board_size := size
		if board_size.x <= 0.0 or board_size.y <= 0.0:
			board_size = custom_minimum_size
		var cell: float = min(board_size.x / w, board_size.y / h)
		cell = maxf(cell, 1.0)
		board_size = Vector2(cell * w, cell * h)
		var origin := (size - board_size) * 0.5
		return {"cell": cell, "origin": origin, "size": board_size}


class SnakeBoard:
	extends Control
	signal score_changed(score: int)
	signal game_over(score: int)

	const GRID_W := 20
	const GRID_H := 20

	var _snake: Array = []
	var _dir := Vector2i(1, 0)
	var _score := 0
	var _running := false
	var _food := Vector2i()
	var _rng := RandomNumberGenerator.new()
	var _timer: Timer
	var _step_interval := 0.2

	var _board_opacity := 1.0
	var _block_opacity := 1.0
	var _show_grid := true

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		_timer = Timer.new()
		_timer.one_shot = false
		_timer.timeout.connect(_on_step_tick)
		add_child(_timer)
		resized.connect(func() -> void:
			queue_redraw()
		)
		gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				grab_focus()
		)

	func set_step_interval(seconds: float) -> void:
		_step_interval = maxf(seconds, 0.05)
		if _timer != null:
			_timer.wait_time = _step_interval

	func start_game() -> void:
		_score = 0
		emit_signal("score_changed", _score)
		var start_x := int(GRID_W / 2)
		var start_y := int(GRID_H / 2)
		_snake = [Vector2i(start_x, start_y), Vector2i(start_x - 1, start_y), Vector2i(start_x - 2, start_y)]
		_dir = Vector2i(1, 0)
		_spawn_food()
		_running = true
		_timer.wait_time = _step_interval
		_timer.start()
		queue_redraw()

	func stop_game() -> void:
		_running = false
		if _timer != null:
			_timer.stop()

	func set_board_opacity(value: float) -> void:
		_board_opacity = clampf(value, 0.0, 1.0)
		queue_redraw()

	func set_block_opacity(value: float) -> void:
		_block_opacity = clampf(value, 0.0, 1.0)
		queue_redraw()

	func set_show_grid(value: bool) -> void:
		_show_grid = value
		queue_redraw()

	func get_board_opacity() -> float:
		return _board_opacity

	func get_block_opacity() -> float:
		return _block_opacity

	func is_showing_grid() -> bool:
		return _show_grid

	func _spawn_food() -> void:
		var tries := 0
		while tries < 200:
			var p := Vector2i(_rng.randi_range(0, GRID_W - 1), _rng.randi_range(0, GRID_H - 1))
			if not _snake.has(p):
				_food = p
				return
			tries += 1
		_food = Vector2i(0, 0)

	func _on_step_tick() -> void:
		if not _running:
			return
		_update_dir_from_mouse()
		var head: Vector2i = _snake[0]
		var next := head + _dir
		# 无界墙壁，穿过去
		if next.x < 0:
			next.x = GRID_W - 1
		elif next.x >= GRID_W:
			next.x = 0
		if next.y < 0:
			next.y = GRID_H - 1
		elif next.y >= GRID_H:
			next.y = 0
		if _snake.has(next):
			_game_over()
			return
		_snake.insert(0, next)
		if next == _food:
			_score += 1
			emit_signal("score_changed", _score)
			_spawn_food()
		else:
			_snake.pop_back()
		queue_redraw()

	func _update_dir_from_mouse() -> void:
		var layout: Dictionary = _get_board_layout(GRID_W, GRID_H)
		var cell: float = float(layout["cell"])
		var origin: Vector2 = layout["origin"]
		var local := get_local_mouse_position()
		var grid_pos := Vector2i(int((local.x - origin.x) / cell), int((local.y - origin.y) / cell))
		grid_pos.x = clampi(grid_pos.x, 0, GRID_W - 1)
		grid_pos.y = clampi(grid_pos.y, 0, GRID_H - 1)
		var head: Vector2i = _snake[0]
		var delta := grid_pos - head
		if delta == Vector2i.ZERO:
			return
		var next_dir := _dir
		if abs(delta.x) >= abs(delta.y):
			next_dir = Vector2i(signi(delta.x), 0)
		else:
			next_dir = Vector2i(0, signi(delta.y))
		if _snake.size() > 1 and next_dir == -_dir:
			return
		_dir = next_dir

	func _game_over() -> void:
		_running = false
		_timer.stop()
		emit_signal("game_over", _score)

	func _draw() -> void:
		var layout: Dictionary = _get_board_layout(GRID_W, GRID_H)
		var cell: float = float(layout["cell"])
		var origin: Vector2 = layout["origin"]
		var board_size: Vector2 = layout["size"]
		var bg_color := Color(0.10, 0.10, 0.12, _board_opacity)
		draw_rect(Rect2(origin, board_size), bg_color)
		if _show_grid:
			for x in range(GRID_W + 1):
				var start := origin + Vector2(x * cell, 0)
				var end := origin + Vector2(x * cell, board_size.y)
				draw_line(start, end, Color(0.3, 0.3, 0.35, _board_opacity * 0.5))
			for y in range(GRID_H + 1):
				var start := origin + Vector2(0, y * cell)
				var end := origin + Vector2(board_size.x, y * cell)
				draw_line(start, end, Color(0.3, 0.3, 0.35, _board_opacity * 0.5))
		var food_color: Color = Color(0.88, 0.25, 0.25, 1.0)
		food_color.a = _block_opacity
		_draw_cell(origin, cell, _food, food_color)
		for i in range(_snake.size()):
			var color: Color
			if i == 0:
				color = Color(0.20, 0.90, 0.50, 1.0)
			else:
				color = Color(0.25, 0.75, 0.45, 1.0)
			color.a = _block_opacity
			_draw_cell(origin, cell, _snake[i], color)

	func _draw_cell(origin: Vector2, cell: float, pos: Vector2i, color: Color) -> void:
		var rect := Rect2(origin + Vector2(pos.x * cell, pos.y * cell), Vector2(cell, cell))
		draw_rect(rect.grow(-1), color)

	func _get_board_layout(w: int, h: int) -> Dictionary:
		var board_size := size
		if board_size.x <= 0.0 or board_size.y <= 0.0:
			board_size = custom_minimum_size
		var cell: float = min(board_size.x / w, board_size.y / h)
		cell = maxf(cell, 1.0)
		board_size = Vector2(cell * w, cell * h)
		var origin := (size - board_size) * 0.5
		return {"cell": cell, "origin": origin, "size": board_size}
