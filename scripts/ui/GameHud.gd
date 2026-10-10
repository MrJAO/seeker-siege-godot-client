extends Control

@onready var energy_label: Label = $TopCenterGroup/ResourceBar/EnergyBox/EnergyMargin/EnergyRow/EnergyLabel
@onready var scraps_label: Label = $TopCenterGroup/ResourceBar/ScrapsBox/ScrapsMargin/ScrapsRow/ScrapsLabel
@onready var oil_label: Label = $TopCenterGroup/ResourceBar/OilBox/OilMargin/OilRow/OilLabel
@onready var skr_label: Label = $TopCenterGroup/ResourceBar/SkrBox/SkrMargin/SkrRow/SkrLabel
@onready var region_map_button: Button = $TopCenterGroup/TopBarColumn/TopBar/RegionMapButton
@onready var start_button: Button = $TopCenterGroup/TopBarColumn/TopBar/StartButton
@onready var next_map_button: Button = $TopCenterGroup/TopBarColumn/TopBar/NextMapButton
@onready var show_placement_button: Button = $LeftPanel/ShowPlacementButton
@onready var show_range_button: Button = $LeftPanel/ShowRangeButton
@onready var show_spawn_area_button: Button = $LeftPanel/ShowSpawnAreaButton
@onready var skill_tree_button: Button = $LeftPanel/SkillTreeButton
@onready var kill_progress_label: Label = $LeftPanel/KillProgressBox/KillProgressMargin/KillProgressVBox/KillProgressLabel
@onready var kill_progress_bar: ProgressBar = $LeftPanel/KillProgressBox/KillProgressMargin/KillProgressVBox/KillProgressBar
@onready var spawn_countdown_label: Label = $TopCenterGroup/TopBarColumn/SpawnCountdownLabel

@onready var home_button: Button = $RightPanel/HomeButton
@onready var inventory_button: Button = $RightPanel/InventoryButton
@onready var shop_button: Button = $RightPanel/ShopButton
@onready var marketplace_button: Button = $RightPanel/MarketplaceButton
@onready var profile_button: Button = $RightPanel/ProfileButton
@onready var settings_button: Button = $RightPanel/SettingsButton

@onready var resource_icons: Array = [
	$TopCenterGroup/ResourceBar/EnergyBox/EnergyMargin/EnergyRow/EnergyIcon,
	$TopCenterGroup/ResourceBar/ScrapsBox/ScrapsMargin/ScrapsRow/ScrapsIcon,
	$TopCenterGroup/ResourceBar/OilBox/OilMargin/OilRow/OilIcon,
	$TopCenterGroup/ResourceBar/SkrBox/SkrMargin/SkrRow/SkrIcon,
]
@onready var resource_labels: Array = [energy_label, scraps_label, oil_label, skr_label]
@onready var game_menu_buttons: Array = [home_button, inventory_button, shop_button, marketplace_button, profile_button, settings_button]
@onready var top_bar_buttons: Array = [region_map_button, start_button, next_map_button]
@onready var left_panel_buttons: Array = [show_placement_button, show_range_button, show_spawn_area_button, skill_tree_button]

# icon/min-size px per scale level, by section.
const GAME_MENU_ICON_SIZES := {1.0: 60.0, 2.0: 120.0, 3.0: 180.0}
const RESOURCE_ICON_SIZES := {1.0: 20.0, 2.0: 40.0, 3.0: 60.0}
const RESOURCE_FONT_SIZES := {1.0: 16, 2.0: 22, 3.0: 28}
const TOPBAR_REGION_SIZES := {1.0: Vector2(0, 40), 2.0: Vector2(230, 80), 3.0: Vector2(340, 110)}
const TOPBAR_SIDE_SIZES := {1.0: Vector2(0, 40), 2.0: Vector2(130, 80), 3.0: Vector2(180, 110)}
const TOPBAR_FONT_SIZES := {1.0: 16, 2.0: 30, 3.0: 42}
const LEFTPANEL_SIZES := {1.0: Vector2(0, 40), 1.5: Vector2(260, 60), 2.0: Vector2(300, 70)}
const LEFTPANEL_FONT_SIZES := {1.0: 16, 1.5: 20, 2.0: 24}

