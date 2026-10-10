extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Shade Walker"
	mob_type = "shade_walker"
	max_hp = 160
	move_speed = 55.0
	damage = 20
	super._ready()
