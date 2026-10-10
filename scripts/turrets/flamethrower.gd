extends "res://scripts/turrets/base_turret.gd"

func _ready():
	turret_type = "flamethrower"
	damage = 50
	fire_rate = 1.5
	attack_range = 156.0
	strong_against = ["terra_golem", "void_wraith"]
	weak_against = ["storm_leviathan"]
	targeting_mode = "nearest"
	super._ready()

func update_sprite():
	var path = "res://assets/turrets/flamethrower/flamethrower_level%d.png" % tier
	if ResourceLoader.exists(path):
		$Sprite.texture = load(path)
