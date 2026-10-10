extends PanelContainer

const RESOURCE_NAMES := ["energy", "scraps", "oil"]

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton

@onready var skr_tab_button: Button = $Margin/VBox/TabRow/SkrTabButton
@onready var rex_tab_button: Button = $Margin/VBox/TabRow/RexTabButton

@onready var skr_section: VBoxContainer = $Margin/VBox/Scroll/Content/SkrSection
@onready var rex_section: VBoxContainer = $Margin/VBox/Scroll/Content/RexSection

@onready var skr_energy_fraction: Label = $Margin/VBox/Scroll/Content/SkrSection/SkrRow/EnergyBox/VBox/FractionLabel
@onready var skr_scraps_fraction: Label = $Margin/VBox/Scroll/Content/SkrSection/SkrRow/ScrapsBox/VBox/FractionLabel
@onready var skr_oil_fraction: Label = $Margin/VBox/Scroll/Content/SkrSection/SkrRow/OilBox/VBox/FractionLabel
@onready var skr_exchange_button: Button = $Margin/VBox/Scroll/Content/SkrSection/SkrExchangeButton
@onready var skr_global_cap_label: Label = $Margin/VBox/Scroll/Content/SkrSection/GlobalCapLabel

@onready var rex_energy_pool: Label = $Margin/VBox/Scroll/Content/RexSection/RexRow/EnergyBox/VBox/FractionLabel
@onready var rex_scraps_pool: Label = $Margin/VBox/Scroll/Content/RexSection/RexRow/ScrapsBox/VBox/FractionLabel
@onready var rex_oil_pool: Label = $Margin/VBox/Scroll/Content/RexSection/RexRow/OilBox/VBox/FractionLabel

@onready var my_resource_dropdown: OptionButton = $Margin/VBox/Scroll/Content/RexSection/MyResourcesRow/MyResourceDropdown
@onready var my_resource_balance_label: Label = $Margin/VBox/Scroll/Content/RexSection/MyResourcesRow/BalanceLabel
@onready var amount_input: LineEdit = $Margin/VBox/Scroll/Content/RexSection/AmountInput

@onready var exchange_to_dropdown: OptionButton = $Margin/VBox/Scroll/Content/RexSection/ExchangeToRow/ExchangeToDropdown
@onready var receive_label: Label = $Margin/VBox/Scroll/Content/RexSection/ReceiveLabel

@onready var confirm_exchange_button: Button = $Margin/VBox/Scroll/Content/RexSection/ConfirmExchangeButton
@onready var confirm_row: HBoxContainer = $Margin/VBox/Scroll/Content/RexSection/ConfirmRow
@onready var confirm_button: Button = $Margin/VBox/Scroll/Content/RexSection/ConfirmRow/ConfirmButton
@onready var cancel_button: Button = $Margin/VBox/Scroll/Content/RexSection/ConfirmRow/CancelButton

