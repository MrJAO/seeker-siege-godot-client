extends Control

const ROLE_ORDER := ["primary", "secondary", "tertiary"]
const RESOURCE_LIST := ["energy", "scraps", "oil"]

@onready var energy_box: PanelContainer = $PopupPanel/Margin/VBox/ResourceRow/EnergyBox
@onready var scraps_box: PanelContainer = $PopupPanel/Margin/VBox/ResourceRow/ScrapsBox
@onready var oil_box: PanelContainer = $PopupPanel/Margin/VBox/ResourceRow/OilBox
@onready var confirm_button: Button = $PopupPanel/Margin/VBox/ButtonRow/ConfirmButton
@onready var reset_button: Button = $PopupPanel/Margin/VBox/ButtonRow/ResetButton

var resource_boxes: Dictionary = {}
var selection_order: Array = []

var normal_style: StyleBox = null
var selected_style: StyleBoxFlat = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	resource_boxes = {
		"energy": energy_box,
		"scraps": scraps_box,
		"oil": oil_box,
	}

	normal_style = energy_box.get_theme_stylebox("panel")
	selected_style = StyleBoxFlat.new()
	if normal_style is StyleBoxFlat:
		selected_style = (normal_style as StyleBoxFlat).duplicate()
	selected_style.bg_color = Color(0.66, 0.94, 0.84, 1)

	for res_name in resource_boxes.keys():
		var box: PanelContainer = resource_boxes[res_name]
		box.gui_input.connect(_on_box_gui_input.bind(res_name))

	confirm_button.pressed.connect(_on_confirm_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	confirm_button.disabled = true

func open() -> void:
	_reset_selection()
	visible = true

func _on_box_gui_input(event: InputEvent, res_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_resource(res_name)

func _select_resource(res_name: String) -> void:
	if res_name in selection_order:
		return
	if selection_order.size() >= ROLE_ORDER.size():
		return
	selection_order.append(res_name)
	_refresh_boxes()
	confirm_button.disabled = selection_order.size() < ROLE_ORDER.size()

func _refresh_boxes() -> void:
	for res_name in resource_boxes.keys():
		var box: PanelContainer = resource_boxes[res_name]
		var role_label: Label = box.get_node("VBox/RoleLabel")
		var info_label: Label = box.get_node("VBox/InfoLabel")
		var idx: int = selection_order.find(res_name)
		if idx == -1:
			role_label.text = ""
			info_label.text = ""
			box.add_theme_stylebox_override("panel", normal_style)
		else:
			var role: String = ROLE_ORDER[idx]
			var chance_percent: float = ResourceManager.get_drop_chance_percent(role)
			role_label.text = "%s: %.0f%%" % [role.capitalize(), chance_percent]
			info_label.text = "%.0f%% drop chance on mob kill" % chance_percent
			box.add_theme_stylebox_override("panel", selected_style)

func _on_reset_pressed() -> void:
	_reset_selection()

func _reset_selection() -> void:
	selection_order.clear()
	_refresh_boxes()
	confirm_button.disabled = true

func _on_confirm_pressed() -> void:
	if selection_order.size() < ROLE_ORDER.size():
		return

	confirm_button.disabled = true
	reset_button.disabled = true

	var primary: String = selection_order[0]
	var secondary: String = selection_order[1]
	var tertiary: String = selection_order[2]

	var result: Dictionary = await ServerState.assign_resource_roles_server(primary, secondary, tertiary)

	if not result.ok:
		confirm_button.disabled = false
		reset_button.disabled = false
		return

	ResourceManager.assign_resource_roles(primary, secondary, tertiary)
	SaveManager.save_game()
	visible = false
