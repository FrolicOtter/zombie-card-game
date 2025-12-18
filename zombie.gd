extends Area2D

# FIX: Use Vector2i for grid coordinates to avoid float errors
var main_node: Node
var tile_size := 64
var health := 30

func _ready():
	# Ensure alignment on spawn
	position = position.snapped(Vector2.ONE * tile_size)

func setup(_main_node):
	main_node = _main_node

func take_turn():
	if not main_node:
		return

	var my_tile: Vector2i = main_node.world_to_tile(position)
	var player_tile: Vector2i = main_node.world_to_tile(main_node.player.position)

	var path: Array[Vector2i] = main_node.get_pathfinding(my_tile, player_tile)

	if path.size() > 1:
		var next_tile: Vector2i = path[1]
		var tile_data = main_node.tilemap.get_cell_tile_data(next_tile)

		# 1. Check for Walls (Existing logic)
		if tile_data and tile_data.get_custom_data("isWall"):
			#print("Zombie bumps into wall at ", next_tile)
			pass
		# 2. Check if the tile is occupied by Player or Zombie
		elif main_node.is_tile_occupied(next_tile):
			# If the thing blocking us is the player, we attack!
			if next_tile == player_tile:
				var damage = randi_range(1, 3)
				print("Zombie attacks player for ", damage, " damage!")
				# Apply damage and knockback
				main_node.player.take_damage(damage, position)
				# We intentionally do NOT move here, preventing overlap.
			else:
				#print("Zombie blocked by another zombie at ", next_tile)
				pass

		# 3. Path is clear, move there
		else:
			position = main_node.tile_to_world(next_tile)

func take_damage(amount: int):
		health -= amount
		print("Zombie took ", amount, " damage. HP: ", health)
		if health <= 0:
				die()

func die():
		if main_node:
				main_node.zombies.erase(self)
		queue_free()

func _input_event(_viewport, event, _shape_idx):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if main_node and main_node.player and main_node.player.has_method("on_zombie_clicked"):
						main_node.player.on_zombie_clicked(self)
