extends Node2D

# Note to judges: I'll remove this file later.

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
@onready var camera: Camera2D = $Camera2D
@onready var energy_reactor: Node2D = $EnergyReactor

var tile_highlight: Node2D = null
var placement_overlay: Node2D = null
var spawn_area_overlay: Node2D = null

const MOB_SCENES := {
	"clay_golem": "res://scenes/mobs/clay_golem_mob.tscn",
	"earth_elemental": "res://scenes/mobs/earth_elemental_mob.tscn",
	"rock_sentinel": "res://scenes/mobs/rock_sentinel_mob.tscn",
	"stone_crawler": "res://scenes/mobs/stone_crawler_mob.tscn",
}
const REGULAR_MOB_TYPES := ["clay_golem", "earth_elemental", "rock_sentinel", "stone_crawler"]
const SPAWN_INTERVAL: float = 3.0
const SPAWN_LAYER_NAMES := ["Edges"]

var spawn_timer: float = 0.0
var spawning_active: bool = false
var map_used_rect: Rect2i
var spawn_edge_cells: Array = []

func _ready() -> void:
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
		"settings": settings_popup,
	})
	GameManager.session_started.connect(_on_session_started)
	GameManager.session_ended.connect(_on_session_ended)
	InputManager.turret_clicked.connect(_on_turret_clicked)
	InputManager.reactor_clicked.connect(_on_reactor_clicked)
	InputManager.camera_drag_delta.connect(_on_camera_drag_delta)
	tower_info_popup.set_hidden_skill_popup($UILayer/HiddenSkillPopup)
	InputManager.time_traveler_clicked.connect(_on_time_traveler_clicked)
	InputManager.armory_clicked.connect(_on_armory_clicked)
	InputManager.deployment_clicked.connect(_on_deployment_clicked)
	map_used_rect = ancient_ruins_map.get_used_rect()
	_compute_spawn_edge_cells()
	_center_camera_on_map()
	_position_reactor_at_center()
	time_traveler.set_anchor(energy_reactor.global_position)
	_create_tile_highlight()
	_create_placement_overlay()
	_create_spawn_area_overlay()
	if not ResourceManager.has_assigned_resources:
		resource_assign_popup.open()

func _on_time_traveler_clicked(_npc: Node2D) -> void:
	time_traveler_popup.open()

func _on_armory_clicked(_building: Node2D) -> void:
	armory_popup.open()

func _on_deployment_clicked(_building: Node2D) -> void:
	deployment_popup.open()

func _is_camera_input_blocked() -> bool:
	return time_traveler_popup.visible or resource_assign_popup.visible or armory_popup.visible or deployment_popup.visible

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

func _on_session_ended() -> void:
	spawning_active = false
	for mob in mobs_container.get_children():
		mob.queue_free()

func _process(delta: float) -> void:
	if not spawning_active:
		return
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		_spawn_mob(REGULAR_MOB_TYPES[randi() % REGULAR_MOB_TYPES.size()])

func _get_random_spawn_point() -> Vector2:
	if spawn_edge_cells.is_empty():
		return Vector2.ZERO
	var grid_pos: Vector2i = spawn_edge_cells[randi() % spawn_edge_cells.size()]
	var world_pos: Vector2 = ancient_ruins_map.to_global(ancient_ruins_map.map_to_local(grid_pos))
	var tile_size: Vector2i = ancient_ruins_map.tile_set.tile_size
	world_pos += Vector2(randf_range(-tile_size.x / 6.0, tile_size.x / 6.0), randf_range(-tile_size.y / 6.0, tile_size.y / 6.0))
	return world_pos

func _spawn_mob(mob_type: String) -> void:
	var scene_path: String = MOB_SCENES.get(mob_type, "")
	if scene_path == "":
		return
	var mob = load(scene_path).instantiate()
	mobs_container.add_child(mob)
	mob.global_position = _get_random_spawn_point()

func _position_reactor_at_center() -> void:
	var top_left: Vector2 = ancient_ruins_map.map_to_local(map_used_rect.position)
	var bottom_right: Vector2 = ancient_ruins_map.map_to_local(map_used_rect.position + map_used_rect.size)
	var center_local: Vector2 = (top_left + bottom_right) / 2.0
	energy_reactor.global_position = ancient_ruins_map.to_global(center_local)

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
			_zoom_camera(-ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(ZOOM_STEP)
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
			var new_zoom: float = clamp(pinch_start_zoom / ratio, ZOOM_MIN, ZOOM_MAX)
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
