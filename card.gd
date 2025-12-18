extends Button

signal card_used(card_node)
signal card_selected_for_removal(card_node)
signal turn_ended

var card_name = ""
var in_removal_mode = false
var uses_left := 1
var targeting_lock := false

func _ready():
	pressed.connect(_on_pressed)

func set_card(name: String):
		card_name = name
		uses_left = get_initial_uses(card_name)
		_update_card_text()

func _update_card_text():
		if uses_left > 1:
				text = "%s (%d)" % [card_name, uses_left]
		else:
				text = card_name

func get_initial_uses(name: String) -> int:
		match name:
				"Baseball Bat":
						return 3
				"Hammer":
						return 2
				"Fire Extinguisher":
						return 2
				"Scalpel":
						return 4
				"Bow":
						return 5
				_:
						return 1

func set_removal_mode(enabled: bool):
		in_removal_mode = enabled
		if enabled:
				modulate = Color(1, 0.5, 0.5)  # Red tint
		else:
				modulate = Color(1, 1, 1)  # Normal
		disabled = targeting_lock

func set_targeting_state(enabled: bool):
		targeting_lock = enabled
		disabled = targeting_lock

func consume_use():
		uses_left -= 1
		if uses_left <= 0:
				card_used.emit(self)
		else:
				_update_card_text()

func cancel_targeting_if_active():
		if targeting_lock:
				set_targeting_state(false)

func _on_pressed():
		if in_removal_mode:
				card_selected_for_removal.emit(self)
				return

		if targeting_lock:
				return

		# Normal card usage
		var player = get_tree().get_first_node_in_group("player")

		if player:
				var card_consumed := true
				var uses_managed_by_player := false
				match card_name:
						"Medkit":
								player.heal(30)
						"Bandaid":
								player.heal(10)
						"Baseball Bat":
								uses_managed_by_player = true
								card_consumed = player.request_targeted_attack(15, 2, 0, 1.0, self)
						"Hammer":
								uses_managed_by_player = true
								card_consumed = player.request_targeted_attack(18, 2, 0, 1.0, self)
						"Fire Extinguisher":
								uses_managed_by_player = true
								card_consumed = player.request_targeted_attack(12, 2, 0, 1.0, self)
						"Scalpel":
								uses_managed_by_player = true
								card_consumed = player.request_targeted_attack(10, 1, 0, 0.7, self)
						"Bow":
								uses_managed_by_player = true
								card_consumed = player.request_targeted_attack(20, 3, 2, 0.6, self)
						"Canned Food":
								player.heal(15)
						"Antibiotics":
							player.heal(5)
							player.start_regeneration(2, 5)
						"Backpack":
							player.apply_backpack()
							card_consumed = true
						"Flashlight":
							player.apply_flashlight()
							card_consumed = false
						"Energy Drink":
							card_consumed = player.consume_energy_drink()
						_:
							print("Card not implemented: ", card_name)

				if card_consumed:
						print("Used ", card_name)
						if not uses_managed_by_player:
								consume_use()
				player.turn_ended.emit()
