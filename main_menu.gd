extends CanvasLayer
signal start_game(character)
var character = "Bender"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Characters/Bender.button_pressed = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _char_clicked(button):
	var buttons
	character = button
	match button:
		"Spider":
			buttons = [$Characters/Bender,$Characters/Hello_Kitty,$Characters/Stitch]
		"Bender":
			buttons = [$Characters/Hello_Kitty,$Characters/Spider,$Characters/Stitch]
		"Hello_Kitty":
			buttons = [$Characters/Bender,$Characters/Spider,$Characters/Stitch]
		"Stitch":
			buttons = [$Characters/Bender,$Characters/Hello_Kitty,$Characters/Spider]
	for item in buttons:
		item.button_pressed = false

func _on_spider_pressed() -> void:
	_char_clicked("Spider")


func _on_bender_pressed() -> void:
		_char_clicked("Bender")



func _on_hello_kitty_pressed() -> void:
		_char_clicked("Hello_Kitty")



func _on_stitch_pressed() -> void:
		_char_clicked("Stitch")


func _on_start_game_pressed() -> void:
	start_game.emit(character)
