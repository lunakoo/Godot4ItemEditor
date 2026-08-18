extends SceneTree

const ResourceEditorScript = preload("res://resource_editor.gd")


func _init() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var args := OS.get_cmdline_user_args()
	assert(not args.is_empty())
	var project_path := String(args[0]).simplify_path()
	assert(FileAccess.file_exists(project_path.path_join("project.godot")))

	var editor := ResourceEditorScript.new()
	get_root().add_child(editor)
	await process_frame
	editor._open_workspace(project_path)
	assert(editor.bridge_mode)
	assert(editor.resource_entries.size() >= 50)
	assert(editor.project_validation.is_empty())

	var target_path := ""
	for entry in editor.resource_entries:
		if String(entry.get("type_name", "")) == "EnemyDefinition":
			target_path = String(entry.get("path", ""))
			break
	assert(not target_path.is_empty())
	editor._load_resource_from_path(target_path)
	assert(String(editor.current_document.get("type_name", "")) == "EnemyDefinition")

	var field_name := ""
	var original := {}
	for property_info in editor.field_infos:
		if String(property_info.get("kind", "field")) == "field" and int(property_info.get("type", TYPE_NIL)) == TYPE_INT:
			field_name = String(property_info.get("name", ""))
			original = editor._value_at_path([field_name]).duplicate(true)
			break
	assert(not field_name.is_empty())
	var changed := original.duplicate(true)
	changed["value"] = int(original.get("value", 0)) + 1
	editor._set_external_value(changed, [field_name])
	assert(editor.dirty)
	editor._discard_current_changes()
	assert(not editor.dirty)
	assert(editor._value_at_path([field_name]) == original)

	print("Project Horn bridge smoke test passed")
	editor.queue_free()
	quit()
