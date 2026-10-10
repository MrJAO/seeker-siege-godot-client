extends PanelContainer

const RESOURCE_ICONS := {
	"energy": "res://assets/icons/energy_icon.png",
	"scraps": "res://assets/icons/scraps_icon.png",
	"oil": "res://assets/icons/oil_icon.png",
}
const RESOURCE_ORDER := ["energy", "scraps", "oil"]

# Demo SKR value
const SKR_TO_USD: float = 0.01
const LAMPORTS_PER_SOL: float = 1000000000.0
const SOLANA_RPC_URL: String = "https://api.devnet.solana.com"

const ERROR_MESSAGES := {
	"invalid_resource": "Invalid resource.",
	"invalid_payment_type": "Invalid payment type.",
	"invalid_quantity": "Enter a valid quantity.",
	"quantity_too_large": "Quantity is too large.",
	"invalid_price": "Enter a valid price.",
	"price_too_large": "Price is too large.",
	"marketplace_locked": "Unlocks at Region 1 - Map 6.",
	"insufficient_balance": "Not enough of that resource to list.",
	"listing_not_found": "This listing is gone.",
	"listing_not_active": "Someone already bought this listing.",
	"wrong_payment_type": "This listing's payment type doesn't match.",
	"cannot_buy_own_listing": "You can't buy your own listing.",
	"reservation_expired": "Payment window expired - try again.",
	"not_your_reservation": "This listing is reserved by someone else right now.",
	"signature_already_used": "This payment was already used.",
	"transaction_failed_onchain": "The transaction failed on-chain.",
	"wrong_signer": "Payment wasn't sent from your connected wallet.",
	"treasury_not_configured": "Marketplace payments aren't available right now.",
}

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var buy_tab_button: Button = $Margin/VBox/TabRow/BuyTabButton
@onready var sell_tab_button: Button = $Margin/VBox/TabRow/SellTabButton
@onready var my_listing_tab_button: Button = $Margin/VBox/TabRow/MyListingTabButton

@onready var overview_container: Control = $Margin/VBox/ContentStack/OverviewContainer
@onready var overview_grid: GridContainer = $Margin/VBox/ContentStack/OverviewContainer/VBox/Scroll/Grid
@onready var buy_search_row: HBoxContainer = $Margin/VBox/ContentStack/OverviewContainer/VBox/BuySearchRow

@onready var sell_detail_container: Control = $Margin/VBox/ContentStack/SellDetailContainer
@onready var sell_back_button: Button = $Margin/VBox/ContentStack/SellDetailContainer/BackRow/BackButton
@onready var sell_header_label: Label = $Margin/VBox/ContentStack/SellDetailContainer/HeaderLabel
@onready var sell_icon: TextureRect = $Margin/VBox/ContentStack/SellDetailContainer/FormRow/Icon
@onready var sell_quantity_input: LineEdit = $Margin/VBox/ContentStack/SellDetailContainer/FormRow/QuantityBox/QuantityInput
@onready var sell_price_input: LineEdit = $Margin/VBox/ContentStack/SellDetailContainer/FormRow/PriceBox/PriceInput
@onready var sell_skr_toggle: Button = $Margin/VBox/ContentStack/SellDetailContainer/FormRow/PaymentBox/PaymentRow/SkrToggle
@onready var sell_sol_toggle: Button = $Margin/VBox/ContentStack/SellDetailContainer/FormRow/PaymentBox/PaymentRow/SolToggle
@onready var sell_confirm_button: Button = $Margin/VBox/ContentStack/SellDetailContainer/ConfirmButton
@onready var sell_error_label: Label = $Margin/VBox/ContentStack/SellDetailContainer/ErrorLabel

