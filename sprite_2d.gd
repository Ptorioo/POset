extends Sprite2D

@export var tilemap_path: NodePath
@export var spawn_on_ready: bool = true
@export var element_scene: PackedScene
@export var cell_spacing_x: int = 1
@export var cell_spacing_y: int = 1
@export var element_scale: Vector2 = Vector2(0.5, 0.5)

@onready var layer: TileMapLayer = get_node(tilemap_path) as TileMapLayer

const SPAWN_GROUP := "poset_spawned"
const EDGE_GROUP := "poset_edges"
const POSET_ROOT_NAME := "PosetRoot"

var poset_root: Node2D
var _pending_respawn := false

# poset data
var _nodes: Array = []                  # id -> Sprite2D
var _parents_of: Array = []             # id -> Array[int] parents
var _covers: Array = []                 # Array[Vector2i] (parent, child)
var _children_of: Array = [] 

# grid occupancy
var _node_cell: Dictionary = {}         # id -> Vector2i
var _cell_node: Dictionary = {}         # Vector2i -> id

# dragging state
var _drag_id: int = -1
var _dragging: bool = false
var _drag_start_cell: Vector2i

func _ready() -> void:
	if layer == null or layer.tile_set == null:
		push_error("No layer/tile_set.")
		return
	_pending_respawn = spawn_on_ready
	_ensure_poset_root()

func _process(_delta: float) -> void:
	if _edge_items.size() > 0:
		_update_edges()

func _unhandled_input(event: InputEvent) -> void:
	if poset_root == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit_id := _hit_test_node_id(event.position)
			if hit_id != -1:
				_drag_id = hit_id
				_dragging = true
				_drag_start_cell = _node_cell.get(_drag_id, Vector2i.ZERO)
				get_viewport().set_input_as_handled()
		else:
			if _dragging:
				_commit_drag(event.position)
				_dragging = false
				_drag_id = -1
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		_preview_drag(event.position)
		get_viewport().set_input_as_handled()

func _ensure_poset_root() -> void:
	poset_root = _get_poset_root()
	if poset_root != null:
		if _pending_respawn:
			_pending_respawn = false
			respawn()
		return

	var root := Node2D.new()
	root.name = POSET_ROOT_NAME
	get_parent().call_deferred("add_child", root)
	call_deferred("_finish_poset_root_setup")

func _finish_poset_root_setup() -> void:
	poset_root = _get_poset_root()
	if poset_root == null:
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
	if existing is Node2D:
		return existing as Node2D
	return null

# -------------------- spawning --------------------

var _edge_items: Array = [] # [{a,b,line},...]

func respawn() -> void:
	if poset_root == null:
		_pending_respawn = true
		_ensure_poset_root()
		return

	var rect: Rect2i = layer.get_used_rect()
	if rect.size == Vector2i.ZERO:
		push_error("TileMapLayer empty.")
		return

	_clear_spawned()
	_clear_edges()
	_node_cell.clear()
	_cell_node.clear()

	var n := 4
	var P: Array = PosetIsomorphism.create(n)

	_covers = [
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 1),
		Vector2i(3, 2),
	]

	for e in _covers:
		PosetIsomorphism.try_add_covering(n, P, int(e.x), int(e.y))

	var ranks: Array = PosetIsomorphism.get_ranks(n, P)
	
	var _rank_of: Array = []
	_rank_of.resize(n)
	for i in range(n):
		_rank_of[i] = int(ranks[i])

	# build parents_of from covers
	_parents_of.clear()
	_parents_of.resize(n)
	for i in range(n):
		_parents_of[i] = []
	for e in _covers:
		var parent := int(e.x)
		var child := int(e.y)
		_parents_of[child].append(parent)
	
	_children_of.clear()
	_children_of.resize(n)
	for i in range(n):
		_children_of[i] = []
	for e in _covers:
		var parent := int(e.x)
		var child := int(e.y)
		_children_of[parent].append(child)

	# group by rank
	var max_rank := 0
	for rv in ranks:
		max_rank = maxi(max_rank, int(rv))

	var per_rank: Array = []
	per_rank.resize(max_rank + 1)
	for r in range(max_rank + 1):
		per_rank[r] = []
	for i in range(n):
		per_rank[int(ranks[i])].append(i)

	_nodes.clear()
	_nodes.resize(n)

	# root placed once
	var base_cell := rect.position + Vector2i(6, 4)
	var base_local := layer.map_to_local(base_cell)
	poset_root.global_position = layer.to_global(base_local)

	# isometric basis vectors from TileMapLayer (correct for iso)
	var o: Vector2 = layer.map_to_local(Vector2i(0, 0))
	var sx: Vector2 = layer.map_to_local(Vector2i(1, 0)) - o
	var sy: Vector2 = layer.map_to_local(Vector2i(0, 1)) - o
	sx *= float(cell_spacing_x)
	sy *= float(cell_spacing_y)

	# spawn nodes with an initial cell assignment
	for r in range(max_rank + 1):
		var nodes_in_rank: Array = per_rank[r]
		for j in range(nodes_in_rank.size()):
			var id: int = int(nodes_in_rank[j])

			var s := _spawn_sprite()
			_nodes[id] = s

			# initial cell in a simple block layout relative to base_cell
			var cell := base_cell + Vector2i(j * cell_spacing_x, r * cell_spacing_y)
			_place_node_at_cell(id, cell, true)

	_build_edges(_covers)

