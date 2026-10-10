extends Node

signal defeated
signal recovered
signal hp_changed(current: float, max: float)
signal tier_changed(new_tier: int)
signal damage_taken

const GRACE_WINDOW: float = 3.0
const DEFEAT_HP_PERCENT: float = 0.30
const RECOVERY_HP_PERCENT: float = 0.80
const SWITCH_LOCKOUT: float = 15.0

const TIER_DAMAGE := {
	"regular": 5.0,
	"medium": 15.0,
	"hard": 40.0,
	"boss": 99999.0,
}

# Regions mobs rosters
const MOB_TIER := {
	# Region 1 - Ancient Ruins
	"clay_golem": "regular",
	"stone_crawler": "regular",
	"earth_elemental": "medium",
	"rock_sentinel": "hard",
	"terra_golem_boss": "boss",
	# Region 2 - Industrial Forge
	"forge_construct": "regular",
	"rust_bug": "regular",
	"steel_guardian": "medium",
	"molten_golem": "hard",
	"iron_colossus_boss": "boss",
	# Region 3 - Tempest Seas
	"water_sprite": "regular",
	"wave_rider": "regular",
	"thunder_eel": "medium",
	"tidal_beast": "hard",
	"storm_leviathan_boss": "boss",
	# Region 4 - Neon Wasteland
	"volt_bettle": "regular",
	"drone_scout": "regular",
	"nano_swarm": "medium",
	"plasma_walker": "hard",
	"cyber_phoenix_boss": "boss",
	# Region 5 - Shadow Dimension
	"dark_phantom": "regular",
	"shadow_imp": "regular",
	"shade_walker": "medium",
	"nightmare": "hard",
	"void_wraith_boss": "boss",
}

func get_mob_damage(mob_type: String) -> float:
	var tier: String = MOB_TIER.get(mob_type, "regular")
	return TIER_DAMAGE.get(tier, 5.0)

const TIER_DATA := [
	{"max_hp": 500.0,  "regen_amount": 5.0,  "regen_interval": 3.0, "prod_per_min": 1.0},
	{"max_hp": 650.0,  "regen_amount": 5.0,  "regen_interval": 2.7, "prod_per_min": 1.31},
	{"max_hp": 850.0,  "regen_amount": 5.0,  "regen_interval": 2.4, "prod_per_min": 1.62},
	{"max_hp": 1100.0, "regen_amount": 6.0,  "regen_interval": 2.1, "prod_per_min": 1.93},
	{"max_hp": 1400.0, "regen_amount": 6.0,  "regen_interval": 1.8, "prod_per_min": 2.24},
	{"max_hp": 1750.0, "regen_amount": 7.0,  "regen_interval": 1.6, "prod_per_min": 2.56},
	{"max_hp": 2150.0, "regen_amount": 7.0,  "regen_interval": 1.4, "prod_per_min": 2.87},
	{"max_hp": 2600.0, "regen_amount": 8.0,  "regen_interval": 1.2, "prod_per_min": 3.18},
	{"max_hp": 3100.0, "regen_amount": 8.0,  "regen_interval": 1.0, "prod_per_min": 3.49},
	{"max_hp": 3700.0, "regen_amount": 10.0, "regen_interval": 0.8, "prod_per_min": 3.8},
]

var reactor_tier: int = 1
var unlocked_tier: int = 1
var current_hp: float
var time_since_last_hit: float = 0.0
var regen_accumulator: float = 0.0
var is_producing: bool = false
var active_resource: String = "energy"
var switch_lockout_timer: float = 0.0
var is_recovering: bool = false
var can_advance_map: bool = true

# Local-only: Reactor produced resources during session
var time_since_switch: float = 0.0
var estimated_produced_since_switch: float = 0.0

func _ready() -> void:
	current_hp = _tier().max_hp

func _tier() -> Dictionary:
	return TIER_DATA[reactor_tier - 1]

func get_max_hp() -> float:
	return _tier().max_hp * SkillTreeManager.get_reactor_max_hp_mult()

func get_regen_amount() -> float:
	return _tier().regen_amount * SkillTreeManager.get_reactor_regen_mult()

