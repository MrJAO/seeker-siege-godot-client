extends Node2D

const NPC_NAME := "Engineer"

const PRE_UNLOCK_LINES := [
	"Chief said you can't be here yet",
]
const GREETING := "Armory's fired up, Commander"
const RANDOM_LINES := [
	"Good gear beats good luck.",
	"Bring back what you can. I can rebuild the rest.",
	"Every weapon starts as scrap. Keep the scrap coming.",
	"A tank without repairs is just a big target.",
	"The Armory's open. Forge something worth carrying.",
]
const DIALOGUE_SHOW_DURATION: float = 4.0
const DIALOGUE_GAP: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $NameLabel
@onready var dialogue_bubble: PanelContainer = $DialogueBubble
@onready var dialogue_label: Label = $DialogueBubble/Label

var active_lines: Array = []
var last_line: String = ""
var is_talking: bool = false
var dialogue_step: int = 0
var step_timer: float = 0.0
var waiting_for_next: bool = false

func _ready() -> void:
	dialogue_bubble.visible = false
	_setup_name_label()
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
	InputManager.engineer_clicked.connect(_on_input_manager_clicked)

func _setup_name_label() -> void:
	name_label.text = NPC_NAME
	name_label.z_index = 20
	name_label.position = Vector2(-40, -60)
	name_label.custom_minimum_size = Vector2(80, 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 3)

func _on_input_manager_clicked(npc: Node2D) -> void:
	if npc == self:
		_start_dialogue()

func _start_dialogue() -> void:
	if is_talking:
		return
	is_talking = true
	dialogue_step = 0
	active_lines = _pick_lines()
	_show_current_step()

func _show_current_step() -> void:
	dialogue_label.text = active_lines[dialogue_step]
	dialogue_bubble.visible = true
	step_timer = DIALOGUE_SHOW_DURATION
	waiting_for_next = false

func _process(delta: float) -> void:
	if not is_talking:
		return
	step_timer -= delta
	if step_timer > 0.0:
		return

	if dialogue_bubble.visible:
		dialogue_bubble.visible = false
		if dialogue_step + 1 < active_lines.size():
			step_timer = DIALOGUE_GAP
			waiting_for_next = true
		else:
			is_talking = false
	elif waiting_for_next:
		dialogue_step += 1
		_show_current_step()

func _is_unlocked() -> bool:
	return MapManager.act2_unlocked

func _pick_lines() -> Array:
	if not _is_unlocked():
		return PRE_UNLOCK_LINES
	if not MapManager.npc_greeted.get(NPC_NAME, false):
		MapManager.npc_greeted[NPC_NAME] = true
		last_line = GREETING
		return [GREETING]
	var choices: Array = RANDOM_LINES.duplicate()
	choices.erase(last_line)
	last_line = choices[randi() % choices.size()]
	return [last_line]
