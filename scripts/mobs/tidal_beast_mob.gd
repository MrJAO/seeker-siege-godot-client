extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Tidal Beast"
	mob_type = "tidal_beast"
	max_hp = 260
	move_speed = 35.0
	damage = 30
	super._ready()
