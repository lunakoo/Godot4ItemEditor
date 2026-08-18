class_name TestResource
extends Resource

@export var text_value: String = ""
@export var integer_value: int = 0
@export var float_value: float = 0.0
@export var enabled: bool = false
@export_enum("대기", "공격", "방어") var mode: int = 0
@export var texture: Texture2D
@export var packed_scene: PackedScene
@export var linked_resource: Resource
