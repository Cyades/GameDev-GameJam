extends CharacterBody2D

## ── Companion Behaviour ──────────────────────────────────────────────────────
@export var move_speed: float = 130.0
@export var follow_distance: float = 40.0
@export var max_health: int = 20
@export var attack_damage: int = 2
@export var attack_range: float = 80.0
@export var heal_range: float = 120.0
@export var heal_amount: int = 3
@export var action_interval: float = 2.5
@export var effect_duration: float = 0.8

## ── Collision layers (same convention as Player / Slime) ─────────────────────
const LAYER_PLAYER_HURTBOX: int = 1 << 1
const LAYER_ENEMY_HURTBOX: int = 1 << 3
const LAYER_ENEMY_HITBOX:  int = 1 << 4

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"heal", &"hurt", &"death"]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 0
var is_dead: bool = false
var current_action_animation: StringName = &""
var action_timer: Timer
var leader: Node2D  # the player we follow

# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not is_in_group("companion"):
		add_to_group("companion")
	if not is_in_group("player"):
		add_to_group("player")  # so heal can also target companions

	health = max_health
	leader = get_tree().get_first_node_in_group("player") as Node2D

	# Disable body‑to‑body physics (ghost companion)
	collision_layer = 0
	collision_mask  = 0

	_configure_animation_loops()
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")

	# Repeating timer that triggers attack or heal
	action_timer = Timer.new()
	action_timer.name = "ActionTimer"
	action_timer.wait_time = action_interval
	action_timer.one_shot = false
	action_timer.timeout.connect(_on_action_timer_timeout)
	add_child(action_timer)
	action_timer.start()

# ─── Physics ──────────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Follow the player leader
	if leader == null or not is_instance_valid(leader):
		leader = get_tree().get_first_node_in_group("player") as Node2D
		if leader == null:
			velocity = Vector2.ZERO
			_play_animation(&"idle")
			move_and_slide()
			return

	var to_leader := leader.global_position - global_position
	if to_leader.length() > follow_distance:
		var dir := to_leader.normalized()
		velocity = dir * move_speed
		if dir.x != 0.0:
			animated_sprite.flip_h = dir.x < 0.0
		_play_animation(&"walk")
	else:
		velocity = Vector2.ZERO
		_play_animation(&"idle")

	move_and_slide()

# ─── Action timer (attack or heal) ───────────────────────────────────────────

func _on_action_timer_timeout() -> void:
	if is_dead or _is_action_locked():
		return

	# Decide: heal if any ally is below 70 % HP, otherwise attack
	var heal_target := _find_lowest_hp_ally()
	if heal_target != null:
		_do_heal(heal_target)
	else:
		var enemy := _find_nearest_enemy()
		if enemy != null:
			_do_attack(enemy)

# ─── Attack ───────────────────────────────────────────────────────────────────

func _do_attack(enemy: Node2D) -> void:
	# Face the enemy
	if enemy.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false

	_play_action(&"attack01")
	_spawn_effect_on_target(enemy, &"attack01 effect")

	# Apply damage
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", attack_damage)

# ─── Heal ─────────────────────────────────────────────────────────────────────

func _do_heal(target: Node2D) -> void:
	# Face the target
	if target.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false

	_play_action(&"heal")
	_spawn_effect_on_target(target, &"heal effect")

	# Apply healing
	if target.has_method("receive_heal"):
		target.call("receive_heal", heal_amount)
	elif target.get("health") != null and target.get("max_health") != null:
		target.health = mini(target.health + heal_amount, target.max_health)
		if target.has_method("_update_health_bar"):
			target.call("_update_health_bar")

# ─── Effect spawner ──────────────────────────────────────────────────────────

func _spawn_effect_on_target(target: Node2D, anim_name: StringName) -> void:
	# Create an AnimatedSprite2D that plays the effect animation on the target
	var effect := AnimatedSprite2D.new()
	effect.name = "PriestEffect"
	effect.sprite_frames = animated_sprite.sprite_frames
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.z_index = 15

	# Add to the scene root so it stays in world space
	get_parent().add_child(effect)
	effect.global_position = target.global_position

	# Play the effect animation
	if effect.sprite_frames.has_animation(anim_name):
		effect.sprite_frames.set_animation_loop(anim_name, false)
		effect.play(anim_name)
		effect.animation_finished.connect(effect.queue_free)
	else:
		effect.queue_free()

# ─── Target finding helpers ──────────────────────────────────────────────────

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var nearest: Node2D = null
	var nearest_dist_sq := attack_range * attack_range

	for e in enemies:
		if not is_instance_valid(e) or not e is Node2D:
			continue
		if e.get("is_dead") == true:
			continue
		var dist_sq := global_position.distance_squared_to(e.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = e as Node2D
	return nearest

func _find_lowest_hp_ally() -> Node2D:
	# Check player and all companions — find the one with lowest HP ratio
	# Only heal if they are below 70% HP
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("player"))
	candidates.append_array(get_tree().get_nodes_in_group("companion"))

	var best_target: Node2D = null
	var lowest_ratio: float = 0.7  # threshold: only heal if below 70%

	for c in candidates:
		if not is_instance_valid(c) or not c is Node2D:
			continue
		if c == self:
			continue
		if c.get("is_dead") == true:
			continue
		var hp = c.get("health")
		var max_hp = c.get("max_health")
		if hp == null or max_hp == null or max_hp <= 0:
			continue
		var dist := global_position.distance_to(c.global_position)
		if dist > heal_range:
			continue
		var ratio: float = float(hp) / float(max_hp)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			best_target = c as Node2D
	return best_target

# ─── Damage / Heal receiving ─────────────────────────────────────────────────

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	var applied := maxi(amount, 0)
	if applied <= 0:
		return
	health = maxi(health - applied, 0)
	if health <= 0:
		_trigger_death()
		return
	if _has_animation(&"hurt"):
		_play_action(&"hurt")

func receive_heal(amount: int) -> void:
	if is_dead:
		return
	health = mini(health + amount, max_health)

func get_contact_damage() -> int:
	return 0  # companion doesn't deal contact damage

# ─── Death ────────────────────────────────────────────────────────────────────

func _trigger_death() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if action_timer != null:
		action_timer.stop()
	_play_action(&"death")

# ─── Animation helpers ───────────────────────────────────────────────────────

func _play_action(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	current_action_animation = animation_name
	velocity = Vector2.ZERO
	_play_animation(animation_name)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death":
		animated_sprite.pause()
		return
	if animated_sprite.animation == current_action_animation:
		current_action_animation = &""

func _is_action_locked() -> bool:
	return current_action_animation != &""

func _play_animation(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _configure_animation_loops() -> void:
	var frames := animated_sprite.sprite_frames
	if frames == null:
		return
	for anim in MOVEMENT_ANIMATIONS:
		if frames.has_animation(anim):
			frames.set_animation_loop(anim, true)
	for anim in ACTION_ANIMATIONS:
		if frames.has_animation(anim):
			frames.set_animation_loop(anim, false)

func _has_animation(animation_name: StringName) -> bool:
	var frames := animated_sprite.sprite_frames
	return frames != null and frames.has_animation(animation_name)
