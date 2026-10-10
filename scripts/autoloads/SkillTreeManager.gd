extends Node

signal global_node_leveled(node_id: String, new_level: int)

const CORE_MASTERY_COST := {"energy": 10.0, "scraps": 10.0, "oil": 10.0}
const TOWER_HUB_COST := {"energy": 20.0, "scraps": 20.0, "oil": 20.0}

# Combat branch: 100 -> +50 per node
const COMBAT_NODE_COSTS := {
	"combat_dmg1": 100.0,
	"combat_atkspd1": 150.0,
	"combat_crit_chance": 200.0,
	"combat_crit_dmg": 250.0,
	"combat_dmg2": 300.0,
	"combat_atkspd2": 350.0,
	"combat_splash": 400.0,
	"combat_capstone": 2000.0,
}

# Survival branch: 50 -> +50 per node
const SURVIVAL_NODE_COSTS := {
	"surv_max_hp1": 50.0,
	"surv_regen_rate1": 100.0,
	"surv_regen_delay": 150.0,
	"surv_max_hp2": 200.0,
	"surv_regen_rate2": 250.0,
	"surv_grace_window": 300.0,
	"surv_recovery_threshold": 350.0,
	"surv_capstone": 1200.0,
}

# Economy branch: every node has its own unique fixed cost
const ECONOMY_NODE_COSTS := {
	"econ_drop_rate1": 500.0,
	"econ_crypto_drop": 1500.0,
	"econ_relocate_cd": 250.0,
	"econ_switch_cd": 250.0,
	"econ_drop_rate2": 1000.0,
	"econ_skr_efficiency": 3000.0,
	"econ_passive_prod": 2500.0,
	"econ_capstone": 5000.0,
}

# Tower Mastery: same 100 -> +50 pattern per suffix, shared across all 5 tower types
# Capstone is a fixed unique value regardless of tower type
const TOWER_MASTERY_NODE_COSTS := {
	"dmg1": 100.0,
	"atkspd1": 150.0,
	"range1": 200.0,
	"crit": 250.0,
	"dmg2": 300.0,
	"special": 350.0,
	"capstone": 2500.0,
}

const SWITCH_COOLDOWN_MAX: float = 300.0
const SWITCH_COOLDOWN_MIN: float = 90.0

var GLOBAL_TREE := {
	"core_mastery": {"prereq": null, "max_level": 1},

	"combat_dmg1": {"prereq": "core_mastery", "max_level": 3},
	"combat_atkspd1": {"prereq": "combat_dmg1", "max_level": 3},
	"combat_crit_chance": {"prereq": "combat_atkspd1", "max_level": 3},
	"combat_crit_dmg": {"prereq": "combat_crit_chance", "max_level": 3},
	"combat_dmg2": {"prereq": "combat_crit_dmg", "max_level": 3},
	"combat_atkspd2": {"prereq": "combat_dmg2", "max_level": 3},
	"combat_splash": {"prereq": "combat_atkspd2", "max_level": 3},
	"combat_capstone": {"prereq": "combat_splash", "max_level": 1},

	"econ_drop_rate1": {"prereq": "core_mastery", "max_level": 3},
	"econ_crypto_drop": {"prereq": "econ_drop_rate1", "max_level": 2},
	"econ_relocate_cd": {"prereq": "econ_crypto_drop", "max_level": 3},
	"econ_switch_cd": {"prereq": "econ_relocate_cd", "max_level": 3},
	"econ_drop_rate2": {"prereq": "econ_switch_cd", "max_level": 3},
	"econ_skr_efficiency": {"prereq": "econ_drop_rate2", "max_level": 3},
	"econ_passive_prod": {"prereq": "econ_skr_efficiency", "max_level": 3},
	"econ_capstone": {"prereq": "econ_passive_prod", "max_level": 1},

	"surv_max_hp1": {"prereq": "core_mastery", "max_level": 3},
	"surv_regen_rate1": {"prereq": "surv_max_hp1", "max_level": 3},
	"surv_regen_delay": {"prereq": "surv_regen_rate1", "max_level": 3},
	"surv_max_hp2": {"prereq": "surv_regen_delay", "max_level": 3},
	"surv_regen_rate2": {"prereq": "surv_max_hp2", "max_level": 3},
	"surv_grace_window": {"prereq": "surv_regen_rate2", "max_level": 3},
	"surv_recovery_threshold": {"prereq": "surv_grace_window", "max_level": 3},
	"surv_capstone": {"prereq": "surv_recovery_threshold", "max_level": 1},

	"tower_hub": {"prereq": "core_mastery", "max_level": 1},
}

