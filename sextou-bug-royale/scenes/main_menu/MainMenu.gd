extends Control

@onready var skin_option_button: OptionButton = $MarginContainer/VBoxContainer/SkinHBox/SkinOptionButton
@onready var mode_option_button: OptionButton = $MarginContainer/VBoxContainer/ModeHBox/ModeOptionButton
@onready var play_button: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var skin_preview_label: Label = $MarginContainer/VBoxContainer/SkinHBox/SkinPreviewLabel

func _ready() -> void:
	_populate_options()
	skin_option_button.item_selected.connect(_on_skin_selected)
	mode_option_button.item_selected.connect(_on_mode_selected)
	play_button.pressed.connect(_on_play_pressed)

func _populate_options() -> void:
	skin_option_button.clear()
	var skins = GameManager.skins_info.keys()
	for i in range(skins.size()):
		var key = skins[i]
		var info = GameManager.skins_info[key]
		skin_option_button.add_item(info["icon"] + " " + info["name"], i)
		
	mode_option_button.clear()
	mode_option_button.add_item("🌐 Multiplayer Online (Lobby da Firma)", 0)
	mode_option_button.add_item("🕹️ Treino Solo contra Bots", 1)
	mode_option_button.add_item("⚙️ Sandbox de Testes", 2)
	
	_update_skin_preview(0)

func _on_skin_selected(index: int) -> void:
	var skins = GameManager.skins_info.keys()
	if index >= 0 and index < skins.size():
		GameManager.selected_skin = skins[index]
		_update_skin_preview(index)

func _update_skin_preview(index: int) -> void:
	var skins = GameManager.skins_info.keys()
	if index >= 0 and index < skins.size():
		var key = skins[index]
		var info = GameManager.skins_info[key]
		skin_preview_label.text = info["icon"]

func _on_mode_selected(index: int) -> void:
	match index:
		0:
			GameManager.current_control_mode = GameManager.ControlMode.SOLO_INTERN
		1:
			GameManager.current_control_mode = GameManager.ControlMode.BOT_PARTNER
		2:
			GameManager.current_control_mode = GameManager.ControlMode.DUO_LOCAL

func _on_play_pressed() -> void:
	var target_scene = "res://scenes/lobby/LobbyScene.tscn"
	if mode_option_button.selected == 1:
		target_scene = GameManager.get_random_map_scene()
	elif mode_option_button.selected == 2:
		target_scene = "res://scenes/game/TestArena.tscn"
		
	get_tree().change_scene_to_file(target_scene)
