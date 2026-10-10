extends Control

@onready var start_button: Button = $StartButton
@onready var region_map_label: Label = $TopBar/RegionMapLabel

func _ready() -> void:
	_refresh_view()

func _refresh_view() -> void:
	if GameManager.is_new_player:
		start_button.visible = true
		start_button.disabled = not GameManager.check_can_start()
	else:
		start_button.visible = false
		region_map_label.text = "Region %d - Map %d" % [GameManager.current_region, GameManager.current_map]

func _on_start_button_pressed() -> void:
	GameManager.start_game()
	_refresh_view()
