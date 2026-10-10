extends Node

signal tile_clicked(grid_pos: Vector2i, world_pos: Vector2)
signal turret_clicked(turret: Node2D)
signal reactor_clicked(reactor: Node2D)
signal time_traveler_clicked(npc: Node2D)
signal portal_guard_clicked(npc: Node2D)
signal armory_clicked(building: Node2D)
signal deployment_clicked(building: Node2D)
signal engineer_clicked(npc: Node2D)
signal chief_clicked(npc: Node2D)
signal mining_shaft_clicked(building: Node2D)
signal mr_miner_clicked(npc: Node2D)
signal empty_clicked
signal camera_drag_delta(delta: Vector2)

var tilemap: TileMap = null
var buildable_layer_name: String = "BuildableZones"

const DRAG_THRESHOLD: float = 14.0

var pointer_down: bool = false
var press_screen_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false

func setup_tilemap(map: TileMap) -> void:
	tilemap = map

func _unhandled_input(event: InputEvent) -> void:
	if BuildManager.pending_tower_id != -1:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down = true
			is_dragging = false
			press_screen_pos = event.position
		else:
			if pointer_down and not is_dragging:
				_process_tap()
			pointer_down = false
			is_dragging = false
	elif event is InputEventMouseMotion and pointer_down:
		if not is_dragging and press_screen_pos.distance_to(event.position) > DRAG_THRESHOLD:
			is_dragging = true
		if is_dragging:
			camera_drag_delta.emit(event.relative)

func _process_tap() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var world_pos: Vector2 = camera.get_global_mouse_position()

	var space_state := get_tree().root.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := space_state.intersect_point(query, 32)

	if result.size() > 0:
		for hit in result:
			var collider = hit.collider
			var parent = collider.get_parent()
			if parent.is_in_group("turret"):
				turret_clicked.emit(parent)
				return
			elif parent.is_in_group("reactor"):
				reactor_clicked.emit(parent)
				return
			elif parent.is_in_group("time_traveler"):
				time_traveler_clicked.emit(parent)
				return
			elif parent.is_in_group("portal_guard"):
				portal_guard_clicked.emit(parent)
				return
			elif parent.is_in_group("armory_building"):
				armory_clicked.emit(parent)
				return
			elif parent.is_in_group("deployment_building"):
				deployment_clicked.emit(parent)
				return
			elif parent.is_in_group("engineer"):
				engineer_clicked.emit(parent)
				return
			elif parent.is_in_group("chief"):
				chief_clicked.emit(parent)
				return
			elif parent.is_in_group("mining_shaft_building"):
				mining_shaft_clicked.emit(parent)
				return
			elif parent.is_in_group("mr_miner"):
				mr_miner_clicked.emit(parent)
				return

	if tilemap:
		var local_pos: Vector2 = tilemap.to_local(world_pos)
		var grid_pos: Vector2i = tilemap.local_to_map(local_pos)
		if is_tile_buildable(grid_pos):
			var tile_center: Vector2 = tilemap.to_global(tilemap.map_to_local(grid_pos))
			tile_clicked.emit(grid_pos, tile_center)
			return

	empty_clicked.emit()

func is_tile_buildable(grid_pos: Vector2i) -> bool:
	if not tilemap:
		return false
	for layer in range(tilemap.get_layers_count()):
		var tile_data = tilemap.get_cell_tile_data(layer, grid_pos)
		if tile_data != null and tilemap.get_layer_name(layer) == buildable_layer_name:
			return GridManager.is_buildable(grid_pos)
	return false

func get_all_buildable_positions() -> Array:
	var result: Array = []
	if not tilemap:
		return result
	for layer in range(tilemap.get_layers_count()):
		if tilemap.get_layer_name(layer) == buildable_layer_name:
			for cell in tilemap.get_used_cells(layer):
				result.append(cell)
	return result
