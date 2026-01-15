extends Sprite2D

@export var tilemap_path: NodePath
@export var spawn_on_ready := true

@onready var layer: TileMapLayer = get_node(tilemap_path) as TileMapLayer

func _ready() -> void:
	randomize()
	if spawn_on_ready:
		respawn()

func respawn() -> void:
	if layer == null:
		push_error("tilemap_path not set or not a TileMapLayer.")
		return

	# Works even if the TileMapLayer has no tiles/sources configured.
	# Uses the layer's used rect as the spawn space.
	var rect: Rect2i = layer.get_used_rect()
	if rect.size == Vector2i.ZERO:
		push_error("TileMapLayer used rect is empty. Add tiles or set a bigger area by painting at least one tile.")
		return

	var cell := Vector2i(
		randi_range(rect.position.x, rect.position.x + rect.size.x - 1),
		randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
	)

	# Isometric-safe: map_to_local gives layer-local. Convert to global.
	var p_local: Vector2 = layer.map_to_local(cell)

	# Optional: center on tile if tile_size is valid.
	if layer.tile_set != null:
		p_local += Vector2(layer.tile_set.tile_size) * 0.5

	global_position = layer.to_global(p_local)
