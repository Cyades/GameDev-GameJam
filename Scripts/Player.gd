extends CharacterBody2D

@export var walk_speed: float = 150.0
@export var sprint_speed_multiplier: float = 1.6
@export var max_health: int = 20
@export var melee_damage: int = 1
@export var melee_interval: float = 0.65
@export var melee_active_duration: float = 0.20
@export var melee_radius: float = 16.0
@export var hurtbox_radius: float = 10.0
@export var hurt_cooldown: float = 0.35
@export var melee_hitbox_offset: float = 22.0
@export var arrow_distance: float = 20.0
@export var attack_cone_dot: float = 0.0

const MOVEMENT_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"sprint"]
const ACTION_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"attack03", &"hurt", &"death"]
const MELEE_ATTACK_ANIMATIONS: Array[StringName] = [&"attack01", &"attack02", &"attack03"]
const LAYER_PLAYER_HURTBOX: int = 1 << 1
const LAYER_PLAYER_HITBOX: int = 1 << 2
const LAYER_ENEMY_HURTBOX: int = 1 << 3
const LAYER_ENEMY_HITBOX: int = 1 << 4
const LAYER_ITEM: int = 1 << 5
const ARROW_SCENE: PackedScene = preload("res://Scenes/Arrow.tscn")


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: TextureProgressBar = $HealthBar


var facing_sign: float = 1.0
var attack_direction: Vector2 = Vector2.RIGHT
var current_action_animation: StringName = &""
var is_dead: bool = false
var health: int = 0
var melee_hitbox: Area2D
var player_hurtbox: Area2D
var melee_cycle_timer: Timer
var melee_window_timer: Timer
var hurt_cooldown_timer: Timer
var hit_targets_this_swing: Dictionary = {}
var selected_attack_index: int = 0

var _arrow_node: Node2D
var _arrow_polygon: Polygon2D
var _arrow_shadow: Polygon2D

@export var magnet_radius: float = 120.0
@export var pickup_radius: float = 16.0
@export var base_exp_threshold: int = 10

var current_exp: int = 0
var current_level: int = 1

var magnet_area: Area2D
var pickup_area: Area2D

# HUD EXP bar references
var exp_canvas_layer: CanvasLayer
var exp_bar: ProgressBar
var level_label: Label

# Gacha system reference (set by Main.gd)
var gacha_system: Node = null

func set_gacha_system(system: Node) -> void:
	gacha_system = system

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	health = max_health
	_setup_health_bar()
	_update_health_bar()
	_create_exp_hud()
	_update_exp_bar()
	_setup_inputs()
	_setup_combat_areas()
	_setup_combat_timers()
	_create_arrow_indicator()
	_configure_animation_loops()
	animated_sprite.speed_scale = 1.5
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("die"):
		_trigger_death()
		return

	if _handle_attack_switch_input(event):
		return

	if is_dead or _is_action_locked():
		return

	if event.is_action_pressed("hurt"):
		_play_animation(&"hurt")

func _physics_process(_delta: float) -> void:
	if is_dead or _is_action_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var keep_attack_animation := melee_window_timer != null and melee_window_timer.time_left > 0.0
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		var is_sprinting := Input.is_action_pressed("sprint") and _has_animation(&"sprint")
		var speed := walk_speed * (sprint_speed_multiplier if is_sprinting else 1.0)
		velocity = direction * speed

		attack_direction = _snap_to_8way(direction)
		facing_sign = sign(attack_direction.x) if attack_direction.x != 0.0 else facing_sign
		animated_sprite.flip_h = facing_sign < 0.0
		if not keep_attack_animation:
			_play_animation(&"sprint" if is_sprinting else &"walk")
	else:
		velocity = Vector2.ZERO
		if not keep_attack_animation:
			_play_animation(&"idle")

	move_and_slide()
	_update_arrow_indicator()
	_check_hurtbox_overlap_damage()

# ─── 8-way helpers ────────────────────────────────────────────────────────────

