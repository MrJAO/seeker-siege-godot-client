extends Node2D

var speed: float = 400.0
var damage: int = 10
var target: Node2D = null
var turret_type: String = "machine_gun"
var turret_level: int = 1
var source_tower_id: int = -1

# AoE system
var splash_radius: float = 0.0
var splash_damage_mult: float = 0.5

# Status effects
var applies_frozen: bool = false
var applies_burning: bool = false
var freeze_duration: float = 2.0
var burn_dps_percent_bonus: float = 0.0
const BURN_DURATION: float = 3.0
const BURN_DPS_PERCENT: float = 0.02

var sprite_prefixes = {
	"machine_gun":     "mg_muzzle",
	"laser_gun":       "laser",
	"flamethrower":    "flame",
	"freeze_ray":      "freeze",
	"plasma_cannon":   "plasma",
	"ion_beam":        "beam",
	"railgun":         "rail",
	"rocket_launcher": "rocket",
	"mortar":          "mortar",
	"tesla_coil":      "tesla"
}

const LEVEL_ANIM_NAMES := ["level_one", "level_two", "level_three", "level_four"]
const GRID_SIZE: int = 4

func _ready():
	var prefix = sprite_prefixes.get(turret_type, "mg_muzzle")
	var sprite_path = "res://assets/turrets_projectiles/%s/%s_level%d.png" % [turret_type, prefix, turret_level]

	var animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"

	# Tower level and tier
	var level_index: int = clamp(turret_level, 1, LEVEL_ANIM_NAMES.size()) - 1
	var anim_name: String = LEVEL_ANIM_NAMES[level_index]

	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		var frame_width: float = texture.get_width() / float(GRID_SIZE)
		var frame_height: float = texture.get_height() / float(GRID_SIZE)

		var frames = SpriteFrames.new()
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 12.0)

		for row in range(GRID_SIZE):
			for col in range(GRID_SIZE):
				var atlas = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
				frames.add_frame(anim_name, atlas)

		animated_sprite.sprite_frames = frames
		animated_sprite.animation = anim_name
		animated_sprite.play(anim_name)
		animated_sprite.scale = Vector2(0.5, 0.5)
	else:
		var frames = SpriteFrames.new()
		frames.add_animation(anim_name)
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 0))
		var tex = ImageTexture.create_from_image(img)
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0, 0, 8, 8)
		frames.add_frame(anim_name, atlas)
		animated_sprite.sprite_frames = frames
		animated_sprite.play(anim_name)

	animated_sprite.rotation = -PI / 2
	add_child(animated_sprite)

func _physics_process(delta):
	if not is_instance_valid(target):
		queue_free()
		return
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()
	if global_position.distance_to(target.global_position) < 10:
		hit()

func hit():
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage, source_tower_id)
		if applies_frozen and target.has_method("apply_frozen"):
			target.apply_frozen(freeze_duration, source_tower_id)
		if applies_burning and target.has_method("apply_burning"):
			var dps: float = target.max_hp * (BURN_DPS_PERCENT + burn_dps_percent_bonus) if "max_hp" in target else 0.0
			target.apply_burning(BURN_DURATION, dps, source_tower_id)
	if splash_radius > 0.0:
		_apply_splash_damage()
	queue_free()

func _apply_splash_damage() -> void:
	var splash_damage: int = int(damage * splash_damage_mult)
	for mob in get_tree().get_nodes_in_group("mob"):
		if mob == target or not is_instance_valid(mob):
			continue
		if mob.has_method("take_damage") and mob.global_position.distance_to(global_position) <= splash_radius:
			mob.take_damage(splash_damage, source_tower_id)
