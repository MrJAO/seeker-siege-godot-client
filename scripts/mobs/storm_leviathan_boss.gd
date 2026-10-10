extends "res://scripts/mobs/boss_mob_base.gd"

func _ready():
	mob_name = "Storm Leviathan"
	mob_type = "storm_leviathan_boss"
	max_hp = 5000000
	move_speed = 30.0
	damage = 203
	super._ready()
