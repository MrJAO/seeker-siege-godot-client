extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Rock Sentinel"
	mob_type = "rock_sentinel"
	max_hp = 260
	move_speed = 35.0
	damage = 30
	super._ready()
