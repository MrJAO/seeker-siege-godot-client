extends Node2D

const WANDER_RADIUS_X: float = 160.0
const WANDER_OFFSET_Y: float = 90.0
const WANDER_HEIGHT: float = 100.0
const MOVE_SPEED: float = 40.0
const PAUSE_MIN: float = 1.0
const PAUSE_MAX: float = 3.0

const DIALOGUE_LINES := [
	"Exchange resources for SKR to me!",
	"Got some spared resources?",
	"I got some SKR with me.",
	"Swap energy to oil?",
	"Swap scraps to energy?",
	"Swap oil to scraps?",
	"Time waits for no one... but I do.",
	"Fair trades, always.",
	"Come, let's make a deal.",
]
const DIALOGUE_SHOW_MIN: float = 3.0
const DIALOGUE_SHOW_MAX: float = 5.0
const DIALOGUE_GAP: float = 30.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dialogue_bubble: PanelContainer = $DialogueBubble
@onready var dialogue_label: Label = $DialogueBubble/Label
@onready var name_label: Label = $NameLabel

var anchor_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var pause_timer: float = 0.0
var is_paused: bool = true

var dialogue_visible_timer: float = 0.0
var dialogue_gap_timer: float = DIALOGUE_GAP

func _ready() -> void:
	dialogue_bubble.visible = false
	_setup_name_label()
	_pick_new_target()

func _setup_name_label() -> void:
	name_label.text = "Time Traveler"
	name_label.z_index = 20
	name_label.position = Vector2(-40, -60)
	name_label.custom_minimum_size = Vector2(80, 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 3)

func set_anchor(world_position: Vector2) -> void:
	anchor_position = world_position + Vector2(0, WANDER_OFFSET_Y)
	global_position = anchor_position
	_pick_new_target()

func _pick_new_target() -> void:
	is_paused = false
	target_position = anchor_position + Vector2(
		randf_range(-WANDER_RADIUS_X, WANDER_RADIUS_X),
		randf_range(0, WANDER_HEIGHT)
	)

func _process(delta: float) -> void:
	_process_movement(delta)
	_process_dialogue(delta)

func _process_movement(delta: float) -> void:
	if is_paused:
		pause_timer -= delta
		if pause_timer <= 0.0:
			_pick_new_target()
		return

	var to_target: Vector2 = target_position - global_position
	if to_target.length() < 4.0:
		is_paused = true
		pause_timer = randf_range(PAUSE_MIN, PAUSE_MAX)
		return

	var direction: Vector2 = to_target.normalized()
	_update_animation(direction)
	global_position += direction * MOVE_SPEED * delta

func _update_animation(direction: Vector2) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			if animated_sprite.sprite_frames.has_animation("walk_right"):
				animated_sprite.play("walk_right")
		else:
			if animated_sprite.sprite_frames.has_animation("walk_left"):
				animated_sprite.play("walk_left")
	else:
		if direction.y > 0:
			if animated_sprite.sprite_frames.has_animation("walk_down"):
				animated_sprite.play("walk_down")
		else:
			if animated_sprite.sprite_frames.has_animation("walk_up"):
				animated_sprite.play("walk_up")

func _process_dialogue(delta: float) -> void:
	if dialogue_bubble.visible:
		dialogue_visible_timer -= delta
		if dialogue_visible_timer <= 0.0:
			dialogue_bubble.visible = false
			dialogue_gap_timer = DIALOGUE_GAP
	else:
		dialogue_gap_timer -= delta
		if dialogue_gap_timer <= 0.0:
			_show_random_dialogue()

func _show_random_dialogue() -> void:
	dialogue_label.text = DIALOGUE_LINES[randi() % DIALOGUE_LINES.size()]
	dialogue_bubble.visible = true
	dialogue_visible_timer = randf_range(DIALOGUE_SHOW_MIN, DIALOGUE_SHOW_MAX)
