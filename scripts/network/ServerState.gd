extends Node

signal state_loaded
signal state_load_failed(status: int, data: Variant)

var raw_state: Dictionary = {}
var loaded: bool = false

var session_id: int = -1
var kill_queue: Array = []

var tower_holdings: Dictionary = {"units": 0, "needsSelection": false}
var skr_exchange_status: Dictionary = {}
var resource_exchange_status: Dictionary = {}
var miner_units: Dictionary = {}
var deployment_units: Dictionary = {}

var _checkpoint_timer: Timer = null
var _kill_report_timer: Timer = null

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	MapManager.map_switched.connect(_on_map_switched)
	GameManager.session_started.connect(_on_session_started)
	GameManager.session_ended.connect(_on_session_ended)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		flush_kills()
		checkpoint_now()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		await flush_kills()
		await checkpoint_now()
		get_tree().quit()

func _on_map_switched(_region: int, _map: int) -> void:
	checkpoint_now()

func _on_session_started() -> void:
	checkpoint_now()
	if _checkpoint_timer == null:
		_checkpoint_timer = Timer.new()
		_checkpoint_timer.wait_time = 60.0
		_checkpoint_timer.timeout.connect(checkpoint_now)
		add_child(_checkpoint_timer)
	_checkpoint_timer.start()

	if _kill_report_timer == null:
		_kill_report_timer = Timer.new()
		_kill_report_timer.wait_time = 5.0
		_kill_report_timer.timeout.connect(flush_kills)
		add_child(_kill_report_timer)
	_kill_report_timer.start()

func _on_session_ended() -> void:
	if _checkpoint_timer != null:
		_checkpoint_timer.stop()
	if _kill_report_timer != null:
		_kill_report_timer.stop()
	await flush_kills()
	checkpoint_now()

func load_state() -> bool:
	var result: Dictionary = await NetworkManager.request_json(HTTPClient.METHOD_GET, "/state", {})

	if result.ok:
		raw_state = result.data
		loaded = true
		state_loaded.emit()
		return true
	else:
		state_load_failed.emit(result.status, result.data)
		return false

func apply_to_managers() -> void:
	if not loaded:
		return

	var player: Dictionary = raw_state.get("player", {})
	GameManager.current_region = int(player.get("currentRegion", 1))
	GameManager.current_map = int(player.get("currentMap", 1))

	var balances: Dictionary = raw_state.get("balances", {})
	for res in ["energy", "scraps", "oil"]:
		if balances.has(res):
			ResourceManager.balances[res] = float(balances[res])
	if balances.has("skr"):
		SKRManager.skr_balance = float(balances["skr"])

	var roles = raw_state.get("resourceRoles")
	if roles != null:
		ResourceManager.resource_roles = {
			"primary": roles.get("primary", ""),
			"secondary": roles.get("secondary", ""),
			"tertiary": roles.get("tertiary", ""),
		}
		ResourceManager.has_assigned_resources = true

	MapManager.furthest_unlocked_region = int(player.get("highestRegion", 1))
	MapManager.furthest_unlocked_map = int(player.get("highestMap", 1))

	var act2_unlocked: bool = bool(player.get("act2Unlocked", false))
	MapManager.act2_unlocked = act2_unlocked
	MapManager.terra_golem_defeated = act2_unlocked

	MapManager.cleared_maps.clear()
	for entry in raw_state.get("clearedMaps", []):
		var key: String = "%d_%d" % [int(entry.region), int(entry.map)]
		MapManager.cleared_maps[key] = true

	TowerManager.owned_towers.clear()
	var max_id: int = 0
	for t in raw_state.get("towers", []):
		var id: int = int(t.get("slot_index", 0))
		var placed: bool = bool(t.get("placed", false))
		var pos_x = t.get("pos_x")
		var pos_y = t.get("pos_y")
		var position: Vector2 = Vector2.ZERO
		if placed and pos_x != null and pos_y != null:
			position = Vector2(float(pos_x), float(pos_y))

		var relocate_timer: float = 0.0
		var relocate_ready_at = t.get("relocate_ready_at")
		if relocate_ready_at != null:
			var ready_unix: float = Time.get_unix_time_from_datetime_string(String(relocate_ready_at))
			if ready_unix > 0.0:
				relocate_timer = max(0.0, ready_unix - Time.get_unix_time_from_system())

		TowerManager.owned_towers[id] = {
			"id": id,
			"type": t.get("type", ""),
			"tier": int(t.get("tier", 1)),
			"level": int(t.get("level", 1)),
			"exp": float(t.get("exp", 0)),
			"enabled": bool(t.get("enabled", true)),
			"placed": placed,
			"position": position,
			"relocate_timer": relocate_timer,
			"hidden_skill_levels": t.get("hidden_levels", {}),
		}
		if id > max_id:
			max_id = id

	TowerManager.set_next_id_floor(max_id + 1)
	GameManager.has_placed_tower = TowerManager.has_any_placed_tower()

	var holdings = raw_state.get("holdings")
	if holdings != null:
		tower_holdings = {
			"units": int(holdings.get("units", 0)),
			"needsSelection": bool(holdings.get("needsSelection", false)),
		}

	_apply_tiered_units(miner_units, raw_state.get("miners", []))
	_apply_tiered_units(deployment_units, raw_state.get("deployment", []))

	var reactor = raw_state.get("reactor")
	if reactor != null:
		ReactorManager.apply_server_state(
			int(reactor.get("tier", 1)),
			String(reactor.get("activeResource", "energy")),
			int(reactor.get("unlockedTier", 1))
		)

