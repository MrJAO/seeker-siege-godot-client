extends Node2D

@export var region: int = 1
@export var map: int = 1

@onready var ancient_ruins_map: TileMap = $AncientRuinsMap
@onready var turrets_container: Node2D = $TurretsContainer
@onready var mobs_container: Node2D = $MobsContainer
@onready var build_popup = $UILayer/BuildCancelPopup
@onready var tower_select_popup = $UILayer/TowerSelectPopup
@onready var confirm_popup = $UILayer/ConfirmPlacementPopup
@onready var region_map_popup = $UILayer/RegionMapSwitchPopup
@onready var game_hud = $UILayer/GameHud
@onready var tower_info_popup = $UILayer/TowerInfoPopup
@onready var reactor_info_popup = $UILayer/ReactorInfoPopup
@onready var inventory_popup = $UILayer/InventoryPopup
@onready var shop_popup = $UILayer/ShopPopup
@onready var settings_popup = $UILayer/SettingsPopup
@onready var resource_assign_popup = $UILayer/ResourceAssignPopup
@onready var time_traveler = $TimeTraveler
@onready var time_traveler_popup = $UILayer/TimeTravelerPopup
@onready var armory_popup = $UILayer/ArmoryPopup
@onready var deployment_popup = $UILayer/DeploymentPopup
@onready var mining_shaft_popup = $UILayer/MiningShaftPopup
@onready var marketplace_popup = $UILayer/MarketplacePopup
@onready var profile_popup = $UILayer/ProfilePopup
@onready var camera: Camera2D = $Camera2D
@onready var energy_reactor: Node2D = $EnergyReactor

const TOWER_KEEP_POPUP_SCENE := preload("res://scenes/ui/TowerKeepPopup.tscn")
var tower_keep_popup: Control = null

var tile_highlight: Node2D = null
var placement_overlay: Node2D = null
var spawn_area_overlay: Node2D = null

const SPAWN_TIER_OFFSETS := {
	"easy_regular": 0,
	"fast_easy_regular": 2,
	"medium": 4,
	"hard": 6,
}

# Preloaded game assets once at script-parse-time
const REGION_MOB_ROSTER := {
	1: {
		"easy_regular": preload("res://scenes/mobs/clay_golem_mob.tscn"),
		"fast_easy_regular": preload("res://scenes/mobs/stone_crawler_mob.tscn"),
		"medium": preload("res://scenes/mobs/earth_elemental_mob.tscn"),
		"hard": preload("res://scenes/mobs/rock_sentinel_mob.tscn"),
		"boss": preload("res://scenes/mobs/terra_golem_boss.tscn"),
	},
	2: {
		"easy_regular": preload("res://scenes/mobs/forge_construct_mob.tscn"),
		"fast_easy_regular": preload("res://scenes/mobs/rust_bug_mob.tscn"),
		"medium": preload("res://scenes/mobs/steel_guardian_mob.tscn"),
		"hard": preload("res://scenes/mobs/molten_golem_mob.tscn"),
		"boss": preload("res://scenes/mobs/iron_colossus_boss.tscn"),
	},
	3: {
		"easy_regular": preload("res://scenes/mobs/water_sprite_mob.tscn"),
		"fast_easy_regular": preload("res://scenes/mobs/wave_rider_mob.tscn"),
		"medium": preload("res://scenes/mobs/thunder_eel_mob.tscn"),
		"hard": preload("res://scenes/mobs/tidal_beast_mob.tscn"),
		"boss": preload("res://scenes/mobs/storm_leviathan_boss.tscn"),
	},
	4: {
		"easy_regular": preload("res://scenes/mobs/volt_bettle_mob.tscn"),
		"fast_easy_regular": preload("res://scenes/mobs/drone_scout_mob.tscn"),
		"medium": preload("res://scenes/mobs/nano_swarm_mob.tscn"),
		"hard": preload("res://scenes/mobs/plasma_walker_mob.tscn"),
		"boss": preload("res://scenes/mobs/cyber_phoenix_boss.tscn"),
	},
	5: {
		"easy_regular": preload("res://scenes/mobs/dark_phantom_mob.tscn"),
		"fast_easy_regular": preload("res://scenes/mobs/shadow_imp_mob.tscn"),
		"medium": preload("res://scenes/mobs/shade_walker_mob.tscn"),
		"hard": preload("res://scenes/mobs/nightmare_mob.tscn"),
		"boss": preload("res://scenes/mobs/void_wraith_boss.tscn"),
	},
}