var pending_source: String = "energy"
var pending_target: String = "scraps"
var pending_amount: float = 0.0

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	skr_tab_button.pressed.connect(_on_skr_tab_pressed)
	rex_tab_button.pressed.connect(_on_rex_tab_pressed)
	skr_exchange_button.pressed.connect(_on_skr_exchange_pressed)

	for res_name in RESOURCE_NAMES:
		my_resource_dropdown.add_item(res_name.capitalize())
	my_resource_dropdown.select(0)
	my_resource_dropdown.item_selected.connect(_on_my_resource_selected)

	amount_input.text_changed.connect(_on_amount_text_changed)
	exchange_to_dropdown.item_selected.connect(_on_exchange_to_selected)

	confirm_exchange_button.pressed.connect(_on_confirm_exchange_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_row.visible = false

	ResourceManager.balance_changed.connect(_on_data_changed)
	SKRManager.skr_balance_changed.connect(_on_data_changed)
	SKRManager.resource_exchange_pool_changed.connect(_on_data_changed)

	_rebuild_exchange_to_options()
	_show_tab("skr")
	_refresh_all()
	_apply_lock_state()

func open() -> void:
	visible = true
	_apply_lock_state()
	_show_tab("skr")
	await ServerState.refresh_skr_status()
	await ServerState.refresh_resource_pool_status()
	_refresh_all()

# Gated banner
func is_locked() -> bool:
	return not MapManager.is_feature_unlocked("skr_exchange")

func _apply_lock_state() -> void:
	var locked: bool = is_locked()
	my_resource_dropdown.disabled = locked
	exchange_to_dropdown.disabled = locked
	amount_input.editable = not locked
	_refresh_all()

func _on_close_pressed() -> void:
	visible = false
	confirm_row.visible = false

# Mini tabs
func _show_tab(tab: String) -> void:
	skr_section.visible = tab == "skr"
	rex_section.visible = tab == "rex"
	skr_tab_button.button_pressed = tab == "skr"
	rex_tab_button.button_pressed = tab == "rex"

func _on_skr_tab_pressed() -> void:
	_show_tab("skr")

func _on_rex_tab_pressed() -> void:
	_show_tab("rex")

func _on_data_changed(_a = null, _b = null) -> void:
	_refresh_all()

func _refresh_all() -> void:
	_refresh_skr_section()
	_refresh_rex_pools()
	_refresh_my_resource_balance()
	_update_receive_label()

func _format_num(n: int) -> String:
	var s: String = str(n)
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "," + result
	return result

# SKR Exchange
func _refresh_skr_section() -> void:
	var status: Dictionary = ServerState.skr_exchange_status
	var efficiency: float = float(status.get("efficiency", 1.0))
	var cost_energy: int = int(SKRManager.EXCHANGE_RATE.energy * efficiency)
	var cost_scraps: int = int(SKRManager.EXCHANGE_RATE.scraps * efficiency)
	var cost_oil: int = int(SKRManager.EXCHANGE_RATE.oil * efficiency)

	skr_energy_fraction.text = "%d/%d" % [int(ResourceManager.get_balance("energy")), cost_energy]
	skr_scraps_fraction.text = "%d/%d" % [int(ResourceManager.get_balance("scraps")), cost_scraps]
	skr_oil_fraction.text = "%d/%d" % [int(ResourceManager.get_balance("oil")), cost_oil]

	var player_remaining: int = int(status.get("playerRemaining", 0))
	var pool_remaining: int = int(status.get("poolRemaining", 0))
	var pool_total: int = int(status.get("poolTotal", 0))
	skr_global_cap_label.text = "Global Daily Cap: %s/%s" % [_format_num(pool_remaining), _format_num(pool_total)]
	var can_afford: bool = (
		ResourceManager.get_balance("energy") >= cost_energy
		and ResourceManager.get_balance("scraps") >= cost_scraps
		and ResourceManager.get_balance("oil") >= cost_oil
	)
	skr_exchange_button.disabled = is_locked() or player_remaining < 1 or pool_remaining < 1 or not can_afford

func _on_skr_exchange_pressed() -> void:
	if is_locked():
		return
	skr_exchange_button.disabled = true
	await ServerState.exchange_skr(1)
	_refresh_all()

# Resources Exchange
func _refresh_rex_pools() -> void:
	var remaining: Dictionary = ServerState.resource_exchange_status.get("remaining", {})
	var total: int = int(ServerState.resource_exchange_status.get("total", SKRManager.RESOURCE_EXCHANGE_DAILY_CAP))
	rex_energy_pool.text = "%d/%d" % [int(remaining.get("energy", total)), total]
	rex_scraps_pool.text = "%d/%d" % [int(remaining.get("scraps", total)), total]
	rex_oil_pool.text = "%d/%d" % [int(remaining.get("oil", total)), total]

func _on_my_resource_selected(index: int) -> void:
	pending_source = RESOURCE_NAMES[index]
	_rebuild_exchange_to_options()
	_refresh_my_resource_balance()
	_update_receive_label()

func _refresh_my_resource_balance() -> void:
	my_resource_balance_label.text = "You have: %d" % int(ResourceManager.get_balance(pending_source))

func _rebuild_exchange_to_options() -> void:
	exchange_to_dropdown.clear()
	var options: Array = []
	for res_name in RESOURCE_NAMES:
		if res_name != pending_source:
			options.append(res_name)
	for res_name in options:
		exchange_to_dropdown.add_item(res_name.capitalize())
	if not (pending_target in options):
		pending_target = options[0] if options.size() > 0 else ""
	var idx: int = options.find(pending_target)
	if idx >= 0:
		exchange_to_dropdown.select(idx)

func _on_exchange_to_selected(index: int) -> void:
	var options: Array = []
	for res_name in RESOURCE_NAMES:
		if res_name != pending_source:
			options.append(res_name)
	if index >= 0 and index < options.size():
		pending_target = options[index]
	_update_receive_label()

func _on_amount_text_changed(new_text: String) -> void:
	pending_amount = new_text.to_float() if new_text.is_valid_float() else 0.0
	_update_receive_label()

func _update_receive_label() -> void:
	receive_label.text = "You will receive: %d" % int(pending_amount)
	var remaining: Dictionary = ServerState.resource_exchange_status.get("remaining", {})
	var pool_remaining: float = float(remaining.get(pending_target, 0))
	var has_enough_source: bool = ResourceManager.get_balance(pending_source) >= pending_amount
	var valid_amount: bool = pending_amount > 0.0 and pending_source != pending_target
	confirm_exchange_button.disabled = (
		is_locked() or not valid_amount or not has_enough_source or pending_amount > pool_remaining
	)

func _on_confirm_exchange_pressed() -> void:
	confirm_row.visible = true

func _on_confirm_pressed() -> void:
	if is_locked():
		confirm_row.visible = false
		return
	confirm_button.disabled = true
	var result: Dictionary = await ServerState.exchange_resources_server(
		pending_source, pending_target, int(pending_amount)
	)
	confirm_button.disabled = false
	if result.ok:
		amount_input.text = ""
		pending_amount = 0.0
	confirm_row.visible = false
	_refresh_all()

func _on_cancel_pressed() -> void:
	confirm_row.visible = false
