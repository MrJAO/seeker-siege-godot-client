extends Node2D

var turret_type: String = ""
var projectile_scene_path: String = "res://scenes/projectiles/projectile.tscn"

var tower_id: int = -1
var tier: int = 1
var is_active: bool = true

var damage: float = 35.0
var fire_rate: float = 1.0
var attack_range: float = 260.0
var splash_radius: float = 0.0
var shots_fired: int = 0
var strong_against: Array = []
var weak_against: Array = []
var targeting_mode: String = "nearest"

var targets_in_range = []
var current_target = null
var time_since_last_shot: float = 0.0

var range_draw: Node2D = null
var click_draw: Node2D = null
var ascend_indicator: Node2D = null
var ascend_indicator_dismissed: bool = false
var was_ascension_eligible: bool = false

func _ready():
	add_to_group("turret")
	z_index = 5
	setup_signals()
	update_range_shape()
	update_sprite()
	draw_range_circle()
	draw_click_circle()
	_create_ascend_indicator()
	time_since_last_shot = 0.0
	BuildManager.show_range_toggled.connect(_on_show_range_toggled)
	SkillTreeManager.global_node_leveled.connect(_on_global_skill_leveled)
	range_draw.visible = BuildManager.show_range_enabled

func _on_show_range_toggled(enabled: bool) -> void:
	if range_draw:
		range_draw.visible = enabled

func _on_global_skill_leveled(_node_id: String, _new_level: int) -> void:
	sync_stats_from_manager()

func set_tower_id(id: int) -> void:
	tower_id = id
	if not TowerManager.owned_towers.has(id):
		return
	tier = TowerManager.owned_towers[id].tier
	if not TowerManager.tower_leveled_up.is_connected(_on_tower_leveled_up):
		TowerManager.tower_leveled_up.connect(_on_tower_leveled_up)
	if not TowerManager.tower_ascended.is_connected(_on_tower_ascended):
		TowerManager.tower_ascended.connect(_on_tower_ascended)
	sync_stats_from_manager()
	_refresh_ascend_indicator()

func _on_tower_leveled_up(changed_id: int, _new_level: int) -> void:
	if changed_id != tower_id:
		return
	sync_stats_from_manager()
	_show_level_up_popup()
	_refresh_ascend_indicator()

func _on_tower_ascended(changed_id: int, _new_tier: int) -> void:
	if changed_id != tower_id:
		return
	sync_stats_from_manager()
	ascend_indicator_dismissed = false
	_refresh_ascend_indicator()

func sync_stats_from_manager() -> void:
	if tower_id < 0 or not TowerManager.owned_towers.has(tower_id):
		return
	var t: Dictionary = TowerManager.owned_towers[tower_id]
	tier = t.tier
	var stats: Dictionary = TowerManager.get_computed_stats(tower_id)
	damage = stats.dmg
	fire_rate = 1.0 / stats.atk_speed
	attack_range = stats.range
	splash_radius = TowerManager.get_computed_splash_radius(tower_id)
	update_sprite()
	update_range_shape()
	draw_range_circle()

func _show_level_up_popup() -> void:
	var label := Label.new()
	label.text = "Level Up!"
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	add_child(label)
	label.top_level = true
	label.global_position = global_position + Vector2(-30, -55)
	label.z_index = 30
	var target_y: float = label.global_position.y - 20
	var tween := create_tween()
	tween.tween_property(label, "global_position:y", target_y, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)

func _create_ascend_indicator() -> void:
	ascend_indicator = Node2D.new()
	ascend_indicator.z_index = 30
	ascend_indicator.visible = false
	add_child(ascend_indicator)
	ascend_indicator.top_level = true
	ascend_indicator.global_position = global_position + Vector2(0, -50)

	var label := Label.new()
	label.text = "Ascend Tower"
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.position = Vector2(-40, -10)
	ascend_indicator.add_child(label)

func _refresh_ascend_indicator() -> void:
	if tower_id < 0:
		return
	var eligible: bool = TowerManager.is_ascension_level_met(tower_id)
	if eligible and not was_ascension_eligible:
		ascend_indicator_dismissed = false
	was_ascension_eligible = eligible
	ascend_indicator.visible = eligible and not ascend_indicator_dismissed

