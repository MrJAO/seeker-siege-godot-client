extends Node

signal tower_placed(tower_id: int)
signal tower_leveled_up(tower_id: int, new_level: int)
signal tower_ascended(tower_id: int, new_tier: int)
signal tower_relocated(tower_id: int)
signal towers_returned_to_inventory
signal tower_exp_changed(tower_id: int, exp: float, exp_to_next: float)
signal hidden_node_leveled(tower_id: int, node_id: String, new_level: int)

const RELOCATE_COOLDOWN_MAX: float = 300.0

const TIER_LEVEL_CAP := [20, 50, 80, 100]
const TIER_STAT_MULT := [1.0, 1.5, 2.1, 2.9]

# Towers initial and shared stats
const BASE_STATS := {
	"machine_gun":     {"dmg": 5.0,  "atk_speed": 9.0, "range": 260.0},
	"freeze_ray":       {"dmg": 12.0, "atk_speed": 7.5, "range": 260.0},
	"rocket_launcher":  {"dmg": 14.0, "atk_speed": 4.5, "range": 260.0},
	"railgun":          {"dmg": 15.0, "atk_speed": 3.0, "range": 260.0},
	"flamethrower":     {"dmg": 10.0, "atk_speed": 6.6, "range": 260.0},
}

const RANGE_PER_LEVEL: float = 2.0

# AoE base kit
const BASE_SPLASH_RADIUS := {
	"machine_gun": 0.0,
	"railgun": 0.0,
	"freeze_ray": 0.0,
	"rocket_launcher": 70.0,
	"flamethrower": 50.0,
}
const BASE_SPLASH_DAMAGE_MULT: float = 0.5

const ASCEND_COST_BASE := {"energy": 500.0, "scraps": 500.0, "oil": 500.0}
const ASCEND_COST_MULT: float = 1.8

const TYPE_EFFECTIVENESS := {
	"machine_gun": "cyber",
	"freeze_ray": "water",
	"rocket_launcher": "earth",
	"railgun": "steel",
	"flamethrower": "shadow",
}

var owned_towers: Dictionary = {}
var _next_id: int = 1

const HIDDEN_TREE := {
	"minor_dmg": {"prereq": null, "max_level": 3, "sp_cost": 1, "resource_mult": 1.0},
	"minor_atkspd": {"prereq": "minor_dmg", "max_level": 3, "sp_cost": 1, "resource_mult": 1.5},
	"medium_bonus": {"prereq": "minor_atkspd", "max_level": 2, "sp_cost": 2, "resource_mult": 3.0},
	"strong_bonus": {"prereq": "medium_bonus", "max_level": 2, "sp_cost": 2, "resource_mult": 5.0},
	"capstone": {"prereq": "strong_bonus", "max_level": 1, "sp_cost": 3, "resource_mult": 8.0},
}
const HIDDEN_BASE_RESOURCE_COST: float = 200.0
const HIDDEN_UNLOCK_TIER: int = 2

func _make_tower_data(tower_type: String) -> Dictionary:
	return {
		"id": _next_id,
		"type": tower_type,
		"tier": 1,
		"level": 1,
		"exp": 0.0,
		"placed": false,
		"position": Vector2.ZERO,
		"relocate_timer": 0.0,
		"hidden_skill_levels": {},
	}

func add_tower_to_inventory(tower_type: String) -> int:
	if not BASE_STATS.has(tower_type):
		return -1
	var data: Dictionary = _make_tower_data(tower_type)
	owned_towers[_next_id] = data
	var id: int = _next_id
	_next_id += 1
	return id

# Called after ServerState restores owned_towers
func set_next_id_floor(min_next_id: int) -> void:
	_next_id = max(_next_id, min_next_id)

func place_tower(tower_id: int, position: Vector2) -> bool:
	if not owned_towers.has(tower_id):
		return false
	var t: Dictionary = owned_towers[tower_id]
	if t.placed:
		return false
	if t.relocate_timer > 0.0:
		return false
	t.placed = true
	t.position = position
	owned_towers[tower_id] = t
	GameManager.register_tower_placed()
	emit_signal("tower_placed", tower_id)
	return true

func return_all_towers_to_inventory() -> void:
	for id in owned_towers.keys():
		var t: Dictionary = owned_towers[id]
		if t.placed:
			t.placed = false
			t.position = Vector2.ZERO
			t.relocate_timer = 0.0
			owned_towers[id] = t
	emit_signal("towers_returned_to_inventory")

func has_any_placed_tower() -> bool:
	for id in owned_towers.keys():
		if owned_towers[id].placed:
			return true
	return false

