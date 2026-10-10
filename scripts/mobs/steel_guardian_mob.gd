extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Steel Guardian"
	mob_type = "steel_guardian"
	max_hp = 160
	move_speed = 55.0
	damage = 20
	super._ready()