func _apply_tiered_units(target: Dictionary, rows: Array) -> void:
	target.clear()
	for r in rows:
		target[r.unit_type] = {
			"claimedCount": int(r.claimed_count),
			"enabledCount": int(r.enabled_count),
		}

# Pushes current_region/current_map and all tower positions to the server
func checkpoint_now() -> void:
	if not loaded:
		return
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/state/checkpoint", _build_checkpoint_body()
	)
	if result.ok:
		var settled: Dictionary = result.data.get("reactorSettled", {})
		if settled.has("resource") and float(settled.get("amount", 0)) > 0.0:
			ResourceManager.add_resource(settled.resource, float(settled.amount))

func _build_checkpoint_body() -> Dictionary:
	var towers_payload: Array = []
	for id in TowerManager.owned_towers.keys():
		var t: Dictionary = TowerManager.owned_towers[id]
		towers_payload.append({
			"slotIndex": id,
			"placed": t.placed,
			"posX": t.position.x if t.placed else null,
			"posY": t.position.y if t.placed else null,
		})

	return {
		"region": GameManager.current_region,
		"map": GameManager.current_map,
		"towers": towers_payload,
	}

# Called by GameHud Start button before GameManager.start_game()
func start_session() -> bool:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/session/start",
		{"region": GameManager.current_region, "map": GameManager.current_map}
	)
	if result.ok:
		session_id = int(result.data.get("sessionId", -1))
		MapManager.current_kills = int(result.data.get("killsAccepted", 0))
		return true

	print("[ServerState] session/start failed: ", result.status, " ", result.data)
	return false

# base_mob.gd's die() for a non-boss kill
func queue_kill(tower_id: int, mob_type: String) -> void:
	kill_queue.append({"towerId": tower_id, "mobType": mob_type})

func _build_kill_report_body() -> Dictionary:
	var grouped: Dictionary = {}
	for k in kill_queue:
		var key: String = "%d:%s" % [k.towerId, k.mobType]
		if not grouped.has(key):
			grouped[key] = {"towerId": k.towerId, "mobType": k.mobType, "count": 0}
		grouped[key].count += 1
	return {"sessionId": session_id, "kills": grouped.values()}

# Sends every queued kill in one /session/report call
func flush_kills() -> void:
	if kill_queue.is_empty() or session_id == -1:
		return
	var body: Dictionary = _build_kill_report_body()
	kill_queue.clear()

	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/session/report", body
	)
	if result.ok:
		_apply_granted(result.data.get("granted", {}))
	else:
		print("[ServerState] session/report failed: ", result.status, " ", result.data)