const GLOBAL_LABELS := {
	"core_mastery": "Core Mastery",
	"tower_hub": "Tower Mastery Hub",

	"combat_dmg1": "+ Damage I",
	"combat_atkspd1": "+ Attack Speed I",
	"combat_crit_chance": "+ Crit Chance",
	"combat_crit_dmg": "+ Crit Damage",
	"combat_dmg2": "+ Damage II",
	"combat_atkspd2": "+ Attack Speed II",
	"combat_splash": "+ Splash Radius",
	"combat_capstone": "[Capstone] Overwhelming Force",

	"econ_drop_rate1": "+ Resource Drop Rate I",
	"econ_crypto_drop": "+ Crypto Drop Rate",
	"econ_relocate_cd": "- Relocation Cooldown",
	"econ_switch_cd": "- Switch Map Cooldown",
	"econ_drop_rate2": "+ Resource Drop Rate II",
	"econ_skr_efficiency": "+ SKR Exchange Efficiency",
	"econ_passive_prod": "+ Passive Production Rate",
	"econ_offline_earnings": "+ Offline Earnings",
	"econ_capstone": "[Capstone] Economic Mastery",

	"surv_max_hp1": "+ Reactor Max HP I",
	"surv_regen_rate1": "+ Reactor Regen Rate I",
	"surv_regen_delay": "- Regen Delay",
	"surv_max_hp2": "+ Reactor Max HP II",
	"surv_regen_rate2": "+ Reactor Regen Rate II",
	"surv_grace_window": "- Grace Window",
	"surv_recovery_threshold": "+ Post-Defeat Reactor HP",
	"surv_capstone": "[Capstone] Reactor Shield",
}

const TOWER_MASTERY_TYPES := ["machine_gun", "railgun", "freeze_ray", "rocket_launcher", "flamethrower"]
const TOWER_MASTERY_SUFFIXES := ["dmg1", "atkspd1", "range1", "crit", "dmg2", "special", "capstone"]

const TOWER_MASTERY_LABELS := {
	"dmg1": "+ Damage I",
	"atkspd1": "+ Attack Speed I",
	"range1": "+ Range I",
	"crit": "+ Crit Chance",
	"dmg2": "+ Damage II",
	"special": "",
	"capstone": "",
}

const TOWER_MASTERY_SPECIAL := {
	"machine_gun": "Overclock Rounds",
	"railgun": "Charged Rounds",
	"freeze_ray": "Deep Freeze",
	"rocket_launcher": "Bigger Warheads",
	"flamethrower": "Ignite",
}

const TOWER_MASTERY_CAPSTONE := {
	"machine_gun": "Bullet Storm",
	"railgun": "Piercing Beam",
	"freeze_ray": "Absolute Zero",
	"rocket_launcher": "Cluster Munitions",
	"flamethrower": "Inferno",
}

const GLOBAL_DESCRIPTIONS := {
	"core_mastery": "Unlocks access to all skill branches.",
	"tower_hub": "Unlocks Tower Mastery branches for all 5 tower types.",

	"combat_dmg1": "Add damage to all towers.",
	"combat_atkspd1": "Add attack speed to all towers.",
	"combat_crit_chance": "Add a chance for towers to land a critical hit.",
	"combat_crit_dmg": "Increase the bonus damage dealt by critical hits.",
	"combat_dmg2": "Further increase damage on all towers.",
	"combat_atkspd2": "Further increase attack speed on all towers.",
	"combat_splash": "Add splash radius to towers that deal area damage.",
	"combat_capstone": "All towers deal bonus damage against boss enemies.",

	"econ_drop_rate1": "Increase the chance mobs drop Energy/Scraps on kill.",
	"econ_crypto_drop": "Increase the chance mobs drop crypto tokens on kill.",
	"econ_relocate_cd": "Reduce the cooldown before a relocated tower can be placed again.",
	"econ_switch_cd": "Reduce the cooldown before switching maps again.",
	"econ_drop_rate2": "Further increase resource drop rate from mob kills.",
	"econ_skr_efficiency": "Reduce the resources required per SKR exchange.",
	"econ_passive_prod": "Increase the Reactor's passive resource production rate.",
	"econ_offline_earnings": "Increase resources earned while away from the game.",
	"econ_capstone": "All resource gains are increased significantly.",

	"surv_max_hp1": "Increase the Energy Reactor's maximum HP.",
	"surv_regen_rate1": "Increase how much HP the Reactor regenerates per tick.",
	"surv_regen_delay": "Reduce the delay before the Reactor starts regenerating HP after taking damage.",
	"surv_max_hp2": "Further increase the Reactor's maximum HP.",
	"surv_regen_rate2": "Further increase the Reactor's regen amount per tick.",
	"surv_grace_window": "Reduce the grace window before regen can begin.",
	"surv_recovery_threshold": "After a defeat the Reactor restarts with more HP: 40% at level 1, 50% at level 2, 60% at level 3 (30% without this skill).",
	"surv_capstone": "The Reactor periodically gains a temporary damage-absorbing shield.",
}

