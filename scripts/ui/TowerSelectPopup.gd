extends PanelContainer

@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton

const TOWER_ART_PREFIX := {
	"machine_gun": "machinegun",
	"railgun": "railgun",
	"freeze_ray": "freeze_ray",
	"rocket_launcher": "rocket_launcher",
	"flamethrower": "flamethrower",
}

var card_nodes: Dictionary = {}

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func open() -> void:
	_sync_list()
	visible = true

func _process(_delta: float) -> void:
	if visible:
		_sync_list()

func _get_tower_image_path(type: String, tier: int) -> String:
	var prefix: String = TOWER_ART_PREFIX.get(type, type)
	return "res://assets/turrets/%s/%s_level%d.png" % [type, prefix, tier]

func _sync_list() -> void:
	var inventory: Array = BuildManager.get_available_inventory()
	var current_ids: Dictionary = {}

	for tower_data in inventory:
		current_ids[tower_data.id] = true
		if not card_nodes.has(tower_data.id):
			var card: Control = _build_card(tower_data.id)
			card_nodes[tower_data.id] = card
			grid.add_child(card)
		_update_card(tower_data.id)

	for id in card_nodes.keys():
		if not current_ids.has(id):
			card_nodes[id].queue_free()
			card_nodes.erase(id)

func _build_card(tower_id: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	# Tower Image
	var image := TextureRect.new()
	image.name = "Image"
	image.custom_minimum_size = Vector2(88, 88)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(image)

	# Stats (Level/Tier + DMG/ATK Spd/Range)
	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(stats_label)

	# Tower Equipments
	var equip_row := HBoxContainer.new()
	equip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_row.add_theme_constant_override("separation", 6)
	var equip_label := Label.new()
	equip_label.text = "Equipment:"
	equip_label.add_theme_font_size_override("font_size", 16)
	equip_row.add_child(equip_label)
	for i in range(5):
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(28, 28)
		box.color = Color(0.5, 0.5, 0.5, 1)
		equip_row.add_child(box)
	vbox.add_child(equip_row)

	var cooldown_label := Label.new()
	cooldown_label.name = "CooldownLabel"
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 16)
	cooldown_label.visible = false
	vbox.add_child(cooldown_label)

	# Select button
	var select_button := Button.new()
	select_button.name = "SelectButton"
	select_button.text = "Select"
	select_button.custom_minimum_size = Vector2(0, 50)
	select_button.add_theme_font_size_override("font_size", 18)
	select_button.pressed.connect(_on_select_pressed.bind(tower_id))
	vbox.add_child(select_button)

	return card

func _update_card(tower_id: int) -> void:
	if not TowerManager.owned_towers.has(tower_id):
		return
	var t: Dictionary = TowerManager.owned_towers[tower_id]
	var vbox: VBoxContainer = card_nodes[tower_id].get_child(0).get_node("VBox")

	vbox.get_node("NameLabel").text = t.type.capitalize().replace("_", " ")

	var image: TextureRect = vbox.get_node("Image")
	var icon_path: String = _get_tower_image_path(t.type, t.tier)
	image.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null

	var stats: Dictionary = TowerManager.get_computed_stats(tower_id)
	vbox.get_node("StatsLabel").text = "Lvl. %d | Tier %d\nDMG %.1f | ATK Spd %.2f | Range %.0f" % [t.level, t.tier, stats.dmg, stats.atk_speed, stats.range]

	var on_cooldown: bool = t.relocate_timer > 0.0
	var cooldown_label: Label = vbox.get_node("CooldownLabel")
	cooldown_label.visible = on_cooldown
	if on_cooldown:
		cooldown_label.text = "Cooldown: %ds" % int(t.relocate_timer)

	var select_button: Button = vbox.get_node("SelectButton")
	select_button.disabled = on_cooldown

func _on_select_pressed(tower_id: int) -> void:
	if BuildManager.stage_tower_for_confirmation(tower_id):
		visible = false

func _on_close_pressed() -> void:
	visible = false
	BuildManager.cancel_selection()
	for id in card_nodes.keys():
		card_nodes[id].queue_free()
	card_nodes.clear()