func _apply_granted(granted: Dictionary) -> void:
	var resources: Dictionary = granted.get("resources", {})
	for res in resources.keys():
		ResourceManager.add_resource(res, float(resources[res]))

	var skr: float = float(granted.get("skr", 0))
	if skr > 0.0:
		SKRManager.grant_skr(skr)

	for texp in granted.get("towerExp", []):
		var tower_id: int = int(texp.get("towerId", -1))
		if not TowerManager.owned_towers.has(tower_id):
			continue
		var t: Dictionary = TowerManager.owned_towers[tower_id]
		t.level = int(texp.get("newLevel", t.level))
		t.exp = float(texp.get("newExp", t.exp))
		TowerManager.owned_towers[tower_id] = t
		if bool(texp.get("leveledUp", false)):
			TowerManager.emit_signal("tower_leveled_up", tower_id, t.level)
		TowerManager.emit_signal(
			"tower_exp_changed", tower_id, t.exp, TowerManager.exp_to_next_level(t.level)
		)

# MapManager.advance_to_next_map()
func confirm_map_advance() -> bool:
	await flush_kills()
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/maps/advance", {"sessionId": session_id}
	)
	if not result.ok:
		print("[ServerState] maps/advance failed: ", result.status, " ", result.data)
	return result.ok

# base_mob.gd die() for a boss kill
func report_boss_kill(tower_id: int, mob_type: String) -> void:
	queue_kill(tower_id, mob_type)
	await flush_kills()

	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/boss/claim", {"sessionId": session_id}
	)
	if not result.ok:
		print("[ServerState] boss/claim failed: ", result.status, " ", result.data)
		return

	var reward: Dictionary = result.data.get("reward", {})
	for res in reward.keys():
		ResourceManager.add_resource(res, float(reward[res]))

	if bool(result.data.get("act2Unlocked", false)):
		MapManager.mark_act1_complete_from_server()

# ShopPopup Tower tab
func fetch_tower_claim_status() -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(HTTPClient.METHOD_GET, "/towers/claim-status", {})
	if result.ok:
		tower_holdings = {
			"units": int(result.data.get("units", 0)),
			"needsSelection": false,
		}
		for slot in result.data.get("towerSlots", []):
			var id: int = int(slot.get("slotIndex", -1))
			if TowerManager.owned_towers.has(id):
				var t: Dictionary = TowerManager.owned_towers[id]
				t.enabled = bool(slot.get("enabled", true))
				TowerManager.owned_towers[id] = t
	return result

# ShopPopup Tower tab Claim button
func claim_tower(tower_type: String) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/towers/claim", {"towerType": tower_type}
	)
	if result.ok:
		var id: int = int(result.data.get("slotIndex", 0))
		TowerManager.owned_towers[id] = {
			"id": id,
			"type": String(result.data.get("type", tower_type)),
			"tier": 1,
			"level": 1,
			"exp": 0.0,
			"enabled": true,
			"placed": false,
			"position": Vector2.ZERO,
			"relocate_timer": 0.0,
			"hidden_skill_levels": {},
		}
	return result

# ShopPopup Miner tab Claim button
func claim_miners() -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/miners/claim", {}
	)
	if result.ok:
		_apply_tiered_units(miner_units, result.data.get("miners", []))
	return result

# ShopPopup Deployment tab Claim button
func claim_deployment() -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/deployment/claim", {}
	)
	if result.ok:
		_apply_tiered_units(deployment_units, result.data.get("deployment", []))
	return result

# SkillTreePopup confirm button
func purchase_skill_node(node_id: String) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/skills/purchase", {"nodeId": node_id}
	)
	if result.ok:
		SkillTreeManager.global_node_levels[node_id] = int(result.data.get("newLevel", 0))
		ResourceManager.spend_resources(result.data.get("cost", {}))
	return result

