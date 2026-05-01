extends CharacterBody2D
## Elite Orc — Strong enemy, high damage, multiple attacks

@export var move_speed: float = 65.0
@export var max_health: int = 10
@export var contact_damage: int = 2
@export var attack_range: float = 30.0
@export var attack_interval: float = 2.0
@export var attack01_damage: int = 3
@export var attack02_damage: int = 4
@export var attack03_damage: int = 6
@export var hurtbox_radius: float = 14.0
@export var contact_hitbox_radius: float = 12.0

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"attack03", &"hurt", &"death"]
const LAYER_PLAYER_HURTBOX: int = 1 << 1; const LAYER_PLAYER_HITBOX: int = 1 << 2
const LAYER_ENEMY_HURTBOX: int = 1 << 3; const LAYER_ENEMY_HITBOX: int = 1 << 4
const ExpGemScript = preload("res://Scripts/ExpGem.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D; var current_action_animation: StringName = &""
var is_dead: bool = false; var health: int = 0
var hurtbox: Area2D; var contact_hitbox: Area2D
var attack_timer: Timer; var attack_cycle: int = 0
var swing_damage: int = 0; var swing_hit_targets: Array = []

func _ready() -> void:
	if not is_in_group("enemy"): add_to_group("enemy")
	collision_layer = 0; collision_mask = 0; health = max_health
	_setup_combat_areas()
	target = CombatUtils.find_priority_target(global_position, get_tree())
	_configure_animation_loops()
	animated_sprite.speed_scale = 1.5
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
		animated_sprite.frame_changed.connect(_on_frame_changed)
	_play_animation(&"idle")
	attack_timer = Timer.new(); attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false; attack_timer.timeout.connect(_on_attack_timer)
	add_child(attack_timer); attack_timer.start()

func _physics_process(_delta: float) -> void:
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO; move_and_slide(); return
	if target == null or not is_instance_valid(target) or target.get("is_dead") == true:
		target = CombatUtils.find_priority_target(global_position, get_tree())
		if target == null: velocity = Vector2.ZERO; _play_animation(&"idle"); move_and_slide(); return
	var to := target.global_position - global_position
	if to.length_squared() > 4.0:
		var d := to.normalized(); velocity = d * move_speed
		if d.x != 0.0: animated_sprite.flip_h = d.x < 0.0
		_play_animation(&"walk")
	else: velocity = Vector2.ZERO; _play_animation(&"idle")
	move_and_slide()

func _on_attack_timer() -> void:
	if is_dead or _is_action_locked(): return
	if target == null or not is_instance_valid(target) or target.get("is_dead") == true: return
	if global_position.distance_to(target.global_position) > attack_range: return
	swing_hit_targets.clear()
	match attack_cycle % 3:
		0: _play_action(&"attack01"); swing_damage = attack01_damage
		1: _play_action(&"attack02"); swing_damage = attack02_damage
		2: _play_action(&"attack03"); swing_damage = attack03_damage
	attack_cycle += 1

func take_damage(amount: int = 1) -> void:
	if is_dead: return
	health = maxi(health - maxi(amount, 0), 0)
	if health <= 0: _play_death()
	else: _play_action(&"hurt")
func get_contact_damage() -> int: return contact_damage

func _play_death() -> void:
	if is_dead: return
	is_dead = true; velocity = Vector2.ZERO
	if attack_timer: attack_timer.stop()
	if hurtbox: hurtbox.set_deferred("monitoring", false); hurtbox.set_deferred("monitorable", false)
	if contact_hitbox: contact_hitbox.set_deferred("monitoring", false); contact_hitbox.set_deferred("monitorable", false)
	_play_action(&"death")

func _setup_combat_areas() -> void:
	hurtbox = _mk_area("Hurtbox", LAYER_ENEMY_HURTBOX, LAYER_PLAYER_HITBOX, "enemy_hurtbox", hurtbox_radius)
	contact_hitbox = _mk_area("ContactHitbox", LAYER_ENEMY_HITBOX, LAYER_PLAYER_HURTBOX, "enemy_hitbox", contact_hitbox_radius)
func _mk_area(n: String, layer: int, mask: int, grp: String, rad: float) -> Area2D:
	var a := get_node_or_null(n) as Area2D
	if a == null: a = Area2D.new(); a.name = n; add_child(a)
	a.position = Vector2(0, 4); a.monitorable = true; a.monitoring = true
	a.collision_layer = layer; a.collision_mask = mask
	if not a.is_in_group(grp): a.add_to_group(grp)
	var cs := a.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null: cs = CollisionShape2D.new(); cs.name = "CollisionShape2D"; a.add_child(cs)
	var c := cs.shape as CircleShape2D
	if c == null: c = CircleShape2D.new(); cs.shape = c
	c.radius = max(rad, 1.0); return a

func _play_action(a: StringName) -> void:
	if not _has_animation(a): return
	current_action_animation = a; velocity = Vector2.ZERO; _play_animation(a)
func _on_animation_finished() -> void:
	if animated_sprite.animation == &"death":
		ExpGemScript.drop_gems(self, 2, randi_range(2, 3))  # Strong tier, 2-3 gems
		queue_free(); return
	if animated_sprite.animation == current_action_animation:
		current_action_animation = &""
		swing_damage = 0
		swing_hit_targets.clear()

func _on_frame_changed() -> void:
	if swing_damage <= 0: return
	var anim := animated_sprite.animation
	var f := animated_sprite.frame
	var should_damage := false
	
	if anim == &"attack01" and f >= 2: should_damage = true
	elif anim == &"attack02" and f >= 0: should_damage = true
	elif anim == &"attack03" and f >= 3: should_damage = true
		
	if should_damage:
		if target != null and is_instance_valid(target) and target.get("is_dead") != true and target not in swing_hit_targets:
			if global_position.distance_to(target.global_position) <= attack_range:
				if target.has_method("take_damage"): target.call("take_damage", swing_damage)
				swing_hit_targets.append(target)
func _is_action_locked() -> bool: return current_action_animation != &""
func _play_animation(a: StringName) -> void:
	if not _has_animation(a): return
	if animated_sprite.animation != a or not animated_sprite.is_playing(): animated_sprite.play(a)
func _configure_animation_loops() -> void:
	var f := animated_sprite.sprite_frames; if f == null: return
	for a in MOVEMENT_ANIMATIONS: if f.has_animation(a): f.set_animation_loop(a, true)
	for a in ACTION_ANIMATIONS: if f.has_animation(a): f.set_animation_loop(a, false)
func _has_animation(a: StringName) -> bool:
	var f := animated_sprite.sprite_frames; return f != null and f.has_animation(a)