const SPAWN_LAYER_NAMES := ["Edges"]
const MOBS_SPAWNED_PER_FRAME: int = 5
const ACT1_COMPLETE_POPUP := preload("res://scenes/ui/Act1CompletePopup.tscn")

var spawn_timer: float = 0.0
var spawning_active: bool = false
var boss_spawned: bool = false
var map_used_rect: Rect2i
var spawn_edge_cells: Array = []
var spawn_queue: Array = []

func _ready() -> void:
	GameManager.current_region = region
	GameManager.current_map = map

	InputManager.setup_tilemap(ancient_ruins_map)
	InputManager.tile_clicked.connect(_on_tile_clicked)
	BuildManager.register_container(turrets_container)
	BuildManager.tile_selected.connect(_on_build_tile_selected)
	BuildManager.selection_cleared.connect(_hide_tile_highlight)
	BuildManager.show_placement_toggled.connect(_on_show_placement_toggled)
	BuildManager.show_spawn_area_toggled.connect(_on_show_spawn_area_toggled)
	build_popup.open_tower_select.connect(func(): tower_select_popup.open())
	game_hud.setup({
		"region_map": region_map_popup,
		"skill_tree": $UILayer/SkillTreePopup,
		"inventory": inventory_popup,
		"shop": shop_popup,
		"marketplace": marketplace_popup,
		"profile": profile_popup,
		"settings": settings_popup,
		"game_map": self,
	})
	GameManager.session_started.connect(_on_session_started)
	GameManager.session_ended.connect(_on_session_ended)
	InputManager.turret_clicked.connect(_on_turret_clicked)
	InputManager.reactor_clicked.connect(_on_reactor_clicked)
	InputManager.camera_drag_delta.connect(_on_camera_drag_delta)
	InputManager.time_traveler_clicked.connect(_on_time_traveler_clicked)
	InputManager.armory_clicked.connect(_on_armory_clicked)
	InputManager.deployment_clicked.connect(_on_deployment_clicked)
	InputManager.mining_shaft_clicked.connect(_on_mining_shaft_clicked)
	MapManager.act1_completed.connect(_on_act1_completed)
	tower_info_popup.set_hidden_skill_popup($UILayer/HiddenSkillPopup)
	map_used_rect = ancient_ruins_map.get_used_rect()
	_compute_spawn_edge_cells()
	_center_camera_on_map()
	time_traveler.set_anchor(energy_reactor.global_position)
	_create_tile_highlight()
	_create_placement_overlay()
	_create_spawn_area_overlay()
	_restore_placed_towers()
	_show_pending_notice()
	if not ResourceManager.has_assigned_resources:
		resource_assign_popup.open()

	tower_keep_popup = TOWER_KEEP_POPUP_SCENE.instantiate()
	$UILayer.add_child(tower_keep_popup)
	if ServerState.tower_holdings.get("needsSelection", false):
		tower_keep_popup.open()

	_apply_all_popup_scales()
	UIScaleManager.scale_changed.connect(_on_popup_scale_changed)

# Popup node map
func _popup_scale_targets() -> Dictionary:
	return {
		"inventory": inventory_popup,
		"shop": shop_popup,
		"marketplace": marketplace_popup,
		"profile": profile_popup,
		"settings": settings_popup,
		"armory": armory_popup,
		"deployment": deployment_popup,
		"mining_shaft": mining_shaft_popup,
		"portal": time_traveler_popup,
	}

func _apply_all_popup_scales() -> void:
	for section in _popup_scale_targets().keys():
		_apply_popup_scale(_popup_scale_targets()[section], UIScaleManager.get_scale(section))

