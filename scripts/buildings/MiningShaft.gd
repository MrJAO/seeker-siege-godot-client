extends Node2D

@export var building_level: int = 1

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_update_sprite()

func _update_sprite() -> void:
	var path: String = "res://assets/mining/mining_shaft.png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		push_warning("MiningShaft: missing art at %s" % path)
