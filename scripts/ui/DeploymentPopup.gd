extends PanelContainer

@onready var close_button: Button = $Margin/VBox/TopRow/CloseButton
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid

const INFANTRY_SPRITE_PATH := "res://assets/deployment/Soldier2_right.png"
const ICON_PATHS := {
	"energy": "res://assets/icons/energy_icon.png",
	"scraps": "res://assets/icons/scraps_icon.png",
	"oil": "res://assets/icons/oil_icon.png",
}

const FLAG_ICON_PATH := "res://assets/icons/flag_icon.png"

# Base stats per unit
const SOLDIER_STATS := {
	"Infantry": {"hp": 80, "damage": 10, "atk_speed": 1.2, "defense": 5, "move_speed": 70, "role": ""},
	"Heavy Infantry": {"hp": 150, "damage": 14, "atk_speed": 0.8, "defense": 15, "move_speed": 45, "role": ""},
	"Sniper": {"hp": 60, "damage": 25, "atk_speed": 0.5, "defense": 2, "move_speed": 55, "role": ""},
	"Commander": {"hp": 100, "damage": 8, "atk_speed": 1.0, "defense": 8, "move_speed": 60, "role": "Buffs allies in 150 radius: +10% Dmg, +10% Atk Spd"},
	"Medic": {"hp": 70, "damage": 4, "atk_speed": 1.0, "defense": 3, "move_speed": 65, "role": "Heals 8 HP/tick to allies in 100 radius"},
	"Tanks": {"hp": 300, "damage": 20, "atk_speed": 0.6, "defense": 25, "move_speed": 30, "role": ""},
	"Engineer": {"hp": 120, "damage": null, "atk_speed": null, "defense": 12, "move_speed": 40, "role": "Repairs 15/tick to vehicles in 80 radius"},
	"Builder": {"hp": 100, "damage": null, "atk_speed": null, "defense": 10, "move_speed": 35, "role": "Build Speed x1.0 (baseline)"},
	"Collector": {"hp": 90, "damage": null, "atk_speed": null, "defense": 5, "move_speed": 50, "role": "Collects 5/sec, 100 cargo capacity"},
}

# Soldier Roster
const SOLDIER_ROSTER := [
	{"name": "Infantry", "available": true},
	{"name": "Tanks", "available": false},
	{"name": "Engineer", "available": false},
	{"name": "Heavy Infantry", "available": false},
	{"name": "Sniper", "available": false},
	{"name": "Commander", "available": false},
	{"name": "Medic", "available": false},
	{"name": "Builder", "available": false},
	{"name": "Collector", "available": false},
]

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	_build_cards()

func open() -> void:
	visible = true

func _build_cards() -> void:
	for entry in SOLDIER_ROSTER:
		grid.add_child(_make_soldier_card(entry))

func _format_stats(unit_name: String) -> String:
	var s: Dictionary = SOLDIER_STATS.get(unit_name, {})
	if s.is_empty():
		return ""
	var dmg_str: String = "N/A" if s.damage == null else str(s.damage)
	var atk_str: String = "N/A" if s.atk_speed == null else str(s.atk_speed)
	var text: String = "HP: %d | DMG: %s | ATK Spd: %s\nDEF: %d | Move Spd: %d" % [s.hp, dmg_str, atk_str, s.defense, s.move_speed]
	if s.role != "":
		text += "\n%s" % s.role
	return text

func _make_soldier_card(entry: Dictionary) -> Control:
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

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	var image_holder := Control.new()
	image_holder.custom_minimum_size = Vector2(0, 190)
	vbox.add_child(image_holder)

	if entry.available:
		var sprite := _build_looping_sprite(INFANTRY_SPRITE_PATH)
		sprite.scale = Vector2(1.8, 1.8)
		image_holder.add_child(sprite)
		var recenter := func():
			sprite.position = image_holder.size / 2.0
		image_holder.resized.connect(recenter)
		recenter.call()
	else:
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.4, 0.4, 0.4, 1)
		image_holder.add_child(placeholder)
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var conf_label := Label.new()
		conf_label.text = "Confidential"
		conf_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
		conf_label.add_theme_font_size_override("font_size", 20)
		conf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		conf_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		image_holder.add_child(conf_label)
		conf_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stats_label := Label.new()
	stats_label.text = _format_stats(entry.name)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(stats_label)

	# Cost row: (icon) NA | (icon) NA | (icon) NA
	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 8)
	var resource_order := ["energy", "scraps", "oil"]
	for i in range(resource_order.size()):
		var res_name: String = resource_order[i]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = ICON_PATHS.get(res_name, "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		cost_row.add_child(icon)

		var val_label := Label.new()
		val_label.text = "NA"
		val_label.add_theme_font_size_override("font_size", 19)
		cost_row.add_child(val_label)

		if i < resource_order.size() - 1:
			var sep := Label.new()
			sep.text = "|"
			sep.add_theme_font_size_override("font_size", 19)
			cost_row.add_child(sep)
	vbox.add_child(cost_row)

	# Recruit Time
	var recruit_time_label := Label.new()
	recruit_time_label.text = "Recruit Time: 15 seconds" if entry.available else "Recruit Time: NA"
	recruit_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recruit_time_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(recruit_time_label)

	# Recruit Button (disabled for now)
	var recruit_button := Button.new()
	recruit_button.text = "Recruit"
	recruit_button.custom_minimum_size = Vector2(0, 56)
	recruit_button.add_theme_font_size_override("font_size", 20)
	recruit_button.disabled = true
	recruit_button.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(recruit_button)

	# Move Button (disabled for now)
	var move_button := Button.new()
	move_button.text = "Move"
	move_button.custom_minimum_size = Vector2(0, 56)
	move_button.add_theme_font_size_override("font_size", 20)
	move_button.disabled = true
	move_button.mouse_filter = Control.MOUSE_FILTER_PASS
	if ResourceLoader.exists(FLAG_ICON_PATH):
		move_button.icon = load(FLAG_ICON_PATH)
	vbox.add_child(move_button)

	return card

# Single animation 4x4/16 frame sheet
var _sprite_frames_cache: Dictionary = {}

func _build_looping_sprite(texture_path: String) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	if not ResourceLoader.exists(texture_path):
		push_warning("DeploymentPopup: missing sprite at %s" % texture_path)
		return sprite

	if not _sprite_frames_cache.has(texture_path):
		var texture: Texture2D = load(texture_path)
		var frame_w: float = texture.get_width() / 4.0
		var frame_h: float = texture.get_height() / 4.0

		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 8.0)

		for row in range(4):
			for col in range(4):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
				frames.add_frame("idle", atlas)

		_sprite_frames_cache[texture_path] = frames

	sprite.sprite_frames = _sprite_frames_cache[texture_path]
	sprite.play("idle")
	return sprite