var popups: Dictionary = {}
var game_map: Node = null

func setup(popup_dict: Dictionary) -> void:
	popups = popup_dict
	if popup_dict.has("game_map"):
		game_map = popup_dict["game_map"]

func _ready() -> void:
	ResourceManager.balance_changed.connect(_on_balance_changed)
	SKRManager.skr_balance_changed.connect(_on_skr_balance_changed)
	region_map_button.pressed.connect(_on_region_map_pressed)
	start_button.pressed.connect(_on_start_pressed)
	next_map_button.pressed.connect(_on_next_map_pressed)
	show_placement_button.pressed.connect(_on_show_placement_pressed)
	show_range_button.pressed.connect(_on_show_range_pressed)
	show_spawn_area_button.pressed.connect(_on_show_spawn_area_pressed)
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)

	home_button.pressed.connect(_on_home_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	marketplace_button.pressed.connect(_on_marketplace_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	home_button.disabled = true

	UIScaleManager.scale_changed.connect(_on_scale_changed)
	_apply_game_menu_scale(UIScaleManager.get_scale("game_menu"))
	_apply_resources_scale(UIScaleManager.get_scale("resources"))
	_apply_top_center_scale(UIScaleManager.get_scale("top_center"))
	_apply_top_left_scale(UIScaleManager.get_scale("top_left"))

	_refresh_resource_labels()

func _on_scale_changed(section: String, factor: float) -> void:
	match section:
		"game_menu":
			_apply_game_menu_scale(factor)
		"resources":
			_apply_resources_scale(factor)
		"top_center":
			_apply_top_center_scale(factor)
		"top_left":
			_apply_top_left_scale(factor)

func _apply_game_menu_scale(factor: float) -> void:
	var icon_size: float = GAME_MENU_ICON_SIZES.get(factor, GAME_MENU_ICON_SIZES[2.0])
	for btn in game_menu_buttons:
		btn.custom_minimum_size = Vector2(icon_size, icon_size)

func _apply_resources_scale(factor: float) -> void:
	var icon_size: float = RESOURCE_ICON_SIZES.get(factor, RESOURCE_ICON_SIZES[2.0])
	var font_size: int = RESOURCE_FONT_SIZES.get(factor, RESOURCE_FONT_SIZES[2.0])
	for icon in resource_icons:
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
	for label in resource_labels:
		label.add_theme_font_size_override("font_size", font_size)

func _apply_top_center_scale(factor: float) -> void:
	var region_size: Vector2 = TOPBAR_REGION_SIZES.get(factor, TOPBAR_REGION_SIZES[2.0])
	var side_size: Vector2 = TOPBAR_SIDE_SIZES.get(factor, TOPBAR_SIDE_SIZES[2.0])
	var font_size: int = TOPBAR_FONT_SIZES.get(factor, TOPBAR_FONT_SIZES[2.0])
	region_map_button.custom_minimum_size = region_size
	region_map_button.add_theme_font_size_override("font_size", font_size)
	for btn in [start_button, next_map_button]:
		btn.custom_minimum_size = side_size
		btn.add_theme_font_size_override("font_size", font_size)

func _apply_top_left_scale(factor: float) -> void:
	var btn_size: Vector2 = LEFTPANEL_SIZES.get(factor, LEFTPANEL_SIZES[1.5])
	var font_size: int = LEFTPANEL_FONT_SIZES.get(factor, LEFTPANEL_FONT_SIZES[1.5])
	for btn in left_panel_buttons:
		btn.custom_minimum_size = btn_size
		btn.add_theme_font_size_override("font_size", font_size)
	kill_progress_label.add_theme_font_size_override("font_size", font_size)

func _process(_delta: float) -> void:
	_refresh_buttons()
	_refresh_spawn_countdown()

func _refresh_resource_labels() -> void:
	energy_label.text = "%d" % int(ResourceManager.get_balance("energy"))
	scraps_label.text = "%d" % int(ResourceManager.get_balance("scraps"))
	oil_label.text = "%d" % int(ResourceManager.get_balance("oil"))
	skr_label.text = "%d" % int(SKRManager.skr_balance)

func _on_balance_changed(_resource: String, _amount: float) -> void:
	_refresh_resource_labels()

func _on_skr_balance_changed(_new_amount: float) -> void:
	_refresh_resource_labels()

func _refresh_buttons() -> void:
	region_map_button.text = "Region %d - Map %d" % [GameManager.current_region, GameManager.current_map]

	start_button.visible = not GameManager.map_session_active
	start_button.disabled = not GameManager.check_can_start()

	var needed: int = MapManager.required_kills(GameManager.current_region, GameManager.current_map)
	var already_cleared: bool = MapManager.is_map_cleared(GameManager.current_region, GameManager.current_map)
	var kill_met: bool = already_cleared or MapManager.current_kills >= needed
	next_map_button.visible = kill_met and MapManager.is_next_map_available()
	next_map_button.disabled = not MapManager.can_switch_map()

	show_placement_button.text = "Show Placement: %s" % ("ON" if BuildManager.show_placement_enabled else "OFF")
	show_range_button.text = "Show Range: %s" % ("ON" if BuildManager.show_range_enabled else "OFF")
	show_spawn_area_button.text = "Show Spawn Area: %s" % ("ON" if BuildManager.show_spawn_area_enabled else "OFF")

	kill_progress_label.text = _progress_label_text()
	kill_progress_bar.max_value = needed
	kill_progress_bar.value = needed if already_cleared else MapManager.current_kills

func _refresh_spawn_countdown() -> void:
	if not game_map or not GameManager.map_session_active or GameManager.current_map == MapManager.BOSS_MAP:
		spawn_countdown_label.visible = false
		return
	var interval: float = game_map.get_spawn_interval()
	var remaining: float = max(0.0, interval - game_map.spawn_timer)
	spawn_countdown_label.visible = true
	var displayed: int = max(0, int(ceil(remaining - 0.001)))
	spawn_countdown_label.text = "Spawning In: %ds" % displayed

func _progress_label_text() -> String:
	if GameManager.current_region == 1 and GameManager.current_map == MapManager.BOSS_MAP:
		return "Defeat the Terra Golem"
	if not MapManager.is_next_map_available():
		return "Ancient Ruins Secured"
	return "Unlock Region %d - Map %d" % [GameManager.current_region, _next_map_number()]

func _next_map_number() -> int:
	if GameManager.current_map < MapManager.MAPS_PER_REGION:
		return GameManager.current_map + 1
	return 1

func _on_region_map_pressed() -> void:
	if popups.has("region_map"):
		popups["region_map"].open()

func _on_start_pressed() -> void:
	var ok: bool = await ServerState.start_session()
	if ok:
		GameManager.start_game()
	elif game_map and game_map.has_method("show_notice"):
		game_map.show_notice("Could not start - check connection")

func _on_next_map_pressed() -> void:
	MapManager.advance_to_next_map()

func _on_show_placement_pressed() -> void:
	BuildManager.toggle_show_placement()

func _on_show_range_pressed() -> void:
	BuildManager.toggle_show_range()

func _on_show_spawn_area_pressed() -> void:
	BuildManager.toggle_show_spawn_area()

func _on_skill_tree_pressed() -> void:
	if popups.has("skill_tree"):
		popups["skill_tree"].open()

func _on_home_pressed() -> void:
	for key in popups.keys():
		if popups[key] is CanvasItem:
			popups[key].visible = false

func _on_inventory_pressed() -> void:
	if popups.has("inventory"):
		popups["inventory"].open()

func _on_shop_pressed() -> void:
	if popups.has("shop"):
		popups["shop"].open()

func _on_marketplace_pressed() -> void:
	if popups.has("marketplace") and game_map and game_map.has_method("open_with_lock_banner"):
		game_map.open_with_lock_banner(popups["marketplace"], "marketplace")

func _on_profile_pressed() -> void:
	if popups.has("profile"):
		popups["profile"].open()

func _on_settings_pressed() -> void:
	if popups.has("settings"):
		popups["settings"].open()
