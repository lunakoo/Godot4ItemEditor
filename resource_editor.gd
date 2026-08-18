extends Control

const TestResourceScript = preload("res://test_resource.gd")
const RESOURCE_TYPES = [
	{"label": "테스트 리소스", "script": TestResourceScript}
]
const SUPPORTED_EXTENSIONS = ["tres", "res"]
const RESOURCE_BASE_PROPERTIES = [
	"resource_name",
	"resource_path",
	"resource_local_to_scene",
	"resource_scene_unique_id",
	"script"
]
const PROPERTY_LABELS = {
	"text_value": "문자열",
	"integer_value": "정수",
	"float_value": "실수",
	"enabled": "활성화",
	"mode": "열거형",
	"texture": "텍스처",
	"packed_scene": "PackedScene",
	"linked_resource": "연결된 Resource"
}

var workspace_dir := ""
var current_resource: Resource
var current_path := ""
var dirty := false
var suppress_changes := false

var resource_entries = []
var field_infos = []
var field_controls = {}
var field_paths = {}
var validation_messages = []

var pending_action: Callable = Callable()
var pending_after_save: Callable = Callable()
var dialog_action := ""
var pending_field_name := ""
var pending_field_expected := ""

var resource_type_option: OptionButton
var search_input: LineEdit
var resource_list: ItemList
var workspace_path_label: Label
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
	workspace_dir = _default_workspace_dir()
	workspace_path_label.text = workspace_dir
	_refresh_resource_list()
	_show_empty_inspector()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_guard_unsaved(Callable(self, "_quit_application"))


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	main.add_child(toolbar)
	_add_toolbar_button(toolbar, "새로 만들기", Callable(self, "_on_new_pressed"))
	_add_toolbar_button(toolbar, "불러오기", Callable(self, "_on_load_pressed"))
	_add_toolbar_button(toolbar, "저장", Callable(self, "_on_save_pressed"))
	var save_as_button := _add_toolbar_button(toolbar, "다른 이름으로 저장", Callable(self, "_on_save_as_pressed"))
	save_as_button.custom_minimum_size.x = 150
	_add_toolbar_button(toolbar, "복제", Callable(self, "_on_duplicate_pressed"))
	_add_toolbar_button(toolbar, "삭제", Callable(self, "_on_delete_pressed"))
	_add_toolbar_button(toolbar, "폴더 열기", Callable(self, "_on_open_folder_pressed"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(status_label)

	var content := HSplitContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.split_offset = 300
	main.add_child(content)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	content.add_child(left_panel)
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 10)
	left_margin.add_theme_constant_override("margin_top", 10)
	left_margin.add_theme_constant_override("margin_right", 10)
	left_margin.add_theme_constant_override("margin_bottom", 10)
	left_panel.add_child(left_margin)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left_margin.add_child(left)
	left.add_child(_make_header("리소스 타입"))
	resource_type_option = OptionButton.new()
	resource_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_type_option.item_selected.connect(_on_resource_type_selected)
	left.add_child(resource_type_option)

	var folder_header := HBoxContainer.new()
	folder_header.add_child(_make_header("리소스 목록"))
	left.add_child(folder_header)
	workspace_path_label = Label.new()
	workspace_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace_path_label.tooltip_text = "현재 작업 폴더"
	workspace_path_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	left.add_child(workspace_path_label)

	search_input = LineEdit.new()
	search_input.placeholder_text = "검색..."
	search_input.clear_button_enabled = true
	search_input.text_changed.connect(func(_value: String) -> void: _refresh_resource_list())
	left.add_child(search_input)

	resource_list = ItemList.new()
	resource_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_list.select_mode = ItemList.SELECT_SINGLE
	resource_list.allow_reselect = true
	resource_list.item_selected.connect(_on_resource_list_selected)
	left.add_child(resource_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	content.add_child(right)
	right.add_child(_make_header("인스펙터"))

	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(inspector_scroll)
	inspector_fields = VBoxContainer.new()
	inspector_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_fields.add_theme_constant_override("separation", 6)
	inspector_scroll.add_child(inspector_fields)

	var validation_panel := PanelContainer.new()
	validation_panel.custom_minimum_size = Vector2(0, 135)
	right.add_child(validation_panel)
	var validation_margin := MarginContainer.new()
	validation_margin.add_theme_constant_override("margin_left", 10)
	validation_margin.add_theme_constant_override("margin_top", 8)
	validation_margin.add_theme_constant_override("margin_right", 10)
	validation_margin.add_theme_constant_override("margin_bottom", 8)
	validation_panel.add_child(validation_margin)
	var validation_box := VBoxContainer.new()
	validation_box.add_child(_make_header("검증"))
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
	delete_dialog.title = "리소스 삭제"
	delete_dialog.get_ok_button().text = "삭제"
	delete_dialog.get_cancel_button().text = "취소"
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_dialog)


func _add_toolbar_button(parent: HBoxContainer, text: String, callback: Callable) -> Button:
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
	resource_type_option.add_item("전체 리소스", -1)
	for index in range(RESOURCE_TYPES.size()):
		resource_type_option.add_item(RESOURCE_TYPES[index]["label"], index)
	resource_type_option.select(0)


func _default_workspace_dir() -> String:
	if FileAccess.file_exists("res://project.godot"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()


func _on_resource_type_selected(_index: int) -> void:
	_refresh_resource_list()


func _on_open_folder_pressed() -> void:
	_guard_unsaved(Callable(self, "_open_folder_dialog"))


func _open_folder_dialog() -> void:
	dialog_action = "folder"
	_configure_file_dialog(FileDialog.FILE_MODE_OPEN_DIR, [])
	file_dialog.current_dir = workspace_dir
	file_dialog.popup_centered()


func _on_directory_selected(path: String) -> void:
	if dialog_action != "folder":
		return
	dialog_action = ""
	workspace_dir = path.simplify_path()
	workspace_path_label.text = workspace_dir
	_refresh_resource_list()
	_set_status("작업 폴더를 열었습니다.")


func _refresh_resource_list() -> void:
	if resource_list == null or search_input == null:
		return
	resource_entries.clear()
	resource_list.clear()
	if workspace_dir.is_empty() or not DirAccess.dir_exists_absolute(workspace_dir):
		_set_status("작업 폴더를 찾을 수 없습니다.")
		return

	var paths := []
	_collect_resource_paths(workspace_dir, paths)
	paths.sort_custom(func(first: String, second: String) -> bool:
		return _relative_path(first).to_lower() < _relative_path(second).to_lower()
	)

	var query := search_input.text.strip_edges().to_lower()
	var selected_id := resource_type_option.get_selected_id()
	for path in paths:
		var relative := _relative_path(path)
		if not query.is_empty() and not relative.to_lower().contains(query):
			continue

		var loaded = ResourceLoader.load(path)
		if selected_id >= 0 and not _matches_registered_type(loaded, selected_id):
			continue

		var entry := {
			"path": path,
			"relative_path": relative,
			"resource": loaded,
			"load_error": loaded == null
		}
		resource_entries.append(entry)
		var display := relative
		if loaded == null:
			display += "  [로드 실패]"
		resource_list.add_item(display)
		resource_list.set_item_tooltip(resource_list.item_count - 1, path)

	_select_current_list_item()


func _collect_resource_paths(directory_path: String, paths: Array) -> void:
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
	var root := workspace_dir.trim_suffix("/").trim_suffix("\\")
	var prefix := root + "/"
	var normalized := path.replace("\\", "/")
	var normalized_root := root.replace("\\", "/")
	if normalized.begins_with(normalized_root + "/"):
		return normalized.trim_prefix(normalized_root + "/")
	return normalized


func _matches_registered_type(resource: Variant, type_index: int) -> bool:
	if resource == null or not resource is Resource:
		return false
	return resource.get_script() == RESOURCE_TYPES[type_index]["script"]


func _select_current_list_item() -> void:
	if current_path.is_empty():
		return
	for index in range(resource_entries.size()):
		if resource_entries[index]["path"] == current_path:
			resource_list.select(index)
			return


func _on_new_pressed() -> void:
	_guard_unsaved(Callable(self, "_create_new_resource"))


func _create_new_resource() -> void:
	var type_index := resource_type_option.get_selected_id()
	if type_index < 0 or type_index >= RESOURCE_TYPES.size():
		type_index = 0
	var created := RESOURCE_TYPES[type_index]["script"].new() as Resource
	if created == null:
		_show_validation_error("선택한 리소스 타입을 생성할 수 없습니다.")
		return
	current_resource = created
	current_path = ""
	dirty = true
	_rebuild_inspector()
	_set_status("새 리소스를 만들었습니다.")


func _on_load_pressed() -> void:
	_guard_unsaved(Callable(self, "_open_load_dialog"))


func _open_load_dialog() -> void:
	dialog_action = "load"
	_configure_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, [["*.tres,*.res", "Resource 파일"]])
	file_dialog.current_dir = workspace_dir
	file_dialog.popup_centered()


func _on_resource_list_selected(index: int) -> void:
	if index < 0 or index >= resource_entries.size():
		return
	var path: String = resource_entries[index]["path"]
	_guard_unsaved(Callable(self, "_load_resource_from_path").bind(path))


func _load_resource_from_path(path: String) -> void:
	var loaded = ResourceLoader.load(path)
	if loaded == null or not loaded is Resource:
		current_resource = null
		current_path = path
		dirty = false
		_rebuild_inspector()
		_show_validation_error("리소스를 로드할 수 없습니다: %s" % path)
		_set_status("로드에 실패했습니다.")
		return

	current_resource = loaded
	current_path = path
	dirty = false
	_select_type_for_resource(loaded)
	_rebuild_inspector()
	_set_status("리소스를 불러왔습니다.")
	_refresh_resource_list()


func _select_type_for_resource(resource: Resource) -> void:
	for index in range(RESOURCE_TYPES.size()):
		if _matches_registered_type(resource, index):
			resource_type_option.select(index + 1)
			return
	resource_type_option.select(0)


func _on_save_pressed() -> void:
	if current_resource == null:
		_show_validation_error("먼저 리소스를 새로 만들거나 불러오세요.")
		return
	if current_path.is_empty():
		_open_save_dialog(false)
	else:
		_save_to_path(current_path)


func _on_save_as_pressed() -> void:
	if current_resource == null:
		_show_validation_error("먼저 리소스를 새로 만들거나 불러오세요.")
		return
	_open_save_dialog(false)


func _open_save_dialog(for_pending_action: bool) -> void:
	dialog_action = "save_pending" if for_pending_action else "save"
	_configure_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, [["*.tres", "Text Resource"]])
	file_dialog.current_dir = workspace_dir
	file_dialog.current_file = _suggested_filename()
	file_dialog.popup_centered()