func unplace_tower(tower_id: int) -> void:
	if not owned_towers.has(tower_id):
		return
	var t: Dictionary = owned_towers[tower_id]
	t.placed = false
	t.position = Vector2.ZERO
	owned_towers[tower_id] = t

func is_on_cooldown(tower_id: int) -> bool:
	if not owned_towers.has(tower_id):
		return false
	return owned_towers[tower_id].relocate_timer > 0.0

func get_relocate_cooldown_remaining(tower_id: int) -> float:
	if not owned_towers.has(tower_id):
		return 0.0
	return owned_towers[tower_id].relocate_timer

func can_relocate(tower_id: int) -> bool:
	if not owned_towers.has(tower_id):
		return false
	var t: Dictionary = owned_towers[tower_id]
	return t.placed and t.relocate_timer <= 0.0

func relocate_to_inventory(tower_id: int) -> bool:
	if not can_relocate(tower_id):
		return false
	var t: Dictionary = owned_towers[tower_id]
	t.placed = false
	t.position = Vector2.ZERO
	t.relocate_timer = RELOCATE_COOLDOWN_MAX * SkillTreeManager.get_relocate_cooldown_mult()
	owned_towers[tower_id] = t
	emit_signal("tower_relocated", tower_id)
	return true

func _process(delta: float) -> void:
	for id in owned_towers.keys():
		var t: Dictionary = owned_towers[id]
		if t.relocate_timer > 0.0:
			t.relocate_timer = max(0.0, t.relocate_timer - delta)
			owned_towers[id] = t

func exp_to_next_level(level: int) -> float:
	return 100.0 * pow(1.15, level - 1)

func level_gap_penalty(tower_level: int, map_recommended_level: int) -> float:
	var gap: int = abs(tower_level - map_recommended_level)
	if gap <= 10:
		return 1.0
	var steps: int = int((gap - 10) / 5.0) + 1
	return max(0.1, 1.0 - (0.1 * steps))

func grant_exp(tower_id: int, amount: float, map_recommended_level: int) -> void:
	if not owned_towers.has(tower_id):
		return
	var t: Dictionary = owned_towers[tower_id]
	var cap: int = TIER_LEVEL_CAP[t.tier - 1]
	if t.level >= cap:
		return
	var penalty: float = level_gap_penalty(t.level, map_recommended_level)
	t.exp += amount * penalty
	while t.exp >= exp_to_next_level(t.level) and t.level < cap:
		t.exp -= exp_to_next_level(t.level)
		t.level += 1
		emit_signal("tower_leveled_up", tower_id, t.level)
	owned_towers[tower_id] = t
	emit_signal("tower_exp_changed", tower_id, t.exp, exp_to_next_level(t.level))

func is_ascension_level_met(tower_id: int) -> bool:
	if not owned_towers.has(tower_id):
		return false
	var t: Dictionary = owned_towers[tower_id]
	if t.tier >= TIER_LEVEL_CAP.size():
		return false
	return t.level >= TIER_LEVEL_CAP[t.tier - 1]

func can_ascend(tower_id: int) -> bool:
	if not owned_towers.has(tower_id):
		return false
	var t: Dictionary = owned_towers[tower_id]
	if t.tier >= TIER_LEVEL_CAP.size():
		return false
	if t.level < TIER_LEVEL_CAP[t.tier - 1]:
		return false
	return ResourceManager.has_enough(ascend_cost(t.tier))

func ascend_cost(current_tier: int) -> Dictionary:
	var mult: float = pow(ASCEND_COST_MULT, current_tier - 1)
	return {
		"energy": ASCEND_COST_BASE.energy * mult,
		"scraps": ASCEND_COST_BASE.scraps * mult,
		"oil": ASCEND_COST_BASE.oil * mult,
	}

func ascend_tower(tower_id: int) -> bool:
	if not can_ascend(tower_id):
		return false
	var t: Dictionary = owned_towers[tower_id]
	if not ResourceManager.spend_resources(ascend_cost(t.tier)):
		return false
	t.tier += 1
	owned_towers[tower_id] = t
	emit_signal("tower_ascended", tower_id, t.tier)
	return true

