extends "res://scripts/turrets/base_turret.gd"

func _ready():
	turret_type = "freeze_ray"
	damage = 55
	fire_rate = 2.0
	attack_range = 260.0
	strong_against = ["void_wraith", "storm_leviathan"]
	weak_against = ["iron_colossus"]
	targeting_mode = "nearest"
	super._ready()

func update_sprite():
	var path = "res://assets/turrets/freeze_ray/freeze_ray_level%d.png" % tier
	if ResourceLoader.exists(path):
		$Sprite.texture = load(path)
