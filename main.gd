extends Node

@export var tilemap: TileMapLayer
var player

# FIX: AStarGrid2D is significantly faster and handles the grid logic internally
var astar = AStarGrid2D.new()
var tile_size := 64 

var zombies := []
var current_turn := 1
var score: int = 0
func _ready():
	# Ensure references are set
	tilemap = $TileMapLayer
	player = $Player
	
	# Inject Main dependency into Player (needed for knockback validation)
	if player.has_method("setup"):
		player.setup(self)

	# Build the optimized grid
	setup_astar_grid()
	
	player.turn_ended.connect(_on_player_turn_ended)
	$MainMenu.visible = true

func setup_astar_grid():
	var used_rect = tilemap.get_used_rect()
	
	astar.region = used_rect
	astar.cell_size = Vector2(tile_size, tile_size)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update() # Build geometry first
	
	# Iterate over every tile in the grid to assign weights
	for x in range(used_rect.position.x, used_rect.end.x):
		for y in range(used_rect.position.y, used_rect.end.y):
			var tile_pos = Vector2i(x, y)
			var tile_data = tilemap.get_cell_tile_data(tile_pos)
			
			var weight = 0.0 # Default weight for unknown zones
			
			if tile_data:
				var zone = tile_data.get_custom_data("zone")
				var is_wall = tile_data.get_custom_data("isWall")
				
				# 1. Apply Zone Costs
				# Zone 0, 1 -> Cost 2
				if zone == 0 or zone == 1:
					weight = 2.0
				# Zone 2, 3, 4 -> Cost 1
				elif zone == 2 or zone == 3 or zone == 4:
					weight = 0.0
				
				# 2. Apply Wall Cost
				# Walls cost 20 (expensive, but theoretically passable)
				if is_wall:
					weight = 20.0
			
			# Apply the calculated weight to the AStar grid point
			astar.set_point_weight_scale(tile_pos, weight)

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(world_pos)

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return tilemap.map_to_local(tile_pos)

func get_pathfinding(from_tile: Vector2i, to_tile: Vector2i) -> Array[Vector2i]:
	# Dictionary to remember the original weights of tiles we change
	var original_weights = {}
	
	# 1. SOFT OBSTACLES: Mark other zombies as High Cost (e.g., 30.0)
	# This discourages walking through them, but keeps the path "possible"
	# so AStar will look for a way around (flanking).
	for z in zombies:
		var z_tile = world_to_tile(z.position)
		if z_tile != from_tile and z_tile != to_tile:
			# Save the original weight (so we don't break zone costs)
			original_weights[z_tile] = astar.get_point_weight_scale(z_tile)
			
			# Apply a high penalty.
			# If a normal step is 1.0, making this 30.0 means the zombie
			# would rather walk 29 tiles around than 1 tile through a friend.
			astar.set_point_weight_scale(z_tile, 30.0) 

	# 2. Calculate path
	# AStar will now return the flanking path because it is "cheaper"
	var path = astar.get_id_path(from_tile, to_tile)
	
	# 3. CLEANUP: Restore original weights immediately
	for z_tile in original_weights:
		astar.set_point_weight_scale(z_tile, original_weights[z_tile])
			
	return path

func spawn_zombie(tile_pos: Vector2 = Vector2.ZERO):
	var zombie = preload("res://zombie.tscn").instantiate()
	add_child(zombie)
	
	var spawn_tile = Vector2i(tile_pos) if tile_pos != Vector2.ZERO else get_random_walkable_tile()
	
	zombie.position = tile_to_world(spawn_tile)
	zombie.setup(self) # Uses the setup function for cleaner injection
	zombies.append(zombie)

func _on_player_turn_ended():
	print("Player finished turn. Zombies moving...")
	
	for zombie in zombies:
		zombie.take_turn()
		
	current_turn += 1
	print("Turn: ", current_turn)
	randf_range(1,10)
	if current_turn%10 == 0:
		if randi_range(0,10) >= 5:
			spawn_zombie()
			print("Zombie: New Zombie Spawned")
	var health = player.health
	add_score(1)
	player.start_turn()

func get_random_walkable_tile() -> Vector2i:
	var used_rect = tilemap.get_used_rect()
	var attempts = 0
	
	while attempts < 100:
		var random_x = randi_range(used_rect.position.x, used_rect.end.x - 1)
		var random_y = randi_range(used_rect.position.y, used_rect.end.y - 1)
		var tile_coords = Vector2i(random_x, random_y)
		
		# Check if tile exists AND is not occupied
		if tilemap.get_cell_source_id(tile_coords) != -1 and not is_tile_occupied(tile_coords):
			return tile_coords
		
		attempts += 1
	
	return Vector2i.ZERO

# Add this helper function to check for any entity on a tile
func is_tile_occupied(tile_pos: Vector2i) -> bool:
	# Check if Player is on this tile
	if world_to_tile(player.position) == tile_pos:
		return true
		
	# Check if any Zombie is on this tile
	for zombie in zombies:
		if world_to_tile(zombie.position) == tile_pos:
			return true
			
	return false


func _on_main_menu_start_game(character: Variant) -> void:
	print("Game Starting with character: ", character)
	
	# Set the character on the player so the correct sprite/stats load
	print(character)
	player.character = character 
	player.set_animation()
	# Spawn initial zombies (Moved here from _ready)
	for i in range(3):
		spawn_zombie()
	$MainMenu.visible = false
	# NOW we allow the player to move
	player.locked = false
	player.start_turn()


func _on_player_game_over() -> void:
	$HUD/CardInfo.text = "[b] Game Over\nFinal Score: " + str(score) + "[/b]"
	$HUD/Button.visible = true
	player.locked = true
func add_score(amount: int):
	score += amount
	print("Score added: ", amount, " Total: ", score)
	# Update HUD immediately so the player sees the number go up
	if player:
		$HUD.update_ui(score, player.health)
