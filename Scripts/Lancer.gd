extends CharacterBody2D
## Lancer — Piercing companion, linear attacks that hit multiple enemies

@export var move_speed: float = 130.0
@export var follow_distance: float = 60.0
@export var max_health: int = 16
@export var attack01_damage: int = 2
@export var attack02_damage: int = 3
@export var attack03_damage: int = 5
@export var attack_range: float = 45.0
@export var pierce_range: float = 60.0
@export var action_interval: float = 1.8

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"attack03", &"hurt", &"death"]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 0
var is_dead: bool = false
var current_action_animation: StringName = &""
var action_timer: Timer
var leader: Node2D
var current_attack_target: Node2D = null
var attack_cycle: int = 0
var lunge_dir: Vector2 = Vector2.ZERO  # direction of lunge
var lunge_speed: float = 0.0  # pixels per second during lunge
var lunge_damage: int = 0  # damage dealt to enemies passed through
var lunge_hit_enemies: Array = []  # enemies already hit this lunge

func _ready() -> void:
	if not is_in_group("companion"):
		add_to_group("companion")
	if not is_in_group("player"):
		add_to_group("player")
	health = max_health
	leader = get_tree().get_first_node_in_group("player") as Node2D
	collision_layer = 0
	collision_mask = 0
	_configure_animation_loops()
	animated_sprite.speed_scale = 1.5
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)
	_play_animation(&"idle")
	action_timer = Timer.new()
	action_timer.wait_time = action_interval
	action_timer.one_shot = false
	action_timer.timeout.connect(_on_action_timer_timeout)
	add_child(action_timer)
	action_timer.start()

func _physics_process(delta: float) -> void:
	var separation := CombatUtils.get_separation_force(self, get_tree()) if not is_dead else Vector2.ZERO
	if is_dead or _is_action_locked():
		# Apply lunge during action lock (attack animation)
		if lunge_dir != Vector2.ZERO and lunge_speed > 0.0:
			global_position += lunge_dir * lunge_speed * delta
			# Damage enemies we pass through
			for e in get_tree().get_nodes_in_group("enemy"):
				if not is_instance_valid(e) or not e is Node2D: continue
				if e.get("is_dead") == true: continue
				if e in lunge_hit_enemies: continue
				if global_position.distance_to((e as Node2D).global_position) < 20.0:
					lunge_hit_enemies.append(e)
					_dmg(e as Node2D, lunge_damage)
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
	# Intercept: rush toward enemy near player
	var threat := CombatUtils.find_enemy_near_player(global_position, get_tree(), 100.0)
	if threat != null:
		var to_threat := threat.global_position - global_position
		var threat_dist := to_threat.length()
		if threat_dist > attack_range:
			var dir := to_threat.normalized()
			velocity = dir * move_speed + separation
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
	var to := formation_pos - global_position
	if to.length() > follow_distance:
		var d := to.normalized()
		velocity = d * move_speed + separation
		if absf(d.x) > 0.1:
			animated_sprite.flip_h = d.x < 0.0
		_play_animation(&"walk")
	else:
		velocity = separation
		_play_animation(&"idle")
	move_and_slide()

func _on_action_timer_timeout() -> void:
	if is_dead or _is_action_locked():
		return
	var nearest := _find_nearest(attack_range)
	if nearest == null:
		return
	current_attack_target = nearest
	_face(nearest)
	var dir_to_enemy := (nearest.global_position - global_position).normalized()
	# If enemy is too vertical, lunge would look odd — fall back to jab
	var too_vertical := absf(dir_to_enemy.x) < 0.45
	var cycle := attack_cycle % 3
	if too_vertical and (cycle == 1 or cycle == 2):
		# Fall back to attack01 (no lunge)
		lunge_dir = Vector2.ZERO
		lunge_speed = 0.0
		_play_action(&"attack01")
		_dmg(nearest, attack01_damage)
	else:
		match cycle:
			0:  # Quick jab — single target (no lunge)
				lunge_dir = Vector2.ZERO
				lunge_speed = 0.0
				_play_action(&"attack01")
				_dmg(nearest, attack01_damage)
			1:  # Thrust — pierces + gradual lunge
				lunge_dir = dir_to_enemy
				lunge_speed = 120.0
				lunge_damage = attack02_damage
				lunge_hit_enemies.clear()
				_play_action(&"attack02")
				var line_enemies := _find_enemies_in_line(nearest, pierce_range)
				for e in line_enemies:
					lunge_hit_enemies.append(e)
					_dmg(e, attack02_damage)
			2:  # Heavy lance — pierces + big lunge
				lunge_dir = dir_to_enemy
				lunge_speed = 160.0
				lunge_damage = attack03_damage
				lunge_hit_enemies.clear()
				_play_action(&"attack03")
				var line_enemies := _find_enemies_in_line(nearest, pierce_range)
				for e in line_enemies:
					lunge_hit_enemies.append(e)
					_dmg(e, attack03_damage)
	attack_cycle += 1

