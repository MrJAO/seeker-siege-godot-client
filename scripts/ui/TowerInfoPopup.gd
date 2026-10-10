extends PanelContainer

@onready var name_label: Label = $Margin/VBox/TopRow/NameLabel
@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var exp_bar: ProgressBar = $Margin/VBox/ExpBar
@onready var level_label: Label = $Margin/VBox/LevelLabel
@onready var stats_label: Label = $Margin/VBox/StatsLabel
@onready var ascend_cost_energy: Label = $Margin/VBox/AscendCostEnergy
@onready var ascend_cost_scraps: Label = $Margin/VBox/AscendCostScraps
@onready var ascend_cost_oil: Label = $Margin/VBox/AscendCostOil
@onready var ascend_button: Button = $Margin/VBox/AscendButton
@onready var equipment_row: HBoxContainer = $Margin/VBox/EquipmentRow
@onready var relocate_button: Button = $Margin/VBox/RelocateButton
@onready var relocate_cooldown_label: Label = $Margin/VBox/RelocateCooldownLabel
@onready var hidden_skills_button: Button = $Margin/VBox/HiddenSkillsButton

var tower_id: int = -1
var current_turret_node: Node2D = null
var hidden_skill_popup: Control = null

func set_hidden_skill_popup(popup: Control) -> void:
	hidden_skill_popup = popup

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	ascend_button.pressed.connect(_on_ascend_pressed)
	relocate_button.pressed.connect(_on_relocate_pressed)
	hidden_skills_button.pressed.connect(_on_hidden_skills_pressed)

func open(id: int, world_pos: Vector2, turret_node: Node2D = null) -> void:
	tower_id = id
	current_turret_node = turret_node
	if turret_node and turret_node.has_method("hide_ascend_indicator"):
		turret_node.hide_ascend_indicator()
	var screen_pos: Vector2 = get_viewport().canvas_transform * world_pos
	global_position = screen_pos + Vector2(-70, -160)
	_refresh()
	visible = true

func _process(_delta: float) -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	if tower_id < 0 or not TowerManager.owned_towers.has(tower_id):
		return
	var t: Dictionary = TowerManager.owned_towers[tower_id]
	name_label.text = "T%d %s" % [t.tier, t.type.capitalize().replace("_", " ")]
	var exp_needed: float = TowerManager.exp_to_next_level(t.level)
	exp_bar.max_value = exp_needed
	exp_bar.value = t.exp
	level_label.text = "Lvl. %d" % t.level

	var stats: Dictionary = TowerManager.get_computed_stats(tower_id)
	stats_label.text = "DMG: %.1f\nATK Speed: %.2f\nRange: %.0f\nCrit Chance: %.0f%%\nCrit Dmg: %.0fx" % [stats.dmg, stats.atk_speed, stats.range, stats.crit_chance * 100.0, stats.crit_dmg_mult]

	var eligible: bool = TowerManager.is_ascension_level_met(tower_id)
	ascend_button.visible = eligible
	ascend_cost_energy.visible = eligible
	ascend_cost_scraps.visible = eligible
	ascend_cost_oil.visible = eligible

	if eligible:
		var cost: Dictionary = TowerManager.ascend_cost(t.tier)
		ascend_cost_energy.text = "Energy: %d / %d" % [int(ResourceManager.get_balance("energy")), int(cost.energy)]
		ascend_cost_scraps.text = "Scraps: %d / %d" % [int(ResourceManager.get_balance("scraps")), int(cost.scraps)]
		ascend_cost_oil.text = "Oil: %d / %d" % [int(ResourceManager.get_balance("oil")), int(cost.oil)]
		ascend_button.disabled = not TowerManager.can_ascend(tower_id)

	hidden_skills_button.visible = TowerManager.has_hidden_tree_unlocked(tower_id)

	var on_cooldown: bool = t.relocate_timer > 0.0
	relocate_button.disabled = on_cooldown
	relocate_cooldown_label.visible = on_cooldown
	if on_cooldown:
		relocate_cooldown_label.text = "Cooldown: %ds" % int(t.relocate_timer)

func _on_ascend_pressed() -> void:
	if current_turret_node and current_turret_node.has_method("try_ascend"):
		current_turret_node.try_ascend()
	else:
		await ServerState.ascend_tower_server(tower_id)

func _on_relocate_pressed() -> void:
	if BuildManager.relocate_tower(tower_id):
		visible = false

func _on_hidden_skills_pressed() -> void:
	if hidden_skill_popup:
		hidden_skill_popup.open(tower_id)
		visible = false
