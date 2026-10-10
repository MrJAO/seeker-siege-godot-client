extends PanelContainer

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var tower_tab_button: Button = $Margin/VBox/TabRow/TowerTabButton
@onready var deployment_tab_button: Button = $Margin/VBox/TabRow/DeploymentTabButton
@onready var miner_tab_button: Button = $Margin/VBox/TabRow/MinerTabButton
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var tower_status_section: VBoxContainer = $Margin/VBox/TowerStatusSection
@onready var sol_balance_label: Label = $Margin/VBox/TowerStatusSection/SolBalanceLabel
@onready var counts_label: Label = $Margin/VBox/TowerStatusSection/CountsLabel

const TOWER_TYPES := ["machine_gun", "railgun", "freeze_ray", "rocket_launcher", "flamethrower"]

const TOWER_ICON_PATHS := {
	"machine_gun": "res://assets/turrets/machine_gun/machinegun_level1.png",
	"railgun": "res://assets/turrets/railgun/railgun_level1.png",
	"freeze_ray": "res://assets/turrets/freeze_ray/freeze_ray_level1.png",
	"rocket_launcher": "res://assets/turrets/rocket_launcher/rocket_launcher_level1.png",
	"flamethrower": "res://assets/turrets/flamethrower/flamethrower_level1.png",
}

const INFANTRY_SPRITE_PATH := "res://assets/deployment/Soldier2_right.png"
const JUNIOR_MINER_SPRITE_PATH := "res://assets/mining/JuniorMiner.png"

# game-config.json: minerTiers/deploymentTiers
const MINER_TYPE_KEYS := {
	"Junior Miner": "junior_miner",
	"Senior Miner": "senior_miner",
	"Expert Miner": "expert_miner",
}
const DEPLOYMENT_TYPE_KEYS := {
	"Infantry": "infantry",
	"Heavy Infantry": "heavy_infantry",
	"Sniper": "sniper",
	"Commander": "commander",
	"Medic": "medic",
	"Tanks": "tanks",
	"Engineer": "engineer",
	"Builder": "builder",
	"Collector": "collector",
}

# Soldier roster and stats
const SOLDIER_STATS := {
	"Infantry": {"hp": 80, "damage": 10, "atk_speed": 1.2, "defense": 5, "move_speed": 70, "role": ""},
	"Heavy Infantry": {"hp": 150, "damage": 14, "atk_speed": 0.8, "defense": 15, "move_speed": 45, "role": ""},
	"Sniper": {"hp": 60, "damage": 25, "atk_speed": 0.5, "defense": 2, "move_speed": 55, "role": ""},
	"Commander": {"hp": 100, "damage": 8, "atk_speed": 1.0, "defense": 8, "move_speed": 60, "role": "Buffs allies in 150 radius: +10% Dmg, +10% Atk Spd"},
	"Medic": {"hp": 70, "damage": 4, "atk_speed": 1.0, "defense": 3, "move_speed": 65, "role": "Heals 8 HP/tick to allies in 100 radius"},
	"Tanks": {"hp": 300, "damage": 20, "atk_speed": 0.6, "defense": 25, "move_speed": 30, "role": ""},
	"Engineer": {"hp": 120, "damage": null, "atk_speed": null, "defense": 12, "move_speed": 40, "role": "Repairs 15/tick to vehicles in 80 radius"},
	"Builder": {"hp": 100, "damage": null, "atk_speed": null, "defense": 10, "move_speed": 35, "role": "Build Speed x1.0 (baseline)"},
	"Collector": {"hp": 90, "damage": null, "atk_speed": null, "defense": 5, "move_speed": 50, "role": "Collects 5/sec, 100 cargo capacity"},
}

const SOLDIER_ROSTER := [
	{"name": "Infantry", "available": true},
	{"name": "Tanks", "available": false},
	{"name": "Engineer", "available": false},
	{"name": "Heavy Infantry", "available": false},
	{"name": "Sniper", "available": false},
	{"name": "Commander", "available": false},
	{"name": "Medic", "available": false},
	{"name": "Builder", "available": false},
	{"name": "Collector", "available": false},
]

