extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Earth Elemental"
	mob_type = "earth_elemental"
	max_hp = 160
	move_speed = 55.0
	damage = 20
	super._ready()
