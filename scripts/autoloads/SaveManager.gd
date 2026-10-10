extends Node

const SAVE_PATH: String = "user://save_data.json"

func save_game() -> void:
	var data: Dictionary = {
		"region": GameManager.current_region,
		"map": GameManager.current_map,
		"has_placed_tower": GameManager.has_placed_tower,
		"resources": ResourceManager.balances,
		"resource_roles": ResourceManager.resource_roles,
		"has_assigned_resources": ResourceManager.has_assigned_resources,
		"reactor_hp": ReactorManager.current_hp,
		"reactor_tier": ReactorManager.reactor_tier,
		"reactor_unlocked_tier": ReactorManager.unlocked_tier,
		"kill_progress": MapManager.current_kills,
		"skill_points": SkillTreeManager.global_skill_points,
		"skill_node_levels": SkillTreeManager.global_node_levels,
		"skr_balance": SKRManager.skr_balance,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	var data: Dictionary = parsed
	GameManager.current_region = data.get("region", 1)
	GameManager.current_map = data.get("map", 1)
	GameManager.has_placed_tower = data.get("has_placed_tower", false)
	ResourceManager.balances = data.get("resources", ResourceManager.balances)
	ResourceManager.resource_roles = data.get("resource_roles", {})
	ResourceManager.has_assigned_resources = data.get("has_assigned_resources", false)
	ReactorManager.current_hp = data.get("reactor_hp", ReactorManager.current_hp)
	ReactorManager.reactor_tier = data.get("reactor_tier", 1)
	ReactorManager.unlocked_tier = data.get("reactor_unlocked_tier", 1)
	MapManager.current_kills = data.get("kill_progress", 0)
	SkillTreeManager.global_skill_points = data.get("skill_points", 0)
	SkillTreeManager.global_node_levels = data.get("skill_node_levels", {})
	SKRManager.skr_balance = data.get("skr_balance", 0.0)
	return true
