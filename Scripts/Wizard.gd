extends CharacterBody2D

## ── Companion Behaviour ──────────────────────────────────────────────────────
@export var move_speed: float = 120.0
@export var follow_distance: float = 75.0
@export var max_health: int = 15
@export var attack01_damage: int = 3
@export var attack02_damage: int = 5
@export var attack_range: float = 90.0
@export var action_interval: float = 2.0
@export var projectile_speed: float = 200.0

## ── Collision layers ─────────────────────────────────────────────────────────
const LAYER_PLAYER_HURTBOX: int = 1 << 1
const LAYER_ENEMY_HURTBOX: int = 1 << 3

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"hurt", &"death"]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 0
var is_dead: bool = false
var current_action_animation: StringName = &""
var action_timer: Timer
var leader: Node2D
var attack_toggle: bool = false  # alternates between attack01 and attack02
var pending_projectile_target: Node2D = null  # deferred projectile spawn
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

func _physics_process(_delta: float) -> void:
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

	# Intercept: move closer to enemy near player
	var threat := CombatUtils.find_enemy_near_player(global_position, get_tree(), 110.0)
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

# ─── Action timer ─────────────────────────────────────────────────────────────

func _on_action_timer_timeout() -> void:
	if is_dead or _is_action_locked():
		return

	var enemy := _find_nearest_enemy()
	if enemy == null:
		return
	current_attack_target = enemy

	# Alternate between attack01 and attack02
	if attack_toggle:
		_do_attack02(enemy)
	else:
		_do_attack01(enemy)
	attack_toggle = not attack_toggle

# ─── Attack 01 ────────────────────────────────────────────────────────────────

func _do_attack01(enemy: Node2D) -> void:
	_face_target(enemy)
	_play_action(&"attack01")
	_spawn_effect_on_target(enemy, &"attack01 effect")

	if enemy.has_method("take_damage"):
		enemy.call("take_damage", attack01_damage)

# ─── Attack 02 (PROJECTILE) ───────────────────────────────────────────────────

func _do_attack02(enemy: Node2D) -> void:
	_face_target(enemy)
	_play_action(&"attack02")
	pending_projectile_target = enemy  # Projectile fires on 2nd-to-last frame

# ─── Effect spawner ──────────────────────────────────────────────────────────

func _spawn_effect_on_target(target: Node2D, anim_name: StringName) -> void:
	var effect := AnimatedSprite2D.new()
	effect.name = "WizardEffect"
	effect.sprite_frames = animated_sprite.sprite_frames
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.z_index = 15

	get_parent().add_child(effect)
	effect.global_position = target.global_position

	if effect.sprite_frames.has_animation(anim_name):
		effect.sprite_frames.set_animation_loop(anim_name, false)
		effect.play(anim_name)
		effect.animation_finished.connect(effect.queue_free)
	else:
		effect.queue_free()

## Spawn a projectile that travels from wizard to enemy position
func _spawn_projectile(enemy: Node2D) -> void:
	var dir := (enemy.global_position - global_position).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT

	var projectile := AnimatedSprite2D.new()
	projectile.name = "WizardProjectile"
	projectile.sprite_frames = animated_sprite.sprite_frames
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_index = 15

	get_parent().add_child(projectile)
	projectile.global_position = global_position + dir * 12.0
	projectile.rotation = dir.angle()  # Rotate to face travel direction

	# Play the projectile animation
	var anim_name := &"attack02 effect"
	if projectile.sprite_frames.has_animation(anim_name):
		projectile.sprite_frames.set_animation_loop(anim_name, true)
		projectile.play(anim_name)

	# Move the projectile via a script-like approach using a timer + process
	var _target_pos := enemy.global_position
	var dmg := attack02_damage
	var spd := projectile_speed
	var tree_ref := get_tree()
	var max_dist := attack_range * 1.5
	var _traveled := 0.0

	projectile.set_meta("dir", dir)
	projectile.set_meta("spd", spd)
	projectile.set_meta("dmg", dmg)
	projectile.set_meta("traveled", 0.0)
	projectile.set_meta("max_dist", max_dist)
	projectile.set_meta("hit", false)

	# Use a process callback to move the projectile
	var callable := func(delta: float) -> void:
		if not is_instance_valid(projectile): return
		if projectile.get_meta("hit"): return
		var d: Vector2 = projectile.get_meta("dir")
		var s: float = projectile.get_meta("spd")
		var t: float = projectile.get_meta("traveled")
		var md: float = projectile.get_meta("max_dist")
		projectile.global_position += d * s * delta
		t += s * delta
		projectile.set_meta("traveled", t)
		if t >= md:
			projectile.queue_free()
			return
		# Check hit against enemies
		for e in tree_ref.get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not e is Node2D: continue
			if e.get("is_dead") == true: continue
			if projectile.global_position.distance_to((e as Node2D).global_position) < 16.0:
				if e.has_method("take_damage"):
					e.call("take_damage", projectile.get_meta("dmg"))
				projectile.set_meta("hit", true)
				projectile.queue_free()
				return

	# Connect to the tree's process_frame signal for movement
	var timer := Timer.new()
	timer.wait_time = 0.016
	timer.one_shot = false
	projectile.add_child(timer)
	timer.timeout.connect(func(): callable.call(0.016))
	timer.start()

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _face_target(target: Node2D) -> void:
	if target.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false

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
	# Spawn projectile on 2nd-to-last frame of attack02
	if pending_projectile_target == null: return
	if animated_sprite.animation != &"attack02": return
	var frames := animated_sprite.sprite_frames
	if frames == null: return
	var total_frames := frames.get_frame_count(&"attack02")
	if animated_sprite.frame >= total_frames - 2:
		if is_instance_valid(pending_projectile_target):
			_spawn_projectile(pending_projectile_target)
		pending_projectile_target = null

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
