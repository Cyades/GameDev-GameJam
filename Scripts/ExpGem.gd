extends Area2D
## ExpGem — Collectible experience gem with color variants
## Colors: Green (5 exp), Yellow (15 exp), Red (30 exp), Purple (60 exp)

@export var exp_amount: int = 5
@export var max_speed: float = 400.0
@export var accel: float = 800.0

var target: Node2D = null
var current_speed: float = 0.0

# Gem textures loaded at runtime
const GEM_GREEN := preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Items/Resource/GemGreen.png")
const GEM_YELLOW := preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Items/Resource/GemYellow.png")
const GEM_RED := preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Items/Resource/GemRed.png")
const GEM_PURPLE := preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Items/Resource/GemPurple.png")

# Gem tier config: [texture, exp_value, drop_weight_for_weak, drop_weight_for_strong]
enum GemTier { GREEN, YELLOW, RED, PURPLE }

const GEM_DATA: Dictionary = {
	GemTier.GREEN:  { "texture": null, "exp": 5 },
	GemTier.YELLOW: { "texture": null, "exp": 15 },
	GemTier.RED:    { "texture": null, "exp": 30 },
	GemTier.PURPLE: { "texture": null, "exp": 60 },
}

func _ready() -> void:
	if not is_in_group("exp_gem"):
		add_to_group("exp_gem")

func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		current_speed += accel * delta
		current_speed = min(current_speed, max_speed)
		position += direction * current_speed * delta

func fly_to(player_node: Node2D) -> void:
	target = player_node

func collect() -> int:
	queue_free()
	return exp_amount

## Set the gem tier (changes texture and exp)
func set_tier(tier: int) -> void:
	match tier:
		GemTier.GREEN:
			_set_texture(GEM_GREEN); exp_amount = 5
		GemTier.YELLOW:
			_set_texture(GEM_YELLOW); exp_amount = 15
		GemTier.RED:
			_set_texture(GEM_RED); exp_amount = 30
		GemTier.PURPLE:
			_set_texture(GEM_PURPLE); exp_amount = 60

func _set_texture(tex: Texture2D) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite and tex:
		sprite.texture = tex

## ── STATIC HELPER: Drop gems from an enemy ──
## Call from enemy death: ExpGem.drop_gems(self, drop_tier, drop_count)
## drop_tier: 0=weak(Slime), 1=medium(Orc), 2=strong(Elite), 3=boss
static func drop_gems(enemy: Node2D, drop_tier: int = 0, drop_count: int = 1) -> void:
	var scene := preload("res://Scenes/ExpGem.tscn")
	if scene == null or enemy == null: return
	var parent := enemy.get_parent()
	if parent == null: return
	
	for i in drop_count:
		var gem := scene.instantiate() as Area2D
		if gem == null: continue
		
		# Determine gem color based on drop tier
		var tier := _pick_gem_tier(drop_tier)
		parent.add_child(gem)
		gem.global_position = enemy.global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		if gem.has_method("set_tier"):
			gem.set_tier(tier)

static func _pick_gem_tier(drop_tier: int) -> int:
	var roll := randf()
	match drop_tier:
		0: # Weak (Slime, Skeleton) — mostly green
			if roll < 0.85: return GemTier.GREEN
			elif roll < 0.97: return GemTier.YELLOW
			else: return GemTier.RED
		1: # Medium (Orc, SkeletonArcher, OrcRider) — mixed
			if roll < 0.50: return GemTier.GREEN
			elif roll < 0.80: return GemTier.YELLOW
			elif roll < 0.95: return GemTier.RED
			else: return GemTier.PURPLE
		2: # Strong (ArmoredOrc, EliteOrc, Werewolf) — high value
			if roll < 0.20: return GemTier.GREEN
			elif roll < 0.50: return GemTier.YELLOW
			elif roll < 0.80: return GemTier.RED
			else: return GemTier.PURPLE
		3: # Boss — always purple/red
			if roll < 0.30: return GemTier.RED
			else: return GemTier.PURPLE
		_:
			return GemTier.GREEN
