extends Control

const TestResourceScript = preload("res://test_resource.gd")
const BRIDGE_SCRIPT_PATH := "res://project_horn_bridge.gd"
const SUPPORTED_EXTENSIONS := ["tres", "res"]
const RESOURCE_BASE_PROPERTIES := [
	"resource_name",
	"resource_path",
	"resource_local_to_scene",
	"resource_scene_unique_id",
	"script"
]

const RESOURCE_TYPES := [
	{"type_name": "TestResource", "label": "테스트 리소스", "script_path": "res://test_resource.gd", "default_folder": "", "create": true},
	{"type_name": "GameRuleDefinition", "label": "게임 규칙", "script_path": "res://game/core/game_rule_definition.gd", "default_folder": "data/rules", "create": true},
	{"type_name": "HeroDefinition", "label": "영웅", "script_path": "res://game/features/heroes/hero_definition.gd", "default_folder": "data/heroes", "create": true},
	{"type_name": "SkillDefinition", "label": "스킬", "script_path": "res://game/features/heroes/skill_definition.gd", "default_folder": "data/skills", "create": true},
	{"type_name": "EnemyDefinition", "label": "적", "script_path": "res://game/features/enemies/enemy_definition.gd", "default_folder": "data/enemies", "create": true},
	{"type_name": "WaveDefinition", "label": "웨이브", "script_path": "res://game/features/waves/wave_definition.gd", "default_folder": "data/waves", "create": true},
	{"type_name": "BossDefinition", "label": "보스", "script_path": "res://game/features/bosses/boss_definition.gd", "default_folder": "data/bosses", "create": true},
	{"type_name": "BossPhaseDefinition", "label": "보스 페이즈", "script_path": "res://game/features/bosses/boss_phase_definition.gd", "default_folder": "data/bosses/phases", "create": true},
	{"type_name": "BossPatternDefinition", "label": "보스 패턴", "script_path": "res://game/features/bosses/boss_pattern_definition.gd", "default_folder": "data/bosses/patterns", "create": true},
	{"type_name": "BossDifficultyDefinition", "label": "보스 난이도", "script_path": "res://game/features/bosses/boss_difficulty_definition.gd", "default_folder": "data/bosses/difficulties", "create": true},
	{"type_name": "ItemDefinition", "label": "아이템", "script_path": "res://game/features/items/item_definition.gd", "default_folder": "data/items", "create": true},
	{"type_name": "RecipeDefinition", "label": "레시피", "script_path": "res://game/features/items/recipe_definition.gd", "default_folder": "data/items/recipes", "create": true},
	{"type_name": "AugmentDefinition", "label": "증강", "script_path": "res://game/features/augments/augment_definition.gd", "default_folder": "data/augments", "create": true},
	{"type_name": "TurretDefinition", "label": "포탑", "script_path": "res://game/features/defense/turret_definition.gd", "default_folder": "data/turrets", "create": true},
	{"type_name": "RegionDefinition", "label": "지역", "script_path": "res://game/features/world/region_definition.gd", "default_folder": "data/regions", "create": true},
	{"type_name": "MapLayoutDefinition", "label": "맵 데이터", "script_path": "res://game/features/world/map_layout_definition.gd", "default_folder": "data/maps", "create": true},
	{"type_name": "SkillLevelDefinition", "label": "스킬 레벨", "script_path": "res://game/features/heroes/skill_level_definition.gd", "default_folder": "data/skills", "create": false},
	{"type_name": "SkillSpecialParameters", "label": "스킬 특수 파라미터", "script_path": "res://game/features/heroes/skill_special_parameters.gd", "default_folder": "data/skills", "create": false},
	{"type_name": "EnemyBehaviorDefinition", "label": "적 행동", "script_path": "res://game/features/enemies/enemy_behavior_definition.gd", "default_folder": "data/enemies", "create": false},
	{"type_name": "ItemEffectDefinition", "label": "아이템 효과", "script_path": "res://game/features/items/item_effect_definition.gd", "default_folder": "data/items", "create": false},
	{"type_name": "StatModifierDefinition", "label": "스탯 수정자", "script_path": "res://game/features/items/stat_modifier_definition.gd", "default_folder": "data/items", "create": false}
]

const REFERENCE_TARGETS := {
	"enemy_id": "EnemyDefinition",
	"enemy_ids": "EnemyDefinition",
	"group_pool_ids": "EnemyDefinition",
	"spawn_group_ids": "EnemyDefinition",
	"boss_id": "BossDefinition",
	"boss_ids": "BossDefinition",
	"region_id": "RegionDefinition",
	"item_id": "ItemDefinition",
	"item_ids": "ItemDefinition",
	"reward_id": "ItemDefinition",
	"reward_ids": "ItemDefinition",
	"reward_item_ids": "ItemDefinition",
	"result_id": "ItemDefinition",
	"legendary_inputs": "ItemDefinition",
	"material_inputs": "ItemDefinition",
	"pattern_id": "BossPatternDefinition",
	"pattern_ids": "BossPatternDefinition"
}

var project_root := ""
var data_root := ""
var workspace_dir := ""
var bridge_mode := false
var current_resource: Resource
var current_path := ""
var current_document := {}
var current_file_mtime := 0
var dirty := false
var is_new_document := false
var clean_snapshot := {}
var suppress_changes := false

var resource_entries: Array = []
var visible_entries: Array = []
var field_infos: Array = []
var field_controls := {}
var field_paths := {}
var validation_messages: Array = []
var project_validation: Array = []
var undo_stack: Array = []
var redo_stack: Array = []

var pending_action: Callable = Callable()
var pending_after_save: Callable = Callable()
var dialog_action := ""
var pending_field_path: Array = []
var pending_field_expected := ""

