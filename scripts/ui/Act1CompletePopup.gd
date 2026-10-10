extends Control

signal continue_pressed

@onready var continue_button: Button = $PopupPanel/Margin/VBox/ContinueButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed() -> void:
	continue_button.disabled = true
	continue_pressed.emit()
