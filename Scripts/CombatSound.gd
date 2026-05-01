extends Node

var impact_sound = preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Hit & Impact/Impact.wav")
var fire_sound = preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Elemental/Fire.wav")
var fire2_sound = preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Elemental/Fire2.wav")

var slash_sounds = [
	preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Slash.wav"),
	preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Slash2.wav"),
	preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Slash3.wav"),
	preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Slash4.wav"),
	preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Slash5.wav"),
	preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Whoosh.wav"),
	preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Whoosh & Slash/Whoosh2.wav")
]

func play_impact(caller: Node2D) -> void:
	_play_sound(caller, impact_sound)

func play_fire(caller: Node2D) -> void:
	_play_sound(caller, fire_sound)
	
func play_fire2(caller: Node2D) -> void:
	_play_sound(caller, fire2_sound)

func play_random_slash(caller: Node2D) -> void:
	var snd = slash_sounds[randi() % slash_sounds.size()]
	_play_sound(caller, snd)

func _play_sound(caller: Node2D, stream: AudioStream) -> void:
	if not is_instance_valid(caller): return
	var p = AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = "SFX"
	caller.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
