extends SceneTree

## Runs inside the selected Project Horn project. The standalone editor owns
## the UI; this process owns ResourceLoader/ResourceSaver and the game's scripts.

const SUPPORTED_EXTENSIONS := ["tres", "res"]
const RESOURCE_BASE_PROPERTIES := [
	"resource_name",
	"resource_path",
	"resource_local_to_scene",
	"resource_scene_unique_id",
	"script"
]

const TYPE_REGISTRY := {
	"GameRuleDefinition": {"global": true, "id_field": "id"},
	"HeroDefinition": {"global": true, "id_field": "id"},
	"SkillDefinition": {"global": true, "id_field": "id"},
	"EnemyDefinition": {"global": true, "id_field": "id"},
	"WaveDefinition": {"global": true, "id_field": "id", "fallback_field": "wave_number"},
	"BossDefinition": {"global": true, "id_field": "id"},
	"ItemDefinition": {"global": true, "id_field": "id"},
	"RecipeDefinition": {"global": true, "id_field": "result_id", "fallback_field": "id"},
	"AugmentDefinition": {"global": true, "id_field": "id"},
	"TurretDefinition": {"global": true, "id_field": "id"},
	"RegionDefinition": {"global": true, "id_field": "id"},
	"MapLayoutDefinition": {"global": false, "id_field": "id"},
	"BossPhaseDefinition": {"global": false, "id_field": "id"},
	"BossPatternDefinition": {"global": false, "id_field": "id"},
	"BossDifficultyDefinition": {"global": false, "id_field": "id"},
	"SkillLevelDefinition": {"global": false, "id_field": "level"},
	"SkillSpecialParameters": {"global": false, "id_field": ""},
	"EnemyBehaviorDefinition": {"global": false, "id_field": "id"},
	"ItemEffectDefinition": {"global": false, "id_field": ""},
	"StatModifierDefinition": {"global": false, "id_field": ""}
}

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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var result: Dictionary
	var response_path := ""
	if args.is_empty():
		result = _error("Bridge operation is missing.")
	else:
		var operation := String(args[0])
		var request := _read_request(String(args[1])) if args.size() > 1 else {}
		response_path = String(request.get("response_path", ""))
		if request.is_empty() and args.size() > 1:
			result = _error("Bridge request could not be read.")
		else:
			project_root = String(request.get("project_root", ProjectSettings.globalize_path("res://")))
			match operation:
				"scan":
					result = _scan(request)
				"inspect":
					result = _inspect(String(request.get("path", "")))
				"create":
					result = _create(String(request.get("script_path", "")))
				"save":
					result = _save(request)
				"references":
					result = _references(request)
				_:
					result = _error("Unknown bridge operation: %s" % operation)

	if response_path.is_empty():
		print(JSON.stringify(result))
	else:
		_write_response(response_path, result)
	quit()


