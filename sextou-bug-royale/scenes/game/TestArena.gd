extends Node2D

@onready var player_spawn: Marker2D = $Spawns/PlayerSpawn
@onready var bot_spawns_container: Node2D = $Spawns/BotSpawns
@onready var hp_label: Label = $CanvasLayer/HUD/HpLabel
@onready var mode_label: Label = $CanvasLayer/HUD/ModeLabel
@onready var info_label: Label = $CanvasLayer/HUD/InfoLabel

var chair_scene: PackedScene = preload("res://scenes/entities/ChairPlayer.tscn")
var bot_scene: PackedScene = preload("res://scenes/entities/BotPlayer.tscn")

var local_player: ChairPlayer = null

func _ready() -> void:
	_setup_match()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _setup_match() -> void:
	# Limpar entidades antigas
	for p in get_tree().get_nodes_in_group("players"):
		p.queue_free()
		
	# Instanciar o jogador principal
	local_player = chair_scene.instantiate() as ChairPlayer
	local_player.global_position = player_spawn.global_position
	local_player.add_to_group("players")
	add_child(local_player)
	
	local_player.hp_changed.connect(_on_player_hp_changed)
	local_player.chair_destroyed.connect(_on_player_destroyed)
	_on_player_hp_changed(local_player.post_it_hp)
	
	# Instanciar Bots Inimigos nos Markers
	for spawn in bot_spawns_container.get_children():
		if spawn is Marker2D:
			var bot_inst = bot_scene.instantiate() as BotPlayer
			bot_inst.global_position = spawn.global_position
			bot_inst.add_to_group("players")
			add_child(bot_inst)
			
	# Atualizar HUD
	mode_label.text = "Modo: " + GameManager.ControlMode.keys()[GameManager.current_control_mode]
	info_label.text = "WASD = Pilotar | MOUSE = Mirar & Atirar | CLIQUE ESQUERDO / SHIFT = Drift | ESPAÇO = Boost | R = Reiniciar"

func _on_player_hp_changed(hp: int) -> void:
	if hp_label:
		hp_label.text = "Post-its de Vida: " + str(hp) + " / 3"

func _on_player_destroyed(chair: ChairPlayer) -> void:
	if hp_label:
		hp_label.text = "CADEIRA DESTRUÍDA! Pressione 'R' para reiniciar."
