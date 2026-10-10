extends Node

signal session_started
signal session_ended

var current_region: int = 1
var current_map: int = 1
var has_placed_tower: bool = false
var map_session_active: bool = false

# Temporary for frame stall diagnostic
const _STALL_THRESHOLD_SECONDS := 0.1
var _last_frame_usec: int = 0

func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	if _last_frame_usec != 0:
		var frame_seconds: float = (now_usec - _last_frame_usec) / 1000000.0
		if frame_seconds >= _STALL_THRESHOLD_SECONDS:
			print("[DEBUG stall] frame took ", frame_seconds, "s")
	_last_frame_usec = now_usec

func register_tower_placed() -> void:
	has_placed_tower = true

func check_can_start() -> bool:
	return has_placed_tower

func start_game() -> void:
	if not check_can_start():
		return
	map_session_active = true
	ReactorManager.begin_passive_production()
	emit_signal("session_started")

func pause_map() -> void:
	map_session_active = false
	emit_signal("session_ended")

func reset_for_new_map() -> void:
	has_placed_tower = TowerManager.has_any_placed_tower()
	map_session_active = false
	emit_signal("session_ended")