func _snap_to_8way(dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.01:
		return attack_direction
	var angle_rad: float = dir.angle()
	# Renamed from "snapped" — that shadows the GDScript built-in function
	var snapped_angle: float = round(angle_rad / (PI / 4.0)) * (PI / 4.0)
	return Vector2.RIGHT.rotated(snapped_angle)

func _is_in_attack_cone(enemy: Node2D) -> bool:
	var to_enemy: Vector2 = enemy.global_position - global_position
	if to_enemy.length_squared() < 0.001:
		return true
	return to_enemy.normalized().dot(attack_direction) > attack_cone_dot

# ─── Arrow indicator ──────────────────────────────────────────────────────────

func _create_arrow_indicator() -> void:
	_arrow_node = Node2D.new()
	_arrow_node.name = "ArrowIndicator"
	_arrow_node.z_index = 10
	add_child(_arrow_node)

	var tip: float    = arrow_distance
	var base: float   = tip - 9.0
	var half_w: float = 4.5
	var notch: float  = base + 3.5
	var arrow_verts := PackedVector2Array([
		Vector2(tip,    0.0),
		Vector2(base,  -half_w),
		Vector2(notch,  0.0),
		Vector2(base,   half_w),
	])

	_arrow_shadow = Polygon2D.new()
	_arrow_shadow.polygon  = arrow_verts
	_arrow_shadow.color    = Color(0.0, 0.0, 0.0, 0.55)
	_arrow_shadow.position = Vector2(1.0, 1.0)
	_arrow_node.add_child(_arrow_shadow)

	_arrow_polygon = Polygon2D.new()
	_arrow_polygon.polygon = arrow_verts
	_arrow_polygon.color   = Color(1.0, 0.92, 0.18, 0.95)
	_arrow_node.add_child(_arrow_polygon)

	_update_arrow_indicator()

func _update_arrow_indicator() -> void:
	if _arrow_node == null:
		return
	_arrow_node.rotation = attack_direction.angle()
	if _arrow_polygon != null:
		if melee_window_timer != null and melee_window_timer.time_left > 0.0:
			_arrow_polygon.color = Color(1.0, 0.4, 0.1, 1.0)
		else:
			_arrow_polygon.color = Color(1.0, 0.92, 0.18, 0.95)

# ─── Combat ───────────────────────────────────────────────────────────────────

func _setup_inputs() -> void:
	# Values typed as Key enum to avoid INT_AS_ENUM_WITHOUT_CAST warnings
	var defaults: Dictionary = {
		"move_up":    KEY_W,
		"move_down":  KEY_S,
		"move_left":  KEY_A,
		"move_right": KEY_D,
		"sprint":     KEY_SHIFT,
		"attack_1":   KEY_1,
		"attack_2":   KEY_2,
		"attack_3":   KEY_3,
		"hurt":       KEY_H,
		"die":        KEY_X
	}
	for action_name: String in defaults:
		_ensure_action(action_name, defaults[action_name] as Key)

func _ensure_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	# Assign with Key enum type directly — no cast warning
	event.physical_keycode = keycode
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)

func _setup_combat_areas() -> void:
	melee_hitbox = _get_or_create_area("MeleeHitbox")
	melee_hitbox.monitorable = true
	melee_hitbox.monitoring  = false
	melee_hitbox.collision_layer = LAYER_PLAYER_HITBOX
	melee_hitbox.collision_mask  = LAYER_ENEMY_HURTBOX
	if not melee_hitbox.is_in_group("player_hitbox"):
		melee_hitbox.add_to_group("player_hitbox")
	_configure_circle_shape(melee_hitbox, melee_radius)
	if not melee_hitbox.area_entered.is_connected(_on_melee_hitbox_area_entered):
		melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)

	player_hurtbox = _get_or_create_area("Hurtbox")
	player_hurtbox.position    = Vector2(0, 4)
	player_hurtbox.monitorable = true
	player_hurtbox.monitoring  = true
	player_hurtbox.collision_layer = LAYER_PLAYER_HURTBOX
	player_hurtbox.collision_mask  = LAYER_ENEMY_HITBOX
	if not player_hurtbox.is_in_group("player_hurtbox"):
		player_hurtbox.add_to_group("player_hurtbox")
	_configure_circle_shape(player_hurtbox, hurtbox_radius)
	if not player_hurtbox.area_entered.is_connected(_on_player_hurtbox_area_entered):
		player_hurtbox.area_entered.connect(_on_player_hurtbox_area_entered)

	magnet_area = _get_or_create_area("MagnetArea")
	magnet_area.monitorable = false
	magnet_area.monitoring = true
	magnet_area.collision_layer = 0
	magnet_area.collision_mask = LAYER_ITEM
	_configure_circle_shape(magnet_area, magnet_radius)
	if not magnet_area.area_entered.is_connected(_on_magnet_area_entered):
		magnet_area.area_entered.connect(_on_magnet_area_entered)

	pickup_area = _get_or_create_area("PickupArea")
	pickup_area.monitorable = false
	pickup_area.monitoring = true
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = LAYER_ITEM
	_configure_circle_shape(pickup_area, pickup_radius)
	if not pickup_area.area_entered.is_connected(_on_pickup_area_entered):
		pickup_area.area_entered.connect(_on_pickup_area_entered)