const TOWER_MASTERY_DESCRIPTIONS := {
	"dmg1": "Add damage to %s towers.",
	"atkspd1": "Add attack speed to %s towers.",
	"range1": "Add attack range to %s towers.",
	"crit": "Add crit chance to %s towers.",
	"dmg2": "Further increase damage on %s towers.",
}

const TOWER_MASTERY_SPECIAL_DESC := {
	"machine_gun": "Chance to fire an instant bonus shot.",
	"railgun": "Chance to deal double damage on a shot.",
	"freeze_ray": "Chance to briefly immobilize a hit enemy.",
	"rocket_launcher": "Increase explosion splash radius.",
	"flamethrower": "Hits apply a burning damage-over-time effect.",
}

const TOWER_MASTERY_CAPSTONE_DESC := {
	"machine_gun": "Every 10th shot fires a spread burst hitting all enemies in range.",
	"railgun": "Shots pierce through and hit up to 3 enemies in a line.",
	"freeze_ray": "Stacking slow effect plus small AoE frost damage on hit.",
	"rocket_launcher": "Explosions spawn 2-3 secondary explosions nearby.",
	"flamethrower": "Burning enemies that die spread fire to nearby enemies.",
}

const ICON_BASE_PATH := "res://assets/icons/"

const GLOBAL_ICONS := {
	"core_mastery": "core_mastery_icon.png",

	"combat_dmg1": "damage_one_icon.png",
	"combat_atkspd1": "attack_speed_one_icon.png",
	"combat_crit_chance": "crit_chance_icon.png",
	"combat_crit_dmg": "crit_damage_icon.png",
	"combat_dmg2": "damage_two_icon.png",
	"combat_atkspd2": "attack_speed_two_icon.png",
	"combat_splash": "splash_radius_icon.png",
	"combat_capstone": "overwhelming_force_icon.png",

	"econ_drop_rate1": "drop_rate_one_icon.png",
	"econ_crypto_drop": "crypto_drop_icon.png",
	"econ_relocate_cd": "relocate_cooldown_icon.png",
	"econ_switch_cd": "switch_map_cooldown_icon.png",
	"econ_drop_rate2": "drop_rate_two_icon.png",
	"econ_skr_efficiency": "skr_exchange_rate_icon.png",
	"econ_passive_prod": "passive_production_rate_icon.png",
	"econ_offline_earnings": "offline_earnings_icon.png",

	"surv_max_hp1": "max_hp_one_icon.png",
	"surv_regen_rate1": "regen_rate_one_icon.png",
	"surv_regen_delay": "regen_delay_icon.png",
	"surv_max_hp2": "max_hp_two_icon.png",
	"surv_regen_rate2": "regen_rate_two_icon.png",
	"surv_grace_window": "grace_window_icon.png",
	"surv_recovery_threshold": "recovery_hp_threshold_icon.png",
	"surv_capstone": "reactor_shield_icon.png",
}

# Shared across all 5 tower types
const TOWER_MASTERY_SHARED_ICONS := {
	"dmg1": "damage_one_icon.png",
	"atkspd1": "attack_speed_one_icon.png",
	"range1": "range_one_icon.png",
	"crit": "crit_chance_icon.png",
	"dmg2": "damage_two_icon.png",
}

const TOWER_MASTERY_SPECIAL_ICON := {
	"machine_gun": "overclock_rounds_icon.png",
	"railgun": "charge_rounds_icon.png",
	"freeze_ray": "deep_freeze_icon.png",
	"rocket_launcher": "bigger_warheads_icon.png",
	"flamethrower": "ignite_icon.png",
}

const TOWER_MASTERY_CAPSTONE_ICON := {
	"machine_gun": "bullet_storm_icon.png",
	"railgun": "piercing_beam_icon.png",
	"freeze_ray": "absolute_zero_icon.png",
	"rocket_launcher": "cluster_munitions_icon.png",
	"flamethrower": "inferno_icon.png",
}

