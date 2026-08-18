extends SceneTree

const TestResourceScript = preload("res://test_resource.gd")
const ResourceEditorScript = preload("res://resource_editor.gd")
const TEST_PATH := "res://.resource_editor_smoke.tres"


func _init() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var resource := TestResourceScript.new()
	resource.text_value = "smoke"
	resource.integer_value = 7
	resource.float_value = 1.25
	resource.enabled = true
	resource.mode = 2

	var property_names := []
	for property_info in resource.get_property_list():
		if int(property_info.get("usage", 0)) & PROPERTY_USAGE_EDITOR:
			property_names.append(String(property_info["name"]))
	assert("text_value" in property_names)
	assert("integer_value" in property_names)
	assert("float_value" in property_names)
	assert("enabled" in property_names)
	assert("mode" in property_names)
	assert("texture" in property_names)
	assert("packed_scene" in property_names)
	assert("linked_resource" in property_names)

	assert(ResourceSaver.save(resource, TEST_PATH) == OK)
	var loaded := ResourceLoader.load(TEST_PATH) as TestResource
	assert(loaded != null)
	assert(loaded.text_value == "smoke")
	assert(loaded.integer_value == 7)
	assert(is_equal_approx(loaded.float_value, 1.25))
	assert(loaded.enabled)
	assert(loaded.mode == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

	var editor := ResourceEditorScript.new()
	get_root().add_child(editor)
	await process_frame
	editor._open_workspace(ProjectSettings.globalize_path("res://"))
	editor._create_new_resource()
	assert(editor.current_resource is TestResource)
	assert(editor.field_infos.size() == 8)
	assert(editor.inspector_fields.get_child_count() == 8)
	editor._on_field_changed("text_value", "ui smoke")
	var ui_test_path := ProjectSettings.globalize_path("res://.resource_editor_ui_smoke.tres")
	assert(editor._save_to_path(ui_test_path))
	editor._load_resource_from_path(ui_test_path)
	assert(editor.current_resource.text_value == "ui smoke")
	DirAccess.remove_absolute(ui_test_path)
	editor.queue_free()

	print("Resource Editor smoke test passed")
	quit()
