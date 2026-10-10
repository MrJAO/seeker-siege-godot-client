extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Nightmare"
	mob_type = "nightmare"
	max_hp = 260
	move_speed = 35.0
	damage = 30
	super._ready()
