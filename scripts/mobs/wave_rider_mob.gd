extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Wave Rider"
	mob_type = "wave_rider"
	max_hp = 60
	move_speed = 110.0
	damage = 8
	super._ready()