func _on_popup_scale_changed(section: String, factor: float) -> void:
	var targets: Dictionary = _popup_scale_targets()
	if targets.has(section):
		_apply_popup_scale(targets[section], factor)

func _apply_popup_scale(popup: Control, factor: float) -> void:
	popup.pivot_offset = popup.size / 2.0
	popup.scale = Vector2(factor, factor)

func _on_time_traveler_clicked(_npc: Node2D) -> void:
	open_with_lock_banner(time_traveler_popup, "skr_exchange")

func _on_armory_clicked(_building: Node2D) -> void:
	open_with_lock_banner(armory_popup, "armory")

func _on_deployment_clicked(_building: Node2D) -> void:
	open_with_lock_banner(deployment_popup, "deployment")

func _on_mining_shaft_clicked(_building: Node2D) -> void:
	open_with_lock_banner(mining_shaft_popup, "mining_shaft")

# Gated Popups
func open_with_lock_banner(popup: Control, feature: String) -> void:
	var vbox: Node = popup.get_node_or_null("Margin/VBox")
	if vbox:
		var banner: Label = vbox.get_node_or_null("LockBanner")
		if banner == null:
			banner = Label.new()
			banner.name = "LockBanner"
			banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			banner.add_theme_font_size_override("font_size", 16)
			banner.add_theme_color_override("font_color", Color(0.65, 0.05, 0.05, 1))
			vbox.add_child(banner)
			vbox.move_child(banner, 1)
		banner.text = MapManager.get_lock_text(feature)
		banner.visible = not MapManager.is_feature_unlocked(feature)
	popup.open()

# Towers keep their placed state across maps
func _restore_placed_towers() -> void:
	for tower_id in TowerManager.owned_towers.keys():
		var t: Dictionary = TowerManager.owned_towers[tower_id]
		if not t.placed:
			continue
		var world_pos: Vector2 = t.position
		var grid_pos: Vector2i = ancient_ruins_map.local_to_map(ancient_ruins_map.to_local(world_pos))
		if InputManager.is_tile_buildable(grid_pos) and GridManager.is_far_enough(world_pos):
			BuildManager.restore_turret(tower_id, grid_pos, world_pos)
		else:
			TowerManager.unplace_tower(tower_id)
	GameManager.has_placed_tower = TowerManager.has_any_placed_tower()

func _show_pending_notice() -> void:
	var notice: String = MapManager.consume_notice()
	if notice != "":
		show_notice(notice)

func show_notice(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	$UILayer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 80.0
	label.offset_bottom = 110.0
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _on_act1_completed() -> void:
	var popup = ACT1_COMPLETE_POPUP.instantiate()
	$UILayer.add_child(popup)
	popup.continue_pressed.connect(func(): MapManager.return_after_act1())

func _is_camera_input_blocked() -> bool:
	return time_traveler_popup.visible or resource_assign_popup.visible or armory_popup.visible or deployment_popup.visible or mining_shaft_popup.visible or inventory_popup.visible or shop_popup.visible or marketplace_popup.visible or settings_popup.visible or BuildManager.pending_tower_id != -1

func _compute_spawn_edge_cells() -> void:
	var valid_cells: Dictionary = {}
	for layer in range(ancient_ruins_map.get_layers_count()):
		var layer_name: String = ancient_ruins_map.get_layer_name(layer)
		if layer_name in SPAWN_LAYER_NAMES:
			for cell in ancient_ruins_map.get_used_cells(layer):
				valid_cells[cell] = true

	spawn_edge_cells.clear()
	for cell in valid_cells.keys():
		var neighbors = [
			Vector2i(cell.x + 1, cell.y),
			Vector2i(cell.x - 1, cell.y),
			Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x, cell.y - 1),
		]
		for n in neighbors:
			if not valid_cells.has(n):
				spawn_edge_cells.append(cell)
				break

func _on_session_started() -> void:
	spawning_active = true
	spawn_timer = 0.0
	if map == MapManager.BOSS_MAP and not boss_spawned:
		_spawn_boss_once()

