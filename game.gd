extends Node2D

const PLAYER_SCENE := preload("res://Prefabs/player_1.tscn")

func _ready():
	randomize()
	Lobby.add_new_player.connect(_on_add_new_player)
	Lobby.delete_player.connect(_on_delete_player)

func server_disconnected():
	call_deferred('queue_free')


func _on_add_new_player(id: int):
	if not PLAYER_SCENE.can_instantiate(): return
	
	var player := PLAYER_SCENE.instantiate()
	player.name = str(id)
	
	player.global_position = choose_random_spawn_point().global_position
	get_node("Players").add_child(player)


func choose_random_spawn_point() -> Marker2D:
	var spawn_positions := get_node("SpawnPoints").get_children()
	return spawn_positions.pick_random()

func _on_delete_player(id: int) -> void:
	var player := get_node_or_null("Players/" + str(id))
	if player: player.call_deferred("queue_free")

