extends CanvasLayer

@onready var card_container = $HBoxContainer
var max_hand_size := 5
var pending_card: String = ""
var replacement_mode = false
var force_discard_mode = false
var targeting_mode = false

func add_card(card_name: String):
	var player = get_tree().get_first_node_in_group("player")
	if (card_name == "Backpack" or card_name == "Flashlight") and has_card(card_name):
		print(card_name, " already in hand. Skipping duplicate.")
		return

	if player:
		player.on_card_added(card_name)

	if card_container.get_child_count() >= max_hand_size:
		pending_card = card_name
		replacement_mode = true
		force_discard_mode = false
		print("Hand full! Click a card to replace.")
		highlight_cards_for_removal()
	else:
		create_card(card_name)
	enforce_hand_limit()

func create_card(card_name: String):
	var card_ui = preload("res://card.tscn").instantiate()
	card_container.add_child(card_ui)
	card_ui.set_card(card_name)
	card_ui.card_used.connect(_on_card_used)
	card_ui.card_selected_for_removal.connect(_on_card_removal)

func highlight_cards_for_removal():
	for card in card_container.get_children():
		card.set_removal_mode(true)

func clear_removal_highlight():
	for card in card_container.get_children():
		card.set_removal_mode(false)

func _on_card_used(card_node):
	card_node.queue_free()
	enforce_hand_limit()

func _on_card_removal(card_node):
	if replacement_mode and pending_card != "":
		card_node.queue_free()
		create_card(pending_card)
		pending_card = ""
		replacement_mode = false
		force_discard_mode = false
		clear_removal_highlight()
		print("Card replaced!")

	else:
		card_node.queue_free()

	enforce_hand_limit()

func enforce_hand_limit():
		var child_count = card_container.get_child_count()

		if child_count > max_hand_size:
				force_discard_mode = true
				replacement_mode = true
				pending_card = ""
				highlight_cards_for_removal()
				print("Hand over limit! Discard cards.")
				return

		if pending_card != "":
				force_discard_mode = false
				replacement_mode = true
				highlight_cards_for_removal()
				return

		force_discard_mode = false
		replacement_mode = false
		clear_removal_highlight()

func set_max_hand_size(limit: int):
	max_hand_size = limit
	enforce_hand_limit()

func is_blocking_actions() -> bool:
				return force_discard_mode or replacement_mode or targeting_mode

func set_targeting_mode(enabled: bool):
		targeting_mode = enabled
		if not targeting_mode and not force_discard_mode and not replacement_mode:
				clear_removal_highlight()

func has_card(card_name: String) -> bool:
	for card in card_container.get_children():
		if card.card_name == card_name:
			return true
	return false
