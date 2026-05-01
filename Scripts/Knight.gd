extends CharacterBody2D
## Knight — Tank companion with wide sweep and block
## attack01: Shield bash (low dmg), attack02: Sweep (multi-hit area),
## attack03: Heavy slam (high dmg), periodically blocks to reduce incoming damage

@export var move_speed: float = 100.0
@export var follow_distance: float = 55.0
@export var max_health: int = 30
@export var attack01_damage: int = 2
@export var attack02_damage: int = 3
@export var attack03_damage: int = 5
@export var attack_range: float = 35.0
@export var aoe_range: float = 45.0
@export var action_interval: float = 2.0

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"attack03", &"block", &"hurt", &"death"]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int = 0; var is_dead: bool = false
var current_action_animation: StringName = &""
var action_timer: Timer; var leader: Node2D; var attack_cycle: int = 0
var current_attack_target: Node2D = null

func _ready() -> void:
	if not is_in_group("companion"): add_to_group("companion")
	if not is_in_group("player"): add_to_group("player")
	health = max_health
	leader = get_tree().get_first_node_in_group("player") as Node2D
	collision_layer = 0; collision_mask = 0
	_configure_animation_loops()
	animated_sprite.speed_scale = 1.5
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")
	action_timer = Timer.new(); action_timer.name = "ActionTimer"
	action_timer.wait_time = action_interval; action_timer.one_shot = false
	action_timer.timeout.connect(_on_action_timer_timeout)
	add_child(action_timer); action_timer.start()

func _physics_process(_delta: float) -> void:
	var separation := CombatUtils.get_separation_force(self, get_tree()) if not is_dead else Vector2.ZERO
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO; move_and_slide(); return
	if leader == null or not is_instance_valid(leader):
		leader = get_tree().get_first_node_in_group("player") as Node2D
	if leader == null:
		velocity = Vector2.ZERO; _play_animation(&"idle"); move_and_slide(); return
	# Intercept: rush toward enemy near player
	var threat := CombatUtils.find_enemy_near_player(global_position, get_tree(), 100.0)
	if threat != null:
		var to_threat := threat.global_position - global_position
		var threat_dist := to_threat.length()
		if threat_dist > attack_range:
			# Too far — rush toward enemy
			var dir := to_threat.normalized()
			velocity = dir * move_speed * 1.4 + separation
			if absf(dir.x) > 0.1: animated_sprite.flip_h = dir.x < 0.0
			_play_animation(&"walk")
			move_and_slide(); return
		else:
			# In attack range — stop and face enemy
			velocity = separation
			if absf(to_threat.x) > 4.0: animated_sprite.flip_h = to_threat.x < 0.0
			_play_animation(&"idle")
			move_and_slide(); return
	var formation_pos := CombatUtils.get_formation_position(self, get_tree())
	var to := formation_pos - global_position
	if to.length() > follow_distance:
		var d := to.normalized(); velocity = d * move_speed + separation
		if absf(d.x) > 0.1: animated_sprite.flip_h = d.x < 0.0
		_play_animation(&"walk")
	else:
		velocity = separation; _play_animation(&"idle")
	move_and_slide()

func _on_action_timer_timeout() -> void:
	if is_dead or _is_action_locked(): return
	match attack_cycle % 4:
		0:  # Shield bash — single target
			var e := _find_nearest(attack_range)
			if e: current_attack_target = e; _face(e); _play_action(&"attack01"); _dmg(e, attack01_damage)
		1:  # Sweep — hit ALL enemies in aoe_range
			var enemies := _find_all_in_range(aoe_range)
			if enemies.size() > 0:
				_face(enemies[0]); _play_action(&"attack02")
				for e in enemies: _dmg(e, attack02_damage)
		2:  # Heavy slam — single target, high damage
			var e := _find_nearest(attack_range)
			if e: _face(e); _play_action(&"attack03"); _dmg(e, attack03_damage)
		3:  # Block stance — defensive, no attack
			_play_action(&"block")
	attack_cycle += 1

func _find_nearest(rng: float) -> Node2D:
	return CombatUtils.find_distributed_enemy_near_player(self, get_tree(), rng)

func _find_all_in_range(rng: float) -> Array[Node2D]:
	# Find the player
	var player_pos := global_position
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p is Node2D and not p.is_in_group("companion"):
			if p.get("is_dead") != true:
				player_pos = (p as Node2D).global_position; break
	return CombatUtils.find_all_enemies_near(player_pos, get_tree(), rng)

func _dmg(e: Node2D, d: int) -> void:
	if e.has_method("take_damage"): e.call("take_damage", d)

func _face(t: Node2D) -> void:
	animated_sprite.flip_h = t.global_position.x < global_position.x

func take_damage(amount: int = 1) -> void:
	if is_dead: return
	# Knight has natural damage reduction when blocking
	var reduction := 0
	if current_action_animation == &"block": reduction = 1
	var applied := maxi(maxi(amount, 0) - reduction, 0)
	health = maxi(health - applied, 0)
	if health <= 0: _trigger_death(); return
	if current_action_animation != &"block" and _has_animation(&"hurt"): _play_action(&"hurt")

func receive_heal(a: int) -> void:
	if is_dead: return
	health = mini(health + a, max_health)
func get_contact_damage() -> int: return 0

func _trigger_death() -> void:
	if is_dead: return
	is_dead = true; velocity = Vector2.ZERO
	if action_timer: action_timer.stop(); _play_action(&"death")

func _play_action(a: StringName) -> void:
	if not _has_animation(a): return
	current_action_animation = a; velocity = Vector2.ZERO; _play_animation(a)
func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death": animated_sprite.pause(); return
	if animated_sprite.animation == current_action_animation: current_action_animation = &""
func _is_action_locked() -> bool: return current_action_animation != &""
func _play_animation(a: StringName) -> void:
	if not _has_animation(a): return
	if animated_sprite.animation != a or not animated_sprite.is_playing(): animated_sprite.play(a)
func _configure_animation_loops() -> void:
	var f := animated_sprite.sprite_frames; if f == null: return
	for a in MOVEMENT_ANIMATIONS:
		if f.has_animation(a): f.set_animation_loop(a, true)
	for a in ACTION_ANIMATIONS:
		if f.has_animation(a): f.set_animation_loop(a, false)
func _has_animation(a: StringName) -> bool:
	var f := animated_sprite.sprite_frames; return f != null and f.has_animation(a)
