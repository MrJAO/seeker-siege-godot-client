extends "res://scripts/mobs/boss_mob_base.gd"

func _ready():
	mob_name = "Iron Colossus"
	mob_type = "iron_colossus_boss"
	max_hp = 3000000
	move_speed = 28.0
	damage = 135
	super._ready()
