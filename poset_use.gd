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
