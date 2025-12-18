class_name Player
extends CharacterBody2D

signal turn_ended

var tile_size := 64
var moving := false
@export var tilemap: TileMapLayer
var main_node: Node # Reference to main for knockback validation
@export var HUD: PackedScene
# Health Stats
var max_health := 25
var health := 25

# Duplicates = higher chance (weighted lists)
# Backpack + Flashlight are extra rare everywhere
# Weapons more common than heals;
var card_normal := [
	"Baseball Bat","Baseball Bat","Baseball Bat",
	"Fire Extinguisher",
	"Bandaid",
	"Flashlight",   # rare
	"Backpack"      # extra rare
]

var card_hospital := [
	"Bandaid","Bandaid","Bandaid","Bandaid",
	"Medkit","Medkit",
	"Scalpel","Scalpel",
	"Fire Extinguisher",
	"Baseball Bat",
	"Flashlight",   # rare
	"Backpack"      # extra rare
]

var card_supermarket := [
	"Canned Food","Canned Food","Canned Food","Canned Food",
	"Energy Drink","Energy Drink","Energy Drink",
	"Fire Extinguisher","Fire Extinguisher",
	"Baseball Bat",
	"Bandaid",
	"Flashlight",   # rare
	"Backpack"      # extra rare
]

var card_construction := [
	"Hammer","Hammer","Hammer",
	"Barricade","Barricade",
	"Fire Extinguisher","Fire Extinguisher",
	"Baseball Bat",
	"Bandaid",
	"Flashlight",   # rare
	"Backpack"      # extra rare
]

func _ready():
	setup_camera_limits()
	add_to_group("player")


func setup(_main_node):
	main_node = _main_node

func setup_camera_limits():
	var camera = $Camera2D  # Assuming Camera2D is child of Player
	if not camera:
		push_error("No Camera2D found as child of Player!")
		return
	
	var used_rect = tilemap.get_used_rect()
	
	camera.limit_left = used_rect.position.x * tile_size
	camera.limit_top = used_rect.position.y * tile_size
	camera.limit_right = (used_rect.position.x + used_rect.size.x) * tile_size
	camera.limit_bottom = (used_rect.position.y + used_rect.size.y) * tile_size

func _process(_delta):
	# If we are strictly turn-based, we don't need delta
	if moving:
		return
		
	var input_dir = Vector2i.ZERO
	var turn_done = false
	# Map inputs directly to Vector2i for cleaner grid math
	if Input.is_action_just_pressed("ui_right"):
		input_dir = Vector2i.RIGHT
	elif Input.is_action_just_pressed("ui_left"):
		input_dir = Vector2i.LEFT
	elif Input.is_action_just_pressed("ui_down"):
		input_dir = Vector2i.DOWN
	elif Input.is_action_just_pressed("ui_up"):
		input_dir = Vector2i.UP

	if input_dir != Vector2i.ZERO:
		turn_done = move_player(input_dir)
		
	if Input.is_action_just_pressed("search"):
		var tile = tilemap.get_cell_tile_data(tilemap.local_to_map(position))
		var type
		if tilemap.get_cell_source_id(tilemap.local_to_map(position)) != -1:
			type = tile.get_custom_data("zone")
		var cards = []
		if randf_range(1,100) >= 50:
			match type:
				0:
					cards = card_normal
				1:
					cards = card_construction
				2: 
					cards = card_hospital
				3:
					cards = card_supermarket
				4:
					cards = card_normal
			var card = cards.pick_random()
			print("Found Card: ", card, " on tile type ", type)
			
			# ADD THIS: Give card to HUD
			var hud = get_parent().get_node("HUD")
			hud.add_card(card)
		turn_done = true
	if turn_done:
		turn_ended.emit()

func move_player(direction: Vector2i):
	# Calculate target in Grid Coordinates first
	var current_tile: Vector2i = tilemap.local_to_map(position)
	var target_tile: Vector2i = current_tile + direction
	
	var tile_data = tilemap.get_cell_tile_data(target_tile)

	# Check boundaries/existence
	if tile_data == null:
		return false

	# Check for Wall Custom Data
	if tile_data.get_custom_data("isWall"):
		return false
	
	# Check for Zombie Blocking (Optional, prevents walking into enemies)
	if main_node and main_node.is_tile_occupied(target_tile):
		print("Blocked by something!")
		return false

	# Move the player
	position = tilemap.map_to_local(target_tile)
	return true

func take_damage(amount: int, source_world_pos: Vector2):
	health -= amount
	print("Player Hit! Took ", amount, " damage. Health: ", health, "/", max_health)
	
	if health <= 0:
		print("GAME OVER - Player Died")
		# Handle Game Over Logic here (e.g. get_tree().reload_current_scene())
		return

	# --- Knockback Logic ---
	if main_node:
		var my_tile = tilemap.local_to_map(position)
		var attacker_tile = tilemap.local_to_map(source_world_pos)
		
		# Calculate direction away from attacker
		var knockback_dir: Vector2i = my_tile - attacker_tile
		var target_tile: Vector2i = my_tile + knockback_dir
		
		# Validate the knockback tile
		var tile_data = tilemap.get_cell_tile_data(target_tile)
		
		# 1. Check if tile exists and is NOT a wall
		var is_valid_floor = tile_data and not tile_data.get_custom_data("isWall")
		
		# 2. Check if tile is NOT occupied by another entity
		var is_empty = not main_node.is_tile_occupied(target_tile)
		
		if is_valid_floor and is_empty:
			position = tilemap.map_to_local(target_tile)
			print("Player knocked back to ", target_tile)
		else:
			print("Knockback blocked by wall or object.")
func heal(amount: int):
	health = min(health + amount, max_health)
	print("Player healed! HP: ", health)
	# Update HUD here if you have health displayx
