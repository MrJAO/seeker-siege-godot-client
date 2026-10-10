extends "res://scripts/mobs/base_mob.gd"

func _ready():
	mob_name = "Rust Bug"
	mob_type = "rust_bug"
	max_hp = 60
	move_speed = 110.0
	damage = 8
	super._ready()
