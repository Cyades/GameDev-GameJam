extends Node

var click_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	click_player = AudioStreamPlayer.new()
	click_player.stream = preload("res://Assets GameJam/Ninja Adventure - Asset Pack/Audio/Sounds/Menu/Menu5.wav")
	click_player.bus = "SFX"
	add_child(click_player)

func play_click() -> void:
	if click_player:
		click_player.play()
