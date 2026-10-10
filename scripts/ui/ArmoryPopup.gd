extends PanelContainer

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var tower_tab_button: Button = $Margin/VBox/TabRow/TowerTabButton
@onready var deployments_tab_button: Button = $Margin/VBox/TabRow/DeploymentsTabButton
@onready var mining_tab_button: Button = $Margin/VBox/TabRow/MiningTabButton
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid

const ICON_PATHS := {
	"energy": "res://assets/icons/energy_icon.png",
	"scraps": "res://assets/icons/scraps_icon.png",
	"oil": "res://assets/icons/oil_icon.png",
}

# Tower Equipments
const TOWER_EQUIPMENT := {
	"Machine Gun": [
		{"name": "Extended Barrel", "stat": "+15% Range"},
		{"name": "Rapid Feed Belt", "stat": "+12% Attack Speed"},
		{"name": "Thermal Scope", "stat": "+8% Crit Chance"},
		{"name": "Overcharged Motor", "stat": "+15% Damage"},
		{"name": "Armor Plating", "stat": "+10% Crit Damage"},
	],
	"Railgun": [
		{"name": "Focusing Lens", "stat": "+15% Range"},
		{"name": "Capacitor Bank", "stat": "+12% Attack Speed"},
		{"name": "Piercing Rounds", "stat": "+10% Damage"},
		{"name": "Magnetic Coil", "stat": "+15% Damage"},
		{"name": "Stabilizer Frame", "stat": "+15% Crit Damage"},
	],
	"Freeze Ray": [
		{"name": "Cryo Core", "stat": "+20% Freeze/Slow Duration"},
		{"name": "Wide Nozzle", "stat": "+15% Splash Radius"},
		{"name": "Coolant Tank", "stat": "+12% Attack Speed"},
		{"name": "Frost Amplifier", "stat": "+15% Damage"},
		{"name": "Chill Matrix", "stat": "+15% Slow Potency"},
	],
	"Rocket Launcher": [
		{"name": "Reinforced Warhead", "stat": "+15% Damage"},
		{"name": "Blast Shield", "stat": "+15% Splash Radius"},
		{"name": "Auto-Loader", "stat": "+12% Attack Speed"},
		{"name": "Guidance Chip", "stat": "+8% Crit Chance"},
		{"name": "Cluster Casing", "stat": "+1 Secondary Explosion"},
	],
	"Flamethrower": [
		{"name": "Fuel Booster", "stat": "+15% Range"},
		{"name": "Napalm Mix", "stat": "+20% Burn/DoT Damage"},
		{"name": "Pressure Valve", "stat": "+12% Attack Speed"},
		{"name": "Heat Sink", "stat": "+15% Damage"},
		{"name": "Ember Canister", "stat": "+15% Burn Spread Radius"},
	],
}

# Deployment Equipments
const DEPLOYMENTS_EQUIPMENT := {
	"Infantry": [
		{"name": "Combat Vest", "stat": "+8 Defense"},
		{"name": "Assault Rifle Upgrade", "stat": "+15% Damage"},
		{"name": "Field Boots", "stat": "+15% Move Speed"},
	],
	"Heavy Infantry": [
		{"name": "Riot Shield", "stat": "+12 Defense"},
		{"name": "Heavy Ammo Belt", "stat": "+15% Damage"},
		{"name": "Reinforced Plating", "stat": "+20% Max HP"},
	],
	"Sniper": [
		{"name": "Long-Range Scope", "stat": "+20% Range"},
		{"name": "Suppressor", "stat": "+10% Crit Chance"},
		{"name": "Ghillie Cloak", "stat": "+15% Stealth"},
	],
	"Commander": [
		{"name": "Tactical Visor", "stat": "+10% Squad Damage"},
		{"name": "Rally Horn", "stat": "+10% Squad Move Speed"},
		{"name": "Command Baton", "stat": "+10% Squad Attack Speed"},
	],
	"Medic": [
		{"name": "Med Kit Pack", "stat": "+10 Heal Amount/tick"},
		{"name": "Adrenaline Shot", "stat": "+20% Heal Speed"},
		{"name": "Field Stabilizer", "stat": "+15% Revive Chance"},
	],
	"Tanks": [
		{"name": "Composite Armor", "stat": "+20 Defense"},
		{"name": "Turbo Engine", "stat": "+15% Move Speed"},
		{"name": "Main Cannon Upgrade", "stat": "+20% Damage"},
	],
	"Engineer": [
		{"name": "Repair Drone", "stat": "+20% Repair Speed"},
		{"name": "Tow Cable", "stat": "+15% Recovery Range"},
		{"name": "Spare Parts Kit", "stat": "+15 Repair Amount/tick"},
	],
	"Builder": [
		{"name": "Hydraulic Arm", "stat": "+20% Build Speed"},
		{"name": "Blueprint Module", "stat": "+15% Build Range"},
		{"name": "Auto-Crane", "stat": "+1 Simultaneous Build Slot"},
	],
	"Collector": [
		{"name": "Expanded Cargo Hold", "stat": "+25% Cargo Capacity"},
		{"name": "Magnetic Harvester", "stat": "+20% Collect Speed"},
		{"name": "Auto-Sorter", "stat": "+15% Collect Radius"},
	],
}

