extends Node

signal map_cleared(region: int, map: int)
signal region_cleared(region: int)
signal next_map_unlocked
signal map_switched(region: int, map: int)
signal switch_cooldown_started(duration: float)
signal act1_completed

const REGIONS: int = 5
const MAPS_PER_REGION: int = 15
const BOSS_MAP: int = 15

const BASE_KILLS: int = 50
const KILL_GROWTH: float = 1.15

# Tier based EXP
const EXP_PER_KILL := {
	"regular": 3.0,
	"medium": 6.0,
	"hard": 10.0,
}
const BOSS_EXP_REWARD: float = 250.0
const EXP_GROWTH: float = 1.05
const ASSIST_EXP_PERCENT: float = 0.55

# Mob stat growth (Max HP / Damage / Move Speed)
const STAT_GROWTH_PERCENT_PER_MAP: float = 3.0
const NON_BOSS_MAPS_PER_REGION: int = MAPS_PER_REGION - 1
const GROWTH_STEPS_PER_REGION: int = NON_BOSS_MAPS_PER_REGION - 1

# One time boss kill rewards
const BOSS_REWARDS := {
	1: {"energy": 1000.0, "scraps": 1000.0, "oil": 1000.0},
	2: {"energy": 1500.0, "scraps": 1500.0, "oil": 1500.0},
	3: {"energy": 2250.0, "scraps": 2250.0, "oil": 2250.0},
	4: {"energy": 3375.0, "scraps": 3375.0, "oil": 3375.0},
	5: {"energy": 5063.0, "scraps": 5063.0, "oil": 5063.0},
}

# Persisting map progress records
var current_kills: int = 0
var cleared_maps: Dictionary = {}
var last_cleared_region: int = 1
var last_cleared_map: int = 0

var furthest_unlocked_region: int = 1
var furthest_unlocked_map: int = 1

var switch_cooldown_remaining: float = 0.0

# Act I gating
const FEATURE_UNLOCK_MAP: int = 6
const MAP6_FEATURES := ["skr_exchange", "resources_exchange", "marketplace", "mining_shaft"]
const ACT2_FEATURES := ["armory", "deployment", "equipment", "portal"]

var terra_golem_defeated: bool = false
var act2_unlocked: bool = false
var npc_greeted: Dictionary = {}
var pending_notice: String = ""

func _ready() -> void:
	region_cleared.connect(_on_region_cleared)

func _process(delta: float) -> void:
	if switch_cooldown_remaining > 0.0:
		switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - delta)

func _on_region_cleared(_region: int) -> void:
	ReactorManager.unlock_next_tier()

func get_global_map_index(region: int, map: int) -> int:
	return (region - 1) * MAPS_PER_REGION + map

const KILL_REQ_MAP14_BY_REGION := {
	1: 56571,
	2: 79200,
	3: 101829,
	4: 124457,
	5: 147086,
}

func required_kills(region: int, map: int) -> int:
	if map == BOSS_MAP:
		return 1
	var map14_target: int = KILL_REQ_MAP14_BY_REGION.get(region, KILL_REQ_MAP14_BY_REGION[1])
	return int(round(map14_target / 8192.0 * pow(2, map - 1)))

func get_exp_reward(region: int, map: int, mob_type: String) -> float:
	var growth: float = pow(EXP_GROWTH, get_global_map_index(region, map) - 1)
	var tier: String = ReactorManager.MOB_TIER.get(mob_type, "regular")
	if tier == "boss":
		return BOSS_EXP_REWARD * growth
	return EXP_PER_KILL.get(tier, EXP_PER_KILL.regular) * growth

func get_map_recommended_level(region: int, map: int) -> int:
	return get_global_map_index(region, map) * 2

# Mob HP multiplier
const HP_STEP_MULT := {
	1: 2.3,
	2: 6.9,
	3: 27.6,
	4: 138.0,
	5: 828.0,
}

func get_hp_step_mult(region: int, map: int) -> float:
	if region == 1:
		return HP_STEP_MULT[1] if map >= 5 else 1.0
	return HP_STEP_MULT.get(region, 1.0)

func get_mob_stat_growth_mult(region: int, map: int) -> float:
	var growth_pct: float = STAT_GROWTH_PERCENT_PER_MAP * float((region - 1) * GROWTH_STEPS_PER_REGION + (map - 1))
	return 1.0 + growth_pct / 100.0

func grant_boss_reward(region: int) -> void:
	var reward: Dictionary = BOSS_REWARDS.get(region, BOSS_REWARDS[1])
	ResourceManager.add_resource("energy", reward.energy)
	ResourceManager.add_resource("scraps", reward.scraps)
	ResourceManager.add_resource("oil", reward.oil)
	if region == 1:
		_complete_act1()

func _complete_act1() -> void:
	if terra_golem_defeated:
		return
	terra_golem_defeated = true
	act2_unlocked = true
	emit_signal("region_cleared", 1)
	emit_signal("act1_completed")

# Called by ServerState after /boss/claim confirms act2Unlocked
func mark_act1_complete_from_server() -> void:
	_complete_act1()

