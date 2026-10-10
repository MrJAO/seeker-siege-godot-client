extends Node

signal tile_selected(grid_pos: Vector2i, world_pos: Vector2)
signal selection_cleared
signal tower_placed_at(grid_pos: Vector2i, tower_id: int)
signal tower_staged(tower_id: int, world_pos: Vector2)
signal placement_confirmed(tower_id: int)
signal placement_cancelled
signal show_placement_toggled(enabled: bool)
signal show_range_toggled(enabled: bool)
signal show_spawn_area_toggled(enabled: bool)

var selected_grid_pos: Vector2i = Vector2i.ZERO
var selected_world_pos: Vector2 = Vector2.ZERO
var has_selection: bool = false

var pending_tower_id: int = -1
var pending_grid_pos: Vector2i = Vector2i.ZERO
var pending_node: Node2D = null

var show_placement_enabled: bool = false
var show_range_enabled: bool = false
var show_spawn_area_enabled: bool = false

var active_turret_nodes: Dictionary = {}

const TURRET_SCENES := {
	"machine_gun": "res://scenes/turrets/machine_gun.tscn",
	"railgun": "res://scenes/turrets/railgun.tscn",
	"freeze_ray": "res://scenes/turrets/freeze_ray.tscn",
	"rocket_launcher": "res://scenes/turrets/rocket_launcher.tscn",
	"flamethrower": "res://scenes/turrets/flamethrower.tscn",
}

var turrets_container: Node = null

# Drag to relocate
var is_dragging_pending: bool = false
const DRAG_REVERT_ON_INVALID: bool = true

func register_container(container: Node) -> void:
	turrets_container = container

func select_tile(grid_pos: Vector2i, world_pos: Vector2) -> bool:
	if pending_tower_id != -1:
		return false
	if not GridManager.is_buildable(grid_pos) or not GridManager.is_far_enough(world_pos):
		return false
	selected_grid_pos = grid_pos
	selected_world_pos = world_pos
	has_selection = true
	emit_signal("tile_selected", grid_pos, world_pos)
	return true

func cancel_selection() -> void:
	has_selection = false
	emit_signal("selection_cleared")

func get_available_inventory() -> Array:
	var result: Array = []
	for id in TowerManager.owned_towers.keys():
		var t: Dictionary = TowerManager.owned_towers[id]
		if not t.placed and t.get("enabled", true):
			result.append(t)
	return result

func stage_tower_for_confirmation(tower_id: int) -> bool:
	if not has_selection or pending_tower_id != -1:
		return false
	if not TowerManager.owned_towers.has(tower_id):
		return false
	if TowerManager.is_on_cooldown(tower_id):
		return false
	var tower_type: String = TowerManager.owned_towers[tower_id].type
	var scene_path: String = TURRET_SCENES.get(tower_type, "")
	if scene_path == "" or turrets_container == null:
		return false

	pending_node = load(scene_path).instantiate()
	turrets_container.add_child(pending_node)
	pending_node.global_position = selected_world_pos
	pending_node.modulate = Color(1, 1, 1, 0.6)
	pending_node.is_active = false
	pending_node.set_tower_id(tower_id)

	pending_tower_id = tower_id
	pending_grid_pos = selected_grid_pos
	has_selection = false
	emit_signal("tower_staged", tower_id, selected_world_pos)
	return true

func confirm_placement() -> bool:
	if pending_tower_id == -1 or pending_node == null:
		return false
	if not GridManager.place_turret(pending_grid_pos, pending_tower_id, pending_node.global_position):
		return false
	if not TowerManager.place_tower(pending_tower_id, pending_node.global_position):
		GridManager.remove_turret(pending_grid_pos)
		_discard_pending()
		return false

	pending_node.modulate = Color(1, 1, 1, 1)
	pending_node.is_active = true
	active_turret_nodes[pending_tower_id] = pending_node

	emit_signal("tower_placed_at", pending_grid_pos, pending_tower_id)
	emit_signal("placement_confirmed", pending_tower_id)

	pending_tower_id = -1
	pending_grid_pos = Vector2i.ZERO
	pending_node = null
	is_dragging_pending = false
	return true

