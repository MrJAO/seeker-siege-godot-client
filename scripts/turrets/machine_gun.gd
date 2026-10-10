extends "res://scripts/turrets/base_turret.gd"

func _ready():
	turret_type = "machine_gun"
	damage = 35
	fire_rate = 1.0
	attack_range = 260.0
	strong_against = ["cyber_phoenix", "storm_leviathan"]
	weak_against = ["terra_golem"]
	targeting_mode = "nearest"
	super._ready()

func update_sprite():
	var path = "res://assets/turrets/machine_gun/machinegun_level%d.png" % tier
	if ResourceLoader.exists(path):
		$Sprite.texture = load(path)
