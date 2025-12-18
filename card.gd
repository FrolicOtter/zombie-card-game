extends Button

signal card_used(card_node)
signal card_selected_for_removal(card_node)

var card_name = ""
var in_removal_mode = false

func _ready():
    pressed.connect(_on_pressed)

func set_card(name: String):
    card_name = name
    text = card_name

func set_removal_mode(enabled: bool):
    in_removal_mode = enabled
    if enabled:
        modulate = Color(1, 0.5, 0.5)  # Red tint
    else:
        modulate = Color(1, 1, 1)  # Normal

func _on_pressed():
    if in_removal_mode:
        card_selected_for_removal.emit(self)
        return

    # Normal card usage
    var player = get_tree().get_first_node_in_group("player")

    if player:
        var card_consumed := true
        match card_name:
            "Medkit":
                player.heal(30)
            "Bandaid":
                player.heal(10)
            "Baseball Bat":
                card_consumed = player.attack_nearest_zombie(15)
            "Hammer":
                card_consumed = player.attack_nearest_zombie(18)
            "Fire Extinguisher":
                card_consumed = player.attack_nearest_zombie(12)
            "Scalpel":
                card_consumed = player.attack_nearest_zombie(10, 1, 0, 0.7)
            "Bow":
                card_consumed = player.attack_nearest_zombie(20, 3, 2, 0.6)
            "Canned Food":
                player.heal(15)
            "Antibiotics":
                player.heal(5)
                player.start_regeneration(2, 5)
            "Backpack":
                card_consumed = player.apply_backpack()
            "Flashlight":
                player.apply_flashlight()
                card_consumed = false
            "Energy Drink":
                card_consumed = player.consume_energy_drink()
            _:
                print("Card not implemented: ", card_name)

        if card_consumed:
            print("Used ", card_name)
            card_used.emit(self)