func get_computed_stats(tower_id: int) -> Dictionary:
	var t: Dictionary = owned_towers[tower_id]
	var base: Dictionary = BASE_STATS[t.type]
	var tier_mult: float = TIER_STAT_MULT[t.tier - 1]
	var level_mult: float = 1.0 + (0.04 * (t.level - 1))
	var skill_dmg_mult: float = SkillTreeManager.get_combat_damage_mult() * SkillTreeManager.get_tower_type_damage_mult(t.type) * get_hidden_damage_mult(tower_id) * (1.0 + get_hidden_damage_strong_bonus(tower_id))
	var skill_atkspd_mult: float = SkillTreeManager.get_combat_atkspd_mult() * SkillTreeManager.get_tower_type_atkspd_mult(t.type) * get_hidden_atkspd_mult(tower_id) * (1.0 + get_hidden_atkspd_strong_bonus(tower_id))
	var skill_range_mult: float = SkillTreeManager.get_tower_type_range_mult(t.type)
	var crit_chance: float = SkillTreeManager.get_combat_crit_chance() + SkillTreeManager.get_tower_type_crit_chance(t.type) + get_hidden_crit_chance_bonus(tower_id)
	var crit_dmg_mult: float = SkillTreeManager.get_combat_crit_dmg_mult() + get_hidden_crit_dmg_bonus(tower_id)

	# Active Combo/Synergy bonuses
	var dmg_bonus: float = 0.0
	var atkspd_bonus: float = 0.0
	var crit_chance_bonus: float = 0.0
	var crit_dmg_bonus: float = 0.0
	for combo_key in get_active_combos_for_tower(tower_id):
		var combo: Dictionary = COMBO_DEFINITIONS[combo_key]
		if combo.has("dmg_bonus_types"):
			if t.type in combo.dmg_bonus_types:
				dmg_bonus += combo.get("dmg_bonus", 0.0)
		elif combo.has("dmg_bonus"):
			dmg_bonus += combo.dmg_bonus
		if combo.has("atkspd_bonus"):
			atkspd_bonus += combo.atkspd_bonus
		if combo.has("crit_chance_bonus"):
			crit_chance_bonus += combo.crit_chance_bonus
		if combo.has("crit_dmg_bonus"):
			crit_dmg_bonus += combo.crit_dmg_bonus

	return {
		"dmg": base.dmg * tier_mult * level_mult * skill_dmg_mult * (1.0 + dmg_bonus),
		"atk_speed": base.atk_speed * tier_mult * level_mult * skill_atkspd_mult * (1.0 + atkspd_bonus),
		"range": base.range * skill_range_mult + 20.0 * (t.tier - 1) + RANGE_PER_LEVEL * (t.level - 1),
		"crit_chance": crit_chance + crit_chance_bonus,
		"crit_dmg_mult": crit_dmg_mult + crit_dmg_bonus,
	}

# AoE radius, mirrors get_computed_stats()
func get_computed_splash_radius(tower_id: int) -> float:
	var t: Dictionary = owned_towers[tower_id]
	var base_radius: float = BASE_SPLASH_RADIUS.get(t.type, 0.0)
	if base_radius <= 0.0:
		return 0.0
	var radius: float = base_radius + SkillTreeManager.get_splash_radius_bonus() + get_hidden_splash_radius_bonus(tower_id)
	for combo_key in get_active_combos_for_tower(tower_id):
		var combo: Dictionary = COMBO_DEFINITIONS[combo_key]
		if combo.has("splash_bonus_types") and t.type in combo.splash_bonus_types:
			radius += combo.get("splash_bonus", 0.0)
	return radius

func get_computed_splash_damage_mult(tower_id: int) -> float:
	return BASE_SPLASH_DAMAGE_MULT + get_hidden_splash_damage_mult_bonus(tower_id)