@onready var buy_detail_container: Control = $Margin/VBox/ContentStack/BuyDetailContainer
@onready var buy_back_button: Button = $Margin/VBox/ContentStack/BuyDetailContainer/BackRow/BackButton
@onready var buy_header_label: Label = $Margin/VBox/ContentStack/BuyDetailContainer/HeaderLabel
@onready var buy_filter_dropdown: OptionButton = $Margin/VBox/ContentStack/BuyDetailContainer/FilterRow/FilterDropdown
@onready var buy_skr_filter_toggle: Button = $Margin/VBox/ContentStack/BuyDetailContainer/FilterRow/SkrFilterToggle
@onready var buy_sol_filter_toggle: Button = $Margin/VBox/ContentStack/BuyDetailContainer/FilterRow/SolFilterToggle
@onready var buy_overview_search_input: LineEdit = $Margin/VBox/ContentStack/OverviewContainer/VBox/BuySearchRow/SearchInput
@onready var buy_listings_grid: GridContainer = $Margin/VBox/ContentStack/BuyDetailContainer/Scroll/Grid

var current_tab: String = "buy"
var detail_resource: String = ""
var sell_payment_type: String = "SKR"
var buy_payment_filter: String = "SKR"

# Array placement: {id, resource, quantity, price, payment_type, is_mine, status}
var listings: Array = []
var _loading: bool = false

# Demo SOL fallback value
var cached_sol_usd: float = 150.0

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)

	buy_tab_button.pressed.connect(func(): _show_tab("buy"))
	sell_tab_button.pressed.connect(func(): _show_tab("sell"))
	my_listing_tab_button.pressed.connect(func(): _show_tab("my_listing"))

	sell_back_button.pressed.connect(func(): _show_tab("sell"))
	sell_skr_toggle.pressed.connect(_on_sell_skr_toggle_pressed)
	sell_sol_toggle.pressed.connect(_on_sell_sol_toggle_pressed)
	sell_confirm_button.pressed.connect(_on_sell_confirm_pressed)

	buy_back_button.pressed.connect(func(): _show_tab("buy"))
	buy_filter_dropdown.add_item("Lowest to Highest")
	buy_filter_dropdown.add_item("Highest to Lowest")
	buy_filter_dropdown.select(0)
	buy_filter_dropdown.item_selected.connect(func(_i): _refresh_buy_detail())
	buy_skr_filter_toggle.pressed.connect(_on_buy_skr_filter_pressed)
	buy_sol_filter_toggle.pressed.connect(_on_buy_sol_filter_pressed)
	buy_overview_search_input.text_changed.connect(func(_t): _build_buy_overview())

func open() -> void:
	visible = true
	await _refresh_listings_from_server()
	_refresh_sol_price()
	_show_tab(current_tab)

func _refresh_sol_price() -> void:
	var result: Dictionary = await ServerState.fetch_marketplace_sol_price()
	if result.ok and result.data.has("solUsd"):
		cached_sol_usd = float(result.data.solUsd)

# Server Data
func _price_display_to_server_units(price_display: float, payment_type: String) -> int:
	if payment_type == "SOL":
		return int(round(price_display * LAMPORTS_PER_SOL))
	return int(round(price_display))

func _price_server_units_to_display(price_units: int, payment_type: String) -> float:
	if payment_type == "SOL":
		return float(price_units) / LAMPORTS_PER_SOL
	return float(price_units)

func _server_listing_to_dict(row: Dictionary, is_mine: bool) -> Dictionary:
	var payment_type: String = String(row.get("payment_type", "skr")).to_upper()
	var price_units: int = int(row.get("price", 0))
	return {
		"id": int(row.get("id", 0)),
		"resource": String(row.get("resource", "")),
		"quantity": float(row.get("quantity", 0)),
		"price": _price_server_units_to_display(price_units, payment_type),
		"payment_type": payment_type,
		"is_mine": is_mine,
		"status": String(row.get("status", "active")),
	}