func _setup_combat_timers() -> void:
	melee_cycle_timer = _get_or_create_timer("MeleeCycleTimer")
	melee_cycle_timer.one_shot   = false
	melee_cycle_timer.wait_time  = max(melee_interval, 0.05)
	if not melee_cycle_timer.timeout.is_connected(_on_melee_cycle_timer_timeout):
		melee_cycle_timer.timeout.connect(_on_melee_cycle_timer_timeout)
	melee_cycle_timer.start()

	melee_window_timer = _get_or_create_timer("MeleeWindowTimer")
	melee_window_timer.one_shot = true
	if not melee_window_timer.timeout.is_connected(_on_melee_window_timer_timeout):
		melee_window_timer.timeout.connect(_on_melee_window_timer_timeout)

	hurt_cooldown_timer = _get_or_create_timer("HurtCooldownTimer")
	hurt_cooldown_timer.one_shot = true

func _on_melee_cycle_timer_timeout() -> void:
	if is_dead:
		return
	_start_melee_swing()

func _start_melee_swing() -> void:
	if _is_action_locked():
		return
	if melee_window_timer != null and melee_window_timer.time_left > 0.0:
		return

	melee_hitbox.position = Vector2(0.0, 4.0) + attack_direction * melee_hitbox_offset

	hit_targets_this_swing.clear()
	var attack_animation := _get_selected_attack_animation()
	if _has_animation(attack_animation):
		_play_animation(attack_animation)
		
	if attack_animation == &"attack03":
		melee_hitbox.monitoring = false
		_spawn_arrow()
	else:
		melee_hitbox.monitoring = true
		call_deferred("_apply_melee_damage")
		
	melee_window_timer.start(max(melee_active_duration, 0.8))

func _spawn_arrow() -> void:
	if ARROW_SCENE == null:
		return
	var arrow = ARROW_SCENE.instantiate() as Area2D
	get_parent().add_child(arrow)
	
	# Initial position: start slightly offset from player center
	arrow.global_position = global_position + Vector2(0, 4) + attack_direction * 10
	arrow.rotation = attack_direction.angle()
	arrow.direction = attack_direction

func _handle_attack_switch_input(event: InputEvent) -> bool:
	if is_dead:
		return false
	if _is_attack_slot_pressed(event, &"attack_1", KEY_1, KEY_KP_1):
		_set_selected_attack(0)
		_start_melee_swing()
		return true
	if _is_attack_slot_pressed(event, &"attack_2", KEY_2, KEY_KP_2):
		_set_selected_attack(1)
		_start_melee_swing()
		return true
	if _is_attack_slot_pressed(event, &"attack_3", KEY_3, KEY_KP_3):
		_set_selected_attack(2)
		_start_melee_swing()
		return true
	return false

func _is_attack_slot_pressed(event: InputEvent, action_name: StringName, number_key: Key, keypad_key: Key) -> bool:
	if event.is_action_pressed(action_name):
		return true
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return (
		key_event.keycode == number_key
		or key_event.physical_keycode == number_key
		or key_event.keycode == keypad_key
	)

func _set_selected_attack(index: int) -> void:
	selected_attack_index = clampi(index, 0, MELEE_ATTACK_ANIMATIONS.size() - 1)

func _get_selected_attack_animation() -> StringName:
	return MELEE_ATTACK_ANIMATIONS[selected_attack_index]

func _on_melee_window_timer_timeout() -> void:
	melee_hitbox.monitoring = false
	hit_targets_this_swing.clear()

func _apply_melee_damage() -> void:
	if melee_hitbox == null or not melee_hitbox.monitoring:
		return
	for area in melee_hitbox.get_overlapping_areas():
		_try_damage_enemy_from_hurtbox(area)

func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	_try_damage_enemy_from_hurtbox(area)

