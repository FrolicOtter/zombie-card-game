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
var max_hand_size := 5
var has_backpack := false
var has_flashlight := false
var regen_turns_left := 0
var regen_amount := 0
var awaiting_turn := false
var moves_remaining := 1
var pending_attack := {}

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

func start_turn():
		awaiting_turn = false
		moves_remaining = 1
		_clear_targeting_state()
		process_regeneration()
		var hud = get_hud()
		if hud:
				hud.set_max_hand_size(max_hand_size)
				hud.enforce_hand_limit()

func _process(_delta):
	if moving or awaiting_turn:
		return

	var hud = get_hud()
	if hud and hud.is_blocking_actions():
		return

	var input_dir = Vector2i.ZERO
	var action_taken = false
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
		action_taken = move_player(input_dir)

	if Input.is_action_just_pressed("search"):
		action_taken = true
		attempt_search()

	if action_taken:
		handle_action_spent()

func handle_action_spent():
	moves_remaining -= 1
	if moves_remaining <= 0:
		awaiting_turn = true
		turn_ended.emit()

func attempt_search():
	var tile = tilemap.get_cell_tile_data(tilemap.local_to_map(position))
	if tile == null:
		return

	var type = tile.get_custom_data("zone")
	var cards = []
	var search_chance = 50
	if has_flashlight_card():
		search_chance = 75

	if randf_range(1,100) <= search_chance:
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
		if cards.size() > 0:
			var card = cards.pick_random()
			print("Found Card: ", card, " on tile type ", type)

			var hud = get_hud()
			if hud:
				hud.add_card(card)

func get_hud():
	if get_parent().has_node("HUD"):
		return get_parent().get_node("HUD")
	return null

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

func has_flashlight_card() -> bool:
	var hud = get_hud()
	if hud:
		return hud.has_card("Flashlight")
	return has_flashlight

func start_regeneration(amount: int, turns: int):
	regen_amount = amount
	regen_turns_left = turns

func process_regeneration():
	if regen_turns_left > 0:
		heal(regen_amount)
		regen_turns_left -= 1
		if regen_turns_left == 0:
			regen_amount = 0

func get_zombies_in_range(max_range: int, min_range: int) -> Array:
		if not main_node:
				return []

		var zombies_in_range: Array = []
		for zombie in main_node.zombies:
				var distance = position.distance_to(zombie.position)
				if distance <= max_range * tile_size and distance >= min_range * tile_size:
						zombies_in_range.append(zombie)

		return zombies_in_range

func request_targeted_attack(damage: int, max_range: int = 2, min_range: int = 0, hit_chance: float = 1.0, card_node = null) -> bool:
		var zombies_in_range = get_zombies_in_range(max_range, min_range)

		if zombies_in_range.is_empty():
				print("No zombie in range!")
				return false

		if zombies_in_range.size() == 1:
				return _attempt_attack_on_zombie(zombies_in_range[0], damage, hit_chance, card_node)

		pending_attack = {
				"damage": damage,
				"max_range": max_range,
				"min_range": min_range,
				"hit_chance": hit_chance,
				"card_node": card_node
		}

		if card_node and card_node.has_method("set_targeting_state"):
				card_node.set_targeting_state(true)

		var hud = get_hud()
		if hud and hud.has_method("set_targeting_mode"):
				hud.set_targeting_mode(true)

		print("Multiple zombies in range. Click a zombie to attack.")
		return false

func on_zombie_clicked(zombie):
		if pending_attack.is_empty():
				return

		if not main_node or not main_node.zombies.has(zombie):
				_clear_targeting_state()
				return

		var max_range = pending_attack.get("max_range", 2)
		var min_range = pending_attack.get("min_range", 0)
		var distance = position.distance_to(zombie.position)
		if distance > max_range * tile_size or distance < min_range * tile_size:
						print("Selected zombie out of range.")
						return

		_attempt_attack_on_zombie(
				zombie,
				pending_attack.get("damage", 0),
				pending_attack.get("hit_chance", 1.0),
				pending_attack.get("card_node", null)
		)

		_clear_targeting_state()

func _attempt_attack_on_zombie(zombie, damage: int, hit_chance: float, card_node) -> bool:
		if randf() > hit_chance:
				print("Attack missed!")
		else:
				zombie.take_damage(damage)
				print("Hit zombie for ", damage, " damage!")

		if not pending_attack.is_empty() and card_node:
				print("Used ", card_node.card_name)

		if card_node and card_node.has_method("consume_use"):
				card_node.consume_use()

		return true

func _clear_targeting_state():
		if pending_attack.has("card_node") and is_instance_valid(pending_attack.card_node) and pending_attack.card_node.has_method("set_targeting_state"):
				pending_attack.card_node.set_targeting_state(false)

		var hud = get_hud()
		if hud and hud.has_method("set_targeting_mode"):
				hud.set_targeting_mode(false)

		pending_attack.clear()

func attack_nearest_zombie(damage: int, max_range: int = 2, min_range: int = 0, hit_chance: float = 1.0) -> bool:
		return request_targeted_attack(damage, max_range, min_range, hit_chance)

func apply_backpack() -> bool:
	if has_backpack:
		print("Already have a backpack equipped.")
		return false

	has_backpack = true
	max_hand_size += 2
	remove_card_from_pools("Backpack")
	var hud = get_hud()
	if hud:
		hud.set_max_hand_size(max_hand_size)
		hud.enforce_hand_limit()
	return true

func apply_flashlight():
	if has_flashlight:
		return
	has_flashlight = true
	remove_card_from_pools("Flashlight")

func consume_energy_drink() -> bool:
	moves_remaining += 1
	print("Energy boost! Extra movement this turn: ", moves_remaining)
	return true

func on_card_added(card_name: String):
		if card_name == "Backpack":
				remove_card_from_pools("Backpack")
		if card_name == "Flashlight":
				apply_flashlight()

func remove_card_from_pools(card_name: String):
	card_normal = card_normal.filter(func(c): return c != card_name)
	card_hospital = card_hospital.filter(func(c): return c != card_name)
	card_supermarket = card_supermarket.filter(func(c): return c != card_name)
	card_construction = card_construction.filter(func(c): return c != card_name)

func has_card_in_hand(card_name: String) -> bool:
	var hud = get_hud()
	if hud:
		return hud.has_card(card_name)
	return false
