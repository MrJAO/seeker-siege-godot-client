extends "res://scripts/mobs/boss_mob_base.gd"

func _ready():
	mob_name = "Cyber Phoenix"
	mob_type = "cyber_phoenix_boss"
	max_hp = 7000000
	move_speed = 33.0
	damage = 304
	super._ready()
