class_name PosetIsomorphism
extends Reference

const K_INC = 0  # incomparable 
const K_GEQ = 1   # >=
const K_LEQ = 2   # <=
const K_COV = 3   # >.
const K_COVBY = 4  # <.

static func create(n): # n points, no relations
	var arr = []
	for i in range(n):
		var row = []
		for j in range(n):
			row.append([false, false, false, false, false])
		arr.append(row)
	for i in range(n):
		arr[i][i][K_GEQ] = true
		arr[i][i][K_LEQ] = true
		for j in range(n):
			if i != j: arr[i][j][K_INC] = true
	return arr
	
static func try_add_covering(n, arr, u, v) -> bool:
	if u == v: return false # Can't cover self
	
	# 1. CYCLE CHECK: If v >= u, adding u > v creates a cycle (collapsing points)
	if arr[v][u][K_GEQ]: 
		return false 

	# 2. INTERMEDIATE CHECK: If u > k > v exists, u cannot "cover" v
	for k in range(n):
		if k == u or k == v: continue
		if arr[u][k][K_GEQ] and arr[k][v][K_GEQ]:
			return false 
	
	# 3. APPLY COVERING
	arr[u][v][K_COV] = true
	arr[v][u][K_COVBY] = true
	arr[u][v][K_GEQ] = true
	arr[v][u][K_LEQ] = true
	arr[u][v][K_INC] = false
	arr[v][u][K_INC] = false
	
	# 4. UPDATE TRANSITIVITY (Floyd-Warshall)
	_recalculate_transitivity(n, arr)
	
	# 5. AUTO-CLEANUP: The new edge might have made old covers invalid.
	# (e.g. if A covered C, and we just added A->B and B->C, A no longer covers C)
	_clean_redundant_covers(n, arr)
	
	return true
	
static func _recalculate_transitivity(n, arr): # Floyd-Warshall-like algorithm
	for k in range(n):
		for i in range(n):
			for j in range(n):
				if arr[i][k][K_GEQ] and arr[k][j][K_GEQ]:
					if not arr[i][j][K_GEQ]:
						arr[i][j][K_GEQ] = true
						arr[j][i][K_LEQ] = true
						arr[i][j][K_INC] = false
						arr[j][i][K_INC] = false

static func _clean_redundant_covers(n, arr):
	for i in range(n):
		for j in range(n):
			if arr[i][j][K_COV]:
				# Check if this "cover" is now redundant due to an intermediate k
				for k in range(n):
					if k == i or k == j: continue
					if arr[i][k][K_GEQ] and arr[k][j][K_GEQ]:
						# i > k > j exists, so i DOES NOT cover j anymore
						arr[i][j][K_COV] = false
						arr[j][i][K_COVBY] = false
						break

static func are_isomorphic(n, arr_a, arr_b):
	# Using _get_signatures (which now returns strings) ensures stable sorting
	var sigs_a = _get_signatures(n, arr_a)
	var sigs_b = _get_signatures(n, arr_b)
	
	sigs_a.sort()
	sigs_b.sort()
	
	if sigs_a != sigs_b:
		return false
		
	return _backtrack(0, n, arr_a, arr_b, {}, {})

static func _get_signatures(n, arr):
	var sigs = []
	for i in range(n):
		var s = [0, 0, 0, 0, 0]
		for j in range(n):
			if i == j: continue
			for k in range(5):
				if arr[i][j][k]: s[k] += 1
		# Returns String representation to fix Godot 3.5 sort instability
		sigs.append(str(s)) 
	return sigs

static func _backtrack(idx_a, n, arr_a, arr_b, mapping, used_b): # tracing the possibility inductively
	if idx_a == n: return true
	for idx_b in range(n):
		if not used_b.has(idx_b):
			if _is_consistent(idx_a, idx_b, n, arr_a, arr_b, mapping):
				mapping[idx_a] = idx_b
				used_b[idx_b] = true
				if _backtrack(idx_a + 1, n, arr_a, arr_b, mapping, used_b): return true
				mapping.erase(idx_a)
				used_b.erase(idx_b)
	return false

static func _is_consistent(u_a, u_b, n, arr_a, arr_b, mapping):
	for v_a in mapping.keys():
		var v_b = mapping[v_a]
		if arr_a[u_a][v_a] != arr_b[u_b][v_b]: return false
		if arr_a[v_a][u_a] != arr_b[v_b][u_b]: return false
	return true

# -------------------------------------------------------------------------
# ARITHMETIC API (Generative Posets)
# -------------------------------------------------------------------------

# a + b: Disjoint Union
# Two separate islands. No relations between A and B.
static func disjoint_union(n_a, arr_a, n_b, arr_b):
	var n_new = n_a + n_b
	var arr = create(n_new)
	
	# Copy A into top-left
	_copy_submatrix(arr, arr_a, n_a, 0, 0)
	
	# Copy B into bottom-right
	_copy_submatrix(arr, arr_b, n_b, n_a, n_a)
	
	# No relations between A and B, so we leave the rest as Incomparable (default)
	return arr

