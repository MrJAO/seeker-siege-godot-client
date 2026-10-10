extends Node

signal balance_changed(resource: String, new_amount: float)
signal resource_roles_assigned

var balances: Dictionary = {
	"energy": 0.0,
	"scraps": 0.0,
	"oil": 0.0,
}

# Resource role assignment
var resource_roles: Dictionary = {}
var has_assigned_resources: bool = false

const ROLE_BASE_CHANCE_PERCENT := {
	"primary": 15.0,
	"secondary": 10.0,
	"tertiary": 5.0,
}
const DROP_SCALE_PER_MAP_PERCENT: float = 0.5

const TIER_DROP_QTY_BASE := {
	"regular": 1,
	"medium": 2,
	"hard": 3,
	"boss": 0,
}

func get_tier_drop_qty(tier: String, region: int) -> int:
	if tier == "boss":
		return 0
	var base: int = TIER_DROP_QTY_BASE.get(tier, 0)
	return base + (region - 1)

func assign_resource_roles(primary: String, secondary: String, tertiary: String) -> void:
	resource_roles = {
		"primary": primary,
		"secondary": secondary,
		"tertiary": tertiary,
	}
	has_assigned_resources = true
	emit_signal("resource_roles_assigned")

func get_drop_chance_percent(role: String) -> float:
	var base: float = ROLE_BASE_CHANCE_PERCENT.get(role, 0.0)
	var global_map_index: int = MapManager.get_global_map_index(GameManager.current_region, GameManager.current_map)
	var scaled: float = base + DROP_SCALE_PER_MAP_PERCENT * float(global_map_index - 1)
	scaled *= SkillTreeManager.get_resource_reward_mult()
	return min(scaled, 100.0)

func roll_resource_drops(mob_type: String) -> void:
	if not has_assigned_resources:
		return
	var tier: String = ReactorManager.MOB_TIER.get(mob_type, "regular")
	var qty: int = get_tier_drop_qty(tier, GameManager.current_region)
	if qty <= 0:
		return
	for role in resource_roles.keys():
		var chance_percent: float = get_drop_chance_percent(role)
		if randf() * 100.0 < chance_percent:
			add_resource(resource_roles[role], qty)

func get_balance(resource: String) -> float:
	return balances.get(resource, 0.0)

func add_resource(resource: String, amount: float) -> void:
	if not balances.has(resource) or amount <= 0.0:
		return
	balances[resource] += amount
	emit_signal("balance_changed", resource, balances[resource])

func has_enough(cost: Dictionary) -> bool:
	for resource in cost.keys():
		if get_balance(resource) < cost[resource]:
			return false
	return true

func spend_resources(cost: Dictionary) -> bool:
	if not has_enough(cost):
		return false
	for resource in cost.keys():
		balances[resource] -= cost[resource]
		emit_signal("balance_changed", resource, balances[resource])
	return true