func _suggested_filename() -> String:
	if not current_path.is_empty():
		return current_path.get_file()
	if current_resource != null and not current_resource.resource_name.is_empty():
		return current_resource.resource_name + ".tres"
	return "new_resource.tres"


func _on_duplicate_pressed() -> void:
	if current_resource == null:
		_show_validation_error("복제할 리소스가 없습니다.")
		return
	_guard_unsaved(Callable(self, "_duplicate_current_resource"))


func _duplicate_current_resource() -> void:
	var copy := current_resource.duplicate(true) as Resource
	if copy == null:
		_show_validation_error("리소스를 복제할 수 없습니다.")
		return
	current_resource = copy
	current_path = ""
	dirty = true
	_rebuild_inspector()
	_set_status("리소스를 복제했습니다. 저장 위치를 선택하세요.")


func _on_delete_pressed() -> void:
	if current_resource == null and current_path.is_empty():
		_show_validation_error("삭제할 리소스가 없습니다.")
		return
	_guard_unsaved(Callable(self, "_confirm_delete"))


func _confirm_delete() -> void:
	if current_path.is_empty():
		_clear_current_resource()
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
	_refresh_resource_list()
	_set_status("리소스를 삭제했습니다.")


func _clear_current_resource() -> void:
	current_resource = null
	current_path = ""
	dirty = false
	_rebuild_inspector()


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
	var extension := path.get_extension().to_lower()
	if extension in SUPPORTED_EXTENSIONS:
		return path
	return path.get_basename() + ".tres"


