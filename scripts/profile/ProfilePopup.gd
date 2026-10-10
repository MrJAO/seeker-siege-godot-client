extends PanelContainer

const RESOURCE_ICONS := {
	"energy": "res://assets/icons/energy_icon.png",
	"scraps": "res://assets/icons/scraps_icon.png",
	"oil": "res://assets/icons/oil_icon.png",
}

const ERROR_MESSAGES := {
	"invalid_amount": "Enter a valid amount.",
	"insufficient_balance": "Not enough SKR to withdraw that much.",
	"withdraw_not_configured": "Withdrawals aren't available right now.",
	"onchain_withdraw_failed": "The on-chain transfer failed - your balance was not deducted. Try again.",
	"invalid_claim_type": "Invalid request type.",
	"cooldown_active": "Still on cooldown.",
	"claim_failed": "Request failed - try again.",
}

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var wallet_label: Label = $Margin/VBox/WalletLabel
@onready var wallet_balances_label: Label = $Margin/VBox/WalletBalancesLabel

@onready var balance_tab_button: Button = $Margin/VBox/TabRow/BalanceTabButton
@onready var activity_tab_button: Button = $Margin/VBox/TabRow/ActivityTabButton
@onready var clockin_tab_button: Button = $Margin/VBox/TabRow/ClockInTabButton

@onready var balance_container: Control = $Margin/VBox/ContentStack/BalanceContainer
@onready var skr_balance_label: Label = $Margin/VBox/ContentStack/BalanceContainer/SkrBalanceLabel
@onready var withdraw_input: LineEdit = $Margin/VBox/ContentStack/BalanceContainer/WithdrawRow/WithdrawInput
@onready var pct25_button: Button = $Margin/VBox/ContentStack/BalanceContainer/PctRow/Pct25Button
@onready var pct50_button: Button = $Margin/VBox/ContentStack/BalanceContainer/PctRow/Pct50Button
@onready var pct75_button: Button = $Margin/VBox/ContentStack/BalanceContainer/PctRow/Pct75Button
@onready var pct_max_button: Button = $Margin/VBox/ContentStack/BalanceContainer/PctRow/PctMaxButton
@onready var withdraw_button: Button = $Margin/VBox/ContentStack/BalanceContainer/WithdrawButton
@onready var withdraw_status_label: Label = $Margin/VBox/ContentStack/BalanceContainer/WithdrawStatusLabel

@onready var activity_container: Control = $Margin/VBox/ContentStack/ActivityContainer
@onready var activity_list: VBoxContainer = $Margin/VBox/ContentStack/ActivityContainer/Scroll/ActivityList

@onready var clockin_container: Control = $Margin/VBox/ContentStack/ClockInContainer
@onready var resources_label: Label = $Margin/VBox/ContentStack/ClockInContainer/ResourcesLabel
@onready var resources_request_button: Button = $Margin/VBox/ContentStack/ClockInContainer/ResourcesRequestButton
@onready var resources_confirm_row: HBoxContainer = $Margin/VBox/ContentStack/ClockInContainer/ResourcesConfirmRow
@onready var resources_confirm_button: Button = $Margin/VBox/ContentStack/ClockInContainer/ResourcesConfirmRow/ConfirmButton
@onready var resources_cancel_button: Button = $Margin/VBox/ContentStack/ClockInContainer/ResourcesConfirmRow/CancelButton
@onready var resources_status_label: Label = $Margin/VBox/ContentStack/ClockInContainer/ResourcesStatusLabel
@onready var skr_label: Label = $Margin/VBox/ContentStack/ClockInContainer/SkrLabel
@onready var skr_request_button: Button = $Margin/VBox/ContentStack/ClockInContainer/SkrRequestButton
@onready var skr_confirm_row: HBoxContainer = $Margin/VBox/ContentStack/ClockInContainer/SkrConfirmRow
@onready var skr_confirm_button: Button = $Margin/VBox/ContentStack/ClockInContainer/SkrConfirmRow/ConfirmButton
@onready var skr_cancel_button: Button = $Margin/VBox/ContentStack/ClockInContainer/SkrConfirmRow/CancelButton
@onready var skr_status_label: Label = $Margin/VBox/ContentStack/ClockInContainer/SkrStatusLabel

var current_tab: String = "balance"
var selected_pct: float = 0.0
var _updating_input_programmatically: bool = false

