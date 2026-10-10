extends PanelContainer

@onready var list_container: VBoxContainer = $Margin/VBox/Scroll/List
@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)

func open() -> void:
	_populate_list()
	visible = true

func _populate_list() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var maps: Array = MapManager.get_unlocked_maps()
	var on_cooldown: bool = not MapManager.can_switch_map()

	if on_cooldown:
		var cooldown_label := Label.new()
		cooldown_label.text = "Switch cooldown: %ds remaining" % int(MapManager.switch_cooldown_remaining)
		cooldown_label.add_theme_font_size_override("font_size", 18)
		list_container.add_child(cooldown_label)

	for entry in maps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var label := Label.new()
		label.text = "Region %d - Map %d" % [entry.region, entry.map]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 20)
		var switch_button := Button.new()
		switch_button.custom_minimum_size = Vector2(0, 54)
		switch_button.add_theme_font_size_override("font_size", 18)
		var is_current: bool = entry.region == GameManager.current_region and entry.map == GameManager.current_map
		if is_current:
			switch_button.text = "Current Map"
			switch_button.disabled = true
		else:
			switch_button.text = "Switch"
			switch_button.disabled = on_cooldown
			switch_button.pressed.connect(_on_switch_pressed.bind(entry.region, entry.map))
		row.add_child(label)
		row.add_child(switch_button)
		list_container.add_child(row)

func _on_switch_pressed(region: int, map: int) -> void:
	MapManager.request_switch_map(region, map)
	visible = false
