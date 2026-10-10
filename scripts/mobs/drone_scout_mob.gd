extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Drone Scout"
	mob_type = "drone_scout"
	max_hp = 60
	move_speed = 110.0
	damage = 8
	super._ready()