func _save_to_path(path: String) -> bool:
	if current_resource == null:
		_show_validation_error("저장할 리소스가 없습니다.")
		return false
	if not _validate_current_resource():
		_set_status("검증 오류로 저장하지 않았습니다.")
		return false

	var error := ResourceSaver.save(current_resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		_add_validation("error", "저장 실패: %s" % error_string(error))
		_render_validation()
		_set_status("저장에 실패했습니다.")
		return false

	current_path = path
	workspace_dir = path.get_base_dir()
	workspace_path_label.text = workspace_dir
	dirty = false
	_refresh_resource_list()
	_rebuild_inspector()
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
	dirty = false
	if pending_action.is_valid():
		var next := pending_action
		pending_action = Callable()
		next.call()


func _on_dirty_cancel() -> void:
	pending_action = Callable()


func _quit_application() -> void:
	get_tree().quit()


func _rebuild_inspector() -> void:
	suppress_changes = true
	field_controls.clear()
	field_paths.clear()
	field_infos.clear()
	_clear_container(inspector_fields)

	if current_resource == null:
		suppress_changes = false
		_show_empty_inspector()
		return

	field_infos = _get_editable_properties(current_resource)
	if field_infos.is_empty():
		var empty_label := Label.new()
		empty_label.text = "편집 가능한 export 필드가 없습니다."
		inspector_fields.add_child(empty_label)
	else:
		for property_info in field_infos:
			_add_property_editor(property_info)

	suppress_changes = false
	_validate_current_resource()
	_update_document_status()


func _show_empty_inspector() -> void:
	_clear_container(inspector_fields)
	var label := Label.new()
	label.text = "리소스를 선택하거나 새로 만들기를 누르세요."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_fields.add_child(label)
	validation_messages.clear()
	_add_validation("info", "검사할 리소스가 없습니다.")
	_render_validation()
	_update_document_status()


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _get_editable_properties(resource: Resource) -> Array:
	var properties := []
	for property_info in resource.get_property_list():
		var property_name := String(property_info.get("name", ""))
		var usage := int(property_info.get("usage", 0))
		if property_name in RESOURCE_BASE_PROPERTIES:
			continue
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		properties.append(property_info)
	return properties


func _add_property_editor(property_info: Dictionary) -> void:
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
		TYPE_STRING:
			_add_string_editor(row, property_info, value)
		TYPE_INT:
			if int(property_info.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_ENUM:
				_add_enum_editor(row, property_info, value)
			else:
				_add_number_editor(row, property_info, value, true)
		TYPE_FLOAT:
			_add_number_editor(row, property_info, value, false)
		TYPE_BOOL:
			_add_bool_editor(row, property_name, value)
		TYPE_OBJECT:
			if _is_supported_object_property(property_info):
				_add_resource_editor(row, property_info, value)
			else:
				_add_unsupported_editor(row, property_info)
		_:
			_add_unsupported_editor(row, property_info)
	inspector_fields.add_child(row)


func _add_string_editor(row: HBoxContainer, property_info: Dictionary, value: Variant) -> void:
	var property_name := String(property_info["name"])
	var hint := int(property_info.get("hint", PROPERTY_HINT_NONE))
	if hint == PROPERTY_HINT_MULTILINE_TEXT:
		var text_edit := TextEdit.new()
		text_edit.custom_minimum_size = Vector2(0, 80)
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.text = String(value)
		text_edit.text_changed.connect(func() -> void:
			_on_field_changed(property_name, text_edit.text)
		)
		row.add_child(text_edit)
	else:
		var line_edit := LineEdit.new()
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.text = String(value)
		line_edit.text_changed.connect(func(new_text: String) -> void:
			_on_field_changed(property_name, new_text)
		)
		row.add_child(line_edit)


func _add_number_editor(row: HBoxContainer, property_info: Dictionary, value: Variant, integer: bool) -> void:
	var property_name := String(property_info["name"])
	var spin_box := SpinBox.new()
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.min_value = -1000000000.0
	spin_box.max_value = 1000000000.0
	spin_box.allow_greater = true
	spin_box.allow_lesser = true
	spin_box.step = 1.0 if integer else 0.01
	spin_box.value = float(value)
	spin_box.value_changed.connect(func(new_value: float) -> void:
		_on_field_changed(property_name, int(new_value) if integer else new_value)
	)
	row.add_child(spin_box)


func _add_bool_editor(row: HBoxContainer, property_name: String, value: Variant) -> void:
	var check_box := CheckBox.new()
	check_box.text = "사용"
	check_box.button_pressed = bool(value)
	check_box.toggled.connect(func(new_value: bool) -> void:
		_on_field_changed(property_name, new_value)
	)
	row.add_child(check_box)


func _add_enum_editor(row: HBoxContainer, property_info: Dictionary, value: Variant) -> void:
	var property_name := String(property_info["name"])
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := _parse_enum_options(String(property_info.get("hint_string", "")))
	for option_data in options:
		option.add_item(option_data["label"], option_data["value"])
	for index in range(options.size()):
		if options[index]["value"] == int(value):
			option.select(index)
			break
	option.item_selected.connect(func(index: int) -> void:
			_on_field_changed(property_name, option.get_item_id(index))
	)
	row.add_child(option)


func _parse_enum_options(hint_string: String) -> Array:
	var options := []
	var default_value := 0
	for entry in hint_string.split(","):
		var parts := entry.split(":")
		var label := parts[0]
		var value := default_value
		if parts.size() > 1:
			value = int(parts[1])
		options.append({"label": label, "value": value})
		default_value += 1
	return options


func _add_resource_editor(row: HBoxContainer, property_info: Dictionary, value: Variant) -> void:
	var property_name := String(property_info["name"])
	var expected := _object_property_type(property_info)
	var editor := HBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 6)

	var preview: TextureRect
	if expected == "Texture2D":
		preview = TextureRect.new()
		preview.custom_minimum_size = Vector2(56, 56)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		editor.add_child(preview)

	var value_label := Label.new()
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	editor.add_child(value_label)

	var select_button := Button.new()
	select_button.text = "찾기"
	select_button.pressed.connect(func() -> void:
		_open_asset_dialog(property_name, expected)
	)
	editor.add_child(select_button)
	var clear_button := Button.new()
	clear_button.text = "지우기"
	clear_button.pressed.connect(func() -> void:
		_set_resource_field(property_name, null, "")
	)
	editor.add_child(clear_button)

	field_controls[property_name] = {
		"value_label": value_label,
		"preview": preview,
		"expected": expected
	}
	_update_resource_editor(property_name, value)
	row.add_child(editor)


func _add_unsupported_editor(row: HBoxContainer, property_info: Dictionary) -> void:
	var label := Label.new()
	label.text = "지원하지 않는 타입: %s" % _property_type_name(property_info)
	label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
	row.add_child(label)


func _is_supported_object_property(property_info: Dictionary) -> bool:
	return _object_property_type(property_info) in ["Texture2D", "PackedScene", "Resource"]


func _object_property_type(property_info: Dictionary) -> String:
	var type_name := String(property_info.get("class_name", ""))
	if type_name.is_empty():
		type_name = String(property_info.get("hint_string", ""))
	if type_name.is_empty():
		return "Resource"
	if type_name in ["Texture2D", "PackedScene", "Resource"]:
		return type_name
	return type_name


func _property_type_name(property_info: Dictionary) -> String:
	if int(property_info.get("type", TYPE_NIL)) == TYPE_OBJECT:
		return _object_property_type(property_info)
	return type_string(int(property_info.get("type", TYPE_NIL)))


func _property_label(property_name: String) -> String:
	if PROPERTY_LABELS.has(property_name):
		return PROPERTY_LABELS[property_name]
	return property_name.replace("_", " ").capitalize()


func _on_field_changed(property_name: String, value: Variant) -> void:
	if suppress_changes or current_resource == null:
		return
	current_resource.set(property_name, value)
	dirty = true
	_validate_current_resource()
	_update_document_status()


func _open_asset_dialog(property_name: String, expected: String) -> void:
	pending_field_name = property_name
	pending_field_expected = expected
	dialog_action = "asset"
	var filters := []
	match expected:
		"Texture2D":
			filters = [["*.png,*.jpg,*.jpeg,*.webp,*.svg", "이미지"]]
		"PackedScene":
			filters = [["*.tscn,*.scn", "씬"]]
		_:
			filters = [["*.tres,*.res,*.tscn,*.scn", "Resource"]]
	_configure_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, filters)
	file_dialog.current_dir = workspace_dir
	file_dialog.popup_centered()