# Miner Equipments
const MINING_EQUIPMENT := {
	"All Miners": [
		{"name": "Miner's Hat", "stat": "+10% Mine Speed"},
		{"name": "Reinforced Pickaxe", "stat": "+15% Resource Yield"},
		{"name": "Grip Gloves", "stat": "+10% Mine Speed"},
		{"name": "Steel-Toe Boots", "stat": "+10% Move Speed (in cave)"},
		{"name": "Mining Suit", "stat": "+15 Defense (cave hazard protection)"},
	],
}

var current_tab: String = "tower"

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	tower_tab_button.pressed.connect(func(): _show_tab("tower"))
	deployments_tab_button.pressed.connect(func(): _show_tab("deployments"))
	mining_tab_button.pressed.connect(func(): _show_tab("mining"))
	_show_tab("tower")

func open() -> void:
	visible = true

func _show_tab(tab: String) -> void:
	current_tab = tab
	tower_tab_button.button_pressed = tab == "tower"
	deployments_tab_button.button_pressed = tab == "deployments"
	mining_tab_button.button_pressed = tab == "mining"
	_rebuild_grid()

func _get_roster_for_tab(tab: String) -> Dictionary:
	match tab:
		"tower":
			return TOWER_EQUIPMENT
		"deployments":
			return DEPLOYMENTS_EQUIPMENT
		"mining":
			return MINING_EQUIPMENT
	return {}

func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	var roster: Dictionary = _get_roster_for_tab(current_tab)
	for owner_name in roster.keys():
		for item in roster[owner_name]:
			grid.add_child(_make_equipment_card(item.name, owner_name, item.stat))

func _make_equipment_card(item_name: String, owner_name: String, stat_text: String) -> Control:
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
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	var owner_label := Label.new()
	owner_label.text = "For: %s" % owner_name
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(owner_label)

	var image_holder := Control.new()
	image_holder.custom_minimum_size = Vector2(0, 190)
	vbox.add_child(image_holder)

	var placeholder := ColorRect.new()
	placeholder.color = Color(0.4, 0.4, 0.4, 1)
	image_holder.add_child(placeholder)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var conf_label := Label.new()
	conf_label.text = "Confidential"
	conf_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	conf_label.add_theme_font_size_override("font_size", 20)
	conf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conf_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	image_holder.add_child(conf_label)
	conf_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stat_label := Label.new()
	stat_label.text = stat_text
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stat_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(stat_label)

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 8)
	var resource_order := ["energy", "scraps", "oil"]
	for i in range(resource_order.size()):
		var res_name: String = resource_order[i]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = ICON_PATHS.get(res_name, "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		cost_row.add_child(icon)

		var val_label := Label.new()
		val_label.text = "NA"
		val_label.add_theme_font_size_override("font_size", 19)
		cost_row.add_child(val_label)

		if i < resource_order.size() - 1:
			var sep := Label.new()
			sep.text = "|"
			sep.add_theme_font_size_override("font_size", 19)
			cost_row.add_child(sep)
	vbox.add_child(cost_row)

	var forge_time_label := Label.new()
	forge_time_label.text = "Forge Time: NA seconds"
	forge_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forge_time_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(forge_time_label)

	var forge_button := Button.new()
	forge_button.text = "Forge"
	forge_button.custom_minimum_size = Vector2(0, 56)
	forge_button.add_theme_font_size_override("font_size", 20)
	forge_button.disabled = true
	forge_button.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(forge_button)

	return card
