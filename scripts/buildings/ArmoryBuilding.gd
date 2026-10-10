extends Node2D

@export var building_level: int = 1

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_update_sprite()

func _update_sprite() -> void:
	var path: String = "res://assets/armory/armory_level%d.png" % building_level
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		push_warning("ArmoryBuilding: missing art at %s" % path)
