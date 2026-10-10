extends PanelContainer

@onready var title_label: Label = $Margin/VBox/TopRow/TitleLabel
@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var sp_label: Label = $Margin/VBox/SpLabel
@onready var list_container: VBoxContainer = $Margin/VBox/List

var tower_id: int = -1

const NODE_ORDER := ["minor_dmg", "minor_atkspd", "medium_bonus", "strong_bonus", "capstone"]
const NODE_LABELS := {
	"minor_dmg": "Minor + Damage",
	"minor_atkspd": "Minor + Attack Speed",
	"medium_bonus": "Medium Bonus (type-specific, TBD)",
	"strong_bonus": "Strong Bonus (type-specific, TBD)",
	"capstone": "Capstone Ability (TBD)",
}

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	_build_list()

func open(id: int) -> void:
	tower_id = id
	_refresh()
	visible = true

func _process(_delta: float) -> void:
	if visible:
		_refresh()

func _build_list() -> void:
	for node_id in NODE_ORDER:
		var row := HBoxContainer.new()
		row.name = "Row_%s" % node_id
		row.add_theme_constant_override("separation", 14)
		var label := Label.new()
		label.name = "Label_%s" % node_id
		label.custom_minimum_size = Vector2(0, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		var button := Button.new()
		button.name = "Button_%s" % node_id
		button.text = "+"
		button.custom_minimum_size = Vector2(56, 56)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_on_node_pressed.bind(node_id))
		row.add_child(label)
		row.add_child(button)
		list_container.add_child(row)

func _on_node_pressed(node_id: String) -> void:
	await ServerState.purchase_hidden_skill(tower_id, node_id)
	_refresh()

func _refresh() -> void:
	if tower_id < 0 or not TowerManager.owned_towers.has(tower_id):
		return
	var t: Dictionary = TowerManager.owned_towers[tower_id]
	title_label.text = "Hidden Skills - T%d %s" % [t.tier, t.type.capitalize().replace("_", " ")]
	sp_label.text = "Skill Points: %d" % SkillTreeManager.global_skill_points

	for node_id in NODE_ORDER:
		var label: Label = list_container.find_child("Label_%s" % node_id, true, false)
		var button: Button = list_container.find_child("Button_%s" % node_id, true, false)
		var node: Dictionary = TowerManager.HIDDEN_TREE[node_id]
		var level: int = TowerManager.get_hidden_node_level(tower_id, node_id)
		if label:
			var cost: Dictionary = TowerManager.hidden_node_cost(node_id)
			label.text = "%s (%d/%d)\nSP: %d | Energy: %d Scraps: %d Oil: %d" % [NODE_LABELS[node_id], level, node.max_level, node.sp_cost, int(cost.energy), int(cost.scraps), int(cost.oil)]
		if button:
			button.disabled = not TowerManager.can_purchase_hidden_node(tower_id, node_id)
