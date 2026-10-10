extends "res://scripts/turrets/base_turret.gd"

func _ready():
	turret_type = "railgun"
	damage = 100
	fire_rate = 4.0
	attack_range = 468.0
	strong_against = ["iron_colossus", "terra_golem"]
	weak_against = ["cyber_phoenix"]
	targeting_mode = "strongest"
	super._ready()

func update_sprite():
	var path = "res://assets/turrets/railgun/railgun_level%d.png" % tier
	if ResourceLoader.exists(path):
		$Sprite.texture = load(path)
