extends Control

@onready var loading_label: Label = $LoadingLabel
@onready var progress_bar: ProgressBar = $ProgressBar

const BG_LANDSCAPE := preload("res://assets/decoratives/bg_images/login_bg_landscape.png")
const BG_PORTRAIT := preload("res://assets/decoratives/bg_images/login_bg_portrait.png")

const CYAN := Color(0.0, 0.85, 1.0, 1.0)
const CYAN_BRIGHT := Color(0.4, 0.95, 1.0, 1.0)

var background: TextureRect = null
var connect_button: Button = null
var _connecting: bool = false
var _glow_tween: Tween = null

func _ready() -> void:
	NetworkManager.login_success.connect(_on_login_success)
	NetworkManager.login_failed.connect(_on_login_failed)

	_setup_background()
	_style_progress_bar()
	_start_glow_pulse()

	if OS.get_name() == "Android":
		_setup_button()
		_show_idle_state()
	else:
		_show_loading_state()
		_set_progress(0.0, 0.0)
		NetworkManager.debug_login()

func _setup_background() -> void:
	var existing_bg: ColorRect = get_node_or_null("Background")
	if existing_bg:
		existing_bg.visible = false

	background = TextureRect.new()
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	background.texture = BG_LANDSCAPE

func _style_progress_bar() -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.08, 0.1, 0.6)
	bg_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = CYAN
	fill_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	progress_bar.custom_minimum_size = Vector2(0, 20)

func _start_glow_pulse() -> void:
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.tween_property(progress_bar, "modulate", CYAN_BRIGHT, 0.9).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)

func _set_progress(target: float, duration: float = 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(progress_bar, "value", target, duration).set_trans(Tween.TRANS_SINE)

func _setup_button() -> void:
	connect_button = Button.new()
	connect_button.text = "CONNECT WALLET"
	connect_button.size = Vector2(500, 110)
	connect_button.mouse_filter = Control.MOUSE_FILTER_STOP
	connect_button.z_index = 100
	connect_button.pressed.connect(_on_connect_pressed)
	add_child(connect_button)
	_position_button_landscape()

func _position_button_landscape() -> void:
	var vp: Vector2 = get_viewport_rect().size
	connect_button.position = Vector2(
		(vp.x - connect_button.size.x) / 2.0,
		vp.y * 0.82 - connect_button.size.y / 2.0
	)

# Idle State: landscape art
func _show_idle_state() -> void:
	background.texture = BG_LANDSCAPE
	_position_button_landscape()
	connect_button.visible = true
	connect_button.disabled = false
	loading_label.visible = false
	progress_bar.visible = false

# Connecting State: portrait art
func _show_connecting_state() -> void:
	background.texture = BG_PORTRAIT
	if connect_button:
		connect_button.visible = false
	loading_label.visible = true
	loading_label.text = "Connecting wallet..."
	progress_bar.visible = false

# Loading State: landscape art restored
func _show_loading_state() -> void:
	background.texture = BG_LANDSCAPE
	if connect_button:
		connect_button.visible = false
	loading_label.visible = true
	progress_bar.visible = true

func _on_connect_pressed() -> void:
	if _connecting:
		return
	_connecting = true
	_show_connecting_state()

	await NetworkManager.wallet_login()

	_connecting = false
	if not WalletManager.wallet_is_connected:
		_show_idle_state()

func _on_login_success(_player_id: int) -> void:
	_show_loading_state()
	loading_label.text = "Loading..."
	_set_progress(15.0, 0.3)

	var ok: bool = await ServerState.load_state()
	_set_progress(60.0, 0.3)

	if ok:
		ServerState.apply_to_managers()
		_set_progress(90.0, 0.3)
		await get_tree().create_timer(0.15).timeout
		_set_progress(100.0, 0.2)
		await get_tree().create_timer(0.25).timeout
		_go_to_saved_map()
	else:
		loading_label.text = "Failed to load save data. Please restart."

func _on_login_failed(status: int, data: Variant) -> void:
	if OS.get_name() == "Android":
		_show_idle_state()
		loading_label.visible = true
		loading_label.text = "Connection cancelled. Tap to try again."
		await get_tree().create_timer(1.5).timeout
		if connect_button and connect_button.visible:
			loading_label.visible = false
	else:
		loading_label.text = "Login failed (%d). Tap to try again." % status
	print("[LoadingScreen] login failed: ", status, " ", data)

func _go_to_saved_map() -> void:
	var region: int = GameManager.current_region
	var map: int = GameManager.current_map
	var scene_path: String = "res://scenes/maps/region%d/Region%dMap%d.tscn" % [region, region, map]
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("LoadingScreen: no scene at %s" % scene_path)
		loading_label.text = "Map not found: Region %d Map %d" % [region, map]
