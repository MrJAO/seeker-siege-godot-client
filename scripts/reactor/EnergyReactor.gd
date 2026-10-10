extends Node2D

@onready var sprite: Sprite2D = $Sprite

var hp_bar: Node2D = null
var base_position: Vector2
var shake_time: float = 0.0

const SHAKE_DURATION: float = 0.3
const SHAKE_STRENGTH: float = 6.0

func _ready() -> void:
	ReactorManager.tier_changed.connect(_on_tier_changed)
	ReactorManager.hp_changed.connect(_on_hp_changed)
	ReactorManager.damage_taken.connect(_on_damage_taken)
	base_position = position
	_update_sprite()
	_create_hp_bar()

func _on_tier_changed(_new_tier: int) -> void:
	_update_sprite()

func _update_sprite() -> void:
	var path: String = "res://assets/reactor/core_level%d.png" % ReactorManager.reactor_tier
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

func _create_hp_bar() -> void:
	hp_bar = Node2D.new()
	hp_bar.z_index = 25
	hp_bar.position = Vector2(-40, -70)
	add_child(hp_bar)
	hp_bar.draw.connect(_draw_hp_bar)
	hp_bar.queue_redraw()

func _get_hp_color(pct: float) -> Color:
	if pct >= 0.85:
		return Color(0, 1, 1, 1)
	elif pct >= 0.50:
		return Color(1, 0.55, 0, 1)
	else:
		return Color(1, 0, 0, 1)

func _draw_hp_bar() -> void:
	var width: float = 80.0
	var height: float = 8.0
	var max_hp: float = ReactorManager.get_max_hp()
	var pct: float = clamp(ReactorManager.current_hp / max_hp, 0.0, 1.0)
	hp_bar.draw_rect(Rect2(0, 0, width, height), Color(0.1, 0.1, 0.1, 0.85))
	hp_bar.draw_rect(Rect2(0, 0, width * pct, height), _get_hp_color(pct))

func _on_hp_changed(_current: float, _max: float) -> void:
	if hp_bar:
		hp_bar.queue_redraw()

func _on_damage_taken() -> void:
	shake_time = SHAKE_DURATION

func _process(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		position = base_position + Vector2(randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH), randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH))
		if shake_time <= 0.0:
			position = base_position

func take_damage_from_mob(mob_type: String) -> void:
	ReactorManager.take_damage_from_mob(mob_type)
