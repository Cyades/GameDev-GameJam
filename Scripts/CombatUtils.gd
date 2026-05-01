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

## ═══ DISTRIBUTED target: spread companion attacks across enemies ═══
## Bosses (group "boss") can be targeted by all companions simultaneously.
## Normal enemies get a soft penalty if other companions are already near them.
## With few enemies, companions will still share targets (penalty is small).
static func find_distributed_enemy_near_player(self_node: Node2D, tree: SceneTree, max_range: float = 150.0) -> Node2D:
	# Find the main player
	var player: Node2D = null
	for p in tree.get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p is Node2D: continue
		if p.get("is_dead") == true: continue
		if not p.is_in_group("companion"):
			player = p as Node2D
			break

	var search_origin := player.global_position if player else self_node.global_position

	# Gather all valid enemies near the player OR near the companion itself
	var candidates: Array[Node2D] = []
	for e in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e is Node2D: continue
		if e.get("is_dead") == true: continue
		var epos := (e as Node2D).global_position
		var near_player := search_origin.distance_to(epos) < max_range
		var near_self := self_node.global_position.distance_to(epos) < max_range
		if near_player or near_self:
			candidates.append(e as Node2D)

	if candidates.is_empty():
		return null

	# Only 1 enemy? Return it immediately — no distribution needed
	if candidates.size() == 1:
		return candidates[0]

	# Count companions already targeting each enemy
	var companions: Array = []
	for c in tree.get_nodes_in_group("companion"):
		if not is_instance_valid(c) or not c is Node2D: continue
		if c == self_node: continue
		if c.get("is_dead") == true: continue
		companions.append(c)

	var best: Node2D = null
	var best_score: float = INF  # lower is better

	for enemy in candidates:
		var is_boss: bool = enemy.is_in_group("boss")
		var dist_to_self := self_node.global_position.distance_to(enemy.global_position)

		# Count companions already targeting this enemy
		var attacker_count := 0
		if not is_boss:
			for c in companions:
				# Check actual target variable first
				var c_target = c.get("current_attack_target")
				if c_target != null and is_instance_valid(c_target) and c_target == enemy:
					attacker_count += 1
				# Fallback: melee companions within attack range
				elif c_target == null and (c as Node2D).global_position.distance_to(enemy.global_position) < 35.0:
					attacker_count += 1

		# Soft penalty: prefer less-targeted enemies but don't avoid them
		var score := dist_to_self + attacker_count * 60.0
		if score < best_score:
			best_score = score
			best = enemy

	return best

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

## ═══ COMPANION SEPARATION: Push away from other companions ═══
## Returns a separation velocity to prevent companions from stacking.
## Uses quadratic falloff and a dead-zone threshold to avoid micro-vibration.
static func get_separation_force(self_node: Node2D, tree: SceneTree, sep_radius: float = 30.0, sep_strength: float = 50.0) -> Vector2:
	var force := Vector2.ZERO
	for c in tree.get_nodes_in_group("companion"):
		if not is_instance_valid(c) or not c is Node2D: continue
		if c == self_node: continue
		if c.get("is_dead") == true: continue
		var diff := self_node.global_position - (c as Node2D).global_position
		var dist := diff.length()
		if dist < sep_radius and dist > 1.0:
			# Quadratic falloff — gentle near boundary, strong only when very close
			var ratio := 1.0 - dist / sep_radius
			force += diff.normalized() * sep_strength * ratio * ratio
	# Dead-zone: ignore very small forces that just cause jitter
	if force.length() < 2.0:
		return Vector2.ZERO
	return force

## ═══ FORMATION: Give each companion a unique position around the player ═══
## Returns the world position where this companion should stand when idle/following.
static func get_formation_position(self_node: Node2D, tree: SceneTree, formation_radius: float = 25.0) -> Vector2:
	# Find the main player
	var player: Node2D = null
	for p in tree.get_nodes_in_group("player"):
		if not is_instance_valid(p) or not p is Node2D: continue
		if p.get("is_dead") == true: continue
		if not p.is_in_group("companion"):
			player = p as Node2D
			break
	if player == null:
		return self_node.global_position

	# Gather living companions and find our index
	var companions: Array = []
	for c in tree.get_nodes_in_group("companion"):
		if not is_instance_valid(c) or not c is Node2D: continue
		if c.get("is_dead") == true: continue
		companions.append(c)

	var my_index := 0
	for i in companions.size():
		if companions[i] == self_node:
			my_index = i
			break

	var total := companions.size()
	if total == 0:
		return player.global_position

	# Spread evenly in a circle around the player
	var angle := (TAU / total) * my_index
	return player.global_position + Vector2(cos(angle), sin(angle)) * formation_radius