# HiddenSkillPopup node buttons
func purchase_hidden_skill(tower_id: int, node_id: String) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/hidden-skills/purchase",
		{"towerId": tower_id, "nodeId": node_id}
	)
	if result.ok:
		if TowerManager.owned_towers.has(tower_id):
			var t: Dictionary = TowerManager.owned_towers[tower_id]
			t.hidden_skill_levels[node_id] = int(result.data.get("newLevel", 0))
			TowerManager.owned_towers[tower_id] = t
		SkillTreeManager.global_skill_points -= int(result.data.get("skillPointsSpent", 0))
		ResourceManager.spend_resources(result.data.get("cost", {}))
	return result

# TowerInfoPopup Ascend button
func ascend_tower_server(tower_id: int) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/towers/%d/ascend" % tower_id, {}
	)
	if result.ok:
		if TowerManager.owned_towers.has(tower_id):
			var t: Dictionary = TowerManager.owned_towers[tower_id]
			t.tier = int(result.data.get("newTier", t.tier))
			TowerManager.owned_towers[tower_id] = t
		ResourceManager.spend_resources(result.data.get("cost", {}))
	return result

# TowerKeepPopup Confirm button
func select_towers(keep_ids: Array) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/towers/select", {"keepIds": keep_ids}
	)
	if result.ok:
		var keep_set: Dictionary = {}
		for id in result.data.get("enabledSlots", []):
			keep_set[int(id)] = true

		for id in TowerManager.owned_towers.keys():
			var t: Dictionary = TowerManager.owned_towers[id]
			var should_be_enabled: bool = keep_set.has(id)
			if t.get("enabled", true) != should_be_enabled:
				var was_placed: bool = t.get("placed", false)
				t.enabled = should_be_enabled
				if not should_be_enabled:
					TowerManager.unplace_tower(id)
					if was_placed:
						BuildManager.remove_turret_node(id)
					t = TowerManager.owned_towers[id]
					t.enabled = should_be_enabled
				TowerManager.owned_towers[id] = t

		tower_holdings.needsSelection = false
	return result

# TimeTraveler Popup
func refresh_skr_status() -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_GET, "/skr/exchange/status", {}
	)
	if result.ok:
		skr_exchange_status = result.data
	return result

# TimeTravelerPopup SKR Exchange button
func exchange_skr(amount: int) -> Dictionary:
	var key: String = "skr-%d-%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/skr/exchange", {"amount": amount, "idempotencyKey": key}
	)
	if result.ok:
		ResourceManager.spend_resources(result.data.get("cost", {}))
		SKRManager.grant_skr(float(result.data.get("granted", 0)))
		if result.data.has("poolRemaining"):
			skr_exchange_status["poolRemaining"] = result.data.poolRemaining
		if result.data.has("playerRemaining"):
			skr_exchange_status["playerRemaining"] = result.data.playerRemaining
	return result

# TimeTravelerPopup Resources Exchange tab
func refresh_resource_pool_status() -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_GET, "/resources/pool", {}
	)
	if result.ok:
		resource_exchange_status = result.data
	return result

# TimeTravelerPopup Resources Exchange confirm button
func exchange_resources_server(source: String, target: String, amount: int) -> Dictionary:
	var key: String = "rex-%d-%d" % [Time.get_unix_time_from_system(), randi() % 1000000]
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/resources/exchange",
		{"source": source, "target": target, "amount": amount, "idempotencyKey": key}
	)
	if result.ok:
		ResourceManager.spend_resources({source: float(amount)})
		ResourceManager.add_resource(target, float(result.data.get("granted", amount)))
		if result.data.has("poolRemaining") and resource_exchange_status.has("remaining"):
			resource_exchange_status["remaining"][target] = result.data.poolRemaining
	return result

# Marketplace Popup
func fetch_marketplace_listings() -> Dictionary:
	return await NetworkManager.request_json(HTTPClient.METHOD_GET, "/marketplace/listings", {})

func fetch_my_marketplace_listings() -> Dictionary:
	return await NetworkManager.request_json(HTTPClient.METHOD_GET, "/marketplace/mine", {})

