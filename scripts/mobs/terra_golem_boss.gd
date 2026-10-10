extends "res://scripts/mobs/boss_mob_base.gd"

func _ready():
	mob_name = "Terra Golem"
	mob_type = "terra_golem_boss"
	max_hp = 1000000
	move_speed = 25.0
	damage = 90
	super._ready()
