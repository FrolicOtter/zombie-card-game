extends Control

signal card_used(card_node)
signal card_selected_for_removal(card_node)
signal card_selected_for_info(info_text)
var card_name = ""
var in_removal_mode = false
var uses_left := 1
var targeting_lock := false
var CardInfo
# NEW: Track if the card is selected (clicked once)
var is_primed = false 
const CARD_DATA = {
	"Baseball Bat": {
		"type": "Attack",
		"uses": 3,
		"damage": 15,
		"range": "1-2", # Min 0, Max 2
		"accuracy": "100%",
		"desc": "Standard blunt weapon."
	},
	"Hammer": {
		"type": "Attack",
		"uses": 2,
		"damage": 18,
		"range": "1-2",
		"accuracy": "100%",
		"desc": "Heavy hitter, reliable damage."
	},
	"Fire Extinguisher": {
		"type": "Attack",
		"uses": 2,
		"damage": 12,
		"range": "1-2",
		"accuracy": "100%",
		"desc": "Decent range and utility."
	},
	"Scalpel": {
		"type": "Attack",
		"uses": 4,
		"damage": 10,
		"range": "1", # Max 1
		"accuracy": "70%",
		"desc": "High uses but risky accuracy."
	},
	"Bow": {
		"type": "Attack",
		"uses": 5,
		"damage": 20,
		"range": "2-3", # Min 2, Max 3
		"accuracy": "60%",
		"desc": "Long range sniper. Hard to aim."
	},
	"Medkit": {
		"type": "Heal",
		"uses": 1,
		"effect": "+30 HP",
		"desc": "Restores a large amount of health."
	},
	"Bandaid": {
		"type": "Heal",
		"uses": 1,
		"effect": "+10 HP",
		"desc": "Quick minor patch-up."
	},
	"Canned Food": {
		"type": "Heal",
		"uses": 1,
		"effect": "+15 HP",
		"desc": "Basic sustenance."
	},
	"Antibiotics": {
		"type": "Heal",
		"uses": 1,
		"effect": "+5 HP & Regen",
		"desc": "Heals 5 HP instantly + 2 HP for 5 turns."
	},
	"Backpack": {
		"type": "Utility",
		"uses": 1,
		"effect": "+2 Hand Size",
		"desc": "Permanently increases carrying capacity."
	},
	"Flashlight": {
		"type": "Utility",
		"uses": 1,
		"effect": "+25% Search",
		"desc": "Increases chance to find cards."
	},
	"Energy Drink": {
		"type": "Utility",
		"uses": 1,
		"effect": "+1 Action",
		"desc": "Grants an extra move this turn."
	}
}
var icons  = {
	"Backpack": "res://ART/Cards/card_03.png",
	"Bandaid": "res://ART/Cards/card_04.png",
	"Baseball Bat": "res://ART/Cards/card_05.png",
	"Canned Food": "res://ART/Cards/card_06.png",
	"Energy Drink": "res://ART/Cards/card_07.png",
	"Fire Extinguisher": "res://ART/Cards/card_08.png",
	"Flashlight": "res://ART/Cards/card_09.png",
	"Hammer": "res://ART/Cards/card_10.png",
	"Medkit": "res://ART/Cards/card_11.png",
	"Scalpel": "res://ART/Cards/card_12.png",
}
var card_bases = {
	"Default": "res://ART/Cards/card_00.png",
	"Selected": "res://ART/Cards/card_02.png",
	"Removal": "res://ART/Cards/card_01.png"
}
func _ready():
	$OverlayButton.pressed.connect(_on_pressed)
	$OverlayButton.size = size
	$CardBase.size = size
	$CardBase.pivot_offset = size/2
	$CardBase/CardIcon.size = size
	$CardBase/CardIcon.pivot_offset = size/2
	$CardBase.scale = Vector2(.75,.75)
	$CardBase/CardIcon.scale = Vector2(.75,.75)
	
	#$CardIcon.position = size
	# Add to a group so we can easily deselect other cards
	add_to_group("hand_cards")

func set_card(name: String):
	card_name = name
	uses_left = get_initial_uses(card_name)
	_update_card_text()
	$CardBase/CardIcon.texture = load(icons[card_name])
	

func _update_card_text():
	if uses_left > 1:
		#TODO - Update Uses some how
		#text = "%s (%d)" % [card_name, uses_left]
		pass
	else:
		$CardBase/CardIcon.texture = load(icons[card_name])
		#TODO - Set image
		#text = card_name
		pass

func get_initial_uses(name: String) -> int:
	match name:
		"Baseball Bat": return 3
		"Hammer": return 2
		"Fire Extinguisher": return 2
		"Scalpel": return 4
		"Bow": return 5
		_: return 1

func set_removal_mode(enabled: bool):
	in_removal_mode = enabled
	if enabled:
		#modulate = Color(1, 0.5, 0.5) # Red tint
		$CardBase.texture = load(card_bases["Removal"])
	else:
		reset_visuals()
	$OverlayButton.disabled = targeting_lock

func set_targeting_state(enabled: bool):
	targeting_lock = enabled
	$OverlayButton.disabled = targeting_lock # Prevent clicking card while selecting a zombie

func reset_visuals():
	if is_primed:
		pass
		#card_selected_for_info.emit("")
	is_primed = false
	#modulate = Color(1, 1, 1) # Reset color
	$CardBase.texture = load(card_bases["Default"])
	$CardBase.scale = Vector2(.75,.75)
	$CardBase/CardIcon.scale = Vector2(.75,.75)
	#$CardBase.set_anchor()

func consume_use():
	uses_left -= 1
	if uses_left <= 0:
		card_used.emit(self)
	else:
		_update_card_text()
		reset_visuals() # Reset selection after use

func _on_pressed():
	# 1. Removal/Discard Mode
	if in_removal_mode:
		card_selected_for_removal.emit(self)
		return

	# 2. Prevent clicking if locked
	if targeting_lock:
		return
	
	# 3. Double Click Logic (Prime vs Activate)
	if not is_primed:
		if CARD_DATA.has(card_name):
			var data = CARD_DATA[card_name]
			var info_text = "[b]%s[/b] (%s)\nUses: %d\n" % [card_name, data.type, uses_left]
			
			if data.type == "Attack":
				info_text += "Dmg: %d | Rng: %s | Acc: %s" % [data.damage, data.range, data.accuracy]
			elif data.has("effect"):
				info_text += "Effect: %s" % data.effect
				
			info_text += "\n[i]%s[/i]" % data.desc + "\n\n[b]Click the card to use it[/b]"
			
			card_selected_for_info.emit(info_text)
		get_tree().call_group("hand_cards", "reset_visuals")
		is_primed = true
		#modulate = Color(0, 1, 0) # Green
		$CardBase.texture = load(card_bases["Selected"])
		$CardBase.scale = Vector2(1,1)
		$CardBase/CardIcon.scale = Vector2(.75,.75)
		print("Selected ", card_name, ". Click again to use.")
		return
	card_selected_for_info.emit("")
	# --- Activate Action ---
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var card_consumed := true
	var uses_managed_by_player := false
	var should_end_turn := true  # FIX: Default to true, but allow overriding

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
			should_end_turn = false 
		_:
			print("Card not implemented: ", card_name)
			card_consumed = false

	if card_consumed:
		print("Activated ", card_name)
		card_selected_for_info.emit("")
		if not uses_managed_by_player:
			consume_use()
			
			# FIX: Only end turn if the card type allows it
			if should_end_turn:
				player.turn_ended.emit()
