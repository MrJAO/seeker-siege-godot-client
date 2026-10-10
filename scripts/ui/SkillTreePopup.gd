extends Control

@onready var background: ColorRect = $Background
@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var viewport_clip: Control = $Margin/VBox/ViewportClip
@onready var canvas: Control = $Margin/VBox/ViewportClip/Canvas
@onready var confirm_dialog: PanelContainer = $ConfirmDialog
@onready var confirm_icon: TextureRect = $ConfirmDialog/Margin/VBox/ConfirmIcon
@onready var confirm_title: Label = $ConfirmDialog/Margin/VBox/ConfirmTitle
@onready var confirm_desc: Label = $ConfirmDialog/Margin/VBox/ConfirmDesc
@onready var confirm_level: Label = $ConfirmDialog/Margin/VBox/ConfirmLevel
@onready var confirm_energy: Label = $ConfirmDialog/Margin/VBox/ConfirmEnergy
@onready var confirm_scraps: Label = $ConfirmDialog/Margin/VBox/ConfirmScraps
@onready var confirm_oil: Label = $ConfirmDialog/Margin/VBox/ConfirmOil
@onready var confirm_locked_label: Label = $ConfirmDialog/Margin/VBox/ConfirmLockedLabel
@onready var confirm_status_label: Label = $ConfirmDialog/Margin/VBox/ConfirmStatusLabel
@onready var confirm_button: Button = $ConfirmDialog/Margin/VBox/ButtonRow/ConfirmButton
@onready var cancel_button: Button = $ConfirmDialog/Margin/VBox/ButtonRow/CancelButton

const CENTER := Vector2(1500, 1500)
const HUB_RADIUS: float = 200.0
const SUBHUB_RADIUS: float = 160.0
const NODE_SPACING: float = 110.0
const ZIGZAG_OFFSET: float = 60.0
const NODE_SIZE := Vector2(44, 44)
const ZOOM_MIN: float = 0.4
const ZOOM_MAX: float = 1.3
const ZOOM_STEP: float = 0.1

const COMBAT_CHAIN := ["combat_dmg1", "combat_atkspd1", "combat_crit_chance", "combat_crit_dmg", "combat_dmg2", "combat_atkspd2", "combat_splash", "combat_capstone"]
const ECONOMY_CHAIN := ["econ_drop_rate1", "econ_crypto_drop", "econ_relocate_cd", "econ_switch_cd", "econ_drop_rate2", "econ_skr_efficiency", "econ_passive_prod", "econ_capstone"]
const SURVIVAL_CHAIN := ["surv_max_hp1", "surv_regen_rate1", "surv_regen_delay", "surv_max_hp2", "surv_regen_rate2", "surv_grace_window", "surv_recovery_threshold", "surv_capstone"]
const TOWER_SUB_ANGLES_DEG := [-60.0, -30.0, 0.0, 30.0, 60.0]
const COMBO_DIRECTION := Vector2(0, 1)

var node_positions: Dictionary = {}
var node_buttons: Dictionary = {}
var node_labels: Dictionary = {}

var zoom: float = 1.0
var dragging: bool = false
var pending_confirm_node: String = ""

func _ready() -> void:
	visible = false
	confirm_dialog.visible = false
	close_button.pressed.connect(func(): visible = false)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(func(): confirm_dialog.visible = false)
	viewport_clip.clip_contents = true
	viewport_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport_clip.gui_input.connect(_on_viewport_input)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.custom_minimum_size = Vector2(3000, 3000)
	_compute_positions()
	_build_nodes()
	_build_combo_nodes()
	canvas.draw.connect(_draw_connections)

func open() -> void:
	confirm_dialog.visible = false
	zoom = 1.0
	canvas.scale = Vector2(zoom, zoom)
	call_deferred("_center_on_core")
	_refresh()
	visible = true

func _center_on_core() -> void:
	canvas.position = viewport_clip.size / 2.0 - CENTER * zoom

func _process(_delta: float) -> void:
	if visible:
		_refresh()

func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(-ZOOM_STEP)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		canvas.position += event.relative
		get_viewport().set_input_as_handled()

func _zoom_by(delta: float) -> void:
	zoom = clamp(zoom + delta, ZOOM_MIN, ZOOM_MAX)
	canvas.scale = Vector2(zoom, zoom)

var active_touches: Dictionary = {}
var pinch_start_distance: float = 0.0
var pinch_start_zoom: float = 1.0

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
			if active_touches.size() == 2:
				pinch_start_distance = _touch_distance()
				pinch_start_zoom = zoom
		else:
			active_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		if active_touches.size() == 2 and pinch_start_distance > 0.0:
			var dist: float = _touch_distance()
			var ratio: float = dist / pinch_start_distance
			zoom = clamp(pinch_start_zoom * ratio, ZOOM_MIN, ZOOM_MAX)
			canvas.scale = Vector2(zoom, zoom)