func _assign_asset_to_field(path: String) -> void:
	var value: Resource
	if pending_field_expected == "Texture2D":
		value = ResourceLoader.load(path) as Resource
		if value == null:
			var image := Image.new()
			if image.load(path) == OK:
				value = ImageTexture.create_from_image(image)
	else:
		value = ResourceLoader.load(path) as Resource

	if value == null:
		_add_validation("error", "리소스를 로드할 수 없습니다: %s" % path)
		_render_validation()
		return
	if not _matches_expected_resource(value, pending_field_expected):
		_add_validation("error", "필드 타입과 선택한 파일 타입이 다릅니다: %s" % path)
		_render_validation()
		return
	_set_resource_field(pending_field_name, value, path)
	pending_field_name = ""
	pending_field_expected = ""


func _matches_expected_resource(value: Resource, expected: String) -> bool:
	match expected:
		"Texture2D":
			return value is Texture2D
		"PackedScene":
			return value is PackedScene
		"Resource":
			return true
		_:
			return false


func _set_resource_field(property_name: String, value: Resource, path: String) -> void:
	if current_resource == null:
		return
	current_resource.set(property_name, value)
	field_paths[property_name] = path
	dirty = true
	_update_resource_editor(property_name, value)
	_validate_current_resource()
	_update_document_status()


