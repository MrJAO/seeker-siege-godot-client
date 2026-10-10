extends Control

@onready var result_label: Label = $VBoxContainer/ResultLabel

func _ready() -> void:
	NetworkManager.login_success.connect(_on_login_success)
	NetworkManager.login_failed.connect(_on_login_failed)

func _on_test_button_pressed() -> void:
	result_label.text = "Requesting..."
	NetworkManager.debug_login()

func _on_login_success(player_id: int) -> void:
	result_label.text = "Login OK — playerId: %d" % player_id

func _on_login_failed(status: int, data: Variant) -> void:
	result_label.text = "Login FAILED (%d): %s" % [status, data]
