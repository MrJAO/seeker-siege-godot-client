extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Molten Golem"
	mob_type = "molten_golem"
	max_hp = 260
	move_speed = 35.0
	damage = 30
	super._ready()
