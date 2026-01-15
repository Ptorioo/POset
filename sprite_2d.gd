extends Sprite2D

@export var tilemap_path: NodePath
@export var spawn_on_ready: bool = true
@export var element_scene: PackedScene
@export var cell_spacing_x: int = 2
@export var cell_spacing_y: int = 2
@export var element_scale: Vector2 = Vector2(0.5, 0.5)

@onready var layer: TileMapLayer = get_node(tilemap_path) as TileMapLayer

const SPAWN_GROUP := "poset_spawned"

func _ready() -> void:
	if spawn_on_ready:
		respawn()

func respawn() -> void:
	if layer == null:
		push_error("TileMapLayer not set.")
		return

	var rect: Rect2i = layer.get_used_rect()
	if rect.size == Vector2i.ZERO:
		push_error("TileMapLayer empty.")
		return

	_clear_spawned()

	# -------- build 4-element diamond poset --------
	var n: int = 4

	# If PosetIsomorphism uses Array/Dictionary internally, make the type explicit.
	# Pick ONE of these two, matching your PosetIsomorphism implementation.
	var P: Array = PosetIsomorphism.create(n)
	# var P: Dictionary = PosetIsomorphism.create(n)

	PosetIsomorphism.try_add_covering(n, P, 1, 0)
	PosetIsomorphism.try_add_covering(n, P, 2, 0)
	PosetIsomorphism.try_add_covering(n, P, 3, 1)
	PosetIsomorphism.try_add_covering(n, P, 3, 2)

	var ranks: Array = PosetIsomorphism.get_ranks(n, P)

	# Avoid inference issues with .max()
	var max_rank: int = 0
	for r: int in ranks:
		if r > max_rank:
			max_rank = r

	# choose base cell
	var base: Vector2i = rect.position + Vector2i(2, 2)

	for i: int in range(n):
		var s: Sprite2D = _spawn_sprite()

		var cell: Vector2i = Vector2i(
			base.x + i * cell_spacing_x,
			base.y + ranks[i] * cell_spacing_y
		)

		var p: Vector2 = layer.map_to_local(cell)
		if layer.tile_set:
			p += Vector2(layer.tile_set.tile_size) * 0.5

		s.call_deferred("set_global_position", layer.to_global(p))

func _spawn_sprite() -> Sprite2D:
	var s: Sprite2D
	if element_scene:
		s = element_scene.instantiate() as Sprite2D
	else:
		s = Sprite2D.new()
		s.texture = texture

	s.scale = element_scale

	get_parent().call_deferred("add_child", s)
	s.call_deferred("add_to_group", SPAWN_GROUP)
	return s

func _clear_spawned() -> void:
	for c: Node in get_parent().get_children():
		if c.is_in_group(SPAWN_GROUP):
			c.queue_free()