func hide_ascend_indicator() -> void:
	ascend_indicator_dismissed = true
	ascend_indicator.visible = false

func setup_signals():
	if not $RangeArea.body_entered.is_connected(_on_mob_entered_range):
		$RangeArea.body_entered.connect(_on_mob_entered_range)
	if not $RangeArea.body_exited.is_connected(_on_mob_exited_range):
		$RangeArea.body_exited.connect(_on_mob_exited_range)

func update_range_shape():
	var range_shape = CircleShape2D.new()
	range_shape.radius = attack_range
	$RangeArea/RangeShape.shape = range_shape

func draw_range_circle():
	if range_draw:
		range_draw.queue_free()
	range_draw = Node2D.new()
	range_draw.name = "RangeDraw"
	range_draw.z_index = 5
	add_child(range_draw)
	range_draw.draw.connect(_draw_range.bind(range_draw))
	range_draw.visible = BuildManager.show_range_enabled
	range_draw.queue_redraw()

func draw_click_circle():
	if click_draw:
		click_draw.queue_free()
	click_draw = Node2D.new()
	click_draw.name = "ClickDraw"
	click_draw.z_index = 5
	add_child(click_draw)
	click_draw.draw.connect(_draw_click.bind(click_draw))
	click_draw.visible = false
	click_draw.queue_redraw()

func _draw_range(node: Node2D):
	node.draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.2, 0.8, 1.0, 0.5), 1.5)

func _draw_click(node: Node2D):
	node.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, Color(1.0, 0.8, 0.2, 0.6), 1.5)

func update_sprite():
	pass

func _process(delta):
	if ascend_indicator:
		ascend_indicator.global_position = global_position + Vector2(0, -50)
	if not is_active:
		return
	time_since_last_shot += delta
	targets_in_range = targets_in_range.filter(func(t): return is_instance_valid(t))

	if current_target and is_instance_valid(current_target):
		if time_since_last_shot >= fire_rate:
			look_at(current_target.global_position)
			shoot()
			time_since_last_shot = 0.0
	else:
		var old_target = current_target
		find_target()
		if current_target != null and current_target != old_target:
			look_at(current_target.global_position)
			time_since_last_shot = 0.0

func get_damage_modifier(mob: Node2D) -> float:
	var mob_type = mob.get("mob_type") if mob.get("mob_type") != null else ""
	var mult: float = 1.0
	if mob_type in strong_against:
		mult = 1.5
	elif mob_type in weak_against:
		mult = 0.7
	if mob_type.ends_with("_boss"):
		mult *= (1.0 + SkillTreeManager.get_combat_boss_bonus())
	return mult

func find_target():
	if targets_in_range.is_empty():
		current_target = null
		return
	match targeting_mode:
		"strongest":
			var strong_targets = targets_in_range.filter(func(t): return get_damage_modifier(t) >= 1.5)
			if not strong_targets.is_empty():
				current_target = get_nearest(strong_targets)
			else:
				current_target = get_nearest(targets_in_range)
		"farthest":
			current_target = get_farthest(targets_in_range)
		"nearest", _:
			current_target = get_nearest(targets_in_range)

