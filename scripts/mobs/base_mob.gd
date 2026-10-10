extends CharacterBody2D

@export var mob_name: String = "Base Mob"
@export var mob_type: String = ""
@export var max_hp: int = 100
@export var move_speed: float = 80.0
@export var damage: int = 10
@export var points: int = 1

var current_hp: int
var reactor_target: Node2D = null
var health_bar: Node2D = null
var name_label: Label = null
var contributors: Dictionary = {}
var last_hit_tower_id: int = -1
var is_dead: bool = false

var status_effects: Dictionary = {}
const BLINK_INTERVAL: float = 0.2
const COLOR_NORMAL := Color(1, 1, 1)
const COLOR_FROZEN := Color(0.4, 0.6, 1.0)
const COLOR_BURNING := Color(1.0, 0.4, 0.1)
const SCORCHED_EARTH_BURN_DURATION: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	_apply_region_stat_growth()
	current_hp = max_hp
	add_to_group("mob")
	z_index = 10
	reactor_target = get_tree().get_first_node_in_group("reactor")
	if animated_sprite:
		animated_sprite.play("walk_down")
	_create_health_bar()
	_create_name_label()

func _apply_region_stat_growth() -> void:
	if mob_type.ends_with("_boss"):
		return
	var growth_mult: float = MapManager.get_mob_stat_growth_mult(GameManager.current_region, GameManager.current_map)
	var hp_step_mult: float = MapManager.get_hp_step_mult(GameManager.current_region, GameManager.current_map)
	max_hp = int(max_hp * growth_mult * hp_step_mult)
	damage = int(damage * growth_mult)
	move_speed = move_speed * growth_mult

func _create_name_label() -> void:
	name_label = Label.new()
	name_label.z_index = 20
	name_label.position = Vector2(-16, -44)
	name_label.custom_minimum_size = Vector2(32, 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	var mob_level: int = MapManager.get_global_map_index(GameManager.current_region, GameManager.current_map)
	name_label.text = "Lvl. %d" % mob_level
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 3)
	add_child(name_label)

func _create_health_bar() -> void:
	health_bar = Node2D.new()
	health_bar.z_index = 20
	health_bar.position = Vector2(-16, -30)
	add_child(health_bar)
	health_bar.draw.connect(_draw_health_bar)

func _get_hp_color(pct: float) -> Color:
	if pct >= 0.80:
		return Color(0, 0.9, 0.2, 0.95)
	elif pct >= 0.50:
		return Color(1, 0.55, 0, 0.95)
	else:
		return Color(1, 0, 0, 0.95)

func _draw_health_bar() -> void:
	var width: float = 32.0
	var height: float = 4.0
	var pct: float = float(current_hp) / float(max_hp)
	health_bar.draw_rect(Rect2(0, 0, width, height), Color(0.15, 0.15, 0.15, 0.85))
	health_bar.draw_rect(Rect2(0, 0, width * pct, height), _get_hp_color(pct))

func _process(delta: float) -> void:
	_process_status_effects(delta)

func _physics_process(_delta):
	if not is_instance_valid(reactor_target):
		return
	if is_frozen():
		return
	var direction = (reactor_target.global_position - global_position).normalized()
	update_animation(direction)
	velocity = direction * move_speed
	move_and_slide()
	if global_position.distance_to(reactor_target.global_position) < 20:
		reach_reactor()

func update_animation(direction: Vector2):
	if not animated_sprite:
		return
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			if animated_sprite.sprite_frames.has_animation("walk_right"):
				animated_sprite.play("walk_right")
		else:
			if animated_sprite.sprite_frames.has_animation("walk_left"):
				animated_sprite.play("walk_left")
	else:
		if direction.y > 0:
			if animated_sprite.sprite_frames.has_animation("walk_down"):
				animated_sprite.play("walk_down")
		else:
			if animated_sprite.sprite_frames.has_animation("walk_up"):
				animated_sprite.play("walk_up")