func get_grace_window() -> float:
	return max(0.3, GRACE_WINDOW - SkillTreeManager.get_grace_window_reduction())

func get_recovery_percent() -> float:
	return RECOVERY_HP_PERCENT

# Reactor HP after defeat
func get_defeat_hp_percent() -> float:
	return DEFEAT_HP_PERCENT + SkillTreeManager.get_defeat_hp_bonus()

func _process(delta: float) -> void:
	_process_regen(delta)
	if switch_lockout_timer > 0.0:
		switch_lockout_timer -= delta
	if is_producing:
		time_since_switch += delta
		estimated_produced_since_switch = (_tier().prod_per_min / 60.0) * time_since_switch

func _process_regen(delta: float) -> void:
	var max_hp: float = get_max_hp()
	if current_hp >= max_hp:
		return
	time_since_last_hit += delta
	if time_since_last_hit < get_grace_window():
		return
	regen_accumulator += delta
	var interval: float = _tier().regen_interval
	while regen_accumulator >= interval:
		regen_accumulator -= interval
		current_hp = min(current_hp + get_regen_amount(), max_hp)
		emit_signal("hp_changed", current_hp, max_hp)
		if is_recovering and current_hp >= max_hp * get_recovery_percent():
			is_recovering = false
			can_advance_map = true
			emit_signal("recovered")

func begin_passive_production() -> void:
	is_producing = true

func take_damage_from_mob(mob_type: String) -> void:
	var dmg: float = get_mob_damage(mob_type)
	current_hp = max(current_hp - dmg, 0.0)
	time_since_last_hit = 0.0
	regen_accumulator = 0.0
	emit_signal("hp_changed", current_hp, get_max_hp())
	emit_signal("damage_taken")
	if current_hp <= 0.0:
		_trigger_defeat()

func _trigger_defeat() -> void:
	current_hp = get_max_hp() * get_defeat_hp_percent()
	is_recovering = true
	can_advance_map = false
	emit_signal("defeated")
	emit_signal("hp_changed", current_hp, get_max_hp())
	MapManager.handle_defeat_return()

# ServerState.apply_to_managers()
func apply_server_state(tier: int, resource: String, server_unlocked_tier: int) -> void:
	reactor_tier = tier
	active_resource = resource
	unlocked_tier = server_unlocked_tier
	var max_hp: float = get_max_hp()
	current_hp = min(current_hp if current_hp > 0.0 else max_hp, max_hp)
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("tier_changed", reactor_tier)

# ServerState.upgrade_reactor_tier_server()
func set_tier_from_server(new_tier: int) -> void:
	var old_max: float = get_max_hp()
	reactor_tier = new_tier
	var ratio: float = current_hp / old_max if old_max > 0.0 else 1.0
	var new_max: float = get_max_hp()
	current_hp = min(new_max, new_max * ratio)
	emit_signal("hp_changed", current_hp, new_max)
	emit_signal("tier_changed", reactor_tier)

func tier_upgrade_cost(target_tier: int) -> Dictionary:
	var amount: float = 500.0 * pow(1.8, target_tier - 2)
	return {"energy": amount, "scraps": amount, "oil": amount}

func can_upgrade_tier() -> bool:
	if reactor_tier >= unlocked_tier:
		return false
	return ResourceManager.has_enough(tier_upgrade_cost(reactor_tier + 1))

# ServerState.switch_reactor_resource()
func switch_production(resource: String) -> void:
	push_warning("switch_production() is local-only")
	if switch_lockout_timer > 0.0 or resource == active_resource:
		return
	active_resource = resource
	switch_lockout_timer = SWITCH_LOCKOUT

# ServerState.switch_reactor_resource()
func reset_production_display() -> void:
	time_since_switch = 0.0
	estimated_produced_since_switch = 0.0

func try_upgrade_tier() -> bool:
	push_warning("try_upgrade_tier() is local-only")
	if reactor_tier >= unlocked_tier:
		return false
	var cost: Dictionary = tier_upgrade_cost(reactor_tier + 1)
	if not ResourceManager.spend_resources(cost):
		return false
	set_tier_from_server(reactor_tier + 1)
	return true
