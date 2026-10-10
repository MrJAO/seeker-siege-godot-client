extends PanelContainer

@onready var name_label: Label = $Margin/VBox/TopRow/NameLabel
@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var level_label: Label = $Margin/VBox/LevelLabel
@onready var hp_label: Label = $Margin/VBox/HpLabel
@onready var produced_label: Label = $Margin/VBox/ProducedLabel
@onready var elapsed_label: Label = $Margin/VBox/ElapsedLabel
@onready var producing_label: Label = $Margin/VBox/ProducingLabel
@onready var rate_min_label: Label = $Margin/VBox/RateMinLabel
@onready var rate_hour_label: Label = $Margin/VBox/RateHourLabel
@onready var rate_day_label: Label = $Margin/VBox/RateDayLabel
@onready var resource_row: VBoxContainer = $Margin/VBox/ResourceRow
@onready var switch_confirm_row: HBoxContainer = $Margin/VBox/SwitchConfirmRow
@onready var switch_confirm_label: Label = $Margin/VBox/SwitchConfirmRow/SwitchConfirmLabel
@onready var switch_confirm_button: Button = $Margin/VBox/SwitchConfirmRow/ConfirmButton
@onready var switch_cancel_button: Button = $Margin/VBox/SwitchConfirmRow/CancelButton
@onready var required_map_label: Label = $Margin/VBox/RequiredMapLabel
@onready var cost_energy_label: Label = $Margin/VBox/CostEnergyLabel
@onready var cost_scraps_label: Label = $Margin/VBox/CostScrapsLabel
@onready var cost_oil_label: Label = $Margin/VBox/CostOilLabel
@onready var upgrade_button: Button = $Margin/VBox/UpgradeButton
@onready var upgrade_confirm_row: HBoxContainer = $Margin/VBox/UpgradeConfirmRow
@onready var upgrade_confirm_button: Button = $Margin/VBox/UpgradeConfirmRow/ConfirmButton
@onready var upgrade_cancel_button: Button = $Margin/VBox/UpgradeConfirmRow/CancelButton

var pending_switch_resource: String = ""
var resource_bg_nodes: Dictionary = {}

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	switch_confirm_row.visible = false
	upgrade_confirm_row.visible = false
	switch_confirm_button.pressed.connect(_on_switch_confirm)
	switch_cancel_button.pressed.connect(_on_switch_cancel)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	upgrade_confirm_button.pressed.connect(_on_upgrade_confirm)
	upgrade_cancel_button.pressed.connect(_on_upgrade_cancel)
	_build_resource_buttons()

func open() -> void:
	switch_confirm_row.visible = false
	upgrade_confirm_row.visible = false
	_refresh()
	visible = true

func _process(_delta: float) -> void:
	if visible:
		_refresh()

func _build_resource_buttons() -> void:
	for res in ["energy", "scraps", "oil"]:
		var row := HBoxContainer.new()
		var bg := ColorRect.new()
		bg.custom_minimum_size = Vector2(24, 24)
		var label := Label.new()
		label.text = res.capitalize()
		label.custom_minimum_size = Vector2(90, 0)
		label.add_theme_font_size_override("font_size", 20)
		var btn := Button.new()
		btn.text = "Select"
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_resource_select.bind(res))
		row.add_theme_constant_override("separation", 10)
		row.add_child(bg)
		row.add_child(label)
		row.add_child(btn)
		resource_row.add_child(row)
		resource_bg_nodes[res] = bg

func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]

func _refresh() -> void:
	name_label.text = "Energy Reactor"
	level_label.text = "Level %d" % ReactorManager.reactor_tier
	hp_label.text = "%d / %d" % [int(ReactorManager.current_hp), int(ReactorManager.get_max_hp())]
	producing_label.text = "Currently Producing: %s" % ReactorManager.active_resource.capitalize()
	produced_label.text = "Est. Produced: %d %s" % [int(ReactorManager.estimated_produced_since_switch), ReactorManager.active_resource.capitalize()]
	elapsed_label.text = "Elapse Time: %s" % _format_time(ReactorManager.time_since_switch)

	var per_min: float = ReactorManager._tier().prod_per_min
	rate_min_label.text = "Per Minute: %.2f" % per_min
	rate_hour_label.text = "Per Hour: %.1f" % (per_min * 60.0)
	rate_day_label.text = "Per Day: %.0f" % (per_min * 60.0 * 24.0)
	_update_resource_highlight()

	var maxed_out: bool = ReactorManager.reactor_tier >= ReactorManager.TIER_DATA.size()
	if maxed_out:
		required_map_label.visible = false
		cost_energy_label.visible = false
		cost_scraps_label.visible = false
		cost_oil_label.visible = false
		upgrade_button.visible = false
		return

	upgrade_button.visible = true
	var cost: Dictionary = ReactorManager.tier_upgrade_cost(ReactorManager.reactor_tier + 1)
	cost_energy_label.text = "Energy: %d / %d" % [int(ResourceManager.get_balance("energy")), int(cost.energy)]
	cost_scraps_label.text = "Scraps: %d / %d" % [int(ResourceManager.get_balance("scraps")), int(cost.scraps)]
	cost_oil_label.text = "Oil: %d / %d" % [int(ResourceManager.get_balance("oil")), int(cost.oil)]
	cost_energy_label.visible = true
	cost_scraps_label.visible = true
	cost_oil_label.visible = true

	var map_gated: bool = ReactorManager.reactor_tier >= ReactorManager.unlocked_tier
	required_map_label.visible = map_gated
	if map_gated:
		required_map_label.text = "Required: Clear Region %d - Map %d" % [ReactorManager.unlocked_tier, MapManager.BOSS_MAP]

	upgrade_button.disabled = not ReactorManager.can_upgrade_tier()

func _update_resource_highlight() -> void:
	for res in resource_bg_nodes.keys():
		resource_bg_nodes[res].color = Color(0.2, 0.85, 0.2) if res == ReactorManager.active_resource else Color(0.3, 0.3, 0.35)

func _on_resource_select(res: String) -> void:
	if res == ReactorManager.active_resource:
		return
	pending_switch_resource = res
	switch_confirm_label.text = "Switch production to %s?" % res.capitalize()
	switch_confirm_row.visible = true

func _on_switch_confirm() -> void:
	switch_confirm_row.visible = false
	switch_confirm_button.disabled = true

	var result: Dictionary = await ServerState.switch_reactor_resource(pending_switch_resource)

	switch_confirm_button.disabled = false
	if not result.ok:
		var error_code: String = String(result.data.get("error", ""))
		push_warning("ReactorInfoPopup: switch failed - %s" % error_code)

func _on_switch_cancel() -> void:
	switch_confirm_row.visible = false

func _on_upgrade_pressed() -> void:
	upgrade_confirm_row.visible = true

func _on_upgrade_confirm() -> void:
	upgrade_confirm_row.visible = false
	upgrade_confirm_button.disabled = true

	var result: Dictionary = await ServerState.upgrade_reactor_tier_server()

	upgrade_confirm_button.disabled = false
	if not result.ok:
		var error_code: String = String(result.data.get("error", ""))
		push_warning("ReactorInfoPopup: upgrade failed - %s" % error_code)

func _on_upgrade_cancel() -> void:
	upgrade_confirm_row.visible = false