func _try_damage_enemy_from_hurtbox(area: Area2D) -> void:
	if area == null or not area.is_in_group("enemy_hurtbox"):
		return

	var enemy := area.get_parent()
	if enemy == null or not is_instance_valid(enemy):
		return

	if not _is_in_attack_cone(enemy):
		return

	var enemy_id := enemy.get_instance_id()
	if hit_targets_this_swing.has(enemy_id):
		return

	if enemy.has_method("take_damage"):
		hit_targets_this_swing[enemy_id] = true
		enemy.call("take_damage", melee_damage)

func _on_player_hurtbox_area_entered(area: Area2D) -> void:
	_try_receive_contact_damage(area)

func _check_hurtbox_overlap_damage() -> void:
	if player_hurtbox == null:
		return
	if hurt_cooldown_timer != null and hurt_cooldown_timer.time_left > 0.0:
		return
	for area in player_hurtbox.get_overlapping_areas():
		if _try_receive_contact_damage(area):
			break

func _try_receive_contact_damage(area: Area2D) -> bool:
	if is_dead:
		return false
	if hurt_cooldown_timer != null and hurt_cooldown_timer.time_left > 0.0:
		return false
	if area == null or not area.is_in_group("enemy_hitbox"):
		return false
	var source := area.get_parent()
	var damage := 1
	if source != null and source.has_method("get_contact_damage"):
		damage = int(source.call("get_contact_damage"))
	take_damage(damage)
	return true

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	var applied_damage: int = maxi(amount, 0)
	if applied_damage <= 0:
		return
	health = maxi(health - applied_damage, 0)
	_update_health_bar()
	if health <= 0:
		_trigger_death()
		return
	if _has_animation(&"hurt"):
		_play_animation(&"hurt")
	if hurt_cooldown_timer != null:
		hurt_cooldown_timer.start(max(hurt_cooldown, 0.01))

func receive_heal(amount: int) -> void:
	if is_dead:
		return
	health = mini(health + amount, max_health)
	_update_health_bar()

func _on_magnet_area_entered(area: Area2D) -> void:
	if area.is_in_group("exp_gem") and area.has_method("fly_to"):
		area.fly_to(self)

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.is_in_group("exp_gem") and area.has_method("collect"):
		var gained_exp = area.collect()
		gain_exp(gained_exp)

# ─── Node helpers ─────────────────────────────────────────────────────────────

func _get_or_create_area(node_name: String) -> Area2D:
	var area := get_node_or_null(node_name) as Area2D
	if area != null:
		return area
	area = Area2D.new()
	area.name = node_name
	add_child(area)
	return area

func _get_or_create_timer(node_name: String) -> Timer:
	var timer := get_node_or_null(node_name) as Timer
	if timer != null:
		return timer
	timer = Timer.new()
	timer.name = node_name
	add_child(timer)
	return timer

func _configure_circle_shape(area: Area2D, radius: float) -> void:
	var collision_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		area.add_child(collision_shape)
	var circle := collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision_shape.shape = circle
	circle.radius = max(radius, 1.0)

func _setup_health_bar() -> void:
	if health_bar == null:
		return
	# Make visible and position centered above the character
	health_bar.visible = true
	health_bar.scale = Vector2(0.35, 0.35)
	# Center horizontally: half the bar width (64 * 0.35 / 2 = ~11)
	var half_bar := 64.0 * 0.35 / 2.0
	health_bar.position = Vector2(-half_bar - 12.0, -18.0)

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = max(max_health, 1)
	health_bar.value = clampi(health, 0, max_health)

# ─── EXP / Level system ───────────────────────────────────────────────────────