var clockin_resources_amount: int = 10000
var clockin_skr_amount: int = 1000
var resources_cooldown_remaining: float = 0.0
var skr_cooldown_remaining: float = 0.0

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)

	balance_tab_button.pressed.connect(func(): _show_tab("balance"))
	activity_tab_button.pressed.connect(func(): _show_tab("activity"))
	clockin_tab_button.pressed.connect(func(): _show_tab("clockin"))

	pct25_button.pressed.connect(_on_pct_pressed.bind(0.25, pct25_button))
	pct50_button.pressed.connect(_on_pct_pressed.bind(0.50, pct50_button))
	pct75_button.pressed.connect(_on_pct_pressed.bind(0.75, pct75_button))
	pct_max_button.pressed.connect(_on_pct_pressed.bind(1.0, pct_max_button))
	withdraw_input.text_changed.connect(_on_withdraw_input_changed)
	withdraw_button.pressed.connect(_on_withdraw_pressed)

	resources_request_button.pressed.connect(func(): resources_confirm_row.visible = true)
	resources_cancel_button.pressed.connect(func(): resources_confirm_row.visible = false)
	resources_confirm_button.pressed.connect(_on_resources_claim_confirmed)

	skr_request_button.pressed.connect(func(): skr_confirm_row.visible = true)
	skr_cancel_button.pressed.connect(func(): skr_confirm_row.visible = false)
	skr_confirm_button.pressed.connect(_on_skr_claim_confirmed)

func open() -> void:
	visible = true
	wallet_label.text = "Wallet: %s" % WalletManager.wallet_address
	_refresh_skr_balance_display()
	_refresh_wallet_balances()
	_show_tab("balance")

func _refresh_wallet_balances() -> void:
	wallet_balances_label.text = "SOL Balance: ... | SKR Balance: ..."
	var result: Dictionary = await ServerState.fetch_wallet_balances()
	if not result.ok:
		wallet_balances_label.text = "SOL Balance: - | SKR Balance: -"
		return
	var sol_amount: float = float(result.data.get("solLamports", 0)) / 1000000000.0
	var skr_decimals: int = int(result.data.get("skrDecimals", 6))
	var skr_amount: float = float(result.data.get("skrBaseUnits", "0")) / pow(10.0, skr_decimals)
	wallet_balances_label.text = "SOL Balance: %.4f | SKR Balance: %.2f" % [sol_amount, skr_amount]

func _process(delta: float) -> void:
	if not visible or current_tab != "clockin":
		return
	if resources_cooldown_remaining > 0.0:
		resources_cooldown_remaining = max(0.0, resources_cooldown_remaining - delta)
		_update_clockin_button_state("resources")
	if skr_cooldown_remaining > 0.0:
		skr_cooldown_remaining = max(0.0, skr_cooldown_remaining - delta)
		_update_clockin_button_state("skr")

func _refresh_skr_balance_display() -> void:
	skr_balance_label.text = "In-Game SKR: %d" % int(SKRManager.skr_balance)

# Tab switching
func _show_tab(tab: String) -> void:
	current_tab = tab
	balance_tab_button.button_pressed = tab == "balance"
	activity_tab_button.button_pressed = tab == "activity"
	clockin_tab_button.button_pressed = tab == "clockin"

	balance_container.visible = tab == "balance"
	activity_container.visible = tab == "activity"
	clockin_container.visible = tab == "clockin"

	match tab:
		"balance":
			_refresh_skr_balance_display()
		"activity":
			_refresh_activity()
		"clockin":
			_refresh_clockin_status()

# In-Game Balance / Withdraw
func _on_pct_pressed(pct: float, _button: Button) -> void:
	if is_equal_approx(selected_pct, pct):
		selected_pct = 0.0
		_updating_input_programmatically = true
		withdraw_input.text = ""
		_updating_input_programmatically = false
		_update_pct_buttons()
		return

	selected_pct = pct
	var amount: float = SKRManager.skr_balance * pct
	_updating_input_programmatically = true
	withdraw_input.text = str(int(round(amount)))
	_updating_input_programmatically = false
	_update_pct_buttons()

func _on_withdraw_input_changed(_new_text: String) -> void:
	if _updating_input_programmatically:
		return
	selected_pct = 0.0
	_update_pct_buttons()

func _update_pct_buttons() -> void:
	pct25_button.button_pressed = is_equal_approx(selected_pct, 0.25)
	pct50_button.button_pressed = is_equal_approx(selected_pct, 0.50)
	pct75_button.button_pressed = is_equal_approx(selected_pct, 0.75)
	pct_max_button.button_pressed = is_equal_approx(selected_pct, 1.0)

func _on_withdraw_pressed() -> void:
	var amount: int = int(withdraw_input.text) if withdraw_input.text.is_valid_int() else 0
	if amount <= 0:
		withdraw_status_label.text = "Enter a valid amount."
		return

	withdraw_button.disabled = true
	withdraw_status_label.text = "Processing..."

	var result: Dictionary = await ServerState.withdraw_skr(amount)

	withdraw_button.disabled = false

	if result.ok:
		var signature: String = String(result.data.get("signature", ""))
		var short_sig: String = signature.left(8) + "..." + signature.right(8) if signature.length() > 20 else signature
		withdraw_status_label.text = "Withdrawn! Tx: %s" % short_sig
		withdraw_input.text = ""
		selected_pct = 0.0
		_update_pct_buttons()
		_refresh_skr_balance_display()
		return

	var error_code: String = String(result.data.get("error", ""))
	withdraw_status_label.text = ERROR_MESSAGES.get(error_code, "Could not process withdrawal.")