func _touch_distance() -> float:
	var positions: Array = active_touches.values()
	if positions.size() < 2:
		return 0.0
	return positions[0].distance_to(positions[1])

func _compute_positions() -> void:
	node_positions["core_mastery"] = CENTER
	_layout_branch_from(COMBAT_CHAIN, CENTER, Vector2(-1, -1).normalized(), HUB_RADIUS)
	_layout_branch_from(ECONOMY_CHAIN, CENTER, Vector2(1, -1).normalized(), HUB_RADIUS)
	_layout_branch_from(SURVIVAL_CHAIN, CENTER, Vector2(-1, 1).normalized(), HUB_RADIUS)
	_layout_branch_from(TowerManager.COMBO_DEFINITIONS.keys(), CENTER, COMBO_DIRECTION, HUB_RADIUS)

	var tower_dir: Vector2 = Vector2(1, 1).normalized()
	node_positions["tower_hub"] = CENTER + tower_dir * HUB_RADIUS
	var base_angle: float = tower_dir.angle()

	for i in range(SkillTreeManager.TOWER_MASTERY_TYPES.size()):
		var ttype: String = SkillTreeManager.TOWER_MASTERY_TYPES[i]
		var angle: float = base_angle + deg_to_rad(TOWER_SUB_ANGLES_DEG[i])
		var sub_dir: Vector2 = Vector2(cos(angle), sin(angle))
		var chain: Array = []
		for suffix in SkillTreeManager.TOWER_MASTERY_SUFFIXES:
			chain.append("%s_%s" % [ttype, suffix])
		_layout_branch_from(chain, node_positions["tower_hub"], sub_dir, SUBHUB_RADIUS)

func _layout_branch_from(chain: Array, origin: Vector2, direction: Vector2, hub_radius: float) -> void:
	var perpendicular: Vector2 = direction.rotated(PI / 2.0)
	var hub_pos: Vector2 = origin + direction * hub_radius
	node_positions[chain[0]] = hub_pos
	for i in range(1, chain.size()):
		var base: Vector2 = hub_pos + direction * NODE_SPACING * i
		var side: int = 1 if i % 2 == 1 else -1
		node_positions[chain[i]] = base + perpendicular * ZIGZAG_OFFSET * side