# Tower Combos / Synergy
const COMBO_DEFINITIONS := {
	"machine_gun|railgun": {
		"name": "Focused Barrage",
		"description": "Machine Gun and Railgun share targeting data, boosting each other's Crit Chance by 15% while in range of each other.",
		"crit_chance_bonus": 0.15,
	},
	"freeze_ray|rocket_launcher": {
		"name": "Frozen Payload",
		"description": "Rocket Launcher warheads are pre-chilled by Freeze Ray, boosting Rocket Launcher's Damage by 20% and Splash Radius by 20 while in range of each other.",
		"dmg_bonus_types": ["rocket_launcher"],
		"dmg_bonus": 0.20,
		"splash_bonus_types": ["rocket_launcher"],
		"splash_bonus": 20.0,
	},
	"freeze_ray|machine_gun": {
		"name": "Chill Assist",
		"description": "Machine Gun and Freeze Ray synchronize fire timing, boosting each other's Attack Speed by 15% while in range of each other.",
		"atkspd_bonus": 0.15,
	},
	"flamethrower|railgun": {
		"name": "Charged Ignition",
		"description": "Railgun's charge cycle and Flamethrower's ignition trigger in sync, boosting each other's Attack Speed by 15% while in range of each other.",
		"atkspd_bonus": 0.15,
	},
	"freeze_ray|railgun": {
		"name": "Static Frost",
		"description": "Freeze Ray and Railgun resonance boosts each other's Crit Damage by 15% while in range of each other.",
		"crit_dmg_bonus": 0.15,
	},
	"machine_gun|rocket_launcher": {
		"name": "Suppressive Fire",
		"description": "Machine Gun suppression lets Rocket Launcher reload faster, boosting each other's Attack Speed by 15% while in range of each other.",
		"atkspd_bonus": 0.15,
	},
	"flamethrower|freeze_ray": {
		"name": "Thermal Shock",
		"description": "Extreme heat/cold contrast weakens enemy armor, boosting each other's Damage by 20% while in range of each other.",
		"dmg_bonus": 0.20,
	},
	"railgun|rocket_launcher": {
		"name": "Heavy Ordnance",
		"description": "Shared heavy-ordnance targeting data boosts each other's Damage by 20% while in range of each other.",
		"dmg_bonus": 0.20,
	},
	"flamethrower|machine_gun": {
		"name": "Fuel the Fire",
		"description": "Machine Gun fire keeps Flamethrower fuel lines pressurized, boosting each other's Attack Speed by 15% while in range of each other.",
		"atkspd_bonus": 0.15,
	},
	"flamethrower|rocket_launcher": {
		"name": "Combustion Chain",
		"description": "Rocket detonations ignite Flamethrower fuel clouds, boosting each other's Damage by 20% while in range of each other.",
		"dmg_bonus": 0.20,
	},
}

const COMBO_ICON_PATHS := {
	"machine_gun|railgun": "res://assets/icons/focused_barrage_icon.png",
	"freeze_ray|machine_gun": "res://assets/icons/chill_assist_icon.png",
	"flamethrower|railgun": "res://assets/icons/charged_ignition_icon.png",
	"freeze_ray|railgun": "res://assets/icons/static_frost_icon.png",
	"machine_gun|rocket_launcher": "res://assets/icons/suprressive_fire_icon.png",
	"flamethrower|freeze_ray": "res://assets/icons/thermal_shock_icon.png",
	"railgun|rocket_launcher": "res://assets/icons/heavy_ordinance_icon.png",
	"flamethrower|machine_gun": "res://assets/icons/fuel_the_fire_icon.png",
	"flamethrower|rocket_launcher": "res://assets/icons/combustion_chain_icon.png",
	"freeze_ray|rocket_launcher": "res://assets/icons/frozen_payload_icon.png",
}

func get_combo_icon_path(combo_key: String) -> String:
	return COMBO_ICON_PATHS.get(combo_key, "")

func _combo_key(type_a: String, type_b: String) -> String:
	var pair: Array = [type_a, type_b]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]

func get_combo_definition(type_a: String, type_b: String) -> Dictionary:
	return COMBO_DEFINITIONS.get(_combo_key(type_a, type_b), {})

func _get_base_range(tower_id: int) -> float:
	var t: Dictionary = owned_towers[tower_id]
	var base: Dictionary = BASE_STATS[t.type]
	var skill_range_mult: float = SkillTreeManager.get_tower_type_range_mult(t.type)
	return base.range * skill_range_mult + 20.0 * (t.tier - 1) + RANGE_PER_LEVEL * (t.level - 1)

func get_active_combos_for_tower(tower_id: int) -> Array:
	var active: Array = []
	if not owned_towers.has(tower_id):
		return active
	var t: Dictionary = owned_towers[tower_id]
	if not t.placed:
		return active
	var my_range: float = _get_base_range(tower_id)
	for other_id in owned_towers.keys():
		if other_id == tower_id:
			continue
		var other: Dictionary = owned_towers[other_id]
		if not other.placed:
			continue
		var combo_key: String = _combo_key(t.type, other.type)
		if not COMBO_DEFINITIONS.has(combo_key) or active.has(combo_key):
			continue
		var other_range: float = _get_base_range(other_id)
		var distance: float = t.position.distance_to(other.position)
		if distance <= min(my_range, other_range):
			active.append(combo_key)
	return active

func is_combo_active_anywhere(combo_key: String) -> bool:
	for tower_id in owned_towers.keys():
		if get_active_combos_for_tower(tower_id).has(combo_key):
			return true
	return false

