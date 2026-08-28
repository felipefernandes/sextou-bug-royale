extends Node2D

@onready var player_spawn: Marker2D = $Spawns/PlayerSpawn
@onready var bot_spawns_container: Node2D = $Spawns/BotSpawns
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

var local_player: ChairPlayer = null
var active_bots: Array[BotPlayer] = []
var is_game_over: bool = false
var is_spectating_clean: bool = false
var is_returning_to_lobby: bool = false

var match_duration: float = 180.0 # 3 minutos até as 18h
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
	if not is_game_over:
		match_timer += delta
		_update_happy_hour_clock()
		_check_match_status()

func _update_happy_hour_clock() -> void:
	if clock_label == null: return
	var progress = clamp(match_timer / match_duration, 0.0, 1.0)
	var total_simulated_seconds = int(progress * 3600.0) # 60 minutos simulação
	var minutes = int(float(total_simulated_seconds) / 60.0)
	var seconds = total_simulated_seconds % 60
	
	var min_str = str(minutes).pad_zeros(2)
	var sec_str = str(seconds).pad_zeros(2)
	
	if progress >= 1.0:
		clock_label.text = "🍺 18:00:00 - SEXTOU! HORA DO HAPPY HOUR!"
		clock_label.modulate = Color(0.2, 0.9, 0.3, 1.0)
		if not is_game_over:
			_show_game_over_banner("🍺 18:00:00 - SEXTOU! HORA DO HAPPY HOUR! VOCÊ SOBREVIVEU!", true)
	else:
		clock_label.text = "🕒 17:" + min_str + ":" + sec_str + " (HAPPY HOUR ÀS 18:00)"
		clock_label.modulate = Color(0.95, 0.85, 0.2, 1.0) if fmod(match_timer, 1.0) > 0.5 else Color(1.0, 1.0, 1.0, 1.0)

func _generate_procedural_partitions() -> void:
	# Reposicionar apenas as caixas de deploy para locais válidos (sem alterar o layout visual artesanal do cenário)
	var deploy_boxes = $DeployBoxes.get_children()
	for box in deploy_boxes:
		if box.has_method("relocate_randomly"):
			box.relocate_randomly()

func get_valid_loot_spawn(calling_box: Node2D) -> Vector2:
	var candidate_slots: Array[Vector2] = [
		Vector2(250, 180), Vector2(640, 160), Vector2(1030, 180),
		Vector2(200, 360), Vector2(640, 360), Vector2(1080, 360),
		Vector2(250, 560), Vector2(640, 560), Vector2(1030, 560),
		Vector2(450, 440), Vector2(830, 260)
	]
	candidate_slots.shuffle()
	
	var p1 = partitions_container.get_node_or_null("Partition1")
	var p2 = partitions_container.get_node_or_null("Partition2")
	var other_boxes = $DeployBoxes.get_children()
	
	for slot in candidate_slots:
		var slot_valid = true
		for box in other_boxes:
			if box != calling_box and is_instance_valid(box) and box.visible:
				if box.global_position.distance_to(slot) < 180.0:
					slot_valid = false
					break
		if not slot_valid: continue
		if p1 and p1.global_position.distance_to(slot) < 90.0: slot_valid = false
		if p2 and p2.global_position.distance_to(slot) < 90.0: slot_valid = false
		if slot_valid: return slot
			
	return Vector2(randf_range(200.0, 1080.0), randf_range(160.0, 560.0))

func _setup_match() -> void:
	is_game_over = false
	active_bots.clear()
	
	for p in get_tree().get_nodes_in_group("players"):
		p.queue_free()
		
	local_player = chair_scene.instantiate() as ChairPlayer
	local_player.global_position = player_spawn.global_position
	local_player.add_to_group("players")
	add_child(local_player)
	
	local_player.hp_changed.connect(_on_player_hp_changed)
	local_player.item_changed.connect(_on_player_item_changed)
	local_player.chair_destroyed.connect(_on_player_destroyed)
	_on_player_hp_changed(local_player.post_it_hp)
	_on_player_item_changed("NENHUM")
	
	# 1. Atualizar PlayerNickLabel no HUD
	var nick_label = $CanvasLayer/HUD.get_node_or_null("PlayerNickLabel") as Label
	if nick_label:
		nick_label.text = GameManager.player_nickname
		
	# 3. Atualizar PlayerAvatar no HUD
	var avatar_rect = $CanvasLayer/HUD.get_node_or_null("PlayerAvatar") as TextureRect
	if avatar_rect:
		var avatar_path = "res://assets/avatars/" + GameManager.selected_avatar
		if ResourceLoader.exists(avatar_path):
			avatar_rect.texture = load(avatar_path) as Texture2D
	
	var bot_names = ["Dev_Bugger", "QA_Hunter", "Bug_Slayer"]
	var bot_idx = 0
	for spawn in bot_spawns_container.get_children():
		if spawn is Marker2D:
			var bot_inst = bot_scene.instantiate() as BotPlayer
			bot_inst.global_position = spawn.global_position
			bot_inst.add_to_group("players")
			add_child(bot_inst)
			active_bots.append(bot_inst)
			bot_inst.chair_destroyed.connect(_on_bot_destroyed)
			
			# Configurar Nickname do Bot
			var b_name = bot_names[bot_idx % bot_names.size()]
			bot_idx += 1
			bot_inst.set_meta("nickname", b_name)
			
	info_label.text = "WASD = Mover | SHIFT = Drift | ESPAÇO = Boost | CLIQUE DIREITO / E = Item | R = Reiniciar"