func _update_resource_editor(property_name: String, value: Variant) -> void:
	if not field_controls.has(property_name):
		return
	var control_data: Dictionary = field_controls[property_name]
	var value_label: Label = control_data["value_label"]
	var preview: TextureRect = control_data["preview"]
	if value == null:
		value_label.text = "없음"
		value_label.tooltip_text = ""
		if preview != null:
			preview.texture = null
		return
	var path := String(field_paths.get(property_name, ""))
	if value is Resource and path.is_empty():
		path = value.resource_path
	value_label.text = path.get_file() if not path.is_empty() else "[내장 리소스]"
	value_label.tooltip_text = path if not path.is_empty() else str(value)
	if preview != null:
		preview.texture = value as Texture2D


func _validate_current_resource() -> bool:
	validation_messages.clear()
	if current_resource == null:
		_add_validation("info", "검사할 리소스가 없습니다.")
		_render_validation()
		return true

	var has_error := false
	for property_info in field_infos:
		var property_name := String(property_info["name"])
		var type := int(property_info.get("type", TYPE_NIL))
		if not _is_supported_property(property_info):
			_add_validation("error", "%s 필드는 지원하지 않는 타입입니다." % _property_label(property_name))
			has_error = true
			continue
		var value = current_resource.get(property_name)
		if type == TYPE_STRING and String(value).strip_edges().is_empty():
			_add_validation("warning", "%s 값이 비어 있습니다." % _property_label(property_name))
		if type == TYPE_OBJECT and value != null:
			var expected := _object_property_type(property_info)
			if not _matches_expected_resource(value as Resource, expected):
				_add_validation("error", "%s 필드의 타입이 올바르지 않습니다." % _property_label(property_name))
				has_error = true

	_render_validation()
	return not has_error


func _is_supported_property(property_info: Dictionary) -> bool:
	var type := int(property_info.get("type", TYPE_NIL))
	return type in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL] or (type == TYPE_OBJECT and _is_supported_object_property(property_info))


func _add_validation(severity: String, message: String) -> void:
	validation_messages.append({"severity": severity, "message": message})


func _show_validation_error(message: String) -> void:
	validation_messages.clear()
	_add_validation("error", message)
	_render_validation()
	_set_status("오류가 발생했습니다.")


func _render_validation() -> void:
	if validation_text == null:
		return
	if validation_messages.is_empty():
		validation_text.text = "✓ 문제가 없습니다."
		return
	var lines := []
	for validation in validation_messages:
		var prefix := "[정보]"
		if validation["severity"] == "warning":
			prefix = "[경고]"
		elif validation["severity"] == "error":
			prefix = "[오류]"
		lines.append("%s %s" % [prefix, validation["message"]])
	validation_text.text = "\n".join(lines)


func _update_document_status() -> void:
	var document_name := "새 리소스" if current_path.is_empty() else _relative_path(current_path)
	status_label.text = ("* " if dirty else "") + document_name


func _set_status(message: String) -> void:
	if status_label == null:
		return
	status_label.text = ("* " if dirty else "") + message