func _on_session_ended() -> void:
	spawning_active = false
	spawn_queue.clear()
	for mob in mobs_container.get_children():
		mob.queue_free()

func get_spawn_interval() -> float:
	return float(map)

func _process(delta: float) -> void:
	if not spawn_queue.is_empty():
		var n: int = min(MOBS_SPAWNED_PER_FRAME, spawn_queue.size())
		for i in range(n):
			_spawn_mob(spawn_queue.pop_front())

	if not spawning_active or map == MapManager.BOSS_MAP:
		return
	spawn_timer += delta
	if spawn_timer >= get_spawn_interval():
		spawn_timer = 0.0
		_spawn_wave()

func get_spawn_count(spawn_tier: String, local_map: int) -> int:
	return max(0, local_map - SPAWN_TIER_OFFSETS.get(spawn_tier, 0))

func _get_roster() -> Dictionary:
	return REGION_MOB_ROSTER.get(region, REGION_MOB_ROSTER[1])

func _spawn_wave() -> void:
	var roster: Dictionary = _get_roster()
	for spawn_tier in SPAWN_TIER_OFFSETS.keys():
		var count: int = get_spawn_count(spawn_tier, map)
		if count <= 0 or not roster.has(spawn_tier):
			continue
		for i in range(count):
			spawn_queue.append(roster[spawn_tier])

func _spawn_boss_once() -> void:
	boss_spawned = true
	var roster: Dictionary = _get_roster()
	if roster.has("boss"):
		spawn_queue.append(roster.boss)

func _get_random_spawn_point() -> Vector2:
	if spawn_edge_cells.is_empty():
		return Vector2.ZERO
	var grid_pos: Vector2i = spawn_edge_cells[randi() % spawn_edge_cells.size()]
	var world_pos: Vector2 = ancient_ruins_map.to_global(ancient_ruins_map.map_to_local(grid_pos))
	var tile_size: Vector2i = ancient_ruins_map.tile_set.tile_size
	world_pos += Vector2(randf_range(-tile_size.x / 6.0, tile_size.x / 6.0), randf_range(-tile_size.y / 6.0, tile_size.y / 6.0))
	return world_pos

func _spawn_mob(mob_scene: PackedScene) -> void:
	if not mob_scene:
		push_warning("GameMap: null mob scene in spawn queue")
		return
	var mob = mob_scene.instantiate()
	mobs_container.add_child(mob)
	mob.global_position = _get_random_spawn_point()

func _center_camera_on_map() -> void:
	var top_left: Vector2 = ancient_ruins_map.map_to_local(map_used_rect.position)
	var bottom_right: Vector2 = ancient_ruins_map.map_to_local(map_used_rect.position + map_used_rect.size)
	var center_local: Vector2 = (top_left + bottom_right) / 2.0
	camera.global_position = ancient_ruins_map.to_global(center_local)

func _on_tile_clicked(grid_pos: Vector2i, world_pos: Vector2) -> void:
	BuildManager.select_tile(grid_pos, world_pos)

func _on_turret_clicked(turret: Node2D) -> void:
	if turret.tower_id != -1:
		tower_info_popup.open(turret.tower_id, turret.global_position, turret)

func _on_reactor_clicked(_reactor: Node2D) -> void:
	reactor_info_popup.open()

const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.0
const ZOOM_STEP: float = 0.1

var active_touches: Dictionary = {}
var pinch_start_distance: float = 0.0
var pinch_start_zoom: float = 1.0

func _on_camera_drag_delta(delta: Vector2) -> void:
	if _is_camera_input_blocked():
		return
	camera.global_position -= delta / camera.zoom.x

func _unhandled_input(event: InputEvent) -> void:
	if _is_camera_input_blocked():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(-ZOOM_STEP)
	elif event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
			if active_touches.size() == 2:
				pinch_start_distance = _touch_distance()
				pinch_start_zoom = camera.zoom.x
		else:
			active_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		if active_touches.size() == 2 and pinch_start_distance > 0.0:
			var dist: float = _touch_distance()
			var ratio: float = dist / pinch_start_distance
			var new_zoom: float = clamp(pinch_start_zoom * ratio, ZOOM_MIN, ZOOM_MAX)
			camera.zoom = Vector2(new_zoom, new_zoom)

