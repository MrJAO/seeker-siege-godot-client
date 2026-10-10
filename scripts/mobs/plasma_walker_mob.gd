extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Plasma Walker"
	mob_type = "plasma_walker"
	max_hp = 260
	move_speed = 35.0
	damage = 30
	super._ready()