func _create_exp_hud() -> void:
	# CanvasLayer so the EXP bar is fixed on screen
	exp_canvas_layer = CanvasLayer.new()
	exp_canvas_layer.name = "EXPCanvasLayer"
	exp_canvas_layer.layer = 100
	add_child(exp_canvas_layer)

	var _vp_size := get_viewport_rect().size

	# EXP progress bar — full width at the top of the screen
	exp_bar = ProgressBar.new()
	exp_bar.name = "EXPBar"
	exp_bar.show_percentage = false
	exp_bar.anchor_left = 0.0
	exp_bar.anchor_top = 0.0
	exp_bar.anchor_right = 1.0
	exp_bar.anchor_bottom = 0.0
	exp_bar.offset_left = 0.0
	exp_bar.offset_top = 0.0
	exp_bar.offset_right = 0.0
	exp_bar.offset_bottom = 4.0
	exp_bar.custom_minimum_size = Vector2(0.0, 4.0)
	exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style the bar background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	bg_style.corner_radius_top_left = 0
	bg_style.corner_radius_top_right = 0
	bg_style.corner_radius_bottom_left = 0
	bg_style.corner_radius_bottom_right = 0
	bg_style.content_margin_left = 0
	bg_style.content_margin_right = 0
	bg_style.content_margin_top = 0
	bg_style.content_margin_bottom = 0
	exp_bar.add_theme_stylebox_override("background", bg_style)

	# Style the fill
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.85, 1.0, 0.95)
	fill_style.corner_radius_top_left = 0
	fill_style.corner_radius_top_right = 0
	fill_style.corner_radius_bottom_left = 0
	fill_style.corner_radius_bottom_right = 0
	fill_style.content_margin_left = 0
	fill_style.content_margin_right = 0
	fill_style.content_margin_top = 0
	fill_style.content_margin_bottom = 0
	exp_bar.add_theme_stylebox_override("fill", fill_style)

	exp_canvas_layer.add_child(exp_bar)

	# Level label — left side, next to the bar
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Lv. 1"
	level_label.position = Vector2(10.0, 15.0)
	level_label.add_theme_font_size_override("font_size", 8)
	level_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	level_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_canvas_layer.add_child(level_label)

func _get_max_exp() -> int:
	# Scaling threshold: higher level = more EXP needed
	# Formula: base_exp_threshold * level ^ 1.5
	return int(base_exp_threshold * pow(current_level, 1.5))

func gain_exp(amount: int) -> void:
	current_exp += amount
	var max_exp := _get_max_exp()
	# Level up loop (in case gained enough for multiple levels)
	while current_exp >= max_exp:
		current_exp -= max_exp
		_level_up()
		max_exp = _get_max_exp()
	_update_exp_bar()

func _level_up() -> void:
	current_level += 1
	print("LEVEL UP! Now level: ", current_level)
	if level_label != null:
		level_label.text = "Lv. " + str(current_level)
	
	# ── Stats scaling ──
	# +2 max HP per level, heal to full
	max_health += 2
	health = max_health
	_update_health_bar()
	
	# +1 melee damage every 2 levels
	if current_level % 2 == 0:
		melee_damage += 1
	
	# +5% walk speed per level (capped at 2x base)
	walk_speed = minf(walk_speed * 1.05, 300.0)
	
	# Slightly faster attack interval (min 0.30s)
	melee_interval = maxf(melee_interval * 0.95, 0.30)
	if melee_cycle_timer != null:
		melee_cycle_timer.wait_time = melee_interval
	
	# Increase magnet radius slightly
	magnet_radius = minf(magnet_radius + 5.0, 250.0)
	
	# ── Gacha trigger every 5 levels ──
	if gacha_system != null and gacha_system.has_method("check_gacha_trigger"):
		gacha_system.check_gacha_trigger(self, current_level)

func _update_exp_bar() -> void:
	if exp_bar == null:
		return
	var max_exp := _get_max_exp()
	exp_bar.max_value = max(max_exp, 1)
	exp_bar.value = clampi(current_exp, 0, max_exp)

# ─── Animation helpers ────────────────────────────────────────────────────────

func _configure_animation_loops() -> void:
	var frames := animated_sprite.sprite_frames
	if frames == null:
		return
	for animation_name in MOVEMENT_ANIMATIONS:
		if frames.has_animation(animation_name):
			frames.set_animation_loop(animation_name, true)
	for animation_name in ACTION_ANIMATIONS:
		if frames.has_animation(animation_name):
			frames.set_animation_loop(animation_name, false)

func _trigger_action(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	current_action_animation = animation_name
	velocity = Vector2.ZERO
	_play_animation(animation_name)

func _trigger_death() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if melee_cycle_timer != null:
		melee_cycle_timer.stop()
	if melee_window_timer != null:
		melee_window_timer.stop()
	if melee_hitbox != null:
		melee_hitbox.set_deferred("monitoring", false)
	if player_hurtbox != null:
		player_hurtbox.set_deferred("monitoring", false)
	if _arrow_node != null:
		_arrow_node.visible = false
	_trigger_action(&"death")

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

func _has_animation(animation_name: StringName) -> bool:
	var frames := animated_sprite.sprite_frames
	return frames != null and frames.has_animation(animation_name)
