extends PanelContainer

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var cave_tab_button: Button = $Margin/VBox/TabRow/CaveTabButton
@onready var miner_tab_button: Button = $Margin/VBox/TabRow/MinerTabButton
@onready var assignments_tab_button: Button = $Margin/VBox/TabRow/AssignmentsTabButton
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid

const ICON_PATHS := {
	"energy": "res://assets/icons/energy_icon.png",
	"scraps": "res://assets/icons/scraps_icon.png",
	"oil": "res://assets/icons/oil_icon.png",
}

const CAVE_ROSTER := [
	{"name": "Ancient Cave 1", "difficulty": "Easy"},
	{"name": "Ancient Cave 2", "difficulty": "Hard"},
	{"name": "Ancient Cave 3", "difficulty": "Extreme"},
]

const MINER_ROSTER := [
	{"name": "Junior Miner"},
	{"name": "Senior Miner"},
	{"name": "Expert Miner"},
]

var current_tab: String = "cave"

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	cave_tab_button.pressed.connect(func(): _show_tab("cave"))
	miner_tab_button.pressed.connect(func(): _show_tab("miner"))
	assignments_tab_button.pressed.connect(func(): _show_tab("assignments"))
	_show_tab("cave")

func open() -> void:
	visible = true

func _show_tab(tab: String) -> void:
	current_tab = tab
	cave_tab_button.button_pressed = tab == "cave"
	miner_tab_button.button_pressed = tab == "miner"
	assignments_tab_button.button_pressed = tab == "assignments"
	_rebuild_grid()

func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	match current_tab:
		"cave":
			for entry in CAVE_ROSTER:
				grid.add_child(_make_cave_card(entry))
		"miner":
			for entry in MINER_ROSTER:
				grid.add_child(_make_miner_card(entry))
		"assignments":
			pass # intentionally empty for now

func _make_confidential_placeholder() -> Control:
	var image_holder := Control.new()
	image_holder.custom_minimum_size = Vector2(0, 140)

	var placeholder := ColorRect.new()
	placeholder.color = Color(0.4, 0.4, 0.4, 1)
	image_holder.add_child(placeholder)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var conf_label := Label.new()
	conf_label.text = "Confidential"
	conf_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	conf_label.add_theme_font_size_override("font_size", 18)
	conf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conf_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	image_holder.add_child(conf_label)
	conf_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	return image_holder

func _make_cost_row() -> HBoxContainer:
	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 6)
	var resource_order := ["energy", "scraps", "oil"]
	for i in range(resource_order.size()):
		var res_name: String = resource_order[i]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = ICON_PATHS.get(res_name, "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		cost_row.add_child(icon)

		var val_label := Label.new()
		val_label.text = "NA"
		val_label.add_theme_font_size_override("font_size", 16)
		cost_row.add_child(val_label)

		if i < resource_order.size() - 1:
			var sep := Label.new()
			sep.text = "|"
			sep.add_theme_font_size_override("font_size", 16)
			cost_row.add_child(sep)
	return cost_row

func _make_cave_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	vbox.add_child(_make_confidential_placeholder())

	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty: %s" % entry.difficulty
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(difficulty_label)

	var available_label := Label.new()
	available_label.text = "Available Resources: NA/NA"
	available_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	available_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(available_label)

	var refresh_label := Label.new()
	refresh_label.text = "Refreshes In: NA"
	refresh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(refresh_label)

	var assigned_label := Label.new()
	assigned_label.text = "Assigned Miner: NA/NA"
	assigned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assigned_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(assigned_label)

	var enter_button := Button.new()
	enter_button.text = "Enter Cave"
	enter_button.custom_minimum_size = Vector2(0, 50)
	enter_button.add_theme_font_size_override("font_size", 18)
	enter_button.disabled = true
	vbox.add_child(enter_button)

	return card

func _make_miner_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	vbox.add_child(_make_confidential_placeholder())

	var speed_label := Label.new()
	speed_label.text = "NA% Mine Speed"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(speed_label)

	vbox.add_child(_make_cost_row())

	var train_time_label := Label.new()
	train_time_label.text = "Train Time: NA seconds"
	train_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	train_time_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(train_time_label)

	var train_button := Button.new()
	train_button.text = "Train"
	train_button.custom_minimum_size = Vector2(0, 50)
	train_button.add_theme_font_size_override("font_size", 18)
	train_button.disabled = true
	vbox.add_child(train_button)

	return card