func _find_enemies_in_line(target: Node2D, rng: float) -> Array[Node2D]:
	# Find all enemies roughly in a line from self toward target
	var dir := (target.global_position - global_position).normalized()
	var result: Array[Node2D] = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e is Node2D:
			continue
		if e.get("is_dead") == true:
			continue
		var enemy_node := e as Node2D
		var to_e := enemy_node.global_position - global_position
		if to_e.length() > rng:
			continue
		# Check if enemy is within ~30 degree cone in the attack direction
		var dot := dir.dot(to_e.normalized())
		if dot > 0.85:
			result.append(enemy_node)
	return result

func _find_nearest(rng: float) -> Node2D:
	return CombatUtils.find_distributed_enemy_near_player(self, get_tree(), rng)

func _dmg(e: Node2D, d: int) -> void:
	if e.has_method("take_damage"):
		e.call("take_damage", d)

func _face(t: Node2D) -> void:
	animated_sprite.flip_h = t.global_position.x < global_position.x

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health = maxi(health - maxi(amount, 0), 0)
	if health <= 0:
		_trigger_death()
		return
	if _has_animation(&"hurt"):
		_play_action(&"hurt")

func receive_heal(a: int) -> void:
	if is_dead:
		return
	health = mini(health + a, max_health)

func get_contact_damage() -> int:
	return 0

func _trigger_death() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if action_timer:
		action_timer.stop()
	_play_action(&"death")

func _play_action(a: StringName) -> void:
	if not _has_animation(a):
		return
	current_action_animation = a
	velocity = Vector2.ZERO
	# Keep lunge attack anim at normal speed — movement is the speed
	if a == &"attack02" or a == &"attack03":
		animated_sprite.speed_scale = 1.5
	_play_animation(a)

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death":
		animated_sprite.pause()
		return
	if animated_sprite.animation == current_action_animation:
		current_action_animation = &""
		lunge_dir = Vector2.ZERO
		lunge_speed = 0.0
		animated_sprite.speed_scale = 1.5  # restore base speed

func _on_frame_changed() -> void:
	var anim := animated_sprite.animation
	var frame := animated_sprite.frame
	
	if anim == &"attack01" and frame == 1: CombatSound.play_random_slash(self)
	elif anim == &"attack02" and frame == 1: CombatSound.play_random_slash(self)
	elif anim == &"attack03" and frame == 1: CombatSound.play_fire2(self)

func _is_action_locked() -> bool:
	return current_action_animation != &""

func _play_animation(a: StringName) -> void:
	if not _has_animation(a):
		return
	if animated_sprite.animation != a or not animated_sprite.is_playing():
		animated_sprite.play(a)

func _configure_animation_loops() -> void:
	var f := animated_sprite.sprite_frames
	if f == null:
		return
	for a in MOVEMENT_ANIMATIONS:
		if f.has_animation(a):
			f.set_animation_loop(a, true)
	for a in ACTION_ANIMATIONS:
		if f.has_animation(a):
			f.set_animation_loop(a, false)

func _has_animation(a: StringName) -> bool:
	var f := animated_sprite.sprite_frames
	return f != null and f.has_animation(a)
