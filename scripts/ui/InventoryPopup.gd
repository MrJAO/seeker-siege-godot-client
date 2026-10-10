extends PanelContainer

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var tower_tab_button: Button = $Margin/VBox/TabRow/TowerTabButton
@onready var deployment_tab_button: Button = $Margin/VBox/TabRow/DeploymentTabButton
@onready var miner_tab_button: Button = $Margin/VBox/TabRow/MinerTabButton
@onready var equipment_tab_button: Button = $Margin/VBox/TabRow/EquipmentTabButton
@onready var grid: GridContainer = $Margin/VBox/ScrollContainer/Grid

const TOWER_ART_PREFIX := {
	"machine_gun": "machinegun",
	"railgun": "railgun",
	"freeze_ray": "freeze_ray",
	"rocket_launcher": "rocket_launcher",
	"flamethrower": "flamethrower",
}

var current_tab: String = "tower"
var card_nodes: Dictionary = {} # only used by the Tower tab

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	tower_tab_button.pressed.connect(func(): _show_tab("tower"))
	deployment_tab_button.pressed.connect(func(): _show_tab("deployment"))
	miner_tab_button.pressed.connect(func(): _show_tab("miner"))
	equipment_tab_button.pressed.connect(func(): _show_tab("equipment"))
	_show_tab("tower")

func open() -> void:
	visible = true
	_sync_current_tab()

var _sync_accumulator: float = 0.0
const SYNC_INTERVAL_SECONDS := 0.5

func _process(delta: float) -> void:
	if not visible or current_tab != "tower":
		return
	_sync_accumulator += delta
	if _sync_accumulator >= SYNC_INTERVAL_SECONDS:
		_sync_accumulator = 0.0
		_sync_current_tab()

func _show_tab(tab: String) -> void:
	current_tab = tab
	tower_tab_button.button_pressed = tab == "tower"
	deployment_tab_button.button_pressed = tab == "deployment"
	miner_tab_button.button_pressed = tab == "miner"
	equipment_tab_button.button_pressed = tab == "equipment"
	_sync_current_tab()

func _sync_current_tab() -> void:
	match current_tab:
		"tower":
			_sync_tower_list()
		"deployment", "miner", "equipment":
			_show_empty_state()

func _show_empty_state() -> void:
	for child in grid.get_children():
		child.queue_free()
	card_nodes.clear()
	var label := Label.new()
	label.text = "Nothing to show yet"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(label)

func _get_tower_image_path(type: String, tier: int) -> String:
	var prefix: String = TOWER_ART_PREFIX.get(type, type)
	return "res://assets/turrets/%s/%s_level%d.png" % [type, prefix, tier]

func _sync_tower_list() -> void:
	if card_nodes.is_empty() and grid.get_child_count() > 0:
		for child in grid.get_children():
			child.queue_free()

	var ids: Array = TowerManager.owned_towers.keys()
	var current_ids: Dictionary = {}

	for id in ids:
		current_ids[id] = true
		if not card_nodes.has(id):
			var card: Control = _build_card(id)
			card_nodes[id] = card
			grid.add_child(card)
		_update_card(id)

	for id in card_nodes.keys():
		if not current_ids.has(id):
			card_nodes[id].queue_free()
			card_nodes.erase(id)

func _build_card(_tower_id: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	# Tower Image
	var image := TextureRect.new()
	image.name = "Image"
	image.custom_minimum_size = Vector2(150, 150)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(image)

	# Stats (Level/Tier + DMG/ATK Spd/Range)
	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(stats_label)

	# Equipment slots
	var equip_row := HBoxContainer.new()
	equip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_row.add_theme_constant_override("separation", 8)
	var equip_label := Label.new()
	equip_label.text = "Equipment:"
	equip_label.add_theme_font_size_override("font_size", 18)
	equip_row.add_child(equip_label)
	for i in range(5):
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(34, 34)
		box.color = Color(0.5, 0.5, 0.5, 1)
		equip_row.add_child(box)
	vbox.add_child(equip_row)

	var cooldown_label := Label.new()
	cooldown_label.name = "CooldownLabel"
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 18)
	cooldown_label.visible = false
	vbox.add_child(cooldown_label)

	# Tower Status label: "Placed" or "In Inventory"
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(status_label)

	return card

func _update_card(tower_id: int) -> void:
	if not TowerManager.owned_towers.has(tower_id):
		return
	var t: Dictionary = TowerManager.owned_towers[tower_id]
	var vbox: VBoxContainer = card_nodes[tower_id].get_child(0).get_node("VBox")

	vbox.get_node("NameLabel").text = t.type.capitalize().replace("_", " ")

	var image: TextureRect = vbox.get_node("Image")
	var icon_path: String = _get_tower_image_path(t.type, t.tier)
	if image.get_meta("icon_path", "") != icon_path:
		image.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
		image.set_meta("icon_path", icon_path)

	var stats: Dictionary = TowerManager.get_computed_stats(tower_id)
	vbox.get_node("StatsLabel").text = "Lvl. %d | Tier %d\nDMG %.1f | ATK Spd %.2f | Range %.0f" % [t.level, t.tier, stats.dmg, stats.atk_speed, stats.range]

	var on_cooldown: bool = t.relocate_timer > 0.0
	var cooldown_label: Label = vbox.get_node("CooldownLabel")
	cooldown_label.visible = on_cooldown
	if on_cooldown:
		cooldown_label.text = "Cooldown: %ds" % int(t.relocate_timer)

	var status_label: Label = vbox.get_node("StatusLabel")
	if not t.get("enabled", true):
		status_label.text = "Disabled"
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	else:
		status_label.text = "Placed" if t.placed else "In Inventory"
		status_label.remove_theme_color_override("font_color")
