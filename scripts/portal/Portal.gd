extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

const ROTATE_SPEED: float = 0.3 # radians/sec - slow, non-stop loop

func _process(delta: float) -> void:
	sprite.rotation += ROTATE_SPEED * delta