# a (+) b or a (downarrow) b: Linear Sum
# Stack B on top of A. Every element of B > Every element of A.
static func linear_sum(n_a, arr_a, n_b, arr_b):
	var arr = disjoint_union(n_a, arr_a, n_b, arr_b)
	
	# Force relations: For every u in A and v in B, v > u
	for i in range(n_a):      # i is in A (0 to n_a-1)
		for j in range(n_b):  # j is in B (0 to n_b-1)
			var u = i
			var v = n_a + j
			
			# Set v > u
			arr[v][u][K_GEQ] = true
			arr[u][v][K_LEQ] = true
			arr[v][u][K_INC] = false
			arr[u][v][K_INC] = false
	
	# Recalculate covers (e.g., only Max(A) will be covered by Min(B))
	_derive_covers_from_order(n_a + n_b, arr)
	return arr

# a x b: Cartesian Product
# (a, b) <= (a', b') iff a <= a' AND b <= b'
static func cartesian_product(n_a, arr_a, n_b, arr_b):
	var n_new = n_a * n_b
	var arr = create(n_new)
	
	for i in range(n_new):
		for j in range(n_new):
			# Decode 1D index to (u, v) pairs
			# i -> (u_a, u_b)
			# j -> (v_a, v_b)
			var u_a = i / n_b; var u_b = i % n_b
			var v_a = j / n_b; var v_b = j % n_b
			
			# Logic: Pair i >= Pair j IF (u_a >= v_a) AND (u_b >= v_b)
			var a_geq = arr_a[u_a][v_a][K_GEQ]
			var b_geq = arr_b[u_b][v_b][K_GEQ]
			
			if a_geq and b_geq:
				arr[i][j][K_GEQ] = true
				arr[j][i][K_LEQ] = true
				arr[i][j][K_INC] = false
				arr[j][i][K_INC] = false
			
			# Note: If not >= and not <=, 'create' already set them to Incomparable
			
	_derive_covers_from_order(n_new, arr)
	return arr

# a (tensor) b: Lexicographical Product
# Dictionary order: Compare A first. If equal, compare B.
static func lex_product(n_a, arr_a, n_b, arr_b):
	var n_new = n_a * n_b
	var arr = create(n_new)
	
	for i in range(n_new):
		for j in range(n_new):
			var u_a = i / n_b; var u_b = i % n_b
			var v_a = j / n_b; var v_b = j % n_b
			
			# Logic: Pair i > Pair j IF (u_a > v_a) OR (u_a == v_a AND u_b > v_b)
			
			var a_strict_gt = arr_a[u_a][v_a][K_GEQ] and not arr_a[v_a][u_a][K_GEQ] # u_a > v_a
			var a_eq = (u_a == v_a)
			var b_strict_gt = arr_b[u_b][v_b][K_GEQ] and not arr_b[v_b][u_b][K_GEQ] # u_b > v_b
			
			# We also need to handle the equality case (reflexive)
			var is_geq = false
			
			if u_a == v_a and u_b == v_b:
				is_geq = true # Reflexive
			elif a_strict_gt:
				is_geq = true # First component dominates
			elif a_eq and arr_b[u_b][v_b][K_GEQ]:
				is_geq = true # First component equal, second component dominates
				
			if is_geq:
				arr[i][j][K_GEQ] = true
				arr[j][i][K_LEQ] = true
				arr[i][j][K_INC] = false
				arr[j][i][K_INC] = false

	_derive_covers_from_order(n_new, arr)
	return arr

# -------------------------------------------------------------------------
# ARITHMETIC HELPERS
# -------------------------------------------------------------------------

static func _copy_submatrix(target, source, size, offset_row, offset_col):
	for i in range(size):
		for j in range(size):
			var r = i + offset_row
			var c = j + offset_col
			# Deep copy the 5-bool array
			for k in range(5):
				target[r][c][k] = source[i][j][k]

# Calculates Strict Covers (k=3,4) purely based on Greater Than (k=1)
# Definition: i covers j if i > j AND there is no k such that i > k > j
static func _derive_covers_from_order(n, arr):
	# 1. Reset all covers to False
	for i in range(n):
		for j in range(n):
			arr[i][j][K_COV] = false
			arr[i][j][K_COVBY] = false
			
	# 2. Find Transitive Reductions
	for i in range(n):
		for j in range(n):
			# If i > j (Strictly)
			if arr[i][j][K_GEQ] and not arr[j][i][K_GEQ]:
				var is_cover = true
				
				# Check for intermediate nodes
				for k in range(n):
					if k == i or k == j: continue
					
					# Is there a path i > k > j?
					var i_gt_k = arr[i][k][K_GEQ] and not arr[k][i][K_GEQ]
					var k_gt_j = arr[k][j][K_GEQ] and not arr[j][k][K_GEQ]
					
					if i_gt_k and k_gt_j:
						is_cover = false
						break
				
				if is_cover:
					arr[i][j][K_COV] = true
					arr[j][i][K_COVBY] = true
