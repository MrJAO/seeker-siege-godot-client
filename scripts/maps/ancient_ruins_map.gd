extends TileMap

func _ready():
	print("Ancient Ruins map loaded (Isometric tiles)")
	print("Map tile size: ", tile_set.tile_size)
	print("Map layers: ", get_layers_count())
