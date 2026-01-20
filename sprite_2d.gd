extends Sprite2D

@export var tilemap_path: NodePath
@export var spawn_on_ready: bool = true
@export var element_scene: PackedScene
@export var cell_spacing_x: int = 2
@export var cell_spacing_y: int = 2
@export var element_scale: Vector2 = Vector2(0.5, 0.5)

@onready var layer: TileMapLayer = get_node(tilemap_path) as TileMapLayer

const SPAWN_GROUP := "poset_spawned"
const POSET_ROOT_NAME := "PosetRoot"

const DRAG_START_PX := 8.0

var _pressing := false
var _press_pos := Vector2.ZERO
var _press_root_pos := Vector2.ZERO

var snap_anchor: Sprite2D = null

var poset_root: Node2D
var dragging := false
var drag_offset := Vector2.ZERO
var _pending_respawn := false

func _ready() -> void:
	if layer == null or layer.tile_set == null:
		push_error("No layer/tile_set.")
		return

	_pending_respawn = spawn_on_ready
	_ensure_poset_root() # will respawn when ready

func _ensure_poset_root() -> void:
	poset_root = _get_poset_root()
	if poset_root != null:
		if _pending_respawn:
			_pending_respawn = false
			respawn()
		return

	# Parent is busy: defer creating the root.
	var root := Node2D.new()
	root.name = POSET_ROOT_NAME
	get_parent().call_deferred("add_child", root)
	call_deferred("_finish_poset_root_setup")

func _finish_poset_root_setup() -> void:
	poset_root = _get_poset_root()
	if poset_root == null:
		# If the node is still not there, try again next frame.
		call_deferred("_finish_poset_root_setup")
		return

	if _pending_respawn:
		_pending_respawn = false
		respawn()

func _get_poset_root() -> Node2D:
	var parent_node := get_parent()
	if parent_node == null:
		return null
	var existing := parent_node.get_node_or_null(POSET_ROOT_NAME)
	if existing and existing is Node2D:
		return existing as Node2D
	return null

func _unhandled_input(event: InputEvent) -> void:
	if poset_root == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# only arm dragging if click starts on the poset
			if _hit_test_poset(event.position):
				_pressing = true
				dragging = false
				_press_pos = event.position
				_press_root_pos = poset_root.global_position
				get_viewport().set_input_as_handled()
		else:
			# release
			if dragging:
				dragging = false
				_pressing = false
				_snap_poset_to_grid()
				get_viewport().set_input_as_handled()
			elif _pressing:
				# was just a click, no move
				_pressing = false
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _pressing:
		var delta: Vector2 = (event.position as Vector2) - _press_pos

		# do not move until threshold is exceeded
		if not dragging and delta.length() >= DRAG_START_PX:
			dragging = true

		if dragging:
			poset_root.global_position = _press_root_pos + delta
			get_viewport().set_input_as_handled()


func respawn() -> void:
	if poset_root == null:
		_pending_respawn = true
		_ensure_poset_root()
		return

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

	var P: Array = PosetIsomorphism.create(n)
	# var P: Dictionary = PosetIsomorphism.create(n)

	PosetIsomorphism.try_add_covering(n, P, 1, 0)
	PosetIsomorphism.try_add_covering(n, P, 2, 0)
	PosetIsomorphism.try_add_covering(n, P, 3, 1)
	PosetIsomorphism.try_add_covering(n, P, 3, 2)

	var ranks: Array = PosetIsomorphism.get_ranks(n, P)

	var max_rank: int = 0
	for rv in ranks:
		var r := int(rv)
		if r > max_rank:
			max_rank = r

	var base: Vector2i = rect.position + Vector2i(6, 4)

	var per_rank: Array = []
	per_rank.resize(max_rank + 1)
	for k in range(max_rank + 1):
		per_rank[k] = []

	for i: int in range(n):
		per_rank[ranks[i]].append(i)

	for r: int in range(max_rank + 1):
		var nodes: Array = per_rank[r]
		var m: int = nodes.size()
		if m == 0:
			continue

		for j: int in range(m):
			var x_off: float = (float(j) - (float(m - 1) / 2.0)) * float(cell_spacing_x)
			var cell: Vector2i = Vector2i(
				base.x + int(round(x_off)),
				base.y + r * cell_spacing_y
			)

			var s: Sprite2D = _spawn_sprite()

			var p: Vector2 = layer.map_to_local(cell) # already centered :contentReference[oaicite:2]{index=2}
			s.call_deferred("set_global_position", layer.to_global(p))


func _spawn_sprite() -> Sprite2D:
	var s: Sprite2D
	if element_scene:
		s = element_scene.instantiate() as Sprite2D
	else:
		s = Sprite2D.new()
		s.texture = texture

	s.scale = element_scale

	poset_root.call_deferred("add_child", s)
	s.call_deferred("add_to_group", SPAWN_GROUP)
	
	if snap_anchor == null:
		snap_anchor = s
	return s

func _clear_spawned() -> void:
	if poset_root == null:
		return
	for c: Node in poset_root.get_children():
		if c.is_in_group(SPAWN_GROUP):
			c.queue_free()
	snap_anchor = null


func _hit_test_poset(global_point: Vector2) -> bool:
	if poset_root == null:
		return false

	for c: Node in poset_root.get_children():
		if not (c is Sprite2D):
			continue
		var s := c as Sprite2D
		if not s.is_in_group(SPAWN_GROUP):
			continue
		if _hit_test_sprite(s, global_point):
			return true

	return false

func _hit_test_sprite(s: Sprite2D, global_point: Vector2) -> bool:
	var tex := s.texture
	if tex == null:
		return false

	var lp: Vector2 = s.to_local(global_point)
	var size: Vector2 = tex.get_size()

	var rect: Rect2
	if s.centered:
		rect = Rect2(-size * 0.5, size)
	else:
		rect = Rect2(Vector2.ZERO, size)

	return rect.has_point(lp)
	
func _cell_center_global_for_point(global_point: Vector2) -> Vector2:
	var local_point: Vector2 = layer.to_local(global_point)
	var cell: Vector2i = layer.local_to_map(local_point)

	var snapped_local: Vector2 = layer.map_to_local(cell)

	var td := layer.get_cell_tile_data(cell)
	if td != null:
		snapped_local += Vector2(td.texture_origin)

	return layer.to_global(snapped_local)

func _snap_poset_to_grid() -> void:
	if poset_root == null or layer == null or snap_anchor == null:
		return

	var anchor_global: Vector2 = snap_anchor.global_position
	var snapped_anchor_global: Vector2 = _cell_center_global_for_point(anchor_global)

	poset_root.global_position += (snapped_anchor_global - anchor_global)