# Retrieve placed tower positions
func restore_turret(tower_id: int, grid_pos: Vector2i, world_pos: Vector2) -> bool:
	if turrets_container == null or not TowerManager.owned_towers.has(tower_id):
		return false
	var tower_type: String = TowerManager.owned_towers[tower_id].type
	var scene_path: String = TURRET_SCENES.get(tower_type, "")
	if scene_path == "":
		return false
	if not GridManager.place_turret(grid_pos, tower_id, world_pos):
		return false
	var node = load(scene_path).instantiate()
	turrets_container.add_child(node)
	node.global_position = world_pos
	node.set_tower_id(tower_id)
	node.is_active = true
	active_turret_nodes[tower_id] = node
	return true

func cancel_placement() -> void:
	_discard_pending()
	emit_signal("placement_cancelled")

func _discard_pending() -> void:
	if pending_node:
		pending_node.queue_free()
	pending_node = null
	pending_tower_id = -1
	is_dragging_pending = false

func relocate_tower(tower_id: int) -> bool:
	if not TowerManager.can_relocate(tower_id):
		return false
	if not TowerManager.relocate_to_inventory(tower_id):
		return false
	remove_turret_node(tower_id)
	return true

# Disable tower when holdings drop
func remove_turret_node(tower_id: int) -> void:
	var grid_pos = GridManager.get_grid_pos_for_tower(tower_id)
	if grid_pos != null:
		GridManager.remove_turret(grid_pos)
	if active_turret_nodes.has(tower_id):
		var node = active_turret_nodes[tower_id]
		if is_instance_valid(node):
			node.queue_free()
		active_turret_nodes.erase(tower_id)

func clear_all_placed_turrets() -> void:
	for node in active_turret_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	active_turret_nodes.clear()
	_discard_pending()

func toggle_show_placement() -> void:
	show_placement_enabled = not show_placement_enabled
	emit_signal("show_placement_toggled", show_placement_enabled)

func toggle_show_range() -> void:
	show_range_enabled = not show_range_enabled
	emit_signal("show_range_toggled", show_range_enabled)

func toggle_show_spawn_area() -> void:
	show_spawn_area_enabled = not show_spawn_area_enabled
	emit_signal("show_spawn_area_toggled", show_spawn_area_enabled)

# Drag to relocate pending condition

func _unhandled_input(event: InputEvent) -> void:
	if pending_tower_id == -1 or pending_node == null:
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
		if event.pressed:
			is_dragging_pending = true
		else:
			if is_dragging_pending:
				is_dragging_pending = false
				_finalize_drag_position()
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and is_dragging_pending:
		_move_pending(event.relative)
		get_viewport().set_input_as_handled()

func _move_pending(relative: Vector2) -> void:
	var camera := get_viewport().get_camera_2d()
	var zoom: float = camera.zoom.x if camera else 1.0
	pending_node.global_position += relative / zoom

func _finalize_drag_position() -> void:
	if not InputManager.tilemap:
		return
	var tilemap: TileMap = InputManager.tilemap
	var local_pos: Vector2 = tilemap.to_local(pending_node.global_position)
	var grid_pos: Vector2i = tilemap.local_to_map(local_pos)
	var snapped_world: Vector2 = tilemap.to_global(tilemap.map_to_local(grid_pos))

	if InputManager.is_tile_buildable(grid_pos) and GridManager.is_far_enough(snapped_world):
		pending_grid_pos = grid_pos
		pending_node.global_position = snapped_world
		emit_signal("tower_staged", pending_tower_id, snapped_world)
	else:
		var revert_world: Vector2 = tilemap.to_global(tilemap.map_to_local(pending_grid_pos))
		pending_node.global_position = revert_world
		emit_signal("tower_staged", pending_tower_id, revert_world)