func get_nearest(mob_list: Array) -> Node2D:
	var nearest = null
	var nearest_dist = INF
	for mob in mob_list:
		var d = global_position.distance_to(mob.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = mob
	return nearest

func get_farthest(mob_list: Array) -> Node2D:
	var farthest = null
	var farthest_dist = -INF
	for mob in mob_list:
		var d = global_position.distance_to(mob.global_position)
		if d > farthest_dist:
			farthest_dist = d
			farthest = mob
	return farthest

func _get_crit_chance() -> float:
	if tower_id >= 0 and TowerManager.owned_towers.has(tower_id):
		return TowerManager.get_computed_stats(tower_id).crit_chance
	return 0.0

func shoot():
	if not current_target or not is_instance_valid(current_target):
		return
	var was_crit: bool = _fire_single_projectile(current_target)

	if tower_id >= 0 and TowerManager.owned_towers.has(tower_id):
		var ttype: String = TowerManager.owned_towers[tower_id].type
		if ttype == "machine_gun" and is_instance_valid(current_target):
			if randf() < SkillTreeManager.get_special_proc_chance("machine_gun"):
				_fire_single_projectile(current_target)
			if was_crit and TowerManager.has_hidden_capstone(tower_id):
				time_since_last_shot = fire_rate

func _fire_single_projectile(target: Node2D) -> bool:
	if projectile_scene_path == "":
		return false
	var projectile_scene = load(projectile_scene_path)
	if projectile_scene == null:
		return false

	shots_fired += 1
	var final_damage: float = damage * get_damage_modifier(target)

	var is_crit: bool = randf() < _get_crit_chance()
	if tower_id >= 0 and TowerManager.owned_towers.has(tower_id):
		var crit_ttype: String = TowerManager.owned_towers[tower_id].type
		if crit_ttype == "railgun" and TowerManager.has_hidden_capstone(tower_id) and shots_fired % 5 == 0:
			is_crit = true
	if is_crit:
		final_damage *= TowerManager.get_computed_stats(tower_id).crit_dmg_mult

	if tower_id >= 0 and TowerManager.owned_towers.has(tower_id):
		var ttype: String = TowerManager.owned_towers[tower_id].type
		if ttype == "railgun" and randf() < SkillTreeManager.get_special_proc_chance("railgun"):
			final_damage *= 2.0

	var applies_frozen: bool = false
	var applies_burning: bool = false
	var freeze_duration: float = 2.0
	var burn_dps_percent_bonus: float = 0.0
	if tower_id >= 0 and TowerManager.owned_towers.has(tower_id):
		var status_ttype: String = TowerManager.owned_towers[tower_id].type
		if status_ttype == "freeze_ray" and randf() < (SkillTreeManager.get_special_proc_chance("freeze_ray") + TowerManager.get_hidden_freeze_proc_bonus(tower_id)):
			applies_frozen = true
			freeze_duration = 2.0 + TowerManager.get_hidden_freeze_duration_bonus(tower_id)
		if status_ttype == "flamethrower" and randf() < (SkillTreeManager.get_special_proc_chance("flamethrower") + TowerManager.get_hidden_burn_proc_bonus(tower_id)):
			applies_burning = true
			burn_dps_percent_bonus = TowerManager.get_hidden_burn_dps_percent_bonus(tower_id)

	var projectile = projectile_scene.instantiate()
	projectile.turret_type = turret_type
	projectile.turret_level = tier
	projectile.source_tower_id = tower_id
	projectile.target = target
	projectile.damage = int(final_damage)
	projectile.splash_radius = splash_radius
	projectile.splash_damage_mult = TowerManager.get_computed_splash_damage_mult(tower_id) if tower_id >= 0 else TowerManager.BASE_SPLASH_DAMAGE_MULT
	projectile.applies_frozen = applies_frozen
	projectile.applies_burning = applies_burning
	projectile.freeze_duration = freeze_duration
	projectile.burn_dps_percent_bonus = burn_dps_percent_bonus
	var muzzle = get_node_or_null("Muzzle")
	if muzzle:
		projectile.global_position = muzzle.global_position
		projectile.rotation = muzzle.global_rotation
	else:
		projectile.global_position = global_position
		projectile.rotation = rotation
	var container = get_tree().root.get_node_or_null("Main/ProjectilesContainer")
	if container:
		container.add_child(projectile)
	else:
		get_tree().root.add_child(projectile)
	return is_crit

func _on_mob_entered_range(body):
	if body.is_in_group("mob") and not targets_in_range.has(body):
		targets_in_range.append(body)

func _on_mob_exited_range(body):
	if body.is_in_group("mob"):
		targets_in_range.erase(body)
		if current_target == body:
			current_target = null

func try_ascend() -> void:
	if tower_id < 0:
		return
	await ServerState.ascend_tower_server(tower_id)