func _build_nodes() -> void:
	for node_id in SkillTreeManager.GLOBAL_TREE.keys():
		if not node_positions.has(node_id):
			continue
		var pos: Vector2 = node_positions[node_id]

		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.position = pos - NODE_SIZE / 2.0
		button.text = ""
		var icon_path: String = SkillTreeManager.get_node_icon_path(node_id)
		if ResourceLoader.exists(icon_path):
			button.icon = load(icon_path)
			button.expand_icon = true
		button.pressed.connect(_on_node_pressed.bind(node_id))
		canvas.add_child(button)
		node_buttons[node_id] = button

		var label := Label.new()
		label.position = pos + Vector2(-40, 26)
		label.custom_minimum_size = Vector2(80, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		canvas.add_child(label)
		node_labels[node_id] = label

func _build_combo_nodes() -> void:
	for combo_key in TowerManager.COMBO_DEFINITIONS.keys():
		if not node_positions.has(combo_key):
			continue
		var pos: Vector2 = node_positions[combo_key]

		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.position = pos - NODE_SIZE / 2.0
		button.text = ""
		var combo_icon_path: String = TowerManager.get_combo_icon_path(combo_key)
		if ResourceLoader.exists(combo_icon_path):
			button.icon = load(combo_icon_path)
			button.expand_icon = true
		button.pressed.connect(_on_node_pressed.bind(combo_key))
		canvas.add_child(button)
		node_buttons[combo_key] = button

		var label := Label.new()
		label.position = pos + Vector2(-40, 26)
		label.custom_minimum_size = Vector2(80, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		label.text = TowerManager.COMBO_DEFINITIONS[combo_key].name
		canvas.add_child(label)
		node_labels[combo_key] = label

func _draw_connections() -> void:
	for node_id in SkillTreeManager.GLOBAL_TREE.keys():
		var node: Dictionary = SkillTreeManager.GLOBAL_TREE[node_id]
		if node.prereq == null:
			continue
		if not node_positions.has(node_id) or not node_positions.has(node.prereq):
			continue
		var unlocked: bool = SkillTreeManager.get_node_level(node.prereq) > 0
		var color: Color = Color(0.9, 0.9, 0.9, 0.9) if unlocked else Color(0.35, 0.35, 0.35, 0.7)
		canvas.draw_line(node_positions[node.prereq], node_positions[node_id], color, 3.0)

func _on_node_pressed(node_id: String) -> void:
	pending_confirm_node = node_id
	if TowerManager.COMBO_DEFINITIONS.has(node_id):
		_open_combo_dialog(node_id)
	else:
		_open_confirm_dialog(node_id)

func _open_confirm_dialog(node_id: String) -> void:
	confirm_energy.visible = true
	confirm_scraps.visible = true
	confirm_oil.visible = true
	confirm_button.visible = true
	confirm_status_label.visible = false
	cancel_button.text = "Cancel"

	var node: Dictionary = SkillTreeManager.GLOBAL_TREE[node_id]
	var level: int = SkillTreeManager.get_node_level(node_id)
	var hard_locked: bool = node.prereq != null and SkillTreeManager.get_node_level(node.prereq) < 1

	var icon_path: String = SkillTreeManager.get_node_icon_path(node_id)
	confirm_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null

	confirm_title.text = SkillTreeManager.get_node_label(node_id)
	confirm_desc.text = "Description: %s" % SkillTreeManager.get_node_description(node_id)
	confirm_level.text = "%d/%d" % [level, node.max_level]

	confirm_locked_label.visible = hard_locked
	if hard_locked:
		confirm_locked_label.text = "Requires: %s first" % SkillTreeManager.get_node_label(node.prereq)

	var cost: Dictionary = SkillTreeManager.get_node_cost(node_id)
	confirm_energy.text = "Energy: %d / %d" % [int(ResourceManager.get_balance("energy")), int(cost.energy)]
	confirm_scraps.text = "Scraps: %d / %d" % [int(ResourceManager.get_balance("scraps")), int(cost.scraps)]
	confirm_oil.text = "Oil: %d / %d" % [int(ResourceManager.get_balance("oil")), int(cost.oil)]

	confirm_button.disabled = not SkillTreeManager.can_purchase_node(node_id)
	confirm_dialog.visible = true

func _open_combo_dialog(combo_key: String) -> void:
	var combo: Dictionary = TowerManager.COMBO_DEFINITIONS[combo_key]

	var combo_icon_path: String = TowerManager.get_combo_icon_path(combo_key)
	confirm_icon.texture = load(combo_icon_path) if ResourceLoader.exists(combo_icon_path) else null
	confirm_title.text = combo.name
	confirm_desc.text = "Description: %s" % combo.description
	confirm_level.text = ""
	confirm_locked_label.visible = false

	confirm_energy.visible = false
	confirm_scraps.visible = false
	confirm_oil.visible = false
	confirm_button.visible = false
	cancel_button.text = "Close"

	confirm_status_label.visible = true
	var active: bool = TowerManager.is_combo_active_anywhere(combo_key)
	confirm_status_label.text = "Status: Active" if active else "Status: Inactive - place the required towers in range of each other"

	confirm_dialog.visible = true

func _on_confirm_pressed() -> void:
	confirm_button.disabled = true
	await ServerState.purchase_skill_node(pending_confirm_node)
	confirm_button.disabled = false
	confirm_dialog.visible = false
	_refresh()

func _refresh() -> void:
	canvas.queue_redraw()
	if confirm_dialog.visible and pending_confirm_node != "":
		if TowerManager.COMBO_DEFINITIONS.has(pending_confirm_node):
			_open_combo_dialog(pending_confirm_node)
		else:
			_open_confirm_dialog(pending_confirm_node)

	for node_id in SkillTreeManager.GLOBAL_TREE.keys():
		if not node_buttons.has(node_id):
			continue
		var node: Dictionary = SkillTreeManager.GLOBAL_TREE[node_id]
		var level: int = SkillTreeManager.get_node_level(node_id)
		var maxed: bool = level >= node.max_level
		var unlockable: bool = SkillTreeManager.is_node_unlockable(node_id)
		var affordable: bool = SkillTreeManager.can_purchase_node(node_id)

		var button: Button = node_buttons[node_id]
		var label: Label = node_labels[node_id]

		label.text = "%d/%d" % [level, node.max_level]

		if maxed:
			button.modulate = Color(0.9, 0.8, 0.2)
		elif affordable:
			button.modulate = Color(0.3, 0.85, 0.3)
		elif unlockable:
			button.modulate = Color(0.8, 0.6, 0.2)
		else:
			button.modulate = Color(0.35, 0.35, 0.35)

	for combo_key in TowerManager.COMBO_DEFINITIONS.keys():
		if not node_buttons.has(combo_key):
			continue
		var button: Button = node_buttons[combo_key]
		var active: bool = TowerManager.is_combo_active_anywhere(combo_key)
		button.modulate = Color(0.3, 0.85, 0.3) if active else Color(0.35, 0.35, 0.35)
