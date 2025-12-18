extends CanvasLayer

@onready var card_container = $HBoxContainer
const MAX_CARDS = 5

var pending_card: String = ""
var replacement_mode = false

func add_card(card_name: String):
	if card_container.get_child_count() >= MAX_CARDS:
		pending_card = card_name
		replacement_mode = true
		print("Hand full! Click a card to replace.")
		highlight_cards_for_removal()
	else:
		create_card(card_name)

func create_card(card_name: String):
	var card_ui = preload("res://card.tscn").instantiate()
	card_container.add_child(card_ui)
	card_ui.set_card(card_name)
	card_ui.card_used.connect(_on_card_used)
	card_ui.card_selected_for_removal.connect(_on_card_removal)

func highlight_cards_for_removal():
	for card in card_container.get_children():
		card.set_removal_mode(true)

func _on_card_used(card_node):
	card_node.queue_free()

func _on_card_removal(card_node):
	if replacement_mode and pending_card != "":
		card_node.queue_free()
		create_card(pending_card)
		pending_card = ""
		replacement_mode = false
		
		# Remove red tint
		for card in card_container.get_children():
			card.set_removal_mode(false)
		
		print("Card replaced!")
