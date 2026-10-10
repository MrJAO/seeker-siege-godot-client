extends Node

const SETTINGS_PATH: String = "user://ui_scale_settings.json"

const DEFAULTS := {
	"game_menu": 2.0,
	"resources": 2.0,
	"top_center": 2.0,
	"top_left": 1.5,
	"inventory": 1.0,
	"shop": 1.0,
	"marketplace": 1.0,
	"profile": 1.0,
	"settings": 1.0,
	"armory": 1.0,
	"deployment": 1.0,
	"mining_shaft": 1.0,
	"portal": 1.0,
}

signal scale_changed(section: String, factor: float)

var scales: Dictionary = {}

func _ready() -> void:
	_load()

func get_scale(section: String) -> float:
	return scales.get(section, DEFAULTS.get(section, 1.0))

func set_scale(section: String, factor: float) -> void:
	if scales.get(section, null) == factor:
		return
	scales[section] = factor
	_save()
	scale_changed.emit(section, factor)

func _load() -> void:
	scales = DEFAULTS.duplicate()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in parsed.keys():
			scales[key] = float(parsed[key])

func _save() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scales))
		file.close()
