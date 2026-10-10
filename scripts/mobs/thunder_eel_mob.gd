extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Thunder Eel"
	mob_type = "thunder_eel"
	max_hp = 160
	move_speed = 55.0
	damage = 20
	super._ready()
