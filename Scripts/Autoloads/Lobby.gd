extends Node

# Signals to notify when a new player joins or a player disconnects.
signal add_new_player
signal delete_player

# Preload the game world scene.
const WORLD_SCENE := preload("res://game.tscn")

# Dictionary to store player information (ID, name, etc.).
var players = {}
var peer := ENetMultiplayerPeer.new() # Create a new ENet peer for networking.


func _ready():
	# Connect multiplayer signals for player connections, disconnections, and server status changes.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# Method for a player (client) to join a server.
func join_server(ip_address: String, port: int):
	var error = peer.create_client(ip_address, port) # Create a client connection.
	if not error == OK: return error # Return the error if connection fails.

	multiplayer.set_multiplayer_peer(peer) # Set the peer for multiplayer operations.


# Method to start a server (host).
func start_server(server_port: int, max_clients: int):
	var error = peer.create_server(server_port, max_clients) # Create a server.
	if not error == OK: return error # Return the error if server creation fails.

	multiplayer.set_multiplayer_peer(peer) # Set the peer for multiplayer operations.
	
	
	var peer_id = multiplayer.get_unique_id() # Get the unique ID for the server host (self).
	
	# # Store the player's info
	players[peer_id] = { "player_name": GameManager.local_user_name }
	
	# Instance the game world and emit signal to add this player.
	instance_world()
	add_new_player.emit(peer_id)


# Callback when a new peer (player) connects.
func _on_peer_connected(id: int):
	if not multiplayer.is_server(): return # Only the server needs to handle this.
	
	# Inform the new player about the existing players.
	for existing_peer_id in players.keys():
		var player_info = players[existing_peer_id]
		rpc_id(id, "instance_player", existing_peer_id, player_info["player_name"]) # Send info to the new player.


# Callback when a peer (player) disconnects.
func _on_peer_disconnected(id):
	if not multiplayer.is_server(): return # Only the server needs to handle this.
	
	# Remove the disconnected player from the player list.
	players.erase(id)
	rpc("remove_player", id) # Notify all clients to remove the disconnected player


# Callback when connected to a server.
func _on_connected_to_server():
	# Notify the server of the player's name and ID.
	register_players.rpc_id(1, GameManager.local_user_name, multiplayer.get_unique_id())
	instance_world() # Instance the game world for this player.


# Helper method to instance the game world scene.
func instance_world():
	if not WORLD_SCENE.can_instantiate(): return # Ensure the scene is instantiable.
	
	var world = WORLD_SCENE.instantiate() # Instance the game world.
	get_tree().root.add_child(world) # Add the world to the scene tree.


# Callback when connection to the server fails.
func _on_connection_failed():
	multiplayer.set_multiplayer_peer(null) # Reset multiplayer peer.


# Callback when the server disconnects.
func _on_server_disconnected():
	multiplayer.set_multiplayer_peer(null) # Reset multiplayer peer.
	get_tree().call_group('World', 'server_disconnected') # Inform the game world of the disconnection.


# Remote procedure call to instance a player on all clients.
@rpc("authority", "call_local", "reliable")
func instance_player(id: int, _player_name: String) -> void:
	add_new_player.emit(id) # Emit signal to add the new player.


# Remote procedure call to remove a player on all clients.
@rpc("authority", "call_local", "reliable")
func remove_player(id: int):
	delete_player.emit(id) # Emit signal to remove the player.


# Remote procedure call to register players with their name and ID.
@rpc("any_peer", "call_local", "reliable")
func register_players(peer_name: String, peer_id: int) -> void:
	if players.has(peer_id): return # Do nothing if the player is already registered.
	
	# Register the new player's name and ID.
	players[peer_id] = { "player_name": peer_name }
	
	# Inform all clients about the new player.
	rpc("instance_player",  peer_id, players[peer_id].player_name)
