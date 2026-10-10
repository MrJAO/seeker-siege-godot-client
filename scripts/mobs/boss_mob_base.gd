extends "res://scripts/mobs/base_mob.gd"

@export var wander_min_x: float = 70.0
@export var wander_max_x: float = 1850.0
@export var wander_min_y: float = 70.0
@export var wander_max_y: float = 1040.0

const ORBIT_ANGULAR_SPEED: float = 0.4
const SPIRAL_SHRINK_PER_SEC: float = 3.0

var orbit_angle: float = 0.0
var orbit_radius: float = 0.0

func _ready():
	super._ready()
	if is_instance_valid(reactor_target):
		orbit_radius = global_position.distance_to(reactor_target.global_position)
		orbit_angle = (global_position - reactor_target.global_position).angle()

func _physics_process(delta):
	if not is_instance_valid(reactor_target):
		return

	orbit_angle += ORBIT_ANGULAR_SPEED * delta
	orbit_radius = max(0.0, orbit_radius - SPIRAL_SHRINK_PER_SEC * delta)

	var target_pos: Vector2 = reactor_target.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	target_pos.x = clamp(target_pos.x, wander_min_x, wander_max_x)
	target_pos.y = clamp(target_pos.y, wander_min_y, wander_max_y)

	var to_target: Vector2 = target_pos - global_position
	if to_target.length() > 0.5:
		var direction: Vector2 = to_target.normalized()
		update_animation(direction)
		velocity = direction * move_speed
		move_and_slide()

	if global_position.distance_to(reactor_target.global_position) < 20 or orbit_radius <= 5.0:
		reach_reactor()
