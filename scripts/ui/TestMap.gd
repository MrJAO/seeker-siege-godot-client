extends Node2D

const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 6

@onready var turrets_container: Node2D = $TurretsContainer
@onready var build_popup = $UILayer/BuildCancelPopup
@onready var tower_select_popup = $UILayer/TowerSelectPopup

func _ready() -> void:
	BuildManager.register_container(turrets_container)
	build_popup.open_tower_select.connect(func(): tower_select_popup.open())
	_draw_tiles()

func _draw_tiles() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var tile := ColorRect.new()
			tile.size = Vector2(GridManager.TILE_SIZE - 2, GridManager.TILE_SIZE - 2)
			tile.position = Vector2(x * GridManager.TILE_SIZE, y * GridManager.TILE_SIZE)
			tile.color = Color(0.2, 0.25, 0.2)
			tile.gui_input.connect(_on_tile_input.bind(Vector2i(x, y)))
			tile.mouse_filter = Control.MOUSE_FILTER_STOP
			$TileLayer.add_child(tile)

func _on_tile_input(event: InputEvent, grid_pos: Vector2i) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos: Vector2 = GridManager.grid_to_world(grid_pos)
		BuildManager.select_tile(grid_pos, world_pos)
