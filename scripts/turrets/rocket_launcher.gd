extends "res://scripts/turrets/base_turret.gd"

func _ready():
	turret_type = "rocket_launcher"
	damage = 80
	fire_rate = 3.0
	attack_range = 364.0
	strong_against = ["terra_golem", "iron_colossus"]
	weak_against = ["storm_leviathan"]
	targeting_mode = "strongest"
	super._ready()

func update_sprite():
	var path = "res://assets/turrets/rocket_launcher/rocket_launcher_level%d.png" % tier
	if ResourceLoader.exists(path):
		$Sprite.texture = load(path)