# Activity Tab
func _refresh_activity() -> void:
	for child in activity_list.get_children():
		child.queue_free()

	var result: Dictionary = await ServerState.fetch_profile_activity()
	if not result.ok:
		var error_label := Label.new()
		error_label.text = "Could not load activity."
		error_label.add_theme_font_size_override("font_size", 18)
		activity_list.add_child(error_label)
		return

	var entries: Array = result.data.get("activity", [])
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No activity yet."
		empty_label.add_theme_font_size_override("font_size", 18)
		activity_list.add_child(empty_label)
		return

	for entry in entries:
		activity_list.add_child(_make_activity_row(entry))

func _make_activity_row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var label_text := Label.new()
	label_text.text = String(entry.get("label", "Activity"))
	label_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_text.add_theme_font_size_override("font_size", 18)
	hbox.add_child(label_text)

	var delta: float = float(entry.get("delta", 0))
	var currency: String = String(entry.get("currency", ""))
	var delta_label := Label.new()
	delta_label.text = "%s%d %s" % ["+" if delta >= 0 else "", int(delta), currency.capitalize()]
	delta_label.add_theme_font_size_override("font_size", 18)
	delta_label.add_theme_color_override("font_color", Color(0.1, 0.6, 0.1, 1) if delta >= 0 else Color(0.7, 0.1, 0.1, 1))
	hbox.add_child(delta_label)

	return row

# CLOCK IN Testing
func _refresh_clockin_status() -> void:
	resources_status_label.text = "Checking..."
	skr_status_label.text = ""

	var result: Dictionary = await ServerState.fetch_clockin_status()
	if not result.ok:
		resources_status_label.text = "Could not load status."
		return

	clockin_resources_amount = int(result.data.get("resourcesAmount", 10000))
	clockin_skr_amount = int(result.data.get("skrAmount", 1000))
	resources_label.text = "Resources: Energy %s | Scraps %s | Oil %s" % [
		_format_num(clockin_resources_amount), _format_num(clockin_resources_amount), _format_num(clockin_resources_amount)
	]
	skr_label.text = "In-Game SKR: %s" % _format_num(clockin_skr_amount)
	resources_status_label.text = ""

	var status: Dictionary = result.data.get("status", {})
	resources_cooldown_remaining = float(status.get("resources", {}).get("remainingMs", 0)) / 1000.0
	skr_cooldown_remaining = float(status.get("skr", {}).get("remainingMs", 0)) / 1000.0
	_update_clockin_button_state("resources")
	_update_clockin_button_state("skr")

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

func _update_clockin_button_state(claim_type: String) -> void:
	if claim_type == "resources":
		var is_ready: bool = resources_cooldown_remaining <= 0.0
		resources_request_button.disabled = not is_ready
		resources_request_button.text = "Request" if is_ready else "Ready in %ds" % int(ceil(resources_cooldown_remaining))
	else:
		var is_ready2: bool = skr_cooldown_remaining <= 0.0
		skr_request_button.disabled = not is_ready2
		skr_request_button.text = "Request" if is_ready2 else "Ready in %ds" % int(ceil(skr_cooldown_remaining))

func _on_resources_claim_confirmed() -> void:
	resources_confirm_row.visible = false
	resources_request_button.disabled = true
	resources_status_label.text = "Requesting..."

	var result: Dictionary = await ServerState.claim_clockin("resources", clockin_resources_amount, clockin_skr_amount)

	if not result.ok:
		var error_code: String = String(result.data.get("error", ""))
		resources_status_label.text = ERROR_MESSAGES.get(error_code, "Request failed.")
		if error_code == "cooldown_active":
			resources_cooldown_remaining = float(result.data.get("remainingMs", 0)) / 1000.0
		_update_clockin_button_state("resources")
		return

	resources_status_label.text = "Granted!"
	resources_cooldown_remaining = 120.0
	_update_clockin_button_state("resources")

func _on_skr_claim_confirmed() -> void:
	skr_confirm_row.visible = false
	skr_request_button.disabled = true
	skr_status_label.text = "Requesting..."

	var result: Dictionary = await ServerState.claim_clockin("skr", clockin_resources_amount, clockin_skr_amount)

	if not result.ok:
		var error_code: String = String(result.data.get("error", ""))
		skr_status_label.text = ERROR_MESSAGES.get(error_code, "Request failed.")
		if error_code == "cooldown_active":
			skr_cooldown_remaining = float(result.data.get("remainingMs", 0)) / 1000.0
		_update_clockin_button_state("skr")
		return

	skr_status_label.text = "Granted!"
	skr_cooldown_remaining = 120.0
	_update_clockin_button_state("skr")
	_refresh_skr_balance_display()