func take_damage(amount: int, source_tower_id: int = -1) -> void:
	if is_dead:
		return
	var final_amount: int = amount
	if is_frozen():
		var freeze_source: int = status_effects.frozen.get("source_tower_id", -1)
		if freeze_source != -1 and TowerManager.owned_towers.has(freeze_source):
			var freeze_tower: Dictionary = TowerManager.owned_towers[freeze_source]
			if freeze_tower.type == "freeze_ray" and TowerManager.has_hidden_capstone(freeze_source):
				final_amount = int(amount * 1.2)
	current_hp -= final_amount
	if source_tower_id != -1:
		contributors[source_tower_id] = true
		last_hit_tower_id = source_tower_id
	if health_bar:
		health_bar.queue_redraw()
	if current_hp <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	if mob_type.ends_with("_boss"):
		ServerState.report_boss_kill(last_hit_tower_id, mob_type)
	else:
		ServerState.queue_kill(last_hit_tower_id, mob_type)
		if TowerManager.owned_towers.has(last_hit_tower_id):
			var killer: Dictionary = TowerManager.owned_towers[last_hit_tower_id]
			if killer.type == "rocket_launcher" and TowerManager.has_hidden_capstone(last_hit_tower_id):
				_trigger_shockwave()
	MapManager.register_kill()

	queue_free()

func reach_reactor():
	ReactorManager.take_damage_from_mob(mob_type)
	queue_free()

# Status effects (Frozen/Slow, Fire/Burn)
func apply_frozen(duration: float, source_tower_id: int = -1) -> void:
	status_effects["frozen"] = {"time_left": duration, "source_tower_id": source_tower_id}

func apply_burning(duration: float, dps: float, source_tower_id: int = -1) -> void:
	status_effects["burning"] = {
		"time_left": duration,
		"dps": dps,
		"blink_t": 0.0,
		"accumulator": 0.0,
		"source_tower_id": source_tower_id,
	}

func is_frozen() -> bool:
	return status_effects.has("frozen")

func is_burning() -> bool:
	return status_effects.has("burning")

func _process_status_effects(delta: float) -> void:
	if status_effects.is_empty():
		return

	if status_effects.has("frozen"):
		status_effects.frozen.time_left -= delta
		if status_effects.frozen.time_left <= 0.0:
			status_effects.erase("frozen")

	if status_effects.has("burning"):
		var b: Dictionary = status_effects.burning
		b.blink_t += delta
		b.time_left -= delta
		b.accumulator += b.dps * delta
		if b.accumulator >= 1.0:
			var tick_amount: int = int(b.accumulator)
			b.accumulator -= tick_amount
			take_damage(tick_amount, b.get("source_tower_id", -1))
			_maybe_spread_burn(b)
		if b.time_left <= 0.0:
			status_effects.erase("burning")
		else:
			status_effects.burning = b

	_update_status_modulate()

func _update_status_modulate() -> void:
	var frozen: bool = is_frozen()
	var burning: bool = is_burning()

	if frozen and burning:
		var blink_on: bool = int(status_effects.burning.blink_t / BLINK_INTERVAL) % 2 == 0
		modulate = COLOR_BURNING if blink_on else COLOR_FROZEN
	elif frozen:
		modulate = COLOR_FROZEN
	elif burning:
		var blink_on: bool = int(status_effects.burning.blink_t / BLINK_INTERVAL) % 2 == 0
		modulate = COLOR_BURNING if blink_on else COLOR_NORMAL
	else:
		modulate = COLOR_NORMAL


# Hidden Capstone: Shockwave
func _trigger_shockwave() -> void:
	var shockwave_damage: int = int(max_hp * 0.10)
	var shockwave_radius: float = 50.0
	for mob in get_tree().get_nodes_in_group("mob"):
		if mob == self or not is_instance_valid(mob):
			continue
		if mob.global_position.distance_to(global_position) <= shockwave_radius:
			mob.take_damage(shockwave_damage, last_hit_tower_id)

# Hidden Capstone: Scorched Earth
func _maybe_spread_burn(b: Dictionary) -> void:
	var source_id: int = b.get("source_tower_id", -1)
	if source_id == -1 or not TowerManager.owned_towers.has(source_id):
		return
	var source_tower: Dictionary = TowerManager.owned_towers[source_id]
	if source_tower.type != "flamethrower" or not TowerManager.has_hidden_capstone(source_id):
		return
	var spread_radius: float = 40.0
	var spread_dps: float = b.dps * 0.5
	for mob in get_tree().get_nodes_in_group("mob"):
		if mob == self or not is_instance_valid(mob):
			continue
		if mob.has_method("apply_burning") and mob.has_method("is_burning") and not mob.is_burning():
			if mob.global_position.distance_to(global_position) <= spread_radius:
				mob.apply_burning(SCORCHED_EARTH_BURN_DURATION, spread_dps)