# Called after player dismisses the Act I ending popup.
func return_after_act1() -> void:
	pending_notice = "Unlocked: Armory, Deployment, Equipment and Portal"
	_perform_switch(1, 14)

func is_feature_unlocked(feature: String) -> bool:
	if feature in MAP6_FEATURES:
		return furthest_unlocked_region > 1 or furthest_unlocked_map >= FEATURE_UNLOCK_MAP
	if feature in ACT2_FEATURES:
		return act2_unlocked
	return true

func get_lock_text(feature: String) -> String:
	if feature in MAP6_FEATURES:
		return "Unlocks at Region 1 - Map %d" % FEATURE_UNLOCK_MAP
	if feature in ACT2_FEATURES:
		return "Unlocks after defeating the Terra Golem"
	return ""

func consume_notice() -> String:
	var text: String = pending_notice
	pending_notice = ""
	return text

# Region 1 - Map 15 (final map)
func is_map_closed(region: int, map: int) -> bool:
	return region == 1 and map == BOSS_MAP and terra_golem_defeated

func is_next_map_available() -> bool:
	var region: int = GameManager.current_region
	var map: int = GameManager.current_map
	if region == 1 and map >= BOSS_MAP:
		return false
	return not is_map_closed(region, map + 1)

func _map_key(region: int, map: int) -> String:
	return "%d_%d" % [region, map]

func is_map_cleared(region: int, map: int) -> bool:
	return cleared_maps.get(_map_key(region, map), false)

func register_kill() -> void:
	current_kills += 1
	var needed: int = required_kills(GameManager.current_region, GameManager.current_map)
	if current_kills >= needed:
		cleared_maps[_map_key(GameManager.current_region, GameManager.current_map)] = true
		if ReactorManager.can_advance_map:
			emit_signal("next_map_unlocked")

func can_switch_map() -> bool:
	return switch_cooldown_remaining <= 0.0

func is_map_unlocked(region: int, map: int) -> bool:
	if is_map_closed(region, map):
		return false
	if region < furthest_unlocked_region:
		return true
	if region == furthest_unlocked_region:
		return map <= furthest_unlocked_map
	return false

func get_unlocked_maps() -> Array:
	var result: Array = []
	for region in range(1, furthest_unlocked_region + 1):
		var max_map: int = MAPS_PER_REGION if region < furthest_unlocked_region else furthest_unlocked_map
		for map in range(1, max_map + 1):
			if is_map_closed(region, map):
				continue
			result.append({"region": region, "map": map})
	return result

func _unlock_map(region: int, map: int) -> void:
	if region > furthest_unlocked_region or (region == furthest_unlocked_region and map > furthest_unlocked_map):
		var had_map6_features: bool = is_feature_unlocked("marketplace")
		furthest_unlocked_region = region
		furthest_unlocked_map = map
		if not had_map6_features and is_feature_unlocked("marketplace"):
			pending_notice = "Unlocked: SKR Exchange, Resources Exchange, Marketplace and Mining Shaft"

func _get_map_scene_path(region: int, map: int) -> String:
	return "res://scenes/maps/region%d/Region%dMap%d.tscn" % [region, region, map]

func _perform_switch(region: int, map: int) -> void:
	BuildManager.clear_all_placed_turrets()
	GridManager.clear_all()
	GameManager.current_region = region
	GameManager.current_map = map
	GameManager.reset_for_new_map()
	current_kills = 0
	var duration: float = SkillTreeManager.get_switch_map_cooldown_duration()
	switch_cooldown_remaining = duration
	emit_signal("switch_cooldown_started", duration)
	emit_signal("map_switched", region, map)

	var scene_path: String = _get_map_scene_path(region, map)
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("MapManager: missing scene at %s" % scene_path)

func advance_to_next_map() -> void:
	if not ReactorManager.can_advance_map:
		return
	if not is_next_map_available():
		return
	var region: int = GameManager.current_region
	var map: int = GameManager.current_map

	var confirmed: bool = await ServerState.confirm_map_advance()
	if not confirmed:
		return

	last_cleared_region = region
	last_cleared_map = map
	emit_signal("map_cleared", region, map)

	var next_region: int = region
	var next_map: int = map

	if map == BOSS_MAP:
		emit_signal("region_cleared", region)
		if region < REGIONS:
			next_region = region + 1
			next_map = 1
	elif map < MAPS_PER_REGION:
		next_map = map + 1

	_unlock_map(next_region, next_map)
	_perform_switch(next_region, next_map)

func request_switch_map(region: int, map: int) -> bool:
	if not can_switch_map():
		return false
	if not is_map_unlocked(region, map):
		return false
	_perform_switch(region, map)
	return true

func _get_previous_map(region: int, map: int) -> Dictionary:
	if map > 1:
		return {"region": region, "map": map - 1}
	if region > 1:
		return {"region": region - 1, "map": MAPS_PER_REGION}
	return {"region": 1, "map": 1}

func handle_defeat_return() -> void:
	var current_region: int = GameManager.current_region
	var current_map: int = GameManager.current_map
	if current_region <= 1 and current_map <= 1:
		_perform_switch(1, 1)
		return
	var prev: Dictionary = _get_previous_map(current_region, current_map)
	_perform_switch(prev.region, prev.map)
