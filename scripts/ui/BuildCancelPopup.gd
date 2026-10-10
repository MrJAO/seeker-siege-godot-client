extends Control

signal open_tower_select

@onready var build_button: Button = $HBox/BuildButton
@onready var cancel_button: Button = $HBox/CancelButton

func _ready() -> void:
	visible = false
	BuildManager.tile_selected.connect(_on_tile_selected)
	BuildManager.selection_cleared.connect(_on_selection_cleared)

func _on_tile_selected(_grid_pos: Vector2i, _world_pos: Vector2) -> void:
	_position_bottom_center()
	visible = true

func _position_bottom_center() -> void:
	var vp: Vector2 = get_viewport_rect().size
	global_position = Vector2(
		(vp.x - size.x) / 2.0,
		vp.y - size.y - 40.0
	)

func _on_selection_cleared() -> void:
	visible = false

func _on_build_button_pressed() -> void:
	visible = false
	open_tower_select.emit()

func _on_cancel_button_pressed() -> void:
	BuildManager.cancel_selection()
