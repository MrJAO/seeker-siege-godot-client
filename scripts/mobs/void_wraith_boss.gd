extends "res://scripts/mobs/boss_mob_base.gd"

func _ready():
	mob_name = "Void Wraith"
	mob_type = "void_wraith_boss"
	max_hp = 9000000
	move_speed = 37.0
	damage = 456
	super._ready()