func _spawn_sprite() -> Sprite2D:
	var s: Sprite2D = null

	if element_scene:
		var inst := element_scene.instantiate()
		if inst is Sprite2D:
			s = inst
		else:
			push_error("element_scene root is not Sprite2D")
			return null
	else:
		s = Sprite2D.new()
		s.texture = texture

	s.scale = element_scale
	s.z_index = 1  # sprites above edges
	poset_root.add_child(s)
	s.add_to_group(SPAWN_GROUP)
	return s


func _clear_spawned() -> void:
	if poset_root == null:
		return
	for c in poset_root.get_children():
		if c.is_in_group(SPAWN_GROUP):
			c.queue_free()
	_nodes.clear()

# -------------------- edges --------------------

func _clear_edges() -> void:
	if poset_root == null:
		return
	for c in poset_root.get_children():
		if c is Line2D and c.is_in_group(EDGE_GROUP):
			c.queue_free()
	_edge_items.clear()

func _build_edges(covers: Array) -> void:
	_clear_edges()
	for e in covers:
		var a := int((e as Vector2i).x)
		var b := int((e as Vector2i).y)
		if a < 0 or a >= _nodes.size(): continue
		if b < 0 or b >= _nodes.size(): continue
		if _nodes[a] == null or _nodes[b] == null: continue

		var line := Line2D.new()
		line.z_index = 0
		line.width = 4.0
		line.add_to_group(EDGE_GROUP)
		poset_root.add_child(line)
		_edge_items.append({"a": a, "b": b, "line": line})

	_update_edges()

func _update_edges() -> void:
	for item in _edge_items:
		var a: int = item["a"]
		var b: int = item["b"]
		var line: Line2D = item["line"]
		var sa: Sprite2D = _nodes[a]
		var sb: Sprite2D = _nodes[b]
		if sa == null or sb == null: continue
		line.clear_points()
		line.add_point(sa.position)
		line.add_point(sb.position)

# -------------------- dragging + snapping --------------------

func _preview_drag(global_mouse: Vector2) -> void:
	if _drag_id == -1:
		return
	var target_cell := _global_to_cell(global_mouse)
	var ok := _is_cell_valid_for(_drag_id, target_cell)

	# preview position (snap), but do not commit occupancy unless ok
	_nodes[_drag_id].global_position = _cell_to_global(target_cell)

	# minimal feedback
	_nodes[_drag_id].modulate.a = 1.0
	_nodes[_drag_id].modulate = Color(1, 1, 1, 1) if ok else Color(1, 0.6, 0.6, 1)

func _commit_drag(global_mouse: Vector2) -> void:
	if _drag_id == -1:
		return
	var target_cell := _global_to_cell(global_mouse)

	if _is_cell_valid_for(_drag_id, target_cell):
		_place_node_at_cell(_drag_id, target_cell, false)
	else:
		# revert
		_place_node_at_cell(_drag_id, _drag_start_cell, false)

	_nodes[_drag_id].modulate = Color(1, 1, 1, 1)

func _place_node_at_cell(id: int, cell: Vector2i, initial := false) -> void:
	# remove old occupancy if any
	if _node_cell.has(id):
		var old_cell: Vector2i = _node_cell[id]
		if _cell_node.get(old_cell, -999) == id:
			_cell_node.erase(old_cell)

	# if not initial, also kick out any stale occupant record (should not happen if validated)
	if _cell_node.has(cell) and _cell_node[cell] != id:
		_cell_node.erase(cell)

	_node_cell[id] = cell
	_cell_node[cell] = id

	# set snapped position
	_nodes[id].global_position = _cell_to_global(cell)

const Y_EPS := 6.0  # must be > 0 to forbid same-level ties

func _is_cell_valid_for(id: int, cell: Vector2i) -> bool:
	# prevent overlap
	if _cell_node.has(cell) and int(_cell_node[cell]) != id:
		return false

	var proposed_pos := _cell_to_global(cell)
	var y := proposed_pos.y

	for p in _parents_of[id]:
		var parent_id := int(p)
		var ps: Sprite2D = _nodes[parent_id]
		if ps == null:
			continue
		if y > ps.global_position.y - Y_EPS:
			return false

	for c in _children_of[id]:
		var child_id := int(c)
		var cs: Sprite2D = _nodes[child_id]
		if cs == null:
			continue
		if y < cs.global_position.y + Y_EPS:
			return false

	return true

# -------------------- coordinate helpers --------------------

func _global_to_cell(global_point: Vector2) -> Vector2i:
	var local_point: Vector2 = layer.to_local(global_point)
	return layer.local_to_map(local_point)

func _cell_to_global(cell: Vector2i) -> Vector2:
	var local_pos: Vector2 = layer.map_to_local(cell)
	return layer.to_global(local_pos)

# -------------------- hit test --------------------

func _hit_test_node_id(global_point: Vector2) -> int:
	for id in range(_nodes.size()):
		var s: Sprite2D = _nodes[id]
		if s == null:
			continue
		if _hit_test_sprite(s, global_point):
			return id
	return -1

func _hit_test_sprite(s: Sprite2D, global_point: Vector2) -> bool:
	var tex := s.texture
	if tex == null:
		return false
	var lp: Vector2 = s.to_local(global_point)
	var size: Vector2 = tex.get_size()
	var rect := Rect2(-size * 0.5, size) if s.centered else Rect2(Vector2.ZERO, size)
	return rect.has_point(lp)
