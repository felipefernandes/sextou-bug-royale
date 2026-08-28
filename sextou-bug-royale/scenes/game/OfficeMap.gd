extends Node2D

@onready var partitions_container: Node2D = $Walls
@onready var hp_label: Label = $CanvasLayer.find_child("HpLabel", true, false) as Label
@onready var item_label: Label = $CanvasLayer.find_child("ItemLabel", true, false) as Label
@onready var info_label: Label = $CanvasLayer.find_child("InfoLabel", true, false) as Label
@onready var clock_label: Label = $CanvasLayer.find_child("ClockLabel", true, false) as Label

@onready var dark_overlay: ColorRect = $CanvasLayer.find_child("DarkOverlay", true, false) as ColorRect
@onready var flash_overlay: ColorRect = $CanvasLayer.find_child("FlashOverlay", true, false) as ColorRect
@onready var marquee_banner: Panel = $CanvasLayer.find_child("MarqueeBanner", true, false) as Panel
@onready var marquee_label: Label = $CanvasLayer.find_child("MarqueeLabel", true, false) as Label

var chair_scene: PackedScene = preload("res://scenes/entities/ChairPlayer.tscn")
var bot_scene: PackedScene = preload("res://scenes/entities/BotPlayer.tscn")
var remote_player_scene: PackedScene = preload("res://scenes/entities/RemotePlayer.tscn")
var default_bullet_scene: PackedScene = preload("res://scenes/entities/Bullet.tscn")

const SPAWN_CORNERS: Array[Vector2] = [
	Vector2(180, 140),   # 0: Noroeste
	Vector2(1100, 140),  # 1: Nordeste
	Vector2(180, 650),   # 2: Sudoeste
	Vector2(1100, 650),  # 3: Sudeste
	Vector2(640, 140),   # 4: Norte Central
	Vector2(640, 650)    # 5: Sul Central
]

var local_player: ChairPlayer = null
var active_bots: Array[BotPlayer] = []
var remote_players: Dictionary = {}
var is_game_over: bool = false
var is_spectating_clean: bool = false
var is_returning_to_lobby: bool = false

var match_duration: float = 180.0
var match_timer: float = 0.0

func _ready() -> void:
	dark_overlay.visible = false
	flash_overlay.visible = false
	marquee_banner.visible = false
	_apply_fonts()
	_generate_procedural_partitions()
	_setup_match()

func _apply_fonts() -> void:
	var font_pixel = load("res://assets/fonts/PressStart2P-Regular.ttf") as Font
	var font_audio = load("res://assets/fonts/Audiowide-Regular.ttf") as Font
	
	if font_pixel:
		if clock_label:
			clock_label.add_theme_font_override("font", font_pixel)
			clock_label.add_theme_font_size_override("font_size", 12)
		if marquee_label:
			marquee_label.add_theme_font_override("font", font_pixel)
			marquee_label.add_theme_font_size_override("font_size", 11)
			
	if font_audio:
		if info_label:
			info_label.add_theme_font_override("font", font_audio)
			info_label.add_theme_font_size_override("font_size", 12)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if not is_returning_to_lobby and not is_game_over:
		match_timer += delta
		_update_happy_hour_clock()
		_update_reboot_zone_status()
		_check_match_status()

func _update_reboot_zone_status() -> void:
	if is_game_over or info_label == null: return
	var reboot = get_tree().get_first_node_in_group("reboot_zone") as RebootZone
	if reboot and is_instance_valid(reboot):
		if reboot.cooldown_timer > 0.0:
			var sec_left = int(ceil(reboot.cooldown_timer))
			info_label.text = "🛡️ ZONA SEGURA: Reboot do RH inicia em " + str(sec_left) + "s! Colete armas nas caixas!"
		else:
			info_label.text = "⚠️ ATENÇÃO: O REBOOT DO RH ESTÁ ENCOLHENDO O ANDAR! FUJA DA NÉVOA!"

