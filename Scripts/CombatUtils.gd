class_name CombatUtils
## Shared targeting utilities for enemies and companions

## ═══ ENEMY TARGETING: Find player or companion ═══
## Prioritize player, but attack nearest companion if closer
static func find_priority_target(origin: Vector2, tree: SceneTree, prefer_player_weight: float = 0.8) -> Node2D:
	# Get the main player (Soldier — NOT in companion group)
	var player: Node2D = null
	var player_dist := INF
	var first_player := tree.get_first_node_in_group("player") as Node2D
	for p in tree.get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p is Node2D: continue
		if p.get("is_dead") == true: continue
		if not p.is_in_group("companion"):
			player = p as Node2D
			player_dist = origin.distance_to(player.global_position)
			break
	
	# Get nearest companion
	var nearest_comp: Node2D = null
	var comp_dist := INF
	for c in tree.get_nodes_in_group("companion"):
		if not is_instance_valid(c) or not c is Node2D: continue
		if c.get("is_dead") == true: continue
		var d := origin.distance_to((c as Node2D).global_position)
		if d < comp_dist:
			comp_dist = d
			nearest_comp = c as Node2D
	
	# Decision: target whoever is closest, but player gets a weight advantage
	# Companion needs to be closer than (player_dist * weight) to be chosen
	if nearest_comp and player:
		if comp_dist < player_dist * prefer_player_weight:
			return nearest_comp
		return player
	
	# Fallback
	if player: return player
	if nearest_comp: return nearest_comp
	return first_player

## ═══ COMPANION TARGETING: Find enemy near the player ═══
## Companions should protect the player by attacking enemies near them
static func find_enemy_near_player(origin: Vector2, tree: SceneTree, max_range: float = 150.0) -> Node2D:
	# Find the main player
	var player: Node2D = null
	for p in tree.get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p is Node2D: continue
		if p.get("is_dead") == true: continue
		if not p.is_in_group("companion"):
			player = p as Node2D
			break
	
	var search_origin := player.global_position if player else origin
	var enemies := tree.get_nodes_in_group("enemy")
	var nearest: Node2D = null
	var best_dist_sq := max_range * max_range
	
	for e in enemies:
		if not is_instance_valid(e) or not e is Node2D: continue
		if e.get("is_dead") == true: continue
		# Distance from PLAYER to enemy (not from companion)
		var d_to_player := search_origin.distance_squared_to((e as Node2D).global_position)
		if d_to_player < best_dist_sq:
			best_dist_sq = d_to_player
			nearest = e as Node2D
	
	return nearest

## ═══ Find all enemies near a point ═══
static func find_all_enemies_near(point: Vector2, tree: SceneTree, max_range: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var range_sq := max_range * max_range
	for e in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e is Node2D: continue
		if e.get("is_dead") == true: continue
		if point.distance_squared_to((e as Node2D).global_position) < range_sq:
			result.append(e as Node2D)
	return result