func get_node_icon_path(node_id: String) -> String:
	if GLOBAL_ICONS.has(node_id):
		return ICON_BASE_PATH + GLOBAL_ICONS[node_id]
	for tower_type in TOWER_MASTERY_TYPES:
		if node_id == "%s_special" % tower_type:
			return ICON_BASE_PATH + TOWER_MASTERY_SPECIAL_ICON[tower_type]
		if node_id == "%s_capstone" % tower_type:
			return ICON_BASE_PATH + TOWER_MASTERY_CAPSTONE_ICON[tower_type]
		for suffix in TOWER_MASTERY_SHARED_ICONS.keys():
			if node_id == "%s_%s" % [tower_type, suffix]:
				return ICON_BASE_PATH + TOWER_MASTERY_SHARED_ICONS[suffix]
	return ICON_BASE_PATH + "core_mastery_icon.png"

func get_node_description(node_id: String) -> String:
	if GLOBAL_DESCRIPTIONS.has(node_id):
		return GLOBAL_DESCRIPTIONS[node_id]
	for tower_type in TOWER_MASTERY_TYPES:
		var type_label: String = tower_type.capitalize().replace("_", " ")
		if node_id == "%s_special" % tower_type:
			return TOWER_MASTERY_SPECIAL_DESC[tower_type]
		if node_id == "%s_capstone" % tower_type:
			return TOWER_MASTERY_CAPSTONE_DESC[tower_type]
		for suffix in TOWER_MASTERY_DESCRIPTIONS.keys():
			if node_id == "%s_%s" % [tower_type, suffix]:
				return TOWER_MASTERY_DESCRIPTIONS[suffix] % type_label
	return "No description available."

var global_skill_points: int = 0
var global_node_levels: Dictionary = {}

func _ready() -> void:
	TowerManager.tower_leveled_up.connect(_on_tower_leveled_up)
	_build_tower_mastery_nodes()

func _build_tower_mastery_nodes() -> void:
	for tower_type in TOWER_MASTERY_TYPES:
		var prev_id: String = "tower_hub"
		for suffix in TOWER_MASTERY_SUFFIXES:
			var node_id: String = "%s_%s" % [tower_type, suffix]
			var max_level: int = 3
			if suffix == "special":
				max_level = 2
			elif suffix == "capstone":
				max_level = 1
			GLOBAL_TREE[node_id] = {"prereq": prev_id, "max_level": max_level}
			prev_id = node_id

func get_node_label(node_id: String) -> String:
	if GLOBAL_LABELS.has(node_id):
		return GLOBAL_LABELS[node_id]
	for tower_type in TOWER_MASTERY_TYPES:
		if node_id == "%s_special" % tower_type:
			return TOWER_MASTERY_SPECIAL[tower_type]
		if node_id == "%s_capstone" % tower_type:
			return "[Capstone] " + TOWER_MASTERY_CAPSTONE[tower_type]
		for suffix in TOWER_MASTERY_SUFFIXES:
			if node_id == "%s_%s" % [tower_type, suffix] and TOWER_MASTERY_LABELS.has(suffix) and TOWER_MASTERY_LABELS[suffix] != "":
				return "%s (%s)" % [TOWER_MASTERY_LABELS[suffix], tower_type.capitalize().replace("_", " ")]
	return node_id.capitalize().replace("_", " ")

func _on_tower_leveled_up(_tower_id: int, _new_level: int) -> void:
	global_skill_points += 1

func get_node_level(node_id: String) -> int:
	return global_node_levels.get(node_id, 0)

func is_node_unlockable(node_id: String) -> bool:
	if not GLOBAL_TREE.has(node_id):
		return false
	var node: Dictionary = GLOBAL_TREE[node_id]
	var level: int = get_node_level(node_id)
	if level >= node.max_level:
		return false
	if node.prereq != null and get_node_level(node.prereq) < 1:
		return false
	return true

func get_node_cost(node_id: String) -> Dictionary:
	if node_id == "core_mastery":
		return CORE_MASTERY_COST
	if node_id == "tower_hub":
		return TOWER_HUB_COST
	if COMBAT_NODE_COSTS.has(node_id):
		var v: float = COMBAT_NODE_COSTS[node_id]
		return {"energy": v, "scraps": v, "oil": v}
	if SURVIVAL_NODE_COSTS.has(node_id):
		var v: float = SURVIVAL_NODE_COSTS[node_id]
		return {"energy": v, "scraps": v, "oil": v}
	if ECONOMY_NODE_COSTS.has(node_id):
		var v: float = ECONOMY_NODE_COSTS[node_id]
		return {"energy": v, "scraps": v, "oil": v}
	for tower_type in TOWER_MASTERY_TYPES:
		for suffix in TOWER_MASTERY_SUFFIXES:
			if node_id == "%s_%s" % [tower_type, suffix]:
				var v: float = TOWER_MASTERY_NODE_COSTS.get(suffix, 100.0)
				return {"energy": v, "scraps": v, "oil": v}
	return {"energy": 50.0, "scraps": 50.0, "oil": 50.0}