func get_type_effectiveness_bonus(tower_type: String, region_element: String) -> float:
	if TYPE_EFFECTIVENESS.get(tower_type, "") == region_element:
		return 1.25
	return 1.0

func has_hidden_tree_unlocked(tower_id: int) -> bool:
	if not owned_towers.has(tower_id):
		return false
	return owned_towers[tower_id].tier >= HIDDEN_UNLOCK_TIER

func get_hidden_node_level(tower_id: int, node_id: String) -> int:
	if not owned_towers.has(tower_id):
		return 0
	return owned_towers[tower_id].hidden_skill_levels.get(node_id, 0)

func is_hidden_node_unlockable(tower_id: int, node_id: String) -> bool:
	if not has_hidden_tree_unlocked(tower_id):
		return false
	if not HIDDEN_TREE.has(node_id):
		return false
	var node: Dictionary = HIDDEN_TREE[node_id]
	var level: int = get_hidden_node_level(tower_id, node_id)
	if level >= node.max_level:
		return false
	if node.prereq != null and get_hidden_node_level(tower_id, node.prereq) < 1:
		return false
	return true

func hidden_node_cost(node_id: String) -> Dictionary:
	var mult: float = HIDDEN_TREE[node_id].resource_mult
	var amount: float = HIDDEN_BASE_RESOURCE_COST * mult
	return {"energy": amount, "scraps": amount, "oil": amount}

func can_purchase_hidden_node(tower_id: int, node_id: String) -> bool:
	if not is_hidden_node_unlockable(tower_id, node_id):
		return false
	var sp_cost: int = HIDDEN_TREE[node_id].sp_cost
	if SkillTreeManager.global_skill_points < sp_cost:
		return false
	return ResourceManager.has_enough(hidden_node_cost(node_id))

func purchase_hidden_node(tower_id: int, node_id: String) -> bool:
	if not can_purchase_hidden_node(tower_id, node_id):
		return false
	if not ResourceManager.spend_resources(hidden_node_cost(node_id)):
		return false
	SkillTreeManager.global_skill_points -= HIDDEN_TREE[node_id].sp_cost
	var t: Dictionary = owned_towers[tower_id]
	t.hidden_skill_levels[node_id] = get_hidden_node_level(tower_id, node_id) + 1
	owned_towers[tower_id] = t
	emit_signal("hidden_node_leveled", tower_id, node_id, t.hidden_skill_levels[node_id])
	return true


# Hidden skill bonuses
func get_hidden_damage_mult(tower_id: int) -> float:
	return 1.0 + 0.05 * get_hidden_node_level(tower_id, "minor_dmg")

func get_hidden_atkspd_mult(tower_id: int) -> float:
	return 1.0 + 0.05 * get_hidden_node_level(tower_id, "minor_atkspd")

func get_hidden_crit_chance_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "machine_gun":
		return 0.0
	return 0.05 * get_hidden_node_level(tower_id, "medium_bonus")

func get_hidden_crit_dmg_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "railgun":
		return 0.0
	return 0.10 * get_hidden_node_level(tower_id, "medium_bonus")

func get_hidden_freeze_duration_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "freeze_ray":
		return 0.0
	return 0.5 * get_hidden_node_level(tower_id, "medium_bonus")

func get_hidden_splash_radius_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "rocket_launcher":
		return 0.0
	return 15.0 * get_hidden_node_level(tower_id, "medium_bonus")

func get_hidden_burn_dps_percent_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "flamethrower":
		return 0.0
	return 0.01 * get_hidden_node_level(tower_id, "medium_bonus")

func get_hidden_atkspd_strong_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "machine_gun":
		return 0.0
	return 0.10 * get_hidden_node_level(tower_id, "strong_bonus")

func get_hidden_damage_strong_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "railgun":
		return 0.0
	return 0.10 * get_hidden_node_level(tower_id, "strong_bonus")

func get_hidden_freeze_proc_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "freeze_ray":
		return 0.0
	return 0.10 * get_hidden_node_level(tower_id, "strong_bonus")

func get_hidden_splash_damage_mult_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "rocket_launcher":
		return 0.0
	return 0.10 * get_hidden_node_level(tower_id, "strong_bonus")

func get_hidden_burn_proc_bonus(tower_id: int) -> float:
	if not owned_towers.has(tower_id) or owned_towers[tower_id].type != "flamethrower":
		return 0.0
	return 0.10 * get_hidden_node_level(tower_id, "strong_bonus")

func has_hidden_capstone(tower_id: int) -> bool:
	return get_hidden_node_level(tower_id, "capstone") >= 1