var resource_type_option: OptionButton
var search_input: LineEdit
var resource_list: ItemList
var project_path_label: Label
var workspace_path_label: Label
var document_header: Label
var inspector_fields: VBoxContainer
var validation_text: Label
var status_label: Label
var file_dialog: FileDialog
var dirty_dialog: ConfirmationDialog
var delete_dialog: ConfirmationDialog


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_ui()
	_build_dialogs()
	_populate_resource_types()
	_load_settings_or_open_local()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_guard_unsaved(Callable(self, "_quit_application"))


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if not key_event.ctrl_pressed:
		return
	match key_event.keycode:
		KEY_S:
			if key_event.shift_pressed:
				_on_save_as_pressed()
			else:
				_on_save_pressed()
			get_viewport().set_input_as_handled()
		KEY_N:
			_on_new_pressed()
			get_viewport().set_input_as_handled()
		KEY_Z:
			_on_undo_pressed()
			get_viewport().set_input_as_handled()
		KEY_Y:
			_on_redo_pressed()
			get_viewport().set_input_as_handled()
		KEY_F:
			search_input.grab_focus()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(key, 10)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	margin.add_child(main)

	var title := Label.new()
	title.text = "Project Horn Game Data Editor"
	title.add_theme_font_size_override("font_size", 20)
	main.add_child(title)

	var project_row := HBoxContainer.new()
	project_row.add_theme_constant_override("separation", 6)
	var project_label := Label.new()
	project_label.text = "Project:"
	project_row.add_child(project_label)
	project_path_label = Label.new()
	project_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	project_row.add_child(project_path_label)
	_add_toolbar_button(project_row, "프로젝트 열기", Callable(self, "_on_open_project_pressed"))
	_add_toolbar_button(project_row, "데이터 폴더", Callable(self, "_on_open_folder_pressed"))
	_add_toolbar_button(project_row, "Rescan", Callable(self, "_on_rescan_pressed"))
	main.add_child(project_row)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 5)
	_add_toolbar_button(toolbar, "New", Callable(self, "_on_new_pressed"))
	_add_toolbar_button(toolbar, "Load", Callable(self, "_on_load_pressed"))
	_add_toolbar_button(toolbar, "Save", Callable(self, "_on_save_pressed"))
	_add_toolbar_button(toolbar, "Save As", Callable(self, "_on_save_as_pressed"))
	_add_toolbar_button(toolbar, "Duplicate", Callable(self, "_on_duplicate_pressed"))
	_add_toolbar_button(toolbar, "Delete", Callable(self, "_on_delete_pressed"))
	_add_toolbar_button(toolbar, "Validate All", Callable(self, "_on_validate_all_pressed"))
	_add_toolbar_button(toolbar, "Undo", Callable(self, "_on_undo_pressed"))
	_add_toolbar_button(toolbar, "Redo", Callable(self, "_on_redo_pressed"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(status_label)
	main.add_child(toolbar)

	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.split_offset = 320
	main.add_child(content)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	content.add_child(left_panel)
	var left_margin := MarginContainer.new()
	for key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		left_margin.add_theme_constant_override(key, 8)
	left_panel.add_child(left_margin)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left_margin.add_child(left)
	left.add_child(_make_header("Resource Browser"))
	resource_type_option = OptionButton.new()
	resource_type_option.item_selected.connect(func(_index: int) -> void: _refresh_resource_list())
	left.add_child(resource_type_option)
	workspace_path_label = Label.new()
	workspace_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace_path_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	left.add_child(workspace_path_label)
	search_input = LineEdit.new()
	search_input.placeholder_text = "ID / 이름 / 파일명 / 경로 검색"
	search_input.clear_button_enabled = true
	search_input.text_changed.connect(func(_value: String) -> void: _refresh_resource_list())
	left.add_child(search_input)
	resource_list = ItemList.new()
	resource_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_list.select_mode = ItemList.SELECT_SINGLE
	resource_list.allow_reselect = true
	resource_list.item_selected.connect(_on_resource_list_selected)
	left.add_child(resource_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	content.add_child(right)
	document_header = _make_header("Inspector")
	right.add_child(document_header)
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(inspector_scroll)
	inspector_fields = VBoxContainer.new()
	inspector_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_fields.add_theme_constant_override("separation", 5)
	inspector_scroll.add_child(inspector_fields)

	var validation_panel := PanelContainer.new()
	validation_panel.custom_minimum_size = Vector2(0, 135)
	right.add_child(validation_panel)
	var validation_margin := MarginContainer.new()
	for key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		validation_margin.add_theme_constant_override(key, 8)
	validation_panel.add_child(validation_margin)
	var validation_box := VBoxContainer.new()
	validation_box.add_child(_make_header("Validation"))
	validation_text = Label.new()
	validation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	validation_box.add_child(validation_text)
	validation_margin.add_child(validation_box)


func _build_dialogs() -> void:
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	file_dialog.dir_selected.connect(_on_directory_selected)
	file_dialog.canceled.connect(_on_file_dialog_canceled)
	add_child(file_dialog)

	dirty_dialog = ConfirmationDialog.new()
	dirty_dialog.title = "저장되지 않은 변경"
	dirty_dialog.get_ok_button().text = "저장"
	dirty_dialog.get_cancel_button().text = "취소"
	dirty_dialog.add_button("버리기", true, "discard")
	dirty_dialog.confirmed.connect(_on_dirty_save)
	dirty_dialog.canceled.connect(_on_dirty_cancel)
	dirty_dialog.custom_action.connect(_on_dirty_custom_action)
	add_child(dirty_dialog)

	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Resource 삭제"
	delete_dialog.get_ok_button().text = "삭제"
	delete_dialog.get_cancel_button().text = "취소"
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_dialog)


func _add_toolbar_button(parent: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _make_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _populate_resource_types() -> void:
	resource_type_option.clear()
	resource_type_option.add_item("전체 Resource")
	resource_type_option.set_item_metadata(0, "")
	for type_info in RESOURCE_TYPES:
		resource_type_option.add_item(String(type_info["label"]))
		resource_type_option.set_item_metadata(resource_type_option.item_count - 1, type_info["type_name"])
	resource_type_option.select(0)


func _selected_type_name() -> String:
	if resource_type_option == null or resource_type_option.selected < 0:
		return ""
	return String(resource_type_option.get_item_metadata(resource_type_option.selected))


func _type_info(type_name: String) -> Dictionary:
	for type_info in RESOURCE_TYPES:
		if String(type_info["type_name"]) == type_name:
			return type_info
	return {"type_name": type_name, "label": type_name, "script_path": "", "default_folder": "", "create": false}


func _load_settings_or_open_local() -> void:
	var settings := ConfigFile.new()
	if settings.load("user://project_horn_editor.cfg") == OK:
		var last_project := String(settings.get_value("editor", "last_project_path", ""))
		if not last_project.is_empty() and DirAccess.dir_exists_absolute(last_project) and FileAccess.file_exists(last_project.path_join("project.godot")):
			_open_workspace(last_project)
			return
	_open_workspace(_editor_project_root())


func _editor_project_root() -> String:
	return ProjectSettings.globalize_path("res://").simplify_path()


func _on_open_project_pressed() -> void:
	_guard_unsaved(Callable(self, "_open_project_dialog"))


func _open_project_dialog() -> void:
	dialog_action = "project"
	_configure_file_dialog(FileDialog.FILE_MODE_OPEN_DIR, [])
	file_dialog.current_dir = project_root if not project_root.is_empty() else _editor_project_root()
	file_dialog.popup_centered()


func _on_open_folder_pressed() -> void:
	_guard_unsaved(Callable(self, "_open_folder_dialog"))


func _open_folder_dialog() -> void:
	dialog_action = "folder"
	_configure_file_dialog(FileDialog.FILE_MODE_OPEN_DIR, [])
	file_dialog.current_dir = data_root if not data_root.is_empty() else _editor_project_root()
	file_dialog.popup_centered()


func _on_directory_selected(path: String) -> void:
	var action := dialog_action
	dialog_action = ""
	if action in ["project", "folder"]:
		_open_workspace(path)


func _open_workspace(selected_path: String) -> void:
	var selected := selected_path.simplify_path()
	var root := selected
	var selected_data := selected
	if FileAccess.file_exists(selected.path_join("project.godot")):
		selected_data = selected.path_join("data") if DirAccess.dir_exists_absolute(selected.path_join("data")) else selected
	elif FileAccess.file_exists(selected.get_base_dir().path_join("project.godot")):
		root = selected.get_base_dir()
	else:
		root = selected
		selected_data = selected

	if not DirAccess.dir_exists_absolute(selected_data):
		_show_validation_error("폴더를 찾을 수 없습니다: %s" % selected_data)
		return
	project_root = root
	data_root = selected_data
	workspace_dir = data_root
	bridge_mode = FileAccess.file_exists(project_root.path_join("project.godot")) and not _same_path(project_root, _editor_project_root())
	project_path_label.text = project_root
	workspace_path_label.text = "Data: %s" % data_root
	_save_settings()
	_scan_workspace()
	_set_status("프로젝트를 열었습니다.")


func _save_settings() -> void:
	var settings := ConfigFile.new()
	settings.load("user://project_horn_editor.cfg")
	settings.set_value("editor", "last_project_path", project_root)
	settings.set_value("editor", "last_data_path", data_root)
	settings.set_value("editor", "last_selected_resource", current_path)
	settings.save("user://project_horn_editor.cfg")


func _same_path(left: String, right: String) -> bool:
	return left.replace("\\", "/").trim_suffix("/").to_lower() == right.replace("\\", "/").trim_suffix("/").to_lower()


func _on_rescan_pressed() -> void:
	_guard_unsaved(Callable(self, "_scan_workspace"))


func _scan_workspace() -> void:
	resource_entries.clear()
	project_validation.clear()
	if data_root.is_empty() or not DirAccess.dir_exists_absolute(data_root):
		_show_validation_error("Data Root를 찾을 수 없습니다.")
		return
	if bridge_mode:
		var response := _bridge_call("scan", {"data_root": data_root})
		if not bool(response.get("ok", false)):
			_show_validation_error(String(response.get("error", "Project Bridge scan failed.")))
			return
		resource_entries = response.get("entries", [])
		project_validation = response.get("validation", [])
	else:
		var paths: Array[String] = []
		_collect_resource_paths(data_root, paths)
		paths.sort()
		for path in paths:
			var loaded := ResourceLoader.load(path) as Resource
			if loaded == null:
				resource_entries.append({"path": path, "relative_path": _relative_path(path), "type_name": "", "id": "", "display_name": "", "resource": null, "load_error": true, "validation": []})
				continue
			var type_name := _resource_type_name(loaded)
			resource_entries.append({"path": path, "relative_path": _relative_path(path), "type_name": type_name, "id": _resource_id(loaded, type_name), "display_name": _resource_display_name(loaded, type_name), "resource": loaded, "load_error": false, "validation": []})
	_refresh_resource_list()
	if current_path.is_empty():
		_show_empty_inspector()
	else:
		_select_current_list_item()
	_set_status("%d개 Resource를 스캔했습니다." % resource_entries.size())


func _collect_resource_paths(directory_path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var file_name := directory.get_next()
		if file_name.is_empty():
			break
		if file_name.begins_with("."):
			continue
		var full_path := directory_path.path_join(file_name)
		if directory.current_is_dir():
			_collect_resource_paths(full_path, paths)
		elif file_name.get_extension().to_lower() in SUPPORTED_EXTENSIONS:
			paths.append(full_path)
	directory.list_dir_end()


func _relative_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	var root := data_root.replace("\\", "/").trim_suffix("/")
	return normalized.trim_prefix(root + "/")


func _relative_to_project(path: String) -> String:
	var normalized := path.replace("\\", "/")
	var root := project_root.replace("\\", "/").trim_suffix("/")
	return normalized.trim_prefix(root + "/")


func _refresh_resource_list() -> void:
	if resource_list == null:
		return
	resource_list.clear()
	visible_entries.clear()
	var query := search_input.text.strip_edges().to_lower() if search_input != null else ""
	var type_filter := _selected_type_name()
	for entry in resource_entries:
		var type_name := String(entry.get("type_name", ""))
		if not type_filter.is_empty() and type_name != type_filter:
			continue
		var haystack := "%s %s %s %s" % [type_name, entry.get("id", ""), entry.get("display_name", ""), entry.get("relative_path", "")]
		if not query.is_empty() and not haystack.to_lower().contains(query):
			continue
		visible_entries.append(entry)
		var display := "%s  ·  %s" % [type_name if not type_name.is_empty() else "로드 실패", entry.get("display_name", "")]
		if String(entry.get("display_name", "")).is_empty():
			display = "%s  ·  %s" % [display, entry.get("relative_path", "")]
		var messages: Array = entry.get("validation", [])
		if bool(entry.get("load_error", false)):
			display = "[ERROR] " + display
		elif _has_error(messages):
			display = "[!] " + display
		resource_list.add_item(display)
		resource_list.set_item_tooltip(resource_list.item_count - 1, String(entry.get("path", "")))
	_select_current_list_item()


func _select_current_list_item() -> void:
	if current_path.is_empty():
		return
	for index in range(visible_entries.size()):
		if _same_path(String(visible_entries[index].get("path", "")), current_path):
			resource_list.select(index)
			return


func _on_resource_list_selected(index: int) -> void:
	if index < 0 or index >= visible_entries.size():
		return
	var path := String(visible_entries[index].get("path", ""))
	_guard_unsaved(Callable(self, "_load_resource_from_path").bind(path))


func _on_load_pressed() -> void:
	_guard_unsaved(Callable(self, "_open_load_dialog"))


func _open_load_dialog() -> void:
	dialog_action = "load"
	_configure_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, [["*.tres,*.res", "Resource"]])
	file_dialog.current_dir = data_root
	file_dialog.popup_centered()


func _load_resource_from_path(path: String) -> void:
	if bridge_mode:
		var response := _bridge_call("inspect", {"path": path})
		if not bool(response.get("ok", false)):
			_show_validation_error(String(response.get("error", "Resource load failed.")))
			return
		current_resource = null
		current_path = path
		current_document = response.duplicate(true)
		current_document["source_path"] = path
		current_document["original_id"] = _document_id()
		current_file_mtime = FileAccess.get_modified_time(path)
		field_infos = current_document.get("properties", [])
		dirty = false
		is_new_document = false
		clean_snapshot = _snapshot()
		undo_stack.clear()
		redo_stack.clear()
		_select_type_name(String(current_document.get("type_name", "")))
		_rebuild_inspector()
		_set_status("Resource를 불러왔습니다.")
		return

	var loaded := ResourceLoader.load(path) as Resource
	if loaded == null:
		_show_validation_error("Resource를 로드할 수 없습니다: %s" % path)
		return
	current_resource = loaded
	current_path = path
	current_document.clear()
	field_infos = _get_editable_properties(loaded)
	dirty = false
	is_new_document = false
	clean_snapshot = _snapshot()
	undo_stack.clear()
	redo_stack.clear()
	_select_type_name(_resource_type_name(loaded))
	_rebuild_inspector()
	_set_status("Resource를 불러왔습니다.")


func _select_type_name(type_name: String) -> void:
	for index in range(resource_type_option.item_count):
		if String(resource_type_option.get_item_metadata(index)) == type_name:
			resource_type_option.select(index)
			return
	resource_type_option.select(0)


func _on_new_pressed() -> void:
	_guard_unsaved(Callable(self, "_create_new_resource"))


func _create_new_resource() -> void:
	var type_name := _selected_type_name()
	if bridge_mode:
		if type_name.is_empty() or type_name == "TestResource":
			for type_info in RESOURCE_TYPES:
				if bool(type_info.get("create", false)) and String(type_info["type_name"]) != "TestResource":
					type_name = String(type_info["type_name"])
					break
		var type_info := _type_info(type_name)
		var response := _bridge_call("create", {"script_path": type_info.get("script_path", "")})
		if not bool(response.get("ok", false)):
			_show_validation_error(String(response.get("error", "Resource를 생성할 수 없습니다.")))
			return
		current_resource = null
		current_path = ""
		current_document = response.duplicate(true)
		current_document["source_path"] = ""
		current_document["original_id"] = ""
		field_infos = current_document.get("properties", [])
		dirty = true
		is_new_document = true
		clean_snapshot = {}
		undo_stack.clear()
		redo_stack.clear()
		_select_type_name(type_name)
		_rebuild_inspector()
		_set_status("새 Resource를 만들었습니다.")
		return

	current_resource = TestResourceScript.new()
	current_path = ""
	current_document.clear()
	field_infos = _get_editable_properties(current_resource)
	dirty = true
	is_new_document = true
	clean_snapshot = {}
	undo_stack.clear()
	redo_stack.clear()
	_select_type_name("TestResource")
	_rebuild_inspector()
	_set_status("새 테스트 Resource를 만들었습니다.")


func _on_duplicate_pressed() -> void:
	if current_resource == null and current_document.is_empty():
		_show_validation_error("복제할 Resource가 없습니다.")
		return
	_guard_unsaved(Callable(self, "_duplicate_current_resource"))


func _duplicate_current_resource() -> void:
	if bridge_mode:
		current_document = current_document.duplicate(true)
		current_document["source_path"] = ""
		current_document["path"] = ""
		current_document["original_id"] = _document_id()
		current_path = ""
		current_resource = null
		field_infos = current_document.get("properties", [])
	else:
		current_resource = current_resource.duplicate(true) as Resource
		current_path = ""
	is_new_document = true
	clean_snapshot = {}
	dirty = true
	undo_stack.clear()
	redo_stack.clear()
	_rebuild_inspector()
	_set_status("복제본을 만들었습니다. 저장할 때 파일이 생성됩니다.")


func _on_save_pressed() -> void:
	if current_resource == null and current_document.is_empty():
		_show_validation_error("먼저 Resource를 만들거나 불러오세요.")
		return
	if current_path.is_empty():
		_open_save_dialog(false)
	else:
		_save_to_path(current_path)


func _on_save_as_pressed() -> void:
	if current_resource == null and current_document.is_empty():
		_show_validation_error("먼저 Resource를 만들거나 불러오세요.")
		return
	_open_save_dialog(false)


func _open_save_dialog(for_pending_action: bool) -> void:
	dialog_action = "save_pending" if for_pending_action else "save"
	_configure_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, [["*.tres", "Text Resource"]])
	var default_dir := data_root
	if bridge_mode and current_path.is_empty():
		var type_info := _type_info(String(current_document.get("type_name", _selected_type_name())))
		var folder := String(type_info.get("default_folder", ""))
		if not folder.is_empty():
			default_dir = project_root.path_join(folder)
	file_dialog.current_dir = default_dir
	file_dialog.current_file = _suggested_filename()
	file_dialog.popup_centered()


func _suggested_filename() -> String:
	if not current_path.is_empty():
		return current_path.get_file()
	var id := _document_id()
	if id.is_empty() and current_resource != null and not current_resource.resource_name.is_empty():
		id = current_resource.resource_name
	return (id if not id.is_empty() else "new_resource") + ".tres"


func _on_delete_pressed() -> void:
	if current_resource == null and current_document.is_empty():
		_show_validation_error("삭제할 Resource가 없습니다.")
		return
	_guard_unsaved(Callable(self, "_confirm_delete"))


func _confirm_delete() -> void:
	if current_path.is_empty():
		_clear_current_resource()
		return
	if bridge_mode:
		var response := _bridge_call("references", {"data_root": data_root, "target_type": String(current_document.get("type_name", "")), "target_id": _document_id()})
		if not bool(response.get("ok", false)):
			_show_validation_error(String(response.get("error", "Reference check failed; delete was blocked.")))
			return
		if not response.get("references", []).is_empty():
			var lines: Array[String] = ["참조 중인 Resource는 삭제할 수 없습니다."]
			for reference in response.get("references", []):
				lines.append("- %s · %s" % [reference.get("relative_path", reference.get("path", "")), reference.get("field", "")])
			_show_validation_error("\n".join(lines))
			return
	delete_dialog.dialog_text = "다음 파일을 삭제하시겠습니까?\n%s" % current_path
	delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if current_path.is_empty():
		_clear_current_resource()
		return
	var error := DirAccess.remove_absolute(current_path)
	if error != OK:
		_show_validation_error("파일을 삭제할 수 없습니다: %s" % error_string(error))
		return
	_clear_current_resource()
	_scan_workspace()
	_set_status("Resource를 삭제했습니다.")


func _clear_current_resource() -> void:
	current_resource = null
	current_document.clear()
	current_path = ""
	current_file_mtime = 0
	dirty = false
	is_new_document = false
	clean_snapshot = {}
	undo_stack.clear()
	redo_stack.clear()
	_show_empty_inspector()


func _configure_file_dialog(mode: int, filters: Array) -> void:
	file_dialog.file_mode = mode
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.clear_filters()
	for filter_data in filters:
		file_dialog.add_filter(filter_data[0], filter_data[1])


func _on_file_dialog_file_selected(path: String) -> void:
	var action := dialog_action
	dialog_action = ""
	match action:
		"project", "folder":
			_open_workspace(path)
		"load":
			_load_resource_from_path(path)
		"save":
			_save_to_path(_normalize_save_path(path))
		"save_pending":
			var save_path := _normalize_save_path(path)
			if _save_to_path(save_path) and pending_after_save.is_valid():
				var next := pending_after_save
				pending_after_save = Callable()
				next.call()
		"asset":
			_assign_asset_to_field(path)


func _on_file_dialog_canceled() -> void:
	if dialog_action == "save_pending":
		pending_after_save = Callable()
		pending_action = Callable()
	dialog_action = ""


func _normalize_save_path(path: String) -> String:
	var normalized := path
	if not normalized.get_extension().to_lower() in SUPPORTED_EXTENSIONS:
		normalized = normalized.get_basename() + ".tres"
	if bridge_mode and not _path_within(normalized, project_root):
		_show_validation_error("Project Horn 외부에는 저장할 수 없습니다.")
		return ""
	return normalized


func _save_to_path(path: String) -> bool:
	if path.is_empty():
		return false
	if not _validate_current_resource():
		_set_status("검증 오류로 저장하지 않았습니다.")
		return false
	if bridge_mode:
		if not current_path.is_empty() and current_file_mtime > 0 and FileAccess.get_modified_time(current_path) != current_file_mtime:
			_show_validation_error("파일이 외부에서 변경되었습니다. Rescan 후 다시 확인하세요.")
			return false
		var request := {
			"target_path": path,
			"source_path": String(current_document.get("source_path", "")),
			"script_path": String(current_document.get("script_path", "")),
			"values": current_document.get("values", {})
		}
		var response := _bridge_call("save", request)
		if not bool(response.get("ok", false)):
			_show_validation_error(String(response.get("error", "Save failed.")))
			_set_status("저장에 실패했습니다.")
			return false
		current_document = response.duplicate(true)
		current_document["source_path"] = path
		current_document["original_id"] = _document_id()
		current_path = path
		current_file_mtime = FileAccess.get_modified_time(path)
		field_infos = current_document.get("properties", [])
		dirty = false
		is_new_document = false
		undo_stack.clear()
		redo_stack.clear()
		_scan_workspace()
		_rebuild_inspector()
		clean_snapshot = _snapshot()
		_set_status("저장했습니다.")
		_save_settings()
		return true

	var error := ResourceSaver.save(current_resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		_show_validation_error("저장 실패: %s" % error_string(error))
		_set_status("저장에 실패했습니다.")
		return false
	current_path = path
	workspace_dir = path.get_base_dir()
	data_root = workspace_dir
	current_file_mtime = FileAccess.get_modified_time(path)
	dirty = false
	is_new_document = false
	undo_stack.clear()
	redo_stack.clear()
	_scan_workspace()
	_rebuild_inspector()
	clean_snapshot = _snapshot()
	_set_status("저장했습니다.")
	return true


func _guard_unsaved(action: Callable) -> void:
	if not dirty:
		action.call()
		return
	pending_action = action
	dirty_dialog.dialog_text = "저장되지 않은 변경사항이 있습니다. 어떻게 하시겠습니까?"
	dirty_dialog.popup_centered()


func _on_dirty_save() -> void:
	dirty_dialog.hide()
	if current_path.is_empty():
		pending_after_save = pending_action
		pending_action = Callable()
		_open_save_dialog(true)
		return
	if _save_to_path(current_path) and pending_action.is_valid():
		var next := pending_action
		pending_action = Callable()
		next.call()


func _on_dirty_custom_action(action: StringName) -> void:
	if action != &"discard":
		return
	dirty_dialog.hide()
	_discard_current_changes()
	if pending_action.is_valid():
		var next := pending_action
		pending_action = Callable()
		next.call()


func _discard_current_changes() -> void:
	if is_new_document:
		_clear_current_resource()
		return
	if clean_snapshot.is_empty():
		return
	_restore_snapshot(clean_snapshot)
	dirty = false
	undo_stack.clear()
	redo_stack.clear()
	_update_document_status()


func _on_dirty_cancel() -> void:
	pending_action = Callable()


func _quit_application() -> void:
	_save_settings()
	get_tree().quit()


func _rebuild_inspector() -> void:
	suppress_changes = true
	field_controls.clear()
	field_paths.clear()
	_clear_container(inspector_fields)
	if current_resource == null and current_document.is_empty():
		suppress_changes = false
		_show_empty_inspector()
		return
	if bridge_mode:
		field_infos = current_document.get("properties", [])
		document_header.text = "%s  ·  %s\n%s" % [current_document.get("type_name", "Resource"), _document_id(), _relative_to_project(current_path) if not current_path.is_empty() else "Unsaved"]
		for property_info in field_infos:
			if String(property_info.get("kind", "field")) == "group":
				inspector_fields.add_child(_make_group_header(String(property_info.get("label", property_info.get("name", "")))))
			else:
				_add_external_field(inspector_fields, property_info, [String(property_info.get("name", ""))])
	else:
		document_header.text = "%s  ·  %s" % [_resource_type_name(current_resource), _relative_path(current_path) if not current_path.is_empty() else "Unsaved"]
		field_infos = _get_editable_properties(current_resource)
		for property_info in field_infos:
			_add_local_property_editor(property_info)
	suppress_changes = false
	_validate_current_resource()
	_update_document_status()


func _show_empty_inspector() -> void:
	if inspector_fields == null:
		return
	_clear_container(inspector_fields)
	document_header.text = "Inspector"
	var label := Label.new()
	label.text = "Resource를 선택하거나 New를 누르세요."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_fields.add_child(label)
	validation_messages.clear()
	_add_validation("info", "검사할 Resource가 없습니다.")
	_render_validation()
	_update_document_status()


func _make_group_header(text: String) -> Label:
	var label := Label.new()
	label.text = "▼ " + text
	label.add_theme_font_size_override("font_size", 14)
	return label


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _get_editable_properties(resource: Resource) -> Array:
	var properties: Array = []
	for raw_info in resource.get_property_list():
		var info: Dictionary = raw_info
		var property_name := String(info.get("name", ""))
		var usage := int(info.get("usage", 0))
		if property_name in RESOURCE_BASE_PROPERTIES or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		properties.append(info)
	return properties


func _add_local_property_editor(property_info: Dictionary) -> void:
	var property_name := String(property_info["name"])
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = _property_label(property_name)
	label.custom_minimum_size = Vector2(170, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var type := int(property_info.get("type", TYPE_NIL))
	var value = current_resource.get(property_name)
	match type:
		TYPE_STRING, TYPE_STRING_NAME:
			_add_local_string_editor(row, property_info, value)
		TYPE_INT:
			if int(property_info.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_ENUM:
				_add_local_enum_editor(row, property_info, value)
			else:
				_add_local_number_editor(row, property_info, value, true)
		TYPE_FLOAT:
			_add_local_number_editor(row, property_info, value, false)
		TYPE_BOOL:
			_add_local_bool_editor(row, property_name, value)
		TYPE_OBJECT:
			_add_local_resource_editor(row, property_info, value)
		_:
			var unsupported := Label.new()
			unsupported.text = "지원 UI 없음: %s" % type_string(type)
			unsupported.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
			row.add_child(unsupported)
	inspector_fields.add_child(row)


func _add_local_string_editor(row: HBoxContainer, property_info: Dictionary, value: Variant) -> void:
	var property_name := String(property_info["name"])
	if int(property_info.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_MULTILINE_TEXT:
		var text_edit := TextEdit.new()
		text_edit.custom_minimum_size = Vector2(0, 80)
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.text = String(value)
		text_edit.text_changed.connect(func() -> void: _on_field_changed(property_name, text_edit.text))
		row.add_child(text_edit)
	else:
		var line_edit := LineEdit.new()
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.text = String(value)
		line_edit.text_changed.connect(func(new_text: String) -> void: _on_field_changed(property_name, new_text if int(property_info.get("type", TYPE_STRING)) == TYPE_STRING else StringName(new_text)))
		row.add_child(line_edit)


func _add_local_number_editor(row: HBoxContainer, property_info: Dictionary, value: Variant, integer: bool) -> void:
	var property_name := String(property_info["name"])
	var spin_box := SpinBox.new()
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.allow_greater = true
	spin_box.allow_lesser = true
	var range := _range_from_property(property_info)
	spin_box.min_value = range[0]
	spin_box.max_value = range[1]
	spin_box.step = range[2] if range[2] > 0.0 else (1.0 if integer else 0.01)
	spin_box.value = float(value)
	spin_box.value_changed.connect(func(new_value: float) -> void: _on_field_changed(property_name, int(new_value) if integer else new_value))
	row.add_child(spin_box)


func _add_local_bool_editor(row: HBoxContainer, property_name: String, value: Variant) -> void:
	var check_box := CheckBox.new()
	check_box.text = "사용"
	check_box.button_pressed = bool(value)
	check_box.toggled.connect(func(new_value: bool) -> void: _on_field_changed(property_name, new_value))
	row.add_child(check_box)


func _add_local_enum_editor(row: HBoxContainer, property_info: Dictionary, value: Variant) -> void:
	var property_name := String(property_info["name"])
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := _parse_enum_options(String(property_info.get("hint_string", "")))
	for option_data in options:
		option.add_item(option_data["label"], option_data["value"])
	for index in range(options.size()):
		if options[index]["value"] == int(value):
			option.select(index)
	option.item_selected.connect(func(index: int) -> void: _on_field_changed(property_name, option.get_item_id(index)))
	row.add_child(option)


func _parse_enum_options(hint_string: String) -> Array:
	var options: Array = []
	var default_value := 0
	for entry in hint_string.split(","):
		var parts := entry.split(":")
		var value := default_value
		if parts.size() > 1:
			value = int(parts[1])
		options.append({"label": parts[0], "value": value})
		default_value += 1
	return options


func _add_local_resource_editor(row: HBoxContainer, property_info: Dictionary, value: Variant) -> void:
	var property_name := String(property_info["name"])
	var expected := _object_property_type(property_info)
	var editor := HBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.text = "없음" if value == null else (value.resource_path if value is Resource and not value.resource_path.is_empty() else "[내장 Resource]")
	editor.add_child(value_label)
	var select_button := Button.new()
	select_button.text = "찾기"
	select_button.pressed.connect(func() -> void: _open_asset_dialog([property_name], expected))
	editor.add_child(select_button)
	var clear_button := Button.new()
	clear_button.text = "지우기"
	clear_button.pressed.connect(func() -> void: _set_local_resource_field(property_name, null))
	editor.add_child(clear_button)
	field_controls[property_name] = {"value_label": value_label, "expected": expected}
	row.add_child(editor)


func _add_external_field(parent: Container, property_info: Dictionary, path: Array) -> void:
	var property_name := String(property_info.get("name", ""))
	var value: Dictionary = _value_at_path(path)
	var type := int(property_info.get("type", TYPE_NIL))
	var target := _reference_target_for_property(property_name)
	if type == TYPE_OBJECT and value.get("kind", "") == "inline_resource":
		_add_inline_resource_editor(parent, property_name, value, path)
		return
	if type == TYPE_ARRAY or value.get("kind", "") in ["array", "packed_vector2_array"]:
		_add_array_editor(parent, property_info, value, path)
		return
	if type == TYPE_DICTIONARY or value.get("kind", "") == "dictionary":
		_add_dictionary_editor(parent, property_name, value)
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = _property_label(property_name)
	label.custom_minimum_size = Vector2(180, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	match type:
		TYPE_STRING, TYPE_STRING_NAME:
			if not target.is_empty() and type == TYPE_STRING_NAME:
				_add_reference_picker(row, value, target, Callable(self, "_set_external_value").bind(path))
			else:
				_add_external_string(row, property_info, value, path)
		TYPE_INT:
			if int(property_info.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_ENUM:
				_add_external_enum(row, property_info, value, path)
			else:
				_add_external_number(row, property_info, value, path, true)
		TYPE_FLOAT:
			_add_external_number(row, property_info, value, path, false)
		TYPE_BOOL:
			_add_external_bool(row, value, path)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_RECT2:
			_add_external_components(row, value, path)
		TYPE_COLOR:
			_add_external_color(row, value, path)
		TYPE_OBJECT:
			_add_external_resource(row, property_info, value, path)
		_:
			var unsupported := Label.new()
			unsupported.text = "지원 UI 없음: %s" % String(property_info.get("type_name", ""))
			unsupported.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
			row.add_child(unsupported)
	parent.add_child(row)


func _add_external_string(row: HBoxContainer, property_info: Dictionary, value: Dictionary, path: Array) -> void:
	var setter := Callable(self, "_set_external_value").bind(path)
	if int(property_info.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_MULTILINE_TEXT:
		var text_edit := TextEdit.new()
		text_edit.custom_minimum_size = Vector2(0, 80)
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.text = _encoded_text(value)
		text_edit.text_changed.connect(func() -> void: setter.call({"kind": "string", "value": text_edit.text}))
		row.add_child(text_edit)
		return
	var line_edit := LineEdit.new()
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text = _encoded_text(value)
	line_edit.text_changed.connect(func(new_text: String) -> void:
		var kind := "string_name" if int(property_info.get("type", TYPE_STRING)) == TYPE_STRING_NAME else "string"
		setter.call({"kind": kind, "value": new_text})
	)
	row.add_child(line_edit)


func _add_reference_picker(parent: Container, value: Dictionary, target: String, setter: Callable) -> void:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := _encoded_text(value)
	var seen := {}
	for entry in resource_entries:
		if String(entry.get("type_name", "")) != target:
			continue
		var id := String(entry.get("id", ""))
		if id.is_empty() or seen.has(id):
			continue
		seen[id] = true
		option.add_item(id)
		option.set_item_metadata(option.item_count - 1, id)
	if not current.is_empty() and not seen.has(current):
		option.add_item("⚠ Missing: " + current)
		option.set_item_metadata(option.item_count - 1, current)
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == current:
			option.select(index)
	option.item_selected.connect(func(index: int) -> void: setter.call({"kind": "string_name", "value": String(option.get_item_metadata(index))}))
	parent.add_child(option)


func _add_external_number(row: HBoxContainer, property_info: Dictionary, value: Dictionary, path: Array, integer: bool) -> void:
	var spin := SpinBox.new()
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.allow_greater = true
	spin.allow_lesser = true
	var range := _range_from_property(property_info)
	spin.min_value = range[0]
	spin.max_value = range[1]
	spin.step = range[2] if range[2] > 0.0 else (1.0 if integer else 0.01)
	spin.value = _encoded_number(value)
	var setter := Callable(self, "_set_external_value").bind(path)
	spin.value_changed.connect(func(new_value: float) -> void: setter.call({"kind": "int" if integer else "float", "value": int(new_value) if integer else new_value}))
	row.add_child(spin)


func _add_external_bool(row: HBoxContainer, value: Dictionary, path: Array) -> void:
	var check := CheckBox.new()
	check.text = "사용"
	check.button_pressed = bool(value.get("value", false))
	var setter := Callable(self, "_set_external_value").bind(path)
	check.toggled.connect(func(new_value: bool) -> void: setter.call({"kind": "bool", "value": new_value}))
	row.add_child(check)


func _add_external_enum(row: HBoxContainer, property_info: Dictionary, value: Dictionary, path: Array) -> void:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := _parse_enum_options(String(property_info.get("hint_string", "")))
	for item in options:
		option.add_item(item["label"], item["value"])
	for index in range(options.size()):
		if options[index]["value"] == int(value.get("value", 0)):
			option.select(index)
	var setter := Callable(self, "_set_external_value").bind(path)
	option.item_selected.connect(func(index: int) -> void: setter.call({"kind": "int", "value": option.get_item_id(index)}))
	row.add_child(option)


func _add_external_components(row: HBoxContainer, value: Dictionary, path: Array) -> void:
	var keys: Array = []
	match String(value.get("kind", "")):
		"vector2": keys = ["x", "y"]
		"vector3": keys = ["x", "y", "z"]
		"vector4": keys = ["x", "y", "z", "w"]
		"rect2": keys = ["x", "y", "w", "h"]
		_: return
	for key in keys:
		var spin := SpinBox.new()
		spin.custom_minimum_size.x = 90
		spin.step = 0.01
		spin.value = float(value.get(key, 0.0))
		var setter := Callable(self, "_set_external_component").bind(path, String(key))
		spin.value_changed.connect(func(new_value: float) -> void: setter.call(new_value))
		row.add_child(spin)


func _add_external_color(row: HBoxContainer, value: Dictionary, path: Array) -> void:
	var picker := ColorPickerButton.new()
	picker.color = Color(float(value.get("r", 0.0)), float(value.get("g", 0.0)), float(value.get("b", 0.0)), float(value.get("a", 1.0)))
	var setter := Callable(self, "_set_external_color").bind(path)
	picker.color_changed.connect(func(color: Color) -> void: setter.call(color))
	row.add_child(picker)


func _add_external_resource(row: HBoxContainer, property_info: Dictionary, value: Dictionary, path: Array) -> void:
	var expected := _object_property_type(property_info)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = _encoded_resource_label(value)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var select := Button.new()
	select.text = "찾기"
	select.pressed.connect(func() -> void: _open_asset_dialog(path, expected))
	row.add_child(select)
	var clear := Button.new()
	clear.text = "지우기"
	clear.pressed.connect(func() -> void: _set_external_value({"kind": "nil"}, path))
	row.add_child(clear)
	if expected == "Texture2D" and value.get("kind", "") == "resource":
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(48, 48)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = _preview_texture(String(value.get("path", "")))
		row.add_child(preview)


func _add_array_editor(parent: Container, property_info: Dictionary, value: Dictionary, path: Array) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s [%d]" % [_property_label(String(property_info.get("name", "Array"))), value.get("values", []).size()]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var add := Button.new()
	add.text = "+ Add"
	add.pressed.connect(func() -> void: _array_action(path, -1, "add"))
	header.add_child(add)
	box.add_child(header)
	var values: Array = value.get("values", [])
	for index in range(values.size()):
		var item_box := HBoxContainer.new()
		var item_label := Label.new()
		item_label.text = "%d." % (index + 1)
		item_label.custom_minimum_size.x = 30
		item_box.add_child(item_label)
		var element_info := _element_property_info(property_info, values[index])
		if values[index].get("kind", "") == "inline_resource":
			_add_inline_resource_editor(item_box, "", values[index], path + [index])
		else:
			_add_external_value_editor(item_box, element_info, values[index], path + [index], _reference_target_for_property(String(property_info.get("name", ""))))
		for action in ["up", "down", "duplicate", "remove"]:
			var button := Button.new()
			button.text = {"up": "↑", "down": "↓", "duplicate": "복제", "remove": "삭제"}[action]
			button.pressed.connect(func() -> void: _array_action(path, index, action))
			item_box.add_child(button)
		box.add_child(item_box)
	parent.add_child(box)


func _add_external_value_editor(parent: Container, property_info: Dictionary, value: Dictionary, path: Array, target: String) -> void:
	var type := int(property_info.get("type", _type_from_encoded(value)))
	if not target.is_empty() and value.get("kind", "") == "string_name":
		_add_reference_picker(parent, value, target, Callable(self, "_set_external_value").bind(path))
		return
	match type:
		TYPE_STRING, TYPE_STRING_NAME:
			_add_external_string(parent, property_info, value, path)
		TYPE_INT:
			_add_external_number(parent, property_info, value, path, true)
		TYPE_FLOAT:
			_add_external_number(parent, property_info, value, path, false)
		TYPE_BOOL:
			_add_external_bool(parent, value, path)
		TYPE_OBJECT:
			if value.get("kind", "") == "inline_resource":
				_add_inline_resource_editor(parent, "", value, path)
			else:
				_add_external_resource(parent, property_info, value, path)
		_:
			var label := Label.new()
			label.text = _encoded_text(value)
			parent.add_child(label)


func _add_inline_resource_editor(parent: Container, property_name: String, value: Dictionary, path: Array) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var toggle := Button.new()
	toggle.text = "▼ %s%s" % [String(value.get("type_name", "Resource")), (" · " + property_name) if not property_name.is_empty() else ""]
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(toggle)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	section.add_child(fields)
	toggle.pressed.connect(func() -> void: fields.visible = not fields.visible)
	for child_info in value.get("properties", []):
		if String(child_info.get("kind", "field")) == "group":
			fields.add_child(_make_group_header(String(child_info.get("label", child_info.get("name", "")))))
		else:
			_add_external_field(fields, child_info, path + [String(child_info.get("name", ""))])
	parent.add_child(section)


func _add_dictionary_editor(parent: Container, property_name: String, value: Dictionary) -> void:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s (legacy Dictionary; 보존됨)" % _property_label(property_name)
	label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.35))
	box.add_child(label)
	var preview := Label.new()
	preview.text = _encoded_text(value)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preview)
	parent.add_child(box)


func _array_action(path: Array, index: int, action: String) -> void:
	var array_value: Dictionary = _value_at_path(path)
	if array_value.get("kind", "") not in ["array", "packed_vector2_array"]:
		return
	_record_undo()
	var values: Array = array_value.get("values", [])
	match action:
		"add":
			values.append(_default_array_value(values))
		"remove":
			if index >= 0 and index < values.size(): values.remove_at(index)
		"duplicate":
			if index >= 0 and index < values.size(): values.insert(index + 1, values[index].duplicate(true))
		"up":
			if index > 0:
				var up_value = values[index]
				values[index] = values[index - 1]
				values[index - 1] = up_value
		"down":
			if index >= 0 and index + 1 < values.size():
				var down_value = values[index]
				values[index] = values[index + 1]
				values[index + 1] = down_value
	array_value["values"] = values
	_set_value_at_path(path, array_value)
	dirty = true
	_rebuild_inspector()
	_validate_current_resource()
	_update_document_status()


func _default_array_value(values: Array) -> Dictionary:
	if not values.is_empty() and values[0] is Dictionary:
		var original: Dictionary = values[0]
		return original.duplicate(true)
	return {"kind": "string_name", "value": ""}


func _element_property_info(property_info: Dictionary, value: Dictionary) -> Dictionary:
	var type := _type_from_encoded(value)
	var info := property_info.duplicate(true)
	info["name"] = "element"
	info["type"] = type
	info["type_name"] = type_string(type)
	if type == TYPE_OBJECT:
		info["class_name"] = String(property_info.get("hint_string", "Resource"))
	return info


func _type_from_encoded(value: Dictionary) -> int:
	match String(value.get("kind", "")):
		"bool": return TYPE_BOOL
		"int": return TYPE_INT
		"float": return TYPE_FLOAT
		"string": return TYPE_STRING
		"string_name": return TYPE_STRING_NAME
		"vector2": return TYPE_VECTOR2
		"vector3": return TYPE_VECTOR3
		"vector4": return TYPE_VECTOR4
		"rect2": return TYPE_RECT2
		"color": return TYPE_COLOR
		"resource", "inline_resource": return TYPE_OBJECT
		"array", "packed_vector2_array": return TYPE_ARRAY
		"dictionary": return TYPE_DICTIONARY
	return TYPE_NIL


func _set_external_value(value: Variant, path: Array) -> void:
	if suppress_changes:
		return
	_record_undo()
	_set_value_at_path(path, value)
	dirty = true
	_validate_current_resource()
	_update_document_status()


func _set_external_component(value: float, path: Array, key: String) -> void:
	var current: Dictionary = _value_at_path(path).duplicate(true)
	current[key] = value
	_set_external_value(current, path)


func _set_external_color(color: Color, path: Array) -> void:
	_set_external_value({"kind": "color", "r": color.r, "g": color.g, "b": color.b, "a": color.a}, path)


func _value_at_path(path: Array) -> Dictionary:
	if path.is_empty() or current_document.is_empty():
		return {"kind": "nil"}
	var value: Dictionary = current_document.get("values", {}).get(String(path[0]), {"kind": "nil"})
	for index in range(1, path.size()):
		var key = path[index]
		if value.get("kind", "") == "inline_resource":
			value = value.get("values", {}).get(String(key), {"kind": "nil"})
		elif value.get("kind", "") in ["array", "packed_vector2_array"]:
			var values: Array = value.get("values", [])
			value = values[int(key)] if int(key) >= 0 and int(key) < values.size() else {"kind": "nil"}
		else:
			return {"kind": "nil"}
	return value


func _set_value_at_path(path: Array, new_value: Dictionary) -> void:
	if path.is_empty():
		return
	if path.size() == 1:
		current_document["values"][String(path[0])] = new_value
		return
	var value: Dictionary = current_document["values"].get(String(path[0]), {"kind": "nil"})
	_set_nested_value(value, path, 1, new_value)
	current_document["values"][String(path[0])] = value


func _set_nested_value(value: Dictionary, path: Array, index: int, new_value: Dictionary) -> void:
	var key = path[index]
	var last := index == path.size() - 1
	if value.get("kind", "") == "inline_resource":
		if last:
			value["values"][String(key)] = new_value
		else:
			var child: Dictionary = value["values"].get(String(key), {"kind": "nil"})
			_set_nested_value(child, path, index + 1, new_value)
			value["values"][String(key)] = child
	elif value.get("kind", "") in ["array", "packed_vector2_array"]:
		var values: Array = value.get("values", [])
		var array_index := int(key)
		if array_index < 0 or array_index >= values.size():
			return
		if last:
			values[array_index] = new_value
		else:
			var child: Dictionary = values[array_index]
			_set_nested_value(child, path, index + 1, new_value)
			values[array_index] = child
		value["values"] = values


func _on_field_changed(property_name: String, value: Variant) -> void:
	if suppress_changes or current_resource == null:
		return
	_record_undo()
	current_resource.set(property_name, value)
	dirty = true
	_validate_current_resource()
	_update_document_status()


func _open_asset_dialog(path: Array, expected: String) -> void:
	pending_field_path = path
	pending_field_expected = expected
	dialog_action = "asset"
	var filters: Array = []
	match expected:
		"Texture2D": filters = [["*.png,*.jpg,*.jpeg,*.webp,*.svg", "이미지"]]
		"PackedScene": filters = [["*.tscn,*.scn,*.glb", "Scene"]]
		_: filters = [["*.tres,*.res,*.tscn,*.scn", "Resource"]]
	_configure_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, filters)
	file_dialog.current_dir = project_root if bridge_mode else workspace_dir
	file_dialog.popup_centered()


func _assign_asset_to_field(path: String) -> void:
	if bridge_mode:
		if not _path_within(path, project_root):
			_show_validation_error("Project Horn 외부 Asset은 참조할 수 없습니다.")
			return
		var resource_path := "res://" + _relative_to_project(path).replace("\\", "/")
		_set_external_value({"kind": "resource", "path": resource_path, "type_name": pending_field_expected}, pending_field_path)
		pending_field_path = []
		pending_field_expected = ""
		return
	var value := ResourceLoader.load(path) as Resource
	if value == null or not _matches_expected_resource(value, pending_field_expected):
		_show_validation_error("필드 타입과 선택한 파일 타입이 다릅니다: %s" % path)
		return
	_set_local_resource_field(String(pending_field_path[0]), value)
	pending_field_path = []
	pending_field_expected = ""


func _set_local_resource_field(property_name: String, value: Resource) -> void:
	if current_resource == null:
		return
	_record_undo()
	current_resource.set(property_name, value)
	dirty = true
	_rebuild_inspector()
	_update_document_status()


func _matches_expected_resource(value: Resource, expected: String) -> bool:
	if value == null:
		return true
	if expected.is_empty() or expected == "Resource":
		return true
	match expected:
		"Texture2D": return value is Texture2D
		"PackedScene": return value is PackedScene
	var script := value.get_script() as Script
	return script != null and String(script.get_global_name()) == expected


func _preview_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://"):
		path = project_root.path_join(path.trim_prefix("res://")) if bridge_mode else ProjectSettings.globalize_path(path)
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _validate_current_resource() -> bool:
	validation_messages.clear()
	if current_resource == null and current_document.is_empty():
		_add_validation("info", "검사할 Resource가 없습니다.")
		_render_validation()
		return true
	var has_error := false
	if bridge_mode:
		var type_name := String(current_document.get("type_name", ""))
		var id := _document_id()
		if type_name in ["GameRuleDefinition", "HeroDefinition", "SkillDefinition", "EnemyDefinition", "WaveDefinition", "BossDefinition", "ItemDefinition", "RecipeDefinition", "AugmentDefinition", "TurretDefinition", "RegionDefinition"] and id.is_empty():
			_add_validation("error", "Global ID가 비어 있습니다.")
			has_error = true
		for property_info in field_infos:
			if String(property_info.get("kind", "field")) != "field":
				continue
			var value: Dictionary = _value_at_path([String(property_info.get("name", ""))])
			var range_error := _range_error(property_info, value)
			if not range_error.is_empty():
				_add_validation("error", range_error)
				has_error = true
		for entry in resource_entries:
			if _same_path(String(entry.get("path", "")), current_path):
				for message in entry.get("validation", []):
					_add_validation(String(message.get("severity", "error")), String(message.get("message", "")))
					has_error = has_error or String(message.get("severity", "error")) == "error"
		if not current_path.is_empty() and String(current_document.get("original_id", "")) != id and not String(current_document.get("original_id", "")).is_empty():
			_add_validation("warning", "ID가 변경되었습니다. 참조 업데이트 여부를 Validate All에서 확인하세요.")
	else:
		for property_info in field_infos:
			var property_name := String(property_info.get("name", ""))
			var type := int(property_info.get("type", TYPE_NIL))
			if type == TYPE_OBJECT and current_resource.get(property_name) != null:
				var expected := _object_property_type(property_info)
				if not _matches_expected_resource(current_resource.get(property_name), expected):
					_add_validation("error", "%s 필드의 타입이 올바르지 않습니다." % _property_label(property_name))
					has_error = true
	_render_validation()
	return not has_error


func _range_error(property_info: Dictionary, value: Dictionary) -> String:
	if int(property_info.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RANGE or value.get("kind", "") not in ["int", "float"]:
		return ""
	var parts := String(property_info.get("hint_string", "")).split(",")
	if parts.size() < 2:
		return ""
	var number := float(value.get("value", 0.0))
	var minimum := float(parts[0])
	var maximum := float(parts[1])
	return "%s가 허용 범위 %s..%s 밖입니다." % [_property_label(String(property_info.get("name", "field"))), minimum, maximum] if number < minimum or number > maximum else ""


func _range_from_property(property_info: Dictionary) -> Array:
	if int(property_info.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RANGE:
		return [-1000000000.0, 1000000000.0, 0.0]
	var parts := String(property_info.get("hint_string", "")).split(",")
	var minimum := float(parts[0]) if parts.size() > 0 and not parts[0].is_empty() else -1000000000.0
	var maximum := float(parts[1]) if parts.size() > 1 and not parts[1].is_empty() else 1000000000.0
	var step := float(parts[2]) if parts.size() > 2 and not parts[2].is_empty() else 0.0
	return [minimum, maximum, step]


func _record_undo() -> void:
	if suppress_changes:
		return
	undo_stack.append(_snapshot())
	if undo_stack.size() > 50:
		undo_stack.pop_front()
	redo_stack.clear()


func _snapshot() -> Dictionary:
	if bridge_mode:
		return {"external": true, "document": current_document.duplicate(true), "path": current_path, "file_mtime": current_file_mtime, "new_document": is_new_document}
	return {"external": false, "resource": current_resource.duplicate(true) if current_resource != null else null, "path": current_path, "file_mtime": current_file_mtime, "new_document": is_new_document}


func _restore_snapshot(snapshot: Dictionary) -> void:
	suppress_changes = true
	if bool(snapshot.get("external", false)):
		current_document = snapshot.get("document", {}).duplicate(true)
		field_infos = current_document.get("properties", [])
	else:
		current_resource = snapshot.get("resource")
		field_infos = _get_editable_properties(current_resource) if current_resource != null else []
	current_path = String(snapshot.get("path", ""))
	current_file_mtime = int(snapshot.get("file_mtime", 0))
	is_new_document = bool(snapshot.get("new_document", false))
	dirty = true
	suppress_changes = false
	_rebuild_inspector()


func _on_undo_pressed() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot())
	_restore_snapshot(undo_stack.pop_back())


func _on_redo_pressed() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot())
	_restore_snapshot(redo_stack.pop_back())


func _document_id() -> String:
	if current_document.is_empty():
		return ""
	var values: Dictionary = current_document.get("values", {})
	var type_name := String(current_document.get("type_name", ""))
	var field := "result_id" if type_name == "RecipeDefinition" else "id"
	var value: Dictionary = values.get(field, {"kind": "nil"})
	if value.get("kind", "") in ["string", "string_name"]:
		return String(value.get("value", ""))
	if type_name == "WaveDefinition":
		value = values.get("wave_number", {"kind": "nil"})
	return String(value.get("value", ""))


func _resource_type_name(resource: Resource) -> String:
	var script := resource.get_script() as Script
	if script != null:
		var global_name := String(script.get_global_name())
		if not global_name.is_empty():
			return global_name
	return resource.get_class()


func _resource_id(resource: Resource, type_name: String) -> String:
	var field := "result_id" if type_name == "RecipeDefinition" else "id"
	if type_name == "WaveDefinition":
		field = "id"
	if _has_resource_property(resource, field):
		var value = resource.get(field)
		if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]:
			return str(value)
	if type_name == "WaveDefinition" and _has_resource_property(resource, "wave_number"):
		return str(resource.get("wave_number"))
	return ""


func _resource_display_name(resource: Resource, type_name: String) -> String:
	var id := _resource_id(resource, type_name)
	if _has_resource_property(resource, "name_key") and not str(resource.get("name_key")).is_empty():
		return "%s · %s" % [id, resource.get("name_key")]
	return id


func _has_resource_property(resource: Resource, property_name: String) -> bool:
	for info in resource.get_property_list():
		if String(info.get("name", "")) == property_name:
			return true
	return false


func _property_label(property_name: String) -> String:
	return property_name.replace("_", " ").capitalize()


func _object_property_type(property_info: Dictionary) -> String:
	var type_name := String(property_info.get("class_name", ""))
	if type_name.is_empty():
		type_name = String(property_info.get("hint_string", ""))
	return type_name if not type_name.is_empty() else "Resource"


func _reference_target_for_property(property_name: String) -> String:
	return String(REFERENCE_TARGETS.get(property_name, ""))


func _encoded_text(value: Dictionary) -> String:
	var kind := String(value.get("kind", ""))
	if kind == "nil": return ""
	if kind in ["string", "string_name", "int", "float", "bool"]: return str(value.get("value", ""))
	if kind == "resource": return String(value.get("path", ""))
	if kind == "inline_resource": return String(value.get("type_name", "Resource"))
	return JSON.stringify(value)


func _encoded_number(value: Dictionary) -> float:
	return float(value.get("value", 0.0)) if value.get("kind", "") in ["int", "float"] else 0.0


func _encoded_resource_label(value: Dictionary) -> String:
	if value.get("kind", "") == "nil": return "없음"
	if value.get("kind", "") == "resource": return String(value.get("path", ""))
	if value.get("kind", "") == "inline_resource": return "[내장 %s]" % value.get("type_name", "Resource")
	return _encoded_text(value)


func _show_validation_error(message: String) -> void:
	validation_messages.clear()
	_add_validation("error", message)
	_render_validation()
	_set_status("오류가 발생했습니다.")


func _add_validation(severity: String, message: String) -> void:
	validation_messages.append({"severity": severity, "message": message})


func _render_validation() -> void:
	if validation_text == null:
		return
	if validation_messages.is_empty():
		validation_text.text = "✓ 문제가 없습니다."
		return
	var lines: Array[String] = []
	for validation in validation_messages:
		var prefix := "[INFO]"
		if validation["severity"] == "warning": prefix = "[WARNING]"
		elif validation["severity"] == "error": prefix = "[ERROR]"
		lines.append("%s %s" % [prefix, validation["message"]])
	validation_text.text = "\n".join(lines)


func _has_error(messages: Array) -> bool:
	for message in messages:
		if String(message.get("severity", "")) == "error":
			return true
	return false


func _update_document_status() -> void:
	var name := "새 Resource" if current_path.is_empty() else _relative_to_project(current_path)
	status_label.text = ("* " if dirty else "") + name


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = ("* " if dirty else "") + message


func _path_within(path: String, root: String) -> bool:
	var normalized := path.replace("\\", "/").to_lower()
	var normalized_root := root.replace("\\", "/").trim_suffix("/").to_lower()
	return normalized == normalized_root or normalized.begins_with(normalized_root + "/")


func _bridge_call(operation: String, request: Dictionary) -> Dictionary:
	var executable := String(ProjectSettings.get_setting("application/config/godot_path", ""))
	if executable.is_empty():
		executable = OS.get_executable_path()
	if executable.is_empty() or not FileAccess.file_exists(executable):
		return {"ok": false, "error": "Godot executable를 찾을 수 없습니다. application/config/godot_path를 설정하세요."}
	var bridge_path := ProjectSettings.globalize_path(BRIDGE_SCRIPT_PATH)
	if not FileAccess.file_exists(bridge_path):
		return {"ok": false, "error": "Project Horn bridge script가 없습니다: %s" % bridge_path}
	var request_dir := ProjectSettings.globalize_path("res://.bridge_requests")
	if not DirAccess.dir_exists_absolute(request_dir):
		var directory_error := DirAccess.make_dir_recursive_absolute(request_dir)
		if directory_error != OK:
			return {"ok": false, "error": "Bridge request 폴더를 만들 수 없습니다: %s" % error_string(directory_error)}
	var request_stem := request_dir.path_join("project_horn_bridge_%d_%d" % [Time.get_unix_time_from_system(), OS.get_process_id()])
	var request_path := request_stem + ".json"
	var response_path := request_stem + ".response.json"
	var child_log_path := request_stem + ".log"
	request["response_path"] = response_path
	var file := FileAccess.open(request_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Bridge request 파일을 만들 수 없습니다."}
	request["project_root"] = project_root
	file.store_string(JSON.stringify(request))
	file.close()
	var args := PackedStringArray(["--headless", "--log-file", child_log_path, "--path", project_root, "--script", bridge_path, "--", operation, request_path])
	var process_id := OS.create_process(executable, args)
	if process_id < 0:
		DirAccess.remove_absolute(request_path)
		DirAccess.remove_absolute(child_log_path)
		return {"ok": false, "error": "Project Horn bridge 프로세스를 시작할 수 없습니다."}
	var response: Dictionary = {}
	var deadline := Time.get_ticks_msec() + 30000
	while response.is_empty() and Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(response_path):
			var response_file := FileAccess.open(response_path, FileAccess.READ)
			if response_file != null:
				var parsed = JSON.parse_string(response_file.get_as_text())
				if parsed is Dictionary and parsed.has("ok"):
					response = parsed
				response_file.close()
		if response.is_empty():
			OS.delay_msec(25)
	DirAccess.remove_absolute(request_path)
	DirAccess.remove_absolute(response_path)
	if not response.is_empty():
		DirAccess.remove_absolute(child_log_path)
		return response
	OS.kill(process_id)
	return {"ok": false, "error": "Project Horn bridge 응답 시간 초과(%d)." % process_id}


func _on_validate_all_pressed() -> void:
	if bridge_mode:
		_scan_workspace()
		validation_messages.clear()
		for message in project_validation:
			_add_validation(String(message.get("severity", "error")), String(message.get("message", "")))
		if validation_messages.is_empty():
			_add_validation("info", "Project-wide validation passed.")
		_render_validation()
		return
	_add_validation("info", "현재 로컬 테스트 Resource에는 Project-wide bridge가 없습니다.")
	_render_validation()
