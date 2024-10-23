extends Node2D

const PLAYER_SCENE := preload("res://Prefabs/player_1.tscn")
var scores = {}

const ITEM_PREFABS = {
	"apple": preload("res://Prefabs/apple.tscn"),
	"trash": preload("res://Prefabs/trash.tscn")
}

# Change items from Array to Dictionary
var items = {}

func _ready():
	randomize()
	if not is_multiplayer_authority():
		set_physics_process(false)
	else:
		for i in range(10):
			spawnItemFromList([ITEM_PREFABS.apple, ITEM_PREFABS.trash])

	Lobby.add_new_player.connect(_on_add_new_player)
	Lobby.delete_player.connect(_on_delete_player)

func server_disconnected():
	call_deferred('queue_free')

func sync_item_data():
	var item_data = []
	for item_id in items.keys():
		var item = items[item_id]
		if item["instance"] != null and item["instance"].is_inside_tree():
			item_data.append({
				"scene_path": item["scene_path"],
				"spawn_point_path": item["spawn_point_path"]
			})
	# Only call RPC if there are updates
	if item_data.size() > 0:
		rpc("receive_item_data_update", item_data)

@rpc("authority", "call_local")
func receive_item_data_update(item_data_array):
	var updated_item_ids = []
	var items_to_delete = []  # List to track items to delete
	
	# Check for items to delete
	for item_id in items.keys():
		var local_item = items[item_id]["instance"]
		if local_item == null or not local_item.is_inside_tree():
			continue  # Skip if the item is already freed

		var found = false
		
		for data in item_data_array:
			var scene_path = data["scene_path"]
			var spawn_point_path = data["spawn_point_path"]
			var id = scene_path + ":" + str(spawn_point_path)  # Unique item ID
			
			if item_id == id:
				found = true
				updated_item_ids.append(id)  # Keep track of items that are still valid
				break
		
		# Mark it for deletion if not found
		if not found:
			print("Marking item for deletion: ", item_id)
			items_to_delete.append(item_id)

	# Delete marked items
	for item_id in items_to_delete:
		var item_instance = items[item_id]["instance"]
		if item_instance.is_inside_tree():
			item_instance.queue_free()  # Delete the item
		items.erase(item_id)  # Remove from dictionary

	# Spawn new items
	for data in item_data_array:
		var scene_path = data["scene_path"]
		var spawn_point_path = data["spawn_point_path"]
		var item_id = scene_path + ":" + str(spawn_point_path)
		
		if item_id not in updated_item_ids:
			print("Spawning new item: ", item_id)
			spawnItem(scene_path, spawn_point_path)

func spawnItem(scene_path: String, spawn_point_path: String = ""):
	var item_scene = load(scene_path)
	var _item = item_scene.instantiate()
	
	var point: Marker2D = null
	
	if spawn_point_path == "":
		point = choose_random_empty_item_spawn_point()
		if point == null:
			print("No empty spawn points available")
			return
	else:
		point = get_node_or_null(spawn_point_path) as Marker2D
	
	if point != null and point.get_child_count() == 0:
		# Generate a unique item_id
		_item.item_id = scene_path + ":" + str(point.get_path())
		
		# Store item info in the Dictionary
		items[_item.item_id] = {
			"instance": _item,
			"scene_path": scene_path,
			"spawn_point_path": point.get_path()  # Store the spawn point path
		}

		# Add the item to the scene and position it
		point.add_child(_item)
		_item.global_position = point.global_position
		
		# Connect the item deletion signal
		_item.item_deleted.connect(_on_item_deleted)
		sync_item_data()

func spawnItemFromList(item_pool):
	# Use the consolidated spawnItem function with a random scene path from the pool
	spawnItem(item_pool.pick_random().resource_path)

func _on_item_deleted(item_id):
	print("Attempting to delete item with ID: ", item_id)

	if items.has(item_id):
		var item_instance = items[item_id]["instance"]
		if item_instance.is_inside_tree():  # Ensure the instance is still in the scene tree
			item_instance.queue_free()  # Delete the item
			items.erase(item_id)  # Remove from dictionary
			print("Removed item: ", item_id)
			spawnItemFromList([ITEM_PREFABS.apple, ITEM_PREFABS.trash])
		else:
			print("Item instance is not in the scene tree, skipping deletion.")

func _on_add_new_player(id: int):
	if not PLAYER_SCENE.can_instantiate(): return
	
	var player := PLAYER_SCENE.instantiate()
	player.name = str(id)
	
	player.global_position = choose_random_spawn_point().global_position
	get_node("Players").add_child(player)
	
	if is_multiplayer_authority():
		sync_item_data()

func choose_random_spawn_point() -> Marker2D:
	var spawn_positions := get_node("PlayerSpawnPoints").get_children()
	return spawn_positions.pick_random()
	
func choose_random_empty_item_spawn_point() -> Marker2D:
	var spawn_positions := get_node("ItemSpawnPoints").get_children()
	var _spawn_positions = []

	# Get a list of player positions
	var players = get_node("Players").get_children()
	var player_positions = []
	for player in players:
		player_positions.append(player.global_position)

	for spawn_pos in spawn_positions:
		if spawn_pos.get_child_count() == 0:  # Check if spawn point is empty
			var is_too_close = false
			for player_pos in player_positions:
				if spawn_pos.global_position.distance_to(player_pos) < 75:  # Check distance
					is_too_close = true
					break
			if not is_too_close:
				_spawn_positions.append(spawn_pos)

	if _spawn_positions.size() == 0:
		return null

	return _spawn_positions.pick_random()

func _on_delete_player(id: int) -> void:
	var player := get_node_or_null("Players/" + str(id))
	if player: player.call_deferred("queue_free")
