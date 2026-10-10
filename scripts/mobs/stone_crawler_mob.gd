extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Stone Crawler"
	mob_type = "stone_crawler"
	max_hp = 60
	move_speed = 110.0
	damage = 8
	super._ready()