func _read_request(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_response(path: String, result: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(result))
	file.close()


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _inspect(path: String) -> Dictionary:
	var resource := _load_resource(path)
	if resource == null:
		return _error("Failed to load Resource: %s" % path)
	var data := _serialize_resource(resource)
	data["ok"] = true
	data["path"] = path
	return data


func _create(script_path: String) -> Dictionary:
	if script_path.is_empty():
		return _error("Resource script path is missing.")
	var script := ResourceLoader.load(script_path) as Script
	if script == null:
		return _error("Failed to load Resource script: %s" % script_path)
	var resource := script.new() as Resource
	if resource == null:
		return _error("Resource script cannot create an instance: %s" % script_path)
	var data := _serialize_resource(resource)
	data["ok"] = true
	return data


func _save(request: Dictionary) -> Dictionary:
	var target_path := String(request.get("target_path", ""))
	if target_path.is_empty():
		return _error("Save target is missing.")
	if not _is_within_project(target_path):
		return _error("Save target is outside the selected Project Horn project.")

	var source_path := String(request.get("source_path", ""))
	var resource: Resource
	if source_path.is_empty():
		var script_path := String(request.get("script_path", ""))
		var script := ResourceLoader.load(script_path) as Script
		if script == null:
			return _error("Failed to load Resource script: %s" % script_path)
		resource = script.new() as Resource
	else:
		resource = _load_resource(source_path)
	if resource == null:
		return _error("Failed to load source Resource: %s" % source_path)

	var values: Variant = request.get("values", {})
	if not values is Dictionary:
		return _error("Save values are invalid.")
	var apply_error := _apply_values(resource, values)
	if not apply_error.is_empty():
		return _error(apply_error)

	var engine_target_path := _to_engine_path(target_path)
	var error := ResourceSaver.save(resource, engine_target_path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		return _error("ResourceSaver failed: %s" % error_string(error))

	var reloaded := ResourceLoader.load(engine_target_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	if reloaded == null:
		return _error("Saved Resource could not be reloaded: %s" % target_path)
	var data := _serialize_resource(reloaded)
	data["ok"] = true
	data["path"] = target_path
	return data


func _load_resource(path: String) -> Resource:
	if path.is_empty():
		return null
	return ResourceLoader.load(_to_engine_path(path), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource


func _to_engine_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	var normalized := path.replace("\\", "/")
	var root := project_root.replace("\\", "/").trim_suffix("/")
	if normalized.to_lower().begins_with(root.to_lower() + "/"):
		return "res://" + normalized.substr(root.length() + 1)
	return path


func _scan(request: Dictionary) -> Dictionary:
	var data_root := String(request.get("data_root", ""))
	if data_root.is_empty() or not DirAccess.dir_exists_absolute(data_root):
		return _error("Data root does not exist: %s" % data_root)
	var paths: Array[String] = []
	_collect_resource_paths(data_root, paths)
	paths.sort()

	var entries: Array[Dictionary] = []
	for path in paths:
		var resource := _load_resource(path)
		if resource == null:
			entries.append({
				"path": path,
				"relative_path": _relative_path(path, data_root),
				"type_name": "",
				"script_path": "",
				"id": "",
				"display_name": "",
				"load_error": true,
				"validation": [{"severity": "error", "message": "Resource load failed."}]
			})
			continue
		var serialized := _serialize_resource(resource)
		var type_name := String(serialized.get("type_name", "Resource"))
		var entry := {
			"path": path,
			"relative_path": _relative_path(path, data_root),
			"type_name": type_name,
			"script_path": String(serialized.get("script_path", "")),
			"id": _resource_id(resource, type_name),
			"display_name": _resource_display_name(resource, type_name),
			"load_error": false,
			"validation": []
		}
		entries.append(entry)

	var validation := _validate_project(entries, paths)
	for entry in entries:
		entry["validation"] = validation.get(String(entry["path"]), [])
	return {
		"ok": true,
		"entries": entries,
		"validation": validation.get("__project__", []),
		"types": _type_summary(entries)
	}


func _references(request: Dictionary) -> Dictionary:
	var data_root := String(request.get("data_root", ""))
	var target_type := String(request.get("target_type", ""))
	var target_id := String(request.get("target_id", ""))
	if data_root.is_empty() or target_type.is_empty() or target_id.is_empty():
		return _error("Reference query is incomplete.")
	var paths: Array[String] = []
	_collect_resource_paths(data_root, paths)
	var results: Array[Dictionary] = []
	for path in paths:
		var resource := _load_resource(path)
		if resource == null:
			continue
		var serialized := _serialize_resource(resource)
		var type_name := String(serialized.get("type_name", ""))
		var values: Dictionary = serialized.get("values", {})
		var properties: Array = serialized.get("properties", [])
		for property_info in properties:
			if not property_info is Dictionary or String(property_info.get("kind", "field")) != "field":
				continue
			var property_name := String(property_info.get("name", ""))
			if _contains_reference(values.get(property_name, {"kind": "nil"}), property_name, target_type, target_id):
				results.append({
					"path": path,
					"relative_path": _relative_path(path, data_root),
					"type_name": type_name,
					"field": property_name
				})
	return {"ok": true, "references": results}


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


func _relative_path(path: String, root: String) -> String:
	var normalized := path.replace("\\", "/")
	var normalized_root := root.replace("\\", "/").trim_suffix("/")
	return normalized.trim_prefix(normalized_root + "/")


func _is_within_project(path: String) -> bool:
	var normalized := path.replace("\\", "/").to_lower()
	var root := project_root.replace("\\", "/").trim_suffix("/").to_lower()
	return normalized == root or normalized.begins_with(root + "/")


func _type_summary(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var counts := {}
	var scripts := {}
	for entry in entries:
		var type_name := String(entry.get("type_name", ""))
		if type_name.is_empty():
			continue
		counts[type_name] = int(counts.get(type_name, 0)) + 1
		scripts[type_name] = entry.get("script_path", "")
	for type_name in counts.keys():
		result.append({
			"type_name": type_name,
			"count": counts[type_name],
			"script_path": scripts[type_name]
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["type_name"]) < String(right["type_name"])
	)
	return result


func _validate_project(entries: Array[Dictionary], paths: Array[String]) -> Dictionary:
	var global_by_key := {}
	var all_by_id := {}
	var by_path := {}
	for entry in entries:
		by_path[String(entry["path"])] = entry
		if bool(entry.get("load_error", false)):
			continue
		var type_name := String(entry.get("type_name", ""))
		var id := String(entry.get("id", ""))
		if not id.is_empty():
			if not all_by_id.has(id):
				all_by_id[id] = []
			all_by_id[id].append(entry)
		var type_info: Dictionary = TYPE_REGISTRY.get(type_name, {})
		if not bool(type_info.get("global", false)) or id.is_empty():
			continue
		var key := type_name + ":" + id
		if not global_by_key.has(key):
			global_by_key[key] = []
		global_by_key[key].append(entry)

	var result := {"__project__": []}
	for key in global_by_key.keys():
		var duplicate_entries: Array = global_by_key[key]
		if duplicate_entries.size() < 2:
			continue
		var duplicate_id := String(duplicate_entries[0].get("id", key))
		var paths_text: Array[String] = []
		for entry in duplicate_entries:
			paths_text.append(String(entry["relative_path"]))
		var message := {
			"severity": "error",
			"message": "Duplicate global ID '%s': %s" % [duplicate_id, ", ".join(paths_text)]
		}
		result["__project__"].append(message)
		for entry in duplicate_entries:
			_add_entry_message(result, String(entry["path"]), message)

	for entry in entries:
		if bool(entry.get("load_error", false)):
			continue
		var resource := _load_resource(String(entry["path"]))
		if resource == null:
			continue
		var serialized := _serialize_resource(resource)
		var properties: Array = serialized.get("properties", [])
		var values: Dictionary = serialized.get("values", {})
		var type_name := String(entry.get("type_name", ""))
		for property_info in properties:
			if not property_info is Dictionary or String(property_info.get("kind", "field")) != "field":
				continue
			var property_name := String(property_info.get("name", ""))
			var value: Dictionary = values.get(property_name, {"kind": "nil"})
			var range_message := _range_message(property_info, value)
			if not range_message.is_empty():
				_add_entry_message(result, String(entry["path"]), {"severity": "error", "message": range_message})
			var target_type := _reference_target(type_name, property_name)
			if not target_type.is_empty():
				_validate_reference(result, entry, property_name, value, target_type, all_by_id, by_path)
	return result


func _add_entry_message(result: Dictionary, path: String, message: Dictionary) -> void:
	if not result.has(path):
		result[path] = []
	result[path].append(message)


func _range_message(property_info: Dictionary, value: Dictionary) -> String:
	if int(property_info.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RANGE:
		return ""
	var parts := String(property_info.get("hint_string", "")).split(",")
	if parts.size() < 2 or value.get("kind", "") not in ["int", "float"]:
		return ""
	var number := float(value.get("value", 0.0))
	var minimum := float(parts[0])
	var maximum := float(parts[1])
	if number < minimum or number > maximum:
		return "%s is outside the allowed range %s..%s." % [String(property_info.get("name", "field")), minimum, maximum]
	return ""


func _reference_target(_type_name: String, property_name: String) -> String:
	return String(REFERENCE_TARGETS.get(property_name, ""))


func _validate_reference(result: Dictionary, entry: Dictionary, property_name: String, value: Dictionary, target_type: String, by_type_and_id: Dictionary, by_path: Dictionary) -> void:
	if value.get("kind", "") == "array":
		for item in value.get("values", []):
			_validate_reference(result, entry, property_name, item, target_type, by_type_and_id, by_path)
		return
	if value.get("kind", "") == "string_name":
		var id := String(value.get("value", ""))
		if id.is_empty():
			return
		if target_type == "ItemDefinition" and id == "gold":
			return
		elif not _has_target(by_type_and_id, target_type, id):
			_add_entry_message(result, String(entry["path"]), {"severity": "error", "message": "%s references missing %s '%s'." % [property_name, target_type, id]})
		return
	if value.get("kind", "") == "resource":
		var path := String(value.get("path", ""))
		if path.is_empty():
			return
		var absolute := ProjectSettings.globalize_path(path)
		if not by_path.has(absolute):
			_add_entry_message(result, String(entry["path"]), {"severity": "error", "message": "%s references a missing Resource: %s" % [property_name, path]})


func _has_target(by_type_and_id: Dictionary, target_type: String, id: String) -> bool:
	for entry in by_type_and_id.get(id, []):
		if String(entry.get("type_name", "")) == target_type:
			return true
	return false


func _contains_reference(value: Dictionary, property_name: String, target_type: String, target_id: String) -> bool:
	if value.get("kind", "") == "array":
		for item in value.get("values", []):
			if _contains_reference(item, property_name, target_type, target_id):
				return true
		return false
	if value.get("kind", "") == "string_name":
		return String(value.get("value", "")) == target_id
	if value.get("kind", "") == "resource":
		var resource := _load_resource(String(value.get("path", "")))
		return resource != null and _resource_type_name(resource) == target_type and _resource_id(resource, target_type) == target_id
	return false


func _serialize_resource(resource: Resource, depth: int = 0) -> Dictionary:
	var type_name := _resource_type_name(resource)
	var properties: Array[Dictionary] = []
	var values := {}
	for raw_info in resource.get_property_list():
		var info: Dictionary = raw_info
		var usage := int(info.get("usage", 0))
		var group_name := String(info.get("name", ""))
		var is_base_group := group_name in ["RefCounted", "Resource"] or group_name.ends_with(".gd")
		if (usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_CATEGORY) and not is_base_group:
			properties.append({
				"kind": "group",
				"name": group_name,
				"label": group_name,
				"usage": usage
			})
			continue
		var property_name := String(info.get("name", ""))
		if property_name in RESOURCE_BASE_PROPERTIES or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var property_info := _serialize_property_info(info)
		properties.append(property_info)
		values[property_name] = _encode_variant(resource.get(property_name), depth + 1)
	return {
		"type_name": type_name,
		"script_path": _script_path(resource),
		"properties": properties,
		"values": values
	}


func _serialize_property_info(info: Dictionary) -> Dictionary:
	var property_info := {
		"kind": "field",
		"name": String(info.get("name", "")),
		"type": int(info.get("type", TYPE_NIL)),
		"type_name": type_string(int(info.get("type", TYPE_NIL))),
		"hint": int(info.get("hint", PROPERTY_HINT_NONE)),
		"hint_string": String(info.get("hint_string", "")),
		"class_name": String(info.get("class_name", "")),
		"usage": int(info.get("usage", 0))
	}
	return property_info


func _encode_variant(value: Variant, depth: int = 0) -> Dictionary:
	if value == null:
		return {"kind": "nil"}
	match typeof(value):
		TYPE_BOOL:
			return {"kind": "bool", "value": value}
		TYPE_INT:
			return {"kind": "int", "value": value}
		TYPE_FLOAT:
			return {"kind": "float", "value": value}
		TYPE_STRING:
			return {"kind": "string", "value": value}
		TYPE_STRING_NAME:
			return {"kind": "string_name", "value": str(value)}
		TYPE_VECTOR2:
			return {"kind": "vector2", "x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"kind": "vector3", "x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR4:
			return {"kind": "vector4", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_RECT2:
			return {"kind": "rect2", "x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_COLOR:
			return {"kind": "color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector_values: Array = []
			for item in value:
				vector_values.append(_encode_variant(item, depth + 1))
			return {"kind": "packed_vector2_array", "values": vector_values}
		TYPE_ARRAY:
			var array_values: Array = []
			for item in value:
				array_values.append(_encode_variant(item, depth + 1))
			return {"kind": "array", "values": array_values}
		TYPE_DICTIONARY:
			var pairs: Array = []
			for key in value.keys():
				pairs.append({"key": _encode_variant(key, depth + 1), "value": _encode_variant(value[key], depth + 1)})
			return {"kind": "dictionary", "pairs": pairs}
		TYPE_OBJECT:
			if value is Resource:
				return _encode_resource(value, depth)
	return {"kind": "text", "value": str(value)}


func _encode_resource(resource: Resource, depth: int) -> Dictionary:
	var type_name := _resource_type_name(resource)
	var path := resource.resource_path
	if not path.is_empty() or depth > 6:
		return {"kind": "resource", "path": path, "type_name": type_name}
	var data := _serialize_resource(resource, depth + 1)
	data["kind"] = "inline_resource"
	return data


func _decode_variant(encoded: Variant, template: Variant = null) -> Variant:
	if not encoded is Dictionary:
		return encoded
	var kind := String(encoded.get("kind", ""))
	match kind:
		"nil":
			return null
		"bool", "int", "float", "string":
			return encoded.get("value")
		"string_name":
			return StringName(String(encoded.get("value", "")))
		"vector2":
			return Vector2(float(encoded.get("x", 0.0)), float(encoded.get("y", 0.0)))
		"vector3":
			return Vector3(float(encoded.get("x", 0.0)), float(encoded.get("y", 0.0)), float(encoded.get("z", 0.0)))
		"vector4":
			return Vector4(float(encoded.get("x", 0.0)), float(encoded.get("y", 0.0)), float(encoded.get("z", 0.0)), float(encoded.get("w", 0.0)))
		"rect2":
			return Rect2(float(encoded.get("x", 0.0)), float(encoded.get("y", 0.0)), float(encoded.get("w", 0.0)), float(encoded.get("h", 0.0)))
		"color":
			return Color(float(encoded.get("r", 0.0)), float(encoded.get("g", 0.0)), float(encoded.get("b", 0.0)), float(encoded.get("a", 1.0)))
		"packed_vector2_array":
			var packed := PackedVector2Array()
			for item in encoded.get("values", []):
				var decoded_item = _decode_variant(item)
				if decoded_item is Vector2:
					packed.append(decoded_item)
			return packed
		"array":
			var array_value: Array = template.duplicate(true) if template is Array else []
			array_value.clear()
			for item in encoded.get("values", []):
				array_value.append(_decode_variant(item))
			return array_value
		"dictionary":
			var dictionary_value: Dictionary = template.duplicate(true) if template is Dictionary else {}
			dictionary_value.clear()
			for pair in encoded.get("pairs", []):
				if pair is Dictionary:
					dictionary_value[_decode_variant(pair.get("key", {"kind": "nil"}))] = _decode_variant(pair.get("value", {"kind": "nil"}))
			return dictionary_value
		"resource":
			return _load_resource(String(encoded.get("path", "")))
		"inline_resource":
			var inline: Resource
			if template is Resource:
				inline = template.duplicate(true) as Resource
			if inline == null:
				var script := ResourceLoader.load(String(encoded.get("script_path", ""))) as Script
				inline = script.new() as Resource if script != null else null
			if inline == null:
				return null
			var error := _apply_values(inline, encoded.get("values", {}))
			return null if not error.is_empty() else inline
	return encoded.get("value")


func _apply_values(resource: Resource, values: Dictionary) -> String:
	for property_name in values.keys():
		var name := String(property_name)
		var property_exists := false
		for info in resource.get_property_list():
			if String(info.get("name", "")) == name:
				property_exists = true
				break
		if not property_exists:
			continue
		var template = resource.get(name)
		var decoded = _decode_variant(values[property_name], template)
		resource.set(name, decoded)
	return ""


func _resource_type_name(resource: Resource) -> String:
	var script := resource.get_script() as Script
	if script != null:
		var global_name := String(script.get_global_name())
		if not global_name.is_empty():
			return global_name
	return resource.get_class()


func _script_path(resource: Resource) -> String:
	var script := resource.get_script() as Script
	return script.resource_path if script != null else ""


func _resource_id(resource: Resource, type_name: String) -> String:
	var type_info: Dictionary = TYPE_REGISTRY.get(type_name, {})
	var id_field := String(type_info.get("id_field", "id"))
	if not id_field.is_empty() and _has_property(resource, id_field):
		var value = resource.get(id_field)
		if typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING:
			return String(value)
		if typeof(value) == TYPE_INT:
			return str(value)
	var fallback_field := String(type_info.get("fallback_field", ""))
	if not fallback_field.is_empty() and _has_property(resource, fallback_field):
		return str(resource.get(fallback_field))
	return ""


func _resource_display_name(resource: Resource, _type_name: String) -> String:
	var id := _resource_id(resource, _type_name)
	if _has_property(resource, "name_key"):
		var name_key = resource.get("name_key")
		if not str(name_key).is_empty():
			return "%s · %s" % [id, name_key]
	return id


func _has_property(resource: Resource, property_name: String) -> bool:
	for info in resource.get_property_list():
		if String(info.get("name", "")) == property_name:
			return true
	return false
