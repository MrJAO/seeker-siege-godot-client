extends PanelContainer

@onready var count_label: Label = $Margin/VBox/CountLabel
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid

const TOWER_ICON_PATHS := {
	"machine_gun": "res://assets/turrets/machine_gun/machinegun_level1.png",
	"railgun": "res://assets/turrets/railgun/railgun_level1.png",
	"freeze_ray": "res://assets/turrets/freeze_ray/freeze_ray_level1.png",
	"rocket_launcher": "res://assets/turrets/rocket_launcher/rocket_launcher_level1.png",
	"flamethrower": "res://assets/turrets/flamethrower/flamethrower_level1.png",
}

var units: int = 0
var pending_disable_ids: Array = []

func _ready() -> void:
	visible = false

func open() -> void:
	visible = true
	pending_disable_ids.clear()
	await ServerState.fetch_tower_claim_status()
	units = int(ServerState.tower_holdings.get("units", 0))
	_rebuild_grid()

func _enabled_tower_ids() -> Array:
	var ids: Array = []
	for id in TowerManager.owned_towers.keys():
		if TowerManager.owned_towers[id].get("enabled", true):
			ids.append(id)
	ids.sort()
	return ids

func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	var enabled_ids: Array = _enabled_tower_ids()
	count_label.text = "Enabled: %d / %d" % [enabled_ids.size(), units]

	for id in enabled_ids:
		grid.add_child(_make_tower_card(id, TowerManager.owned_towers[id], pending_disable_ids.has(id)))

	if enabled_ids.size() <= units:
		visible = false

func _make_tower_card(id: int, t: Dictionary, is_pending: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var type_str: String = String(t.get("type", ""))
	var name_label := Label.new()
	name_label.text = type_str.capitalize().replace("_", " ")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(88, 88)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = TOWER_ICON_PATHS.get(type_str, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		image.texture = load(icon_path)
	vbox.add_child(image)

	var stats: Dictionary = TowerManager.BASE_STATS.get(type_str, {})
	var stats_label := Label.new()
	stats_label.text = "Lvl. %d | Tier %d\nDMG %.0f | ATK Spd %.1f | Range %.0f" % [
		int(t.get("level", 1)), int(t.get("tier", 1)),
		float(stats.get("dmg", 0)), float(stats.get("atk_speed", 0)), float(stats.get("range", 0))
	]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(stats_label)

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

	if is_pending:
		var pending_label := Label.new()
		pending_label.text = "Disabling..."
		pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pending_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(pending_label)
		return card

	var disable_button := Button.new()
	disable_button.text = "Disable"
	disable_button.custom_minimum_size = Vector2(0, 50)
	disable_button.add_theme_font_size_override("font_size", 18)
	disable_button.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(disable_button)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.visible = false
	confirm_row.add_theme_constant_override("separation", 12)

	var confirm_button := Button.new()
	confirm_button.text = "Confirm"
	confirm_button.custom_minimum_size = Vector2(0, 50)
	confirm_button.add_theme_font_size_override("font_size", 18)
	confirm_button.mouse_filter = Control.MOUSE_FILTER_PASS
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0, 50)
	cancel_button.add_theme_font_size_override("font_size", 18)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_PASS

	confirm_row.add_child(confirm_button)
	confirm_row.add_child(cancel_button)
	vbox.add_child(confirm_row)

	disable_button.pressed.connect(func(): confirm_row.visible = true)
	cancel_button.pressed.connect(func(): confirm_row.visible = false)
	confirm_button.pressed.connect(_on_disable_confirmed.bind(id, confirm_button, cancel_button))

	return card

func _on_disable_confirmed(id: int, confirm_button: Button, cancel_button: Button) -> void:
	confirm_button.disabled = true
	cancel_button.disabled = true

	var keep_ids: Array = []
	for eid in _enabled_tower_ids():
		if eid != id and not pending_disable_ids.has(eid):
			keep_ids.append(eid)

	var result: Dictionary = await ServerState.select_towers(keep_ids)

	if result.ok:
		pending_disable_ids.clear()
		_rebuild_grid()
		return

	if String(result.data.get("error", "")) == "too_many_selected":
		pending_disable_ids.append(id)
		_rebuild_grid()
		return

	confirm_button.disabled = false
	cancel_button.disabled = false
