extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Dark Phantom"
	mob_type = "dark_phantom"
	max_hp = 100
	move_speed = 60.0
	damage = 15
	super._ready()