func _refresh_listings_from_server() -> void:
	if _loading:
		return
	_loading = true

	var others_result: Dictionary = await ServerState.fetch_marketplace_listings()
	var mine_result: Dictionary = await ServerState.fetch_my_marketplace_listings()

	var new_listings: Array = []
	if others_result.ok:
		for row in others_result.data.get("listings", []):
			new_listings.append(_server_listing_to_dict(row, false))
	if mine_result.ok:
		for row in mine_result.data.get("listings", []):
			new_listings.append(_server_listing_to_dict(row, true))

	listings = new_listings
	_loading = false

func _price_to_usd(price: float, payment_type: String) -> float:
	return price * (cached_sol_usd if payment_type == "SOL" else SKR_TO_USD)

# Marketplace mini tab view
func _show_tab(tab: String) -> void:
	current_tab = tab
	buy_tab_button.button_pressed = tab == "buy"
	sell_tab_button.button_pressed = tab == "sell"
	my_listing_tab_button.button_pressed = tab == "my_listing"

	overview_container.visible = true
	sell_detail_container.visible = false
	buy_detail_container.visible = false

	buy_search_row.visible = tab == "buy"
	if tab == "buy":
		buy_overview_search_input.text = ""

	match tab:
		"buy":
			_build_buy_overview()
		"sell":
			_build_sell_overview()
		"my_listing":
			_build_my_listing_overview()

func _clear_overview_grid() -> void:
	for child in overview_grid.get_children():
		child.queue_free()

# SELL overview
func _build_sell_overview() -> void:
	_clear_overview_grid()
	for res_name in RESOURCE_ORDER:
		overview_grid.add_child(_make_sell_resource_card(res_name))

