extends Node2D


func _ready():
	var n = 3
	var P_A = PosetIsomorphism.create(n)
	var P_B = PosetIsomorphism.create(n)
	
	# Safe building: A chain 0 -> 1 -> 2
	if not PosetIsomorphism.try_add_covering(n, P_A, 0, 1):
		print("Error building P_A: Illegal Move")
	if not PosetIsomorphism.try_add_covering(n, P_A, 1, 2):
		print("Error building P_A: Illegal Move")
		
	# Safe building: A chain 2 -> 0 -> 1
	PosetIsomorphism.try_add_covering(n, P_B, 2, 0)
	PosetIsomorphism.try_add_covering(n, P_B, 0, 1)

	# --- TEST THE SAFETY ---
	# Try to force a cycle (0 -> 1 -> 2 -> 0)
	# This would collapse the points to 0=1=2.
	var success = PosetIsomorphism.try_add_covering(n, P_A, 2, 0)
	print("Attempting to create cycle (2->0): ", success) # Should be FALSE
	
	var result = PosetIsomorphism.are_isomorphic(n, P_A, P_B)
	print("FINAL RESULT: ", result) # Should be TRUE
	
	n = 5

	var P = PosetIsomorphism.create(n)
	
	PosetIsomorphism.try_add_covering(n, P, 1, 0)
	PosetIsomorphism.try_add_covering(n, P, 2, 0)
	PosetIsomorphism.try_add_covering(n, P, 3, 1)
	PosetIsomorphism.try_add_covering(n, P, 4, 3)
	PosetIsomorphism.try_add_covering(n, P, 4, 2)

	# 1. Get Adjacency
	var adj = PosetIsomorphism.get_adjacency_data(n, P)
	print("--- Adjacency Data ---")
	print("Node 4 covers: ", adj[4]["covers"])
	print("Node 4 covered by: ", adj[4]["covered_by"])

	# 2. Get Ranks
	var ranks = PosetIsomorphism.get_ranks(n, P)
	print("\n--- Ranks ---")
	for i in range(5):
		print("Node " + str(i) + " Rank: ", ranks[i]) # Should be 0 (Leaf)
