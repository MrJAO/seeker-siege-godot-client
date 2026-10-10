extends Node

signal exchange_completed(skr_amount: float)
signal crypto_dropped(token: String, amount: float)
signal skr_balance_changed(new_amount: float)
signal resource_exchange_pool_changed(resource: String, remaining: float)

# SKR and Resources Exchange daily cap
const DAILY_CAP: float = 1000.0
const RESOURCE_EXCHANGE_DAILY_CAP: float = 1000.0
const SPAWN_HOUR_UTC: int = 0

# SKR Exchange rate per 1 SKR
const EXCHANGE_RATE := {
	"energy": 100.0,
	"scraps": 100.0,
	"oil": 100.0,
}

# SKR Drop rates
const CRYPTO_DROP_RATES := {
	"regular": 0.0001,
	"medium": 0.0003,
	"hard": 0.0007,
	"boss": 0.0075,
}

var daily_dispensed: float = 0.0
var last_reset_day: int = -1

# Player SKR Balance
var skr_balance: float = 0.0

# Resources Exchange rate 1:1
var resource_exchange_pool: Dictionary = {
	"energy": RESOURCE_EXCHANGE_DAILY_CAP,
	"scraps": RESOURCE_EXCHANGE_DAILY_CAP,
	"oil": RESOURCE_EXCHANGE_DAILY_CAP,
}

func _process(_delta: float) -> void:
	var today: int = Time.get_date_dict_from_system(true).get("day", -1)
	var current_hour: int = Time.get_time_dict_from_system(true).get("hour", -1)
	if today != last_reset_day and current_hour >= SPAWN_HOUR_UTC:
		_reset_daily_pool()
		last_reset_day = today

func _reset_daily_pool() -> void:
	daily_dispensed = 0.0
	for resource in resource_exchange_pool.keys():
		resource_exchange_pool[resource] = RESOURCE_EXCHANGE_DAILY_CAP
		emit_signal("resource_exchange_pool_changed", resource, resource_exchange_pool[resource])

func remaining_daily_skr() -> float:
	return max(0.0, DAILY_CAP - daily_dispensed)

# SKR Exchange: resources -> SKR
func can_exchange(skr_amount: float) -> bool:
	if skr_amount <= 0.0:
		return false
	if skr_amount > remaining_daily_skr():
		return false
	var cost: Dictionary = exchange_resource_cost(skr_amount)
	return ResourceManager.has_enough(cost)

func exchange_resource_cost(skr_amount: float) -> Dictionary:
	var eff: float = SkillTreeManager.get_skr_efficiency_mult()
	return {
		"energy": EXCHANGE_RATE.energy * skr_amount * eff,
		"scraps": EXCHANGE_RATE.scraps * skr_amount * eff,
		"oil": EXCHANGE_RATE.oil * skr_amount * eff,
	}

func exchange_for_skr(skr_amount: float) -> bool:
	if not can_exchange(skr_amount):
		return false
	var cost: Dictionary = exchange_resource_cost(skr_amount)
	if not ResourceManager.spend_resources(cost):
		return false
	daily_dispensed += skr_amount
	skr_balance += skr_amount
	emit_signal("exchange_completed", skr_amount)
	emit_signal("skr_balance_changed", skr_balance)
	return true

# Resources Exchange: resource -> resource

func get_resource_exchange_remaining(resource: String) -> float:
	return resource_exchange_pool.get(resource, 0.0)

func can_exchange_resources(source: String, target: String, amount: float) -> bool:
	if source == target or source == "" or target == "" or amount <= 0.0:
		return false
	if ResourceManager.get_balance(source) < amount:
		return false
	if get_resource_exchange_remaining(target) < amount:
		return false
	return true

func exchange_resources(source: String, target: String, amount: float) -> bool:
	if not can_exchange_resources(source, target, amount):
		return false
	if not ResourceManager.spend_resources({source: amount}):
		return false
	ResourceManager.add_resource(target, amount)
	resource_exchange_pool[target] -= amount
	emit_signal("resource_exchange_pool_changed", target, resource_exchange_pool[target])
	return true

# Mob kill crypto drop
func grant_skr(amount: float) -> void:
	skr_balance += amount
	emit_signal("skr_balance_changed", skr_balance)

func roll_crypto_drop(mob_type: String) -> void:
	var tier: String = ReactorManager.MOB_TIER.get(mob_type, "regular")
	if tier == "boss":
		return
	var rate: float = CRYPTO_DROP_RATES.get(tier, 0.0) * SkillTreeManager.get_crypto_drop_mult()
	if randf() < rate:
		var amount: float = 1.0
		skr_balance += amount
		emit_signal("crypto_dropped", "SKR", amount)
		emit_signal("skr_balance_changed", skr_balance)

func spend_skr(amount: float) -> void:
	skr_balance = max(0.0, skr_balance - amount)
	emit_signal("skr_balance_changed", skr_balance)