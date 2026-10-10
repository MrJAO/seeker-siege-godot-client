extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Shadow Imp"
	mob_type = "shadow_imp"
	max_hp = 60
	move_speed = 110.0
	damage = 8
	super._ready()