func can_purchase_node(node_id: String) -> bool:
	if not is_node_unlockable(node_id):
		return false
	return ResourceManager.has_enough(get_node_cost(node_id))

func purchase_node(node_id: String) -> bool:
	if not can_purchase_node(node_id):
		return false
	var cost: Dictionary = get_node_cost(node_id)
	if not ResourceManager.spend_resources(cost):
		return false
	global_node_levels[node_id] = get_node_level(node_id) + 1
	emit_signal("global_node_leveled", node_id, global_node_levels[node_id])
	return true

func get_combat_damage_mult() -> float:
	return 1.0 + 0.05 * (get_node_level("combat_dmg1") + get_node_level("combat_dmg2"))

func get_combat_atkspd_mult() -> float:
	return 1.0 + 0.05 * (get_node_level("combat_atkspd1") + get_node_level("combat_atkspd2"))

func get_combat_crit_chance() -> float:
	return 0.05 * get_node_level("combat_crit_chance")

func get_combat_crit_dmg_mult() -> float:
	return 1.5 + 0.15 * get_node_level("combat_crit_dmg")

func get_combat_boss_bonus() -> float:
	return 0.20 if get_node_level("combat_capstone") >= 1 else 0.0

func get_tower_type_damage_mult(tower_type: String) -> float:
	return 1.0 + 0.05 * (get_node_level("%s_dmg1" % tower_type) + get_node_level("%s_dmg2" % tower_type))

func get_tower_type_atkspd_mult(tower_type: String) -> float:
	return 1.0 + 0.05 * get_node_level("%s_atkspd1" % tower_type)

func get_tower_type_range_mult(tower_type: String) -> float:
	return 1.0 + 0.05 * get_node_level("%s_range1" % tower_type)

func get_tower_type_crit_chance(tower_type: String) -> float:
	return 0.05 * get_node_level("%s_crit" % tower_type)

func get_special_proc_chance(tower_type: String) -> float:
	return 0.15 * get_node_level("%s_special" % tower_type)

func get_resource_reward_mult() -> float:
	var mult: float = 1.0 + 0.05 * (get_node_level("econ_drop_rate1") + get_node_level("econ_drop_rate2"))
	if get_node_level("econ_capstone") >= 1:
		mult += 0.15
	return mult

func get_crypto_drop_mult() -> float:
	return 1.0 + 0.10 * get_node_level("econ_crypto_drop")

func get_relocate_cooldown_mult() -> float:
	return max(0.4, 1.0 - 0.2 * get_node_level("econ_relocate_cd"))

func get_skr_efficiency_mult() -> float:
	return max(0.5, 1.0 - 0.10 * get_node_level("econ_skr_efficiency"))

func get_passive_prod_mult() -> float:
	var mult: float = 1.0 + 0.10 * get_node_level("econ_passive_prod")
	if get_node_level("econ_capstone") >= 1:
		mult += 0.15
	return mult

func get_reactor_max_hp_mult() -> float:
	return 1.0 + 0.05 * (get_node_level("surv_max_hp1") + get_node_level("surv_max_hp2"))

func get_reactor_regen_mult() -> float:
	return 1.0 + 0.10 * (get_node_level("surv_regen_rate1") + get_node_level("surv_regen_rate2"))

func get_grace_window_reduction() -> float:
	return 0.3 * (get_node_level("surv_regen_delay") + get_node_level("surv_grace_window"))

func get_defeat_hp_bonus() -> float:
	return 0.10 * get_node_level("surv_recovery_threshold")

func get_switch_map_cooldown_duration() -> float:
	var level: int = get_node_level("econ_switch_cd")
	var max_level: int = GLOBAL_TREE["econ_switch_cd"].max_level
	var t: float = float(level) / float(max_level)
	return lerp(SWITCH_COOLDOWN_MAX, SWITCH_COOLDOWN_MIN, t)

func get_splash_radius_bonus() -> float:
	return 15.0 * get_node_level("combat_splash")