const MINER_ROSTER := [
	{"name": "Junior Miner", "available": true},
	{"name": "Senior Miner", "available": false},
	{"name": "Expert Miner", "available": false},
]

var current_tab: String = "tower"
var tower_claim_status: Dictionary = {"claimableUnits": 0, "claimedCount": 0, "disabledCount": 0, "cooldownRemainingMs": 0}
var cooldown_remaining: float = 0.0
var tower_claim_buttons: Dictionary = {}
var tower_claim_result_labels: Dictionary = {}

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	tower_tab_button.pressed.connect(func(): _show_tab("tower"))
	deployment_tab_button.pressed.connect(func(): _show_tab("deployment"))
	miner_tab_button.pressed.connect(func(): _show_tab("miner"))
	_show_tab("tower")

func open() -> void:
	visible = true

func _process(delta: float) -> void:
	if not visible or current_tab != "tower" or cooldown_remaining <= 0.0:
		return
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	_update_tower_claim_buttons()

func _refresh_tower_status() -> void:
	var result: Dictionary = await ServerState.fetch_tower_claim_status()
	if not result.ok:
		sol_balance_label.text = "SOL Balance: -"
		counts_label.text = "Claimable Units: - | Claimed Units: - | Disabled Units: -"
		return

	tower_claim_status = result.data
	var sol_amount: float = float(result.data.get("solBalanceLamports", 0)) / 1000000000.0
	sol_balance_label.text = "SOL Balance: %.4f" % sol_amount
	counts_label.text = "Claimable Units: %d | Claimed Units: %d | Disabled Units: %d" % [
		int(result.data.get("claimableUnits", 0)),
		int(result.data.get("claimedCount", 0)),
		int(result.data.get("disabledCount", 0)),
	]
	cooldown_remaining = float(result.data.get("cooldownRemainingMs", 0)) / 1000.0
	_update_tower_claim_buttons()

func _update_tower_claim_buttons() -> void:
	var claimable: int = int(tower_claim_status.get("claimableUnits", 0))
	for ttype in tower_claim_buttons.keys():
		var button: Button = tower_claim_buttons[ttype]
		if cooldown_remaining > 0.0:
			button.disabled = true
			button.text = "Wait %ds" % int(ceil(cooldown_remaining))
		elif claimable <= 0:
			button.disabled = true
			button.text = "Claim"
		else:
			button.disabled = false
			button.text = "Claim"

func _on_tower_claim_pressed(ttype: String) -> void:
	for t in tower_claim_buttons.keys():
		tower_claim_buttons[t].disabled = true
	var result_label: Label = tower_claim_result_labels.get(ttype)
	if result_label:
		result_label.text = "Claiming..."

	var result: Dictionary = await ServerState.claim_tower(ttype)

	if result_label:
		if result.ok:
			result_label.text = "Claimed!"
		else:
			var error_code: String = String(result.data.get("error", ""))
			var messages := {
				"cooldown_active": "On cooldown",
				"claim_cap_reached": "Cap reached",
				"holdings_check_failed": "Could not check balance",
			}
			result_label.text = messages.get(error_code, "Claim failed")

	await _refresh_tower_status()
	_rebuild_grid()

func _show_tab(tab: String) -> void:
	current_tab = tab
	tower_tab_button.button_pressed = tab == "tower"
	deployment_tab_button.button_pressed = tab == "deployment"
	miner_tab_button.button_pressed = tab == "miner"
	tower_status_section.visible = tab == "tower"
	_rebuild_grid()
	if tab == "tower":
		_refresh_tower_status()

func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	tower_claim_buttons.clear()
	tower_claim_result_labels.clear()

	match current_tab:
		"tower":
			for ttype in TOWER_TYPES:
				grid.add_child(_make_tower_card(ttype))
		"deployment":
			for entry in SOLDIER_ROSTER:
				var key: String = DEPLOYMENT_TYPE_KEYS.get(entry.name, "")
				var claimed: Dictionary = ServerState.deployment_units.get(key, {})
				var owned: bool = int(claimed.get("enabledCount", 0)) > 0
				grid.add_child(_make_unit_card(entry.name, entry.available, owned, INFANTRY_SPRITE_PATH, 4, 4, SOLDIER_STATS))
		"miner":
			for entry in MINER_ROSTER:
				var key: String = MINER_TYPE_KEYS.get(entry.name, "")
				var claimed: Dictionary = ServerState.miner_units.get(key, {})
				var owned: bool = int(claimed.get("enabledCount", 0)) > 0
				grid.add_child(_make_unit_card(entry.name, entry.available, owned, JUNIOR_MINER_SPRITE_PATH, 4, 2, {}))