func _update_happy_hour_clock() -> void:
	if clock_label == null: return
	var progress = clamp(match_timer / match_duration, 0.0, 1.0)
	var total_simulated_seconds = int(progress * 3600.0)
	var minutes = int(float(total_simulated_seconds) / 60.0)
	var seconds = total_simulated_seconds % 60
	
	var min_str = str(minutes).pad_zeros(2)
	var sec_str = str(seconds).pad_zeros(2)
	
	if progress >= 1.0:
		clock_label.text = "🍺 18:00:00 - SEXTOU! HORA DO HAPPY HOUR!"
		clock_label.modulate = Color(0.2, 0.9, 0.3, 1.0)
	else:
		clock_label.text = "🕒 17:" + min_str + ":" + sec_str + " (HAPPY HOUR ÀS 18:00)"
		clock_label.modulate = Color(0.95, 0.85, 0.2, 1.0) if fmod(match_timer, 1.0) > 0.5 else Color(1.0, 1.0, 1.0, 1.0)

func _generate_procedural_partitions() -> void:
	var deploy_boxes = $DeployBoxes.get_children()
	for box in deploy_boxes:
		if box.has_method("relocate_randomly"):
			box.relocate_randomly()

func _setup_match() -> void:
	is_game_over = false
	is_returning_to_lobby = false
	active_bots.clear()
	
	for p in get_tree().get_nodes_in_group("players"):
		p.queue_free()
		
	local_player = chair_scene.instantiate() as ChairPlayer
	local_player.global_position = SPAWN_CORNERS[0]
	local_player.add_to_group("players")
	add_child(local_player)
	
	local_player.hp_changed.connect(_on_player_hp_changed)
	local_player.item_changed.connect(_on_player_item_changed)
	local_player.chair_destroyed.connect(_on_player_destroyed)
	_on_player_hp_changed(local_player.post_it_hp)
	_on_player_item_changed("NENHUM")
	
	# Bots nas extremidades
	var bot_names = ["Dev_Bugger", "QA_Hunter", "Bug_Slayer"]
	for i in range(bot_names.size()):
		var bot_inst = bot_scene.instantiate() as BotPlayer
		bot_inst.global_position = SPAWN_CORNERS[(i + 1) % SPAWN_CORNERS.size()]
		bot_inst.add_to_group("players")
		add_child(bot_inst)
		active_bots.append(bot_inst)
		bot_inst.chair_destroyed.connect(_on_bot_destroyed)
		bot_inst.set_meta("nickname", bot_names[i])

func _check_match_status() -> void:
	if match_timer < 1.0 or is_returning_to_lobby or is_game_over:
		return
		
	var local_alive = is_instance_valid(local_player) and local_player.post_it_hp > 0
	var total_survivors = (1 if local_alive else 0) + active_bots.size()
	
	if total_survivors <= 1 or match_timer >= match_duration:
		is_game_over = true
		if local_alive:
			_show_game_over_banner("🏆 SEXTOU! VITÓRIA ROYALE!\nVOCÊ SOBREVIVEU AO DEPLOY EM PRODUÇÃO!", true)
		else:
			var winner_name = "O BOT INIMIGO"
			if active_bots.size() > 0 and is_instance_valid(active_bots[0]):
				winner_name = active_bots[0].get_meta("nickname", "Dev_Bot") as String
			_show_game_over_banner("🏆 FIM DA PARTIDA!\n👑 VENCEDOR: " + winner_name, false)
			
		_start_countdown_and_return()

func _start_countdown_and_return() -> void:
	if is_returning_to_lobby: return
	is_returning_to_lobby = true
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/lobby/LobbyScene.tscn")

func _on_player_hp_changed(hp: int) -> void:
	if hp_label and not is_game_over:
		hp_label.text = "Post-its de Vida: " + str(hp) + " / 3"

func _on_player_item_changed(item_name: String) -> void:
	if item_label:
		item_label.text = item_name

func _on_player_destroyed(_chair: ChairPlayer) -> void:
	_show_game_over_banner("💀 REINICIADO PELO RH!", false)
	_check_match_status()

func _show_game_over_banner(message: String, is_victory: bool) -> void:
	is_game_over = true
	dark_overlay.visible = true
	marquee_banner.visible = true
	marquee_label.text = message
	marquee_label.modulate = Color(1.0, 0.9, 0.2, 1.0) if is_victory else Color(1.0, 1.0, 1.0, 1.0)

func _on_bot_destroyed(bot: BotPlayer) -> void:
	if bot in active_bots:
		active_bots.erase(bot)
	_check_match_status()
