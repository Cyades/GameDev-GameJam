extends Node

const MENU_MUSIC = preload("res://Assets GameJam/Music/Ember-Crown Main Menu.mp3")
const BATTLE_1 = preload("res://Assets GameJam/Music/Steel Anthem (1) Early Mid.mp3")
const BATTLE_2 = preload("res://Assets GameJam/Music/Steel Anthem continue after (1).mp3")
const BOSS_MUSIC = preload("res://Assets GameJam/Music/Dominus Irae Boss.mp3")
const GAME_OVER_MUSIC = preload("res://Assets GameJam/Music/Echo After the Fall Game Over.mp3")
const WIN_MUSIC = preload("res://Assets GameJam/Music/Huzzah at the Finish Line WIN.mp3")
const GACHA_MUSIC = preload("res://Assets GameJam/Music/Pull The Legend Gacha.mp3")

var player1: AudioStreamPlayer
var player2: AudioStreamPlayer
var active_player: AudioStreamPlayer
var crossfade_tween: Tween

var current_state: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Always process so tween works during pause
	
	player1 = AudioStreamPlayer.new()
	player1.bus = "Music" # Assumes you have a "Music" audio bus, if not it routes to Master
	add_child(player1)
	
	player2 = AudioStreamPlayer.new()
	player2.bus = "Music"
	add_child(player2)
	
	active_player = player1
	
	player1.finished.connect(_on_track_finished.bind(player1))
	player2.finished.connect(_on_track_finished.bind(player2))

func play_track(stream: AudioStream, fade_duration: float = 1.5) -> void:
	if active_player.stream == stream and active_player.playing:
		return # Already playing this track
		
	var next_player = player2 if active_player == player1 else player1
	
	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()
	
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()
		
	crossfade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Fade out current
	if active_player.playing:
		crossfade_tween.tween_property(active_player, "volume_db", -80.0, fade_duration)
	
	# Fade in next
	crossfade_tween.parallel().tween_property(next_player, "volume_db", 0.0, fade_duration)
	
	# After fade, stop the old player
	crossfade_tween.tween_callback(active_player.stop)
	
	active_player = next_player

func _on_track_finished(player: AudioStreamPlayer) -> void:
	# Only handle sequential logic if the player that finished is the active one
	if player != active_player:
		return
		
	if player.stream == BATTLE_1:
		# BATTLE_1 finishes -> play BATTLE_2
		play_track(BATTLE_2, 0.0) # instant switch
	elif player.stream == BATTLE_2:
		# BATTLE_2 finishes -> loop back to BATTLE_1
		play_track(BATTLE_1, 0.0) # instant switch
	else:
		# For other tracks, just loop them
		player.play()

# Helper methods for states
func play_menu_music() -> void:
	current_state = "menu"
	play_track(MENU_MUSIC)

func play_battle_music() -> void:
	current_state = "battle"
	play_track(BATTLE_1)

func play_boss_music() -> void:
	current_state = "boss"
	play_track(BOSS_MUSIC, 2.0)

func play_gacha_music() -> void:
	current_state = "gacha"
	play_track(GACHA_MUSIC, 0.5)

func resume_battle_music() -> void:
	if current_state != "battle":
		current_state = "battle"
		play_track(BATTLE_1, 2.0)

func play_game_over_music() -> void:
	current_state = "game_over"
	play_track(GAME_OVER_MUSIC, 3.0)

func play_win_music() -> void:
	current_state = "win"
	play_track(WIN_MUSIC, 2.0)