func _make_tower_card(ttype: String) -> Control:
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
	name_label.text = ttype.capitalize().replace("_", " ")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(150, 150)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = TOWER_ICON_PATHS.get(ttype, "")
	if icon_path != "":
		var texture: Texture2D = load(icon_path)
		if texture:
			image.texture = texture
		else:
			push_warning("ShopPopup: could not load tower icon at %s" % icon_path)
	vbox.add_child(image)

	var stats: Dictionary = TowerManager.BASE_STATS[ttype]
	var stats_label := Label.new()
	stats_label.text = "DMG %.0f | ATK Spd %.1f\nRange %.0f" % [stats.dmg, stats.atk_speed, stats.range]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(stats_label)

	var owned_count: int = 0
	for tid in TowerManager.owned_towers.keys():
		if TowerManager.owned_towers[tid].type == ttype:
			owned_count += 1
	var status_label := Label.new()
	status_label.text = "Owned: %d" % owned_count
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(status_label)

	var claim_button := Button.new()
	claim_button.text = "Claim"
	claim_button.custom_minimum_size = Vector2(0, 56)
	claim_button.add_theme_font_size_override("font_size", 20)
	claim_button.mouse_filter = Control.MOUSE_FILTER_PASS
	claim_button.pressed.connect(_on_tower_claim_pressed.bind(ttype))
	vbox.add_child(claim_button)
	tower_claim_buttons[ttype] = claim_button

	var result_label := Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(result_label)
	tower_claim_result_labels[ttype] = result_label

	_update_tower_claim_buttons()

	return card

func _make_unit_card(unit_name: String, available: bool, owned: bool, sprite_path: String, cols: int, rows: int, stats_table: Dictionary) -> Control:
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
	name_label.text = unit_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	var image_holder := Control.new()
	image_holder.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(image_holder)

	if available:
		var sprite := _build_looping_sprite(sprite_path, cols, rows)
		sprite.scale = Vector2(1.8, 1.8)
		image_holder.add_child(sprite)
		var recenter := func():
			sprite.position = image_holder.size / 2.0
		image_holder.resized.connect(recenter)
		recenter.call()
	else:
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

	var stats_label := Label.new()
	if stats_table.has(unit_name):
		var s: Dictionary = stats_table[unit_name]
		var dmg_str: String = "N/A" if s.damage == null else str(s.damage)
		var atk_str: String = "N/A" if s.atk_speed == null else str(s.atk_speed)
		stats_label.text = "HP: %d | DMG: %s | ATK Spd: %s\nDEF: %d | Move Spd: %d" % [s.hp, dmg_str, atk_str, s.defense, s.move_speed]
	else:
		stats_label.text = "NA% Mine Speed"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(stats_label)

	var claim_status := Label.new()
	claim_status.text = "Owned" if owned else "Locked"
	claim_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	claim_status.add_theme_font_size_override("font_size", 18)
	claim_status.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1) if owned else Color(1, 1, 1, 0.6))
	vbox.add_child(claim_status)

	return card

# Reusable frame slicer
var _sprite_frames_cache: Dictionary = {}

func _build_looping_sprite(texture_path: String, cols: int, rows: int) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	if not ResourceLoader.exists(texture_path):
		push_warning("ShopPopup: missing sprite at %s" % texture_path)
		return sprite

	if not _sprite_frames_cache.has(texture_path):
		var texture: Texture2D = load(texture_path)
		var frame_w: float = texture.get_width() / float(cols)
		var frame_h: float = texture.get_height() / float(rows)

		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 8.0)

		for row in range(rows):
			for col in range(cols):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
				frames.add_frame("idle", atlas)

		_sprite_frames_cache[texture_path] = frames

	sprite.sprite_frames = _sprite_frames_cache[texture_path]
	sprite.play("idle")
	return sprite