func _check_match_status() -> void:
	if match_timer < 2.0:
		return
		
	var remaining_opponents = active_bots.size()
	if (remaining_opponents == 0 or match_timer >= match_duration) and not is_returning_to_lobby:
		if is_instance_valid(local_player) and local_player.post_it_hp > 0:
			_show_game_over_banner("🎉 SEXTOU! VOCÊ SOBREVIVEU AO DEPLOY EM PROD!", true)
			
		info_label.text = "⏱️ Partida encerrada! Retornando ao Lobby em 3 segundos..."
		is_returning_to_lobby = true
		get_tree().create_timer(3.0).timeout.connect(_return_to_lobby)

func _return_to_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/LobbyScene.tscn")

func _on_player_hp_changed(hp: int) -> void:
	if hp_label and not is_game_over:
		hp_label.text = "Post-its de Vida: " + str(hp) + " / 3"

func _on_player_item_changed(item_name: String) -> void:
	if item_label:
		item_label.text = item_name
		
	# 4. Atualizar IconItemLabel dinamicamente com Emoji
	var icon_label = $CanvasLayer/HUD.get_node_or_null("IconItemLabel") as Label
	if icon_label:
		var emoji = ""
		if "Café" in item_name or "COFFEE" in item_name: emoji = "☕"
		elif "Elástico" in item_name or "ELASTIC" in item_name: emoji = "🟢"
		elif "Disquete" in item_name or "DISKETTE" in item_name: emoji = "💾"
		elif "ESCUDO" in item_name or "CTRL_Z" in item_name: emoji = "🛡️"
		elif "GAMBIARRA" in item_name or "POG" in item_name: emoji = "🚀"
		elif "404" in item_name or "NOT_FOUND" in item_name: emoji = "👻"
		icon_label.text = emoji

func _on_player_destroyed(_chair: ChairPlayer) -> void:
	_show_game_over_banner("💀 VOCÊ FOI REINICIADO PELO RH! MODO ESPECTADOR ATIVO (Pressione 'R' para reiniciar)", false)

func _show_game_over_banner(message: String, is_victory: bool) -> void:
	if is_game_over: return
	is_game_over = true
	
	if not is_victory:
		flash_overlay.visible = true
		flash_overlay.color = Color(0.9, 0.1, 0.1, 0.8)
		var tween = create_tween()
		tween.tween_property(flash_overlay, "color:a", 0.0, 0.25)
		await tween.finished
		flash_overlay.visible = false
	
	dark_overlay.visible = true
	dark_overlay.color = Color(0, 0, 0, 0)
	var dark_tween = create_tween()
	dark_tween.tween_property(dark_overlay, "color:a", 0.55, 0.4)
	
	marquee_banner.visible = true
	marquee_label.text = message
	
	_activate_spectator_mode()

func _activate_spectator_mode() -> void:
	# 2. Revelar Skins e exibir Nicknames Flutuantes no Modo Espectador
	for bot in active_bots:
		if is_instance_valid(bot):
			if bot.has_method("reveal_real_skin"):
				bot.reveal_real_skin()
			var b_nick = bot.get_meta("nickname", "Bot_Dev") as String
			_show_floating_nameplate(bot, b_nick)

func _show_floating_nameplate(target: Node2D, nickname: String) -> void:
	if not is_instance_valid(target): return
	var nameplate = target.get_node_or_null("NameplateLabel") as Label
	if nameplate == null:
		nameplate = Label.new()
		nameplate.name = "NameplateLabel"
		nameplate.position = Vector2(-50, -45)
		nameplate.custom_minimum_size = Vector2(100, 20)
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameplate.modulate = Color(0.95, 0.85, 0.2, 1.0)
		var font_pixel = load("res://assets/fonts/PressStart2P-Regular.ttf") as Font
		if font_pixel:
			nameplate.add_theme_font_override("font", font_pixel)
			nameplate.add_theme_font_size_override("font_size", 9)
		target.add_child(nameplate)
	nameplate.text = nickname
	nameplate.visible = true

func _on_bot_destroyed(bot: BotPlayer) -> void:
	if bot in active_bots:
		active_bots.erase(bot)
