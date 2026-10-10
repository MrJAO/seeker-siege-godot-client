extends PanelContainer

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var audio_toggle: CheckButton = $Margin/VBox/Scroll/ScrollVBox/AudioToggle
@onready var volume_slider: HSlider = $Margin/VBox/Scroll/ScrollVBox/VolumeSlider
@onready var volume_label: Label = $Margin/VBox/Scroll/ScrollVBox/VolumeLabel
@onready var hud_sections_container: GridContainer = $Margin/VBox/Scroll/ScrollVBox/HudSectionsContainer

const HUD_SECTIONS := [
	{"key": "game_menu", "title": "Game Menu", "levels": [1.0, 2.0, 3.0], "note": "Home, Inventory, Shop, Marketplace, and Settings"},
	{"key": "resources", "title": "Resources Icons", "levels": [1.0, 2.0, 3.0], "note": "Energy, Scraps, Oil, and SKR counters"},
	{"key": "top_center", "title": "Top Center", "levels": [1.0, 2.0, 3.0], "note": "Region X - Map X, Start, and Next Map"},
	{"key": "top_left", "title": "Top Left", "levels": [1.0, 1.5, 2.0], "note": "Show Placement, Show Range, Show Spawn Area, Skill Tree, Unlock Region X - Map X"},
]

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	audio_toggle.toggled.connect(_on_audio_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	audio_toggle.button_pressed = true
	volume_slider.value = 100

	for section in HUD_SECTIONS:
		hud_sections_container.add_child(_make_scale_card(section.key, section.title, section.levels, section.note))

func open() -> void:
	visible = true

func _on_audio_toggled(enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not enabled)

func _on_volume_changed(value: float) -> void:
	volume_label.text = "Volume: %d%%" % int(value)
	var db: float = linear_to_db(value / 100.0) if value > 0 else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)

func _level_label(level: float) -> String:
	if level == int(level):
		return "x%d" % int(level)
	return "x%s" % str(level)

func _make_scale_card(section_key: String, title: String, levels: Array, note: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var group := ButtonGroup.new()
	var current: float = UIScaleManager.get_scale(section_key)
	for level in levels:
		var btn := Button.new()
		btn.text = _level_label(level)
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(80, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.button_pressed = is_equal_approx(level, current)
		btn.pressed.connect(func(): UIScaleManager.set_scale(section_key, level))
		row.add_child(btn)

	if note != "":
		var note_label := RichTextLabel.new()
		note_label.bbcode_enabled = true
		note_label.text = "[i]%s[/i]" % note
		note_label.fit_content = true
		note_label.custom_minimum_size = Vector2(0, 28)
		note_label.add_theme_font_size_override("normal_font_size", 14)
		note_label.add_theme_color_override("default_color", Color(0, 0, 0, 1))
		note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(note_label)

	return card