func _make_sell_resource_card(res_name: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.gui_input.connect(_on_sell_card_input.bind(res_name))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.text = res_name.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = RESOURCE_ICONS.get(res_name, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	var balance_label := Label.new()
	balance_label.text = "Your Balance: %d" % int(ResourceManager.get_balance(res_name))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(balance_label)

	return card

func _on_sell_card_input(event: InputEvent, res_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_sell_detail(res_name)

# SELL detail: enter quantity/price/payment type
func _open_sell_detail(res_name: String) -> void:
	detail_resource = res_name
	overview_container.visible = false
	sell_detail_container.visible = true

	sell_header_label.text = "Sell %s" % res_name.capitalize()
	var icon_path: String = RESOURCE_ICONS.get(res_name, "")
	sell_icon.texture = load(icon_path) if (icon_path != "" and ResourceLoader.exists(icon_path)) else null
	sell_quantity_input.text = ""
	sell_price_input.text = ""
	sell_error_label.text = ""
	sell_payment_type = "SKR"
	sell_skr_toggle.button_pressed = true
	sell_sol_toggle.button_pressed = false

func _on_sell_skr_toggle_pressed() -> void:
	sell_payment_type = "SKR"
	sell_skr_toggle.button_pressed = true
	sell_sol_toggle.button_pressed = false

func _on_sell_sol_toggle_pressed() -> void:
	sell_payment_type = "SOL"
	sell_skr_toggle.button_pressed = false
	sell_sol_toggle.button_pressed = true

func _on_buy_skr_filter_pressed() -> void:
	buy_payment_filter = "SKR"
	buy_skr_filter_toggle.button_pressed = true
	buy_sol_filter_toggle.button_pressed = false
	_refresh_buy_detail()

func _on_buy_sol_filter_pressed() -> void:
	buy_payment_filter = "SOL"
	buy_skr_filter_toggle.button_pressed = false
	buy_sol_filter_toggle.button_pressed = true
	_refresh_buy_detail()

func _on_sell_confirm_pressed() -> void:
	var quantity: float = sell_quantity_input.text.to_float() if sell_quantity_input.text.is_valid_float() else 0.0
	var price: float = sell_price_input.text.to_float() if sell_price_input.text.is_valid_float() else 0.0

	if quantity <= 0.0:
		sell_error_label.text = "Enter a valid quantity."
		return
	if price <= 0.0:
		sell_error_label.text = "Enter a valid price."
		return
	if ResourceManager.get_balance(detail_resource) < quantity:
		sell_error_label.text = "Not enough %s to list that much." % detail_resource.capitalize()
		return

	sell_confirm_button.disabled = true
	sell_error_label.text = "Listing..."

	var price_units: int = _price_display_to_server_units(price, sell_payment_type)
	var result: Dictionary = await ServerState.list_marketplace(
		detail_resource, int(round(quantity)), sell_payment_type.to_lower(), price_units
	)

	sell_confirm_button.disabled = false

	if not result.ok:
		var error_code: String = String(result.data.get("error", ""))
		sell_error_label.text = ERROR_MESSAGES.get(error_code, "Could not list (%s) - try again." % error_code)
		return

	await _refresh_listings_from_server()
	_show_tab("sell")

# BUY overview
func _build_buy_overview() -> void:
	_clear_overview_grid()
	var search_text: String = buy_overview_search_input.text.strip_edges().to_lower()
	for res_name in RESOURCE_ORDER:
		if search_text != "" and not (search_text in res_name.to_lower()):
			continue
		overview_grid.add_child(_make_buy_resource_card(res_name))

func _get_active_listings_for(res_name: String, exclude_mine: bool = true) -> Array:
	var result: Array = []
	for listing in listings:
		if listing.resource != res_name:
			continue
		if listing.get("status", "active") != "active":
			continue
		if exclude_mine and listing.is_mine:
			continue
		result.append(listing)
	return result

func _make_buy_resource_card(res_name: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.gui_input.connect(_on_buy_card_input.bind(res_name))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.text = res_name.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = RESOURCE_ICONS.get(res_name, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	var active: Array = _get_active_listings_for(res_name)
	var count_label := Label.new()
	count_label.text = "Listed: %d" % active.size()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(count_label)

	var floor_price_usd: float = 0.0
	if active.size() > 0:
		floor_price_usd = _price_to_usd(active[0].price, active[0].payment_type)
		for listing in active:
			var usd: float = _price_to_usd(listing.price, listing.payment_type)
			if usd < floor_price_usd:
				floor_price_usd = usd
	var floor_label := Label.new()
	floor_label.text = "Floor: $%.2f" % floor_price_usd
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(floor_label)

	return card

func _on_buy_card_input(event: InputEvent, res_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_buy_detail(res_name)

# BUY detail
func _open_buy_detail(res_name: String) -> void:
	detail_resource = res_name
	overview_container.visible = false
	buy_detail_container.visible = true
	buy_header_label.text = "Buy %s" % res_name.capitalize()
	buy_filter_dropdown.select(0)
	buy_payment_filter = "SKR"
	buy_skr_filter_toggle.button_pressed = true
	buy_sol_filter_toggle.button_pressed = false
	_refresh_buy_detail()

func _refresh_buy_detail() -> void:
	for child in buy_listings_grid.get_children():
		child.queue_free()

	var active: Array = _get_active_listings_for(detail_resource)

	var filtered: Array = []
	for listing in active:
		if listing.payment_type == buy_payment_filter:
			filtered.append(listing)
	active = filtered

	var descending: bool = buy_filter_dropdown.selected == 1
	active.sort_custom(func(a, b):
		var pa: float = _price_to_usd(a.price, a.payment_type)
		var pb: float = _price_to_usd(b.price, b.payment_type)
		return pa > pb if descending else pa < pb
	)

	for listing in active:
		buy_listings_grid.add_child(_make_buy_listing_card(listing))

func _make_buy_listing_card(listing: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = RESOURCE_ICONS.get(listing.resource, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	var qty_label := Label.new()
	qty_label.text = "Quantity: %d" % int(listing.quantity)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(qty_label)

	var payment_label := Label.new()
	payment_label.text = "Payment Type: %s" % listing.payment_type
	payment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payment_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(payment_label)

	var price_usd: float = _price_to_usd(listing.price, listing.payment_type)
	var total_label := Label.new()
	total_label.text = "Total Value: $%.2f" % (price_usd * listing.quantity)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(total_label)

	var floor_label := Label.new()
	floor_label.text = "Floor: $%.2f" % price_usd
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(floor_label)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.visible = false
	vbox.add_child(status_label)

	var buy_button := Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(0, 56)
	buy_button.add_theme_font_size_override("font_size", 20)
	buy_button.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(buy_button)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.visible = false
	confirm_row.add_theme_constant_override("separation", 12)

	var confirm_button := Button.new()
	confirm_button.text = "Confirm"
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.add_theme_font_size_override("font_size", 20)
	confirm_button.mouse_filter = Control.MOUSE_FILTER_PASS
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0, 56)
	cancel_button.add_theme_font_size_override("font_size", 20)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_PASS

	confirm_row.add_child(confirm_button)
	confirm_row.add_child(cancel_button)
	vbox.add_child(confirm_row)

	buy_button.pressed.connect(func(): confirm_row.visible = true)
	cancel_button.pressed.connect(func(): confirm_row.visible = false)

	if listing.payment_type == "SKR":
		confirm_button.pressed.connect(_on_buy_listing_confirmed.bind(listing, buy_button, confirm_row, status_label))
	else:
		confirm_button.pressed.connect(_on_buy_sol_listing_confirmed.bind(listing, buy_button, confirm_row, status_label))

	return card

# MY LISTING: cards for player own active listings
func _build_my_listing_overview() -> void:
	_clear_overview_grid()
	for listing in listings:
		if listing.is_mine and listing.get("status", "active") == "active":
			overview_grid.add_child(_make_my_listing_card(listing))

func _make_my_listing_card(listing: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = RESOURCE_ICONS.get(listing.resource, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	var qty_label := Label.new()
	qty_label.text = "Quantity: %d" % int(listing.quantity)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(qty_label)

	var price_usd: float = _price_to_usd(listing.price, listing.payment_type)
	var total_label := Label.new()
	total_label.text = "Total Value: $%.2f" % (price_usd * listing.quantity)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(total_label)

	var floor_label := Label.new()
	floor_label.text = "Floor Price: $%.2f" % price_usd
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(floor_label)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0, 56)
	cancel_button.add_theme_font_size_override("font_size", 20)
	cancel_button.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(cancel_button)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.visible = false
	confirm_row.add_theme_constant_override("separation", 12)

	var confirm_button := Button.new()
	confirm_button.text = "Confirm"
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.add_theme_font_size_override("font_size", 20)
	confirm_button.mouse_filter = Control.MOUSE_FILTER_PASS
	var cancel_cancel_button := Button.new()
	cancel_cancel_button.text = "Cancel"
	cancel_cancel_button.custom_minimum_size = Vector2(0, 56)
	cancel_cancel_button.add_theme_font_size_override("font_size", 20)
	cancel_cancel_button.mouse_filter = Control.MOUSE_FILTER_PASS

	confirm_row.add_child(confirm_button)
	confirm_row.add_child(cancel_cancel_button)
	vbox.add_child(confirm_row)

	cancel_button.pressed.connect(func(): confirm_row.visible = true)
	cancel_cancel_button.pressed.connect(func(): confirm_row.visible = false)
	confirm_button.pressed.connect(_on_my_listing_cancel_confirmed.bind(listing.id, listing.resource, listing.quantity))

	return card

# SKR purchase flow
func _on_buy_listing_confirmed(listing: Dictionary, buy_button: Button, confirm_row: HBoxContainer, status_label: Label) -> void:
	confirm_row.visible = false
	buy_button.disabled = true
	status_label.visible = true
	status_label.text = "Preparing..."

	var prepare_result: Dictionary = await ServerState.prepare_sol_purchase(listing.id)
	if not prepare_result.ok:
		var prep_error: String = String(prepare_result.data.get("error", ""))
		status_label.text = ERROR_MESSAGES.get(prep_error, "Could not start purchase - try again.")
		buy_button.disabled = false
		return

	status_label.text = "Approve in your wallet..."
	var sign_result: Dictionary = await WalletManager.sign_and_send_skr_transfer(prepare_result.data, SOLANA_RPC_URL)

	if not sign_result.ok:
		status_label.text = "Payment cancelled or failed - try again."
		buy_button.disabled = false
		return

	var signature: String = String(sign_result.signature)
	await _confirm_sol_purchase_with_retry(listing, signature, buy_button, status_label)

# SOL purchase flow
func _on_buy_sol_listing_confirmed(listing: Dictionary, buy_button: Button, confirm_row: HBoxContainer, status_label: Label) -> void:
	confirm_row.visible = false
	buy_button.disabled = true
	status_label.visible = true
	status_label.text = "Preparing..."

	var prepare_result: Dictionary = await ServerState.prepare_sol_purchase(listing.id)
	if not prepare_result.ok:
		var prep_error: String = String(prepare_result.data.get("error", ""))
		status_label.text = ERROR_MESSAGES.get(prep_error, "Could not start purchase - try again.")
		buy_button.disabled = false
		return

	status_label.text = "Approve in your wallet..."
	var destinations: Array = [
		{"wallet": prepare_result.data.sellerWallet, "lamports": int(prepare_result.data.sellerLamports)},
		{"wallet": prepare_result.data.treasuryWallet, "lamports": int(prepare_result.data.treasuryLamports)},
	]
	var sign_result: Dictionary = await WalletManager.sign_and_send_sol_transfer(destinations, SOLANA_RPC_URL)

	if not sign_result.ok:
		status_label.text = "Payment cancelled or failed - try again."
		buy_button.disabled = false
		return

	var signature: String = String(sign_result.signature)
	await _confirm_sol_purchase_with_retry(listing, signature, buy_button, status_label)

func _confirm_sol_purchase_with_retry(listing: Dictionary, signature: String, buy_button: Button, status_label: Label, is_silent_retry: bool = false) -> void:
	status_label.text = "Confirming..."
	var confirm_result: Dictionary = await ServerState.confirm_sol_purchase(listing.id, signature)

	if confirm_result.ok:
		status_label.text = "Purchased!"
		await _refresh_listings_from_server()
		_refresh_buy_detail()
		return

	var error_code: String = String(confirm_result.data.get("error", ""))

	if not is_silent_retry:
		await get_tree().create_timer(2.0).timeout
		await _confirm_sol_purchase_with_retry(listing, signature, buy_button, status_label, true)
		return

	if error_code == "not_your_reservation":
		status_label.text = "Your payment was sent - refresh to see your updated balance."
		buy_button.disabled = false
		buy_button.text = "Refresh"
		for c in buy_button.pressed.get_connections():
			buy_button.pressed.disconnect(c.callable)
		buy_button.pressed.connect(func():
			buy_button.disabled = true
			_refresh_after_possible_success(listing, buy_button, status_label)
		)
		return

	status_label.text = ERROR_MESSAGES.get(error_code, "Payment sent but confirming failed - tap Buy to retry confirming.")
	buy_button.disabled = false
	buy_button.text = "Retry Confirm"
	for c in buy_button.pressed.get_connections():
		buy_button.pressed.disconnect(c.callable)
	buy_button.pressed.connect(func():
		buy_button.disabled = true
		_confirm_sol_purchase_with_retry(listing, signature, buy_button, status_label)
	)

func _refresh_after_possible_success(_listing: Dictionary, _buy_button: Button, status_label: Label) -> void:
	status_label.text = "Checking..."
	await _refresh_listings_from_server()
	_refresh_buy_detail()

func _on_my_listing_cancel_confirmed(listing_id: int, resource: String, quantity: float) -> void:
	var result: Dictionary = await ServerState.cancel_marketplace_listing(
		listing_id, resource, int(round(quantity))
	)
	if not result.ok:
		push_warning("MarketplacePopup: cancel failed - %s" % str(result.data))
		return
	await _refresh_listings_from_server()
	_build_my_listing_overview()
