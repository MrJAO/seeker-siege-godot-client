extends Node

const MIN_TOWER_DISTANCE: float = 45.0

var occupied: Dictionary = {}
var placed_positions: Dictionary = {}

func is_buildable(grid_pos: Vector2i) -> bool:
	return not occupied.has(grid_pos)

func is_far_enough(world_pos: Vector2) -> bool:
	for pos in placed_positions.values():
		if world_pos.distance_to(pos) < MIN_TOWER_DISTANCE:
			return false
	return true

func place_turret(grid_pos: Vector2i, tower_id: int, world_pos: Vector2) -> bool:
	if not is_buildable(grid_pos) or not is_far_enough(world_pos):
		return false
	occupied[grid_pos] = tower_id
	placed_positions[tower_id] = world_pos
	return true

func get_tower_id_at(grid_pos: Vector2i) -> int:
	return occupied.get(grid_pos, -1)

func get_grid_pos_for_tower(tower_id: int):
	for pos in occupied.keys():
		if occupied[pos] == tower_id:
			return pos
	return null

func remove_turret(grid_pos: Vector2i) -> void:
	var tower_id: int = occupied.get(grid_pos, -1)
	occupied.erase(grid_pos)
	placed_positions.erase(tower_id)

func clear_all() -> void:
	occupied.clear()
	placed_positions.clear()