func _touch_distance() -> float:
	var positions: Array = active_touches.values()
	if positions.size() < 2:
		return 0.0
	return positions[0].distance_to(positions[1])

func _zoom_camera(delta: float) -> void:
	var new_zoom: float = clamp(camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(new_zoom, new_zoom)

func _create_tile_highlight() -> void:
	tile_highlight = Node2D.new()
	tile_highlight.z_index = 10
	tile_highlight.visible = false
	add_child(tile_highlight)
	tile_highlight.draw.connect(_draw_tile_highlight)

func _draw_tile_highlight() -> void:
	var points := _diamond_points()
	tile_highlight.draw_colored_polygon(points, Color(0, 1, 0, 0.25))
	tile_highlight.draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 1, 0, 0.9), 2.0)

func _diamond_points() -> PackedVector2Array:
	var tile_size: Vector2i = ancient_ruins_map.tile_set.tile_size
	var half_w: float = tile_size.x / 2.0
	var half_h: float = tile_size.y / 2.0
	return PackedVector2Array([
		Vector2(0, -half_h),
		Vector2(half_w, 0),
		Vector2(0, half_h),
		Vector2(-half_w, 0),
	])

func _on_build_tile_selected(_grid_pos: Vector2i, world_pos: Vector2) -> void:
	tile_highlight.global_position = world_pos
	tile_highlight.visible = true
	tile_highlight.queue_redraw()

func _hide_tile_highlight() -> void:
	tile_highlight.visible = false

func _create_placement_overlay() -> void:
	placement_overlay = Node2D.new()
	placement_overlay.z_index = 9
	placement_overlay.visible = false
	add_child(placement_overlay)
	placement_overlay.draw.connect(_draw_placement_overlay)

func _draw_placement_overlay() -> void:
	var points := _diamond_points()
	for grid_pos in InputManager.get_all_buildable_positions():
		var world_pos: Vector2 = ancient_ruins_map.map_to_local(grid_pos)
		var offset_points := PackedVector2Array()
		for p in points:
			offset_points.append(p + world_pos)
		placement_overlay.draw_colored_polygon(offset_points, Color(0, 1, 0, 0.15))
		placement_overlay.draw_polyline(offset_points + PackedVector2Array([offset_points[0]]), Color(0, 1, 0, 0.6), 1.5)

func _on_show_placement_toggled(enabled: bool) -> void:
	placement_overlay.visible = enabled
	if enabled:
		placement_overlay.queue_redraw()

func _create_spawn_area_overlay() -> void:
	spawn_area_overlay = Node2D.new()
	spawn_area_overlay.z_index = 9
	spawn_area_overlay.visible = false
	add_child(spawn_area_overlay)
	spawn_area_overlay.draw.connect(_draw_spawn_area_overlay)

func _draw_spawn_area_overlay() -> void:
	var points := _diamond_points()
	for grid_pos in spawn_edge_cells:
		var world_pos: Vector2 = ancient_ruins_map.map_to_local(grid_pos)
		var offset_points := PackedVector2Array()
		for p in points:
			offset_points.append(p + world_pos)
		spawn_area_overlay.draw_colored_polygon(offset_points, Color(1, 0, 0, 0.15))
		spawn_area_overlay.draw_polyline(offset_points + PackedVector2Array([offset_points[0]]), Color(1, 0, 0, 0.8), 1.5)

func _on_show_spawn_area_toggled(enabled: bool) -> void:
	spawn_area_overlay.visible = enabled
	if enabled:
		spawn_area_overlay.queue_redraw()

# Temporary test hooks
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			MapManager.furthest_unlocked_map = max(MapManager.furthest_unlocked_map, 6)
			show_notice("DEBUG: Map 6 features unlocked")
		elif event.keycode == KEY_F9:
			MapManager.grant_boss_reward(1)
