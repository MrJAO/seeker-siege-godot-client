extends Control

@onready var confirm_button: Button = $HBox/ConfirmButton
@onready var cancel_button: Button = $HBox/CancelButton

func _ready() -> void:
	visible = false
	BuildManager.tower_staged.connect(_on_tower_staged)
	BuildManager.placement_confirmed.connect(_on_closed)
	BuildManager.placement_cancelled.connect(_on_closed)

func _on_tower_staged(_tower_id: int, _world_pos: Vector2) -> void:
	_position_bottom_center()
	visible = true

func _position_bottom_center() -> void:
	var vp: Vector2 = get_viewport_rect().size
	global_position = Vector2(
		(vp.x - size.x) / 2.0,
		vp.y - size.y - 40.0
	)

func _on_closed(_arg = null) -> void:
	visible = false

func _on_confirm_button_pressed() -> void:
	BuildManager.confirm_placement()

func _on_cancel_button_pressed() -> void:
	BuildManager.cancel_placement()
