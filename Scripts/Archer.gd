extends CharacterBody2D

## ── Companion Behaviour ──────────────────────────────────────────────────────
@export var move_speed: float = 110.0
@export var follow_distance: float = 80.0
@export var max_health: int = 12
@export var arrow_damage: int = 2
@export var arrow_speed: float = 300.0
@export var attack_range: float = 120.0
@export var action_interval: float = 1.2

const ARROW_SCENE: PackedScene = preload("res://Scenes/Arrow.tscn")

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"hurt", &"death"]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 0
var is_dead: bool = false
var current_action_animation: StringName = &""
var action_timer: Timer
var leader: Node2D
var attack_toggle: bool = false  # alternate attack01 / attack02
var attack_direction: Vector2 = Vector2.RIGHT
var pending_arrow_spawn: bool = false  # spawn arrow at end of attack anim
var current_attack_target: Node2D = null  # for distributed targeting

# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not is_in_group("companion"):
		add_to_group("companion")
	if not is_in_group("player"):
		add_to_group("player")

	health = max_health
	leader = get_tree().get_first_node_in_group("player") as Node2D

	collision_layer = 0
	collision_mask  = 0

	_configure_animation_loops()
	animated_sprite.speed_scale = 1.5
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)
	_play_animation(&"idle")

	action_timer = Timer.new()
	action_timer.name = "ActionTimer"
	action_timer.wait_time = action_interval
	action_timer.one_shot = false
	action_timer.timeout.connect(_on_action_timer_timeout)
	add_child(action_timer)
	action_timer.start()

# ─── Physics ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var separation := CombatUtils.get_separation_force(self, get_tree()) if not is_dead else Vector2.ZERO
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if leader == null or not is_instance_valid(leader):
		leader = get_tree().get_first_node_in_group("player") as Node2D
		if leader == null:
			velocity = Vector2.ZERO
			_play_animation(&"idle")
			move_and_slide()
			return

	# Intercept: move closer to enemy near player (but keep ranged distance)
	var threat := CombatUtils.find_enemy_near_player(global_position, get_tree(), 120.0)
	if threat != null:
		var to_threat := threat.global_position - global_position
		var threat_dist := to_threat.length()
		if threat_dist > attack_range:
			var dir := to_threat.normalized()
			velocity = dir * move_speed * 1.3 + separation
			if absf(dir.x) > 0.1:
				animated_sprite.flip_h = dir.x < 0.0
			_play_animation(&"walk")
			move_and_slide()
			return
		else:
			velocity = separation
			if absf(to_threat.x) > 4.0:
				animated_sprite.flip_h = to_threat.x < 0.0
			_play_animation(&"idle")
			move_and_slide()
			return

	var formation_pos := CombatUtils.get_formation_position(self, get_tree())
	var to_leader := formation_pos - global_position
	if to_leader.length() > follow_distance:
		var dir := to_leader.normalized()
		velocity = dir * move_speed + separation
		if absf(dir.x) > 0.1:
			animated_sprite.flip_h = dir.x < 0.0
		_play_animation(&"walk")
	else:
		velocity = separation
		_play_animation(&"idle")

	move_and_slide()

# ─── Free-aim direction (direct at target) ────────────────────────────────────────

func _get_direction_to(target_pos: Vector2) -> Vector2:
	var dir := (target_pos - global_position).normalized()
	if dir.length_squared() < 0.01:
		return attack_direction
	return dir

# ─── Action timer ─────────────────────────────────────────────────────────────

func _on_action_timer_timeout() -> void:
	if is_dead or _is_action_locked():
		return

	var enemy := _find_nearest_enemy()
	if enemy == null:
		return
	current_attack_target = enemy

	# Calculate free-aim direction towards enemy
	var to_enemy := enemy.global_position - global_position
	attack_direction = _get_direction_to(enemy.global_position)

	# Face the enemy
	if attack_direction.x != 0.0:
		animated_sprite.flip_h = attack_direction.x < 0.0

	# Alternate between attack01 and attack02
	if attack_toggle:
		_do_attack(&"attack02")
	else:
		_do_attack(&"attack01")
	attack_toggle = not attack_toggle

# ─── Attack (shoot arrow) ────────────────────────────────────────────────────

func _do_attack(anim_name: StringName) -> void:
	_play_action(anim_name)
	pending_arrow_spawn = true  # Arrow fires at end of animation

func _spawn_arrow() -> void:
	if ARROW_SCENE == null:
		return
	var arrow = ARROW_SCENE.instantiate() as Area2D
	get_parent().add_child(arrow)

	# Start arrow slightly offset from the archer center in the attack direction
	arrow.global_position = global_position + Vector2(0, 4) + attack_direction * 10
	arrow.rotation = attack_direction.angle()
	arrow.direction = attack_direction

	# Set arrow properties
	if arrow.get("speed") != null:
		arrow.speed = arrow_speed
	if arrow.get("damage") != null:
		arrow.damage = arrow_damage

# ─── Target finding ──────────────────────────────────────────────────────────

func _find_nearest_enemy() -> Node2D:
	return CombatUtils.find_distributed_enemy_near_player(self, get_tree(), attack_range)

# ─── Damage receiving ────────────────────────────────────────────────────────

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
	return 0

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

func _on_frame_changed() -> void:
	# Spawn arrow on the LAST frame of attack animation
	if not pending_arrow_spawn: return
	var anim := animated_sprite.animation
	if anim != &"attack01" and anim != &"attack02": return
	var frames := animated_sprite.sprite_frames
	if frames == null: return
	var total_frames := frames.get_frame_count(anim)
	if animated_sprite.frame >= total_frames - 1:
		_spawn_arrow()
		pending_arrow_spawn = false

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