func list_marketplace(resource: String, quantity: int, payment_type: String, price_units: int) -> Dictionary:
	var idempotency_key: String = "list_%d_%d" % [Time.get_ticks_usec(), randi()]
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/marketplace/list",
		{"resource": resource, "quantity": quantity, "paymentType": payment_type, "price": price_units, "idempotencyKey": idempotency_key}
	)
	if result.ok:
		ResourceManager.spend_resources({resource: float(quantity)})
	return result

func cancel_marketplace_listing(listing_id: int, resource: String, quantity: int) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/marketplace/cancel", {"listingId": listing_id}
	)
	if result.ok:
		ResourceManager.add_resource(resource, float(quantity))
	return result

# Marketplace: SKR purchases
func buy_marketplace_listing(listing_id: int, resource: String, quantity: int, price_units: int) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/marketplace/buy", {"listingId": listing_id}
	)
	if result.ok:
		SKRManager.skr_balance -= float(price_units)
		ResourceManager.add_resource(resource, float(quantity))
	return result

func assign_resource_roles_server(primary: String, secondary: String, tertiary: String) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/roles",
		{"primary": primary, "secondary": secondary, "tertiary": tertiary}
	)
	if result.ok or result.status == 409:
		result.ok = true
	return result

func switch_reactor_resource(resource: String) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/reactor/switch", {"resource": resource}
	)
	if result.ok:
		var settled: Dictionary = result.data.get("settled", {})
		if settled.has("resource") and float(settled.get("amount", 0)) > 0.0:
			ResourceManager.add_resource(settled.resource, float(settled.amount))
		ReactorManager.active_resource = String(result.data.get("activeResource", resource))
		ReactorManager.switch_lockout_timer = ReactorManager.SWITCH_LOCKOUT
		ReactorManager.reset_production_display()
	return result

func upgrade_reactor_tier_server() -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/reactor/upgrade", {}
	)
	if result.ok:
		var cost: float = float(result.data.get("cost", 0))
		for res in ["energy", "scraps", "oil"]:
			ResourceManager.spend_resources({res: cost})
		ReactorManager.set_tier_from_server(int(result.data.get("tier", ReactorManager.reactor_tier)))
	return result

# Marketplace: SOL purchases
func prepare_sol_purchase(listing_id: int) -> Dictionary:
	return await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/marketplace/buy/prepare", {"listingId": listing_id}
	)

func confirm_sol_purchase(listing_id: int, signature: String) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/marketplace/buy/confirm",
		{"listingId": listing_id, "signature": signature}
	)
	if result.ok:
		ResourceManager.add_resource(
			String(result.data.get("resource", "")),
			float(result.data.get("quantity", 0))
		)
	return result

func fetch_marketplace_sol_price() -> Dictionary:
	return await NetworkManager.request_json(HTTPClient.METHOD_GET, "/marketplace/prices", {})

# Profile Popup
func fetch_wallet_balances() -> Dictionary:
	return await NetworkManager.request_json(HTTPClient.METHOD_GET, "/profile/wallet-balances", {})

func fetch_profile_activity() -> Dictionary:
	return await NetworkManager.request_json(HTTPClient.METHOD_GET, "/profile/activity", {})

# SKR Withdrawal
func withdraw_skr(amount: int) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/profile/withdraw", {"amount": amount}
	)
	if result.ok:
		SKRManager.spend_skr(float(amount))
	return result

func fetch_clockin_status() -> Dictionary:
	return await NetworkManager.request_json(HTTPClient.METHOD_GET, "/profile/clockin/status", {})

func claim_clockin(claim_type: String, resources_amount: int, skr_amount: int) -> Dictionary:
	var result: Dictionary = await NetworkManager.request_json(
		HTTPClient.METHOD_POST, "/profile/clockin/claim", {"claimType": claim_type}
	)
	if result.ok:
		if claim_type == "resources":
			ResourceManager.add_resource("energy", float(resources_amount))
			ResourceManager.add_resource("scraps", float(resources_amount))
			ResourceManager.add_resource("oil", float(resources_amount))
		else:
			SKRManager.grant_skr(float(skr_amount))
	return result
