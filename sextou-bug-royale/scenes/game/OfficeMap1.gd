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
@onready var marquee_countdown_banner: Panel = $CanvasLayer.find_child("MarqueeBannerCountdown", true, false) as Panel
@onready var countdown_label: Label = $CanvasLayer.find_child("CountDownLabel", true, false) as Label

var chair_scene: PackedScene = preload("res://scenes/entities/ChairPlayer.tscn")
var bot_scene: PackedScene = preload("res://scenes/entities/BotPlayer.tscn")
var remote_player_scene: PackedScene = preload("res://scenes/entities/RemotePlayer.tscn")
var default_bullet_scene: PackedScene = preload("res://scenes/entities/Bullet.tscn")

# 8 Pontos de Spawn nas Extremidades e Cantos do Mapa do Escritório
const SPAWN_CORNERS: Array[Vector2] = [
	Vector2(180, 140),   # 0: Noroeste (Canto Superior Esquerdo)
	Vector2(2360, 140),  # 1: Nordeste (Canto Superior Direito)
	Vector2(180, 1260),  # 2: Sudoeste (Canto Inferior Esquerdo)
	Vector2(2360, 1260), # 3: Sudeste (Canto Inferior Direito)
	Vector2(1280, 140),  # 4: Norte Central
	Vector2(1280, 1260), # 5: Sul Central
	Vector2(180, 700),   # 6: Oeste Central
	Vector2(2360, 700)   # 7: Leste Central
]

var local_player: ChairPlayer = null
var active_bots: Array[BotPlayer] = []
var remote_players: Dictionary = {} # player_id -> RemotePlayer
var is_game_over: bool = false
var is_spectating_clean: bool = false
var is_returning_to_lobby: bool = false

var match_duration: float = 180.0 # 3 minutos até as 18h
var match_timer: float = 0.0

var spectator_camera: Camera2D = null
var spectator_target_index: int = 0
var minimap_radar: MinimapRadar = null

func _ready() -> void:
	dark_overlay.visible = false
	flash_overlay.visible = false
	marquee_banner.visible = false
	if marquee_countdown_banner:
		marquee_countdown_banner.visible = false
	_apply_fonts()
	_connect_network_signals()
	_generate_procedural_partitions()
	_setup_match()

func _connect_network_signals() -> void:
	if not NetworkManager.remote_player_transformed.is_connected(_on_remote_player_transformed):
		NetworkManager.remote_player_transformed.connect(_on_remote_player_transformed)
	if not NetworkManager.remote_player_shot.is_connected(_on_remote_player_shot):
		NetworkManager.remote_player_shot.connect(_on_remote_player_shot)
	if not NetworkManager.remote_player_hit.is_connected(_on_remote_player_hit):
		NetworkManager.remote_player_hit.connect(_on_remote_player_hit)
	if not NetworkManager.remote_player_eliminated.is_connected(_on_remote_player_eliminated):
		NetworkManager.remote_player_eliminated.connect(_on_remote_player_eliminated)

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
		if countdown_label:
			countdown_label.add_theme_font_override("font", font_pixel)
			countdown_label.add_theme_font_size_override("font_size", 11)
			
	if font_audio:
		if info_label:
			info_label.add_theme_font_override("font", font_audio)
			info_label.add_theme_font_size_override("font_size", 12)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and not NetworkManager.is_connected_to_ws:
			get_tree().reload_current_scene()
		elif is_game_over:
			if event.keycode == KEY_SPACE:
				_enter_clean_spectator_mode()
			elif event.keycode == KEY_ESCAPE:
				_return_to_lobby()
			elif event.keycode == KEY_TAB:
				_cycle_spectator_target()

func _enter_clean_spectator_mode() -> void:
	is_spectating_clean = true
	marquee_banner.visible = false
	if marquee_countdown_banner: marquee_countdown_banner.visible = false
	dark_overlay.visible = false
	flash_overlay.visible = false
	if info_label:
		info_label.text = "🎥 MODO ESPECTADOR: [WASD/Setas] Mover | [TAB] Trocar Alvo | [ESC] Lobby"

func _cycle_spectator_target() -> void:
	var active_targets: Array[Node2D] = []
	for bot in active_bots:
		if is_instance_valid(bot):
			active_targets.append(bot)
	for r_p in remote_players.values():
		if is_instance_valid(r_p):
			active_targets.append(r_p)
			
	if active_targets.size() > 0:
		spectator_target_index = (spectator_target_index + 1) % active_targets.size()
		var target = active_targets[spectator_target_index]
		if is_instance_valid(spectator_camera) and is_instance_valid(target):
			spectator_camera.global_position = target.global_position
			var target_name = "Bot"
			if target.has_meta("nickname"):
				target_name = target.get_meta("nickname")
			elif "nickname" in target:
				target_name = target.nickname
			if info_label:
				info_label.text = "🎥 Focando em: " + str(target_name) + " | [WASD/Setas] Mover | [TAB] Trocar | [ESC] Lobby"

func _start_5s_countdown_to_lobby() -> void:
	if is_returning_to_lobby: return
	is_returning_to_lobby = true
	
	if marquee_countdown_banner and countdown_label:
		marquee_countdown_banner.visible = true
		for i in range(5, 0, -1):
			countdown_label.text = "⏱️ RETORNANDO AO LOBBY EM " + str(i) + " SEGUNDO" + ("S" if i > 1 else "") + "..."
			await get_tree().create_timer(1.0).timeout
		countdown_label.text = "🚀 RETORNANDO AO LOBBY..."
		await get_tree().create_timer(0.5).timeout
	else:
		await get_tree().create_timer(5.0).timeout
		
	_return_to_lobby()

func _return_to_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/LobbyScene.tscn")

func _process(delta: float) -> void:
	if not is_returning_to_lobby:
		match_timer += delta
		_update_happy_hour_clock()
		_update_reboot_zone_status()
		_check_match_status()
		
	if is_instance_valid(spectator_camera) and (is_game_over or is_spectating_clean):
		var cam_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): cam_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): cam_dir.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): cam_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): cam_dir.x += 1.0
		
		if cam_dir != Vector2.ZERO:
			spectator_camera.global_position += cam_dir.normalized() * 750.0 * delta
			spectator_camera.global_position.x = clamp(spectator_camera.global_position.x, 640.0, 1920.0)
			spectator_camera.global_position.y = clamp(spectator_camera.global_position.y, 360.0, 1080.0)
			
	if is_instance_valid(minimap_radar):
		minimap_radar.local_player = local_player if is_instance_valid(local_player) else null
		minimap_radar.spectator_camera = spectator_camera if is_instance_valid(spectator_camera) else null

func _update_reboot_zone_status() -> void:
	if is_game_over or info_label == null: return
	var reboot = get_tree().get_first_node_in_group("reboot_zone") as RebootZone
	if reboot and is_instance_valid(reboot):
		if reboot.cooldown_timer > 0.0:
			var sec_left = int(ceil(reboot.cooldown_timer))
			info_label.text = "🛡️ ZONA SEGURA: Reboot do RH inicia em " + str(sec_left) + "s! Colete armas nas caixas!"
		else:
			info_label.text = "⚠️ ATENÇÃO: O REBOOT DO RH ESTÁ ENCOLHENDO O ANDAR! FUJA DA NÉVOA!"

func _setup_minimap() -> void:
	var minimap_placeholder = $CanvasLayer.find_child("Minimap", true, false)
	if minimap_placeholder:
		if minimap_radar == null:
			minimap_radar = MinimapRadar.new()
			minimap_radar.name = "MinimapRadarControl"
		
		if minimap_placeholder is Control:
			minimap_radar.anchors_preset = Control.PRESET_FULL_RECT
			minimap_radar.size = minimap_placeholder.size
			minimap_radar.position = Vector2.ZERO
			if minimap_radar.get_parent() != minimap_placeholder:
				minimap_placeholder.add_child(minimap_radar)
		else:
			minimap_radar.position = Vector2(1040, 560)
			minimap_radar.size = Vector2(220, 140)
			if minimap_radar.get_parent() != $CanvasLayer:
				$CanvasLayer.add_child(minimap_radar)
			
	if is_instance_valid(minimap_radar):
		minimap_radar.local_player = local_player if is_instance_valid(local_player) else null
		minimap_radar.active_bots = active_bots
		minimap_radar.remote_players = remote_players
		minimap_radar.spectator_camera = spectator_camera if is_instance_valid(spectator_camera) else null

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

func get_valid_loot_spawn(calling_box: Node2D) -> Vector2:
	var candidate_slots: Array[Vector2] = [
		Vector2(450, 240), Vector2(1000, 240), Vector2(1550, 240), Vector2(2100, 240),
		Vector2(450, 500), Vector2(1000, 500), Vector2(1550, 500), Vector2(2100, 500),
		Vector2(450, 750), Vector2(1000, 750), Vector2(1550, 750), Vector2(2100, 750),
		Vector2(450, 1050), Vector2(1000, 1050), Vector2(1550, 1050), Vector2(2100, 1050)
	]
	candidate_slots.shuffle()
	
	var other_boxes = $DeployBoxes.get_children()
	for slot in candidate_slots:
		var slot_valid = true
		for box in other_boxes:
			if box != calling_box and is_instance_valid(box) and box.visible:
				if box.global_position.distance_to(slot) < 160.0:
					slot_valid = false
					break
		if slot_valid: return slot
			
	return Vector2(randf_range(300.0, 2200.0), randf_range(200.0, 1150.0))

func _setup_match() -> void:
	is_game_over = false
	is_spectating_clean = false
	is_returning_to_lobby = false
	active_bots.clear()
	remote_players.clear()
	
	for p in get_tree().get_nodes_in_group("players"):
		p.queue_free()
		
	# 1. Determinar o índice de Spawn do Jogador Local
	var local_spawn_pos = SPAWN_CORNERS[0]
	var net_players = NetworkManager.last_room_state.get("players", []) as Array
	
	if NetworkManager.is_connected_to_ws and net_players.size() > 0:
		var local_idx = 0
		for i in range(net_players.size()):
			if net_players[i] is Dictionary and net_players[i].get("id", "") == NetworkManager.local_player_id:
				local_idx = i
				break
		local_spawn_pos = SPAWN_CORNERS[local_idx % SPAWN_CORNERS.size()]
	
	local_player = chair_scene.instantiate() as ChairPlayer
	local_player.global_position = local_spawn_pos
	local_player.add_to_group("players")
	add_child(local_player)
	
	local_player.hp_changed.connect(_on_player_hp_changed)
	local_player.item_changed.connect(_on_player_item_changed)
	local_player.chair_destroyed.connect(_on_player_destroyed)
	_on_player_hp_changed(local_player.post_it_hp)
	_on_player_item_changed("NENHUM")
	_setup_minimap()
	
	var nick_label = $CanvasLayer.find_child("PlayerNickLabel", true, false) as Label
	if nick_label:
		nick_label.text = GameManager.player_nickname
		
	var avatar_rect = $CanvasLayer.find_child("PlayerAvatar", true, false) as TextureRect
	if avatar_rect:
		var avatar_path = "res://assets/avatars/" + GameManager.selected_avatar
		if ResourceLoader.exists(avatar_path):
			avatar_rect.texture = load(avatar_path) as Texture2D
	
	# 2. Instanciar Players Remotos nas suas respectivas extremidades determinísticas
	if NetworkManager.is_connected_to_ws:
		for i in range(net_players.size()):
			var p_dict = net_players[i] as Dictionary
			var p_id = p_dict.get("id", "") as String
			if p_id != NetworkManager.local_player_id and not p_id.is_empty():
				var remote_inst = remote_player_scene.instantiate() as RemotePlayer
				remote_inst.player_id = p_id
				remote_inst.nickname = p_dict.get("nickname", "RemoteDev")
				remote_inst.skin_key = p_dict.get("skin", "DEV")
				
				var remote_spawn_pos = SPAWN_CORNERS[i % SPAWN_CORNERS.size()]
				remote_inst.global_position = remote_spawn_pos
					
				remote_inst.add_to_group("players")
				add_child(remote_inst)
				remote_players[p_id] = remote_inst
				remote_inst.chair_destroyed.connect(_on_remote_chair_destroyed.bind(p_id))
				
	# 3. Se estiver jogando sozinho, spawnar bots de treino nas outras pontas!
	if remote_players.is_empty():
		var bot_names = ["Dev_Bugger", "QA_Hunter", "Bug_Slayer"]
		for i in range(bot_names.size()):
			var bot_inst = bot_scene.instantiate() as BotPlayer
			bot_inst.global_position = SPAWN_CORNERS[(i + 1) % SPAWN_CORNERS.size()]
			bot_inst.add_to_group("players")
			add_child(bot_inst)
			active_bots.append(bot_inst)
			bot_inst.chair_destroyed.connect(_on_bot_destroyed)
			bot_inst.set_meta("nickname", bot_names[i])

func _on_remote_chair_destroyed(_chair: RemotePlayer, p_id: String) -> void:
	if remote_players.has(p_id):
		remote_players.erase(p_id)
	_check_match_status()

func _on_remote_player_transformed(p_id: String, pos: Vector2, rot: float, gun_rot: float) -> void:
	if remote_players.has(p_id):
		var remote_inst = remote_players[p_id] as RemotePlayer
		if is_instance_valid(remote_inst):
			remote_inst.update_transform_data(pos, rot, gun_rot)

func _on_remote_player_shot(p_id: String, pos: Vector2, dir: Vector2, _item_type: String) -> void:
	if p_id != NetworkManager.local_player_id:
		var bullet_inst = default_bullet_scene.instantiate() as Bullet
		get_parent().add_child(bullet_inst)
		var shooter_node = remote_players.get(p_id, null)
		bullet_inst.setup(pos, dir, shooter_node)

func _on_remote_player_hit(target_id: String, _attacker_id: String, _remaining_hp: int) -> void:
	if target_id == NetworkManager.local_player_id and is_instance_valid(local_player):
		local_player.take_damage(1)
	elif remote_players.has(target_id):
		var remote_inst = remote_players[target_id] as RemotePlayer
		if is_instance_valid(remote_inst):
			remote_inst.apply_damage(1)

func _on_remote_player_eliminated(p_id: String) -> void:
	if remote_players.has(p_id):
		var remote_inst = remote_players[p_id] as RemotePlayer
		if is_instance_valid(remote_inst):
			remote_inst.reveal_real_skin()
			remote_inst.remove_from_group("players")
			remote_inst.modulate = Color(0.5, 0.5, 0.5, 0.35)
		remote_players.erase(p_id)
		print("[Match] Player remoto eliminado: ", p_id, ". Sobreviventes remotos: ", remote_players.size())
	_check_match_status()

func _check_match_status() -> void:
	if match_timer < 1.0 or is_returning_to_lobby or is_game_over:
		return
		
	var local_alive = is_instance_valid(local_player) and local_player.post_it_hp > 0
	var total_survivors = (1 if local_alive else 0) + active_bots.size() + remote_players.size()
	
	if total_survivors <= 1 or match_timer >= match_duration:
		is_game_over = true
		var winner_name = "Nenhum"
		
		if local_alive:
			winner_name = GameManager.player_nickname
			_show_game_over_banner("🏆 SEXTOU! VITÓRIA ROYALE!\nVOCÊ SOBREVIVEU AO DEPLOY EM PRODUÇÃO!", true)
		else:
			if remote_players.size() > 0:
				var first_remote = remote_players.values()[0] as RemotePlayer
				if is_instance_valid(first_remote):
					winner_name = first_remote.nickname
			elif active_bots.size() > 0 and is_instance_valid(active_bots[0]):
				winner_name = active_bots[0].get_meta("nickname", "Dev_Bot") as String
			else:
				winner_name = "O RH (Reboot Geral)"
				
			_show_game_over_banner("🏆 FIM DA PARTIDA!\n👑 VENCEDOR DO DEPLOY: " + winner_name, false)
			
		_start_5s_countdown_to_lobby()

func _on_player_hp_changed(hp: int) -> void:
	if hp_label and not is_game_over:
		hp_label.text = "Post-its de Vida: " + str(hp) + " / 3"

func _on_player_item_changed(item_name: String) -> void:
	if item_label:
		item_label.text = item_name
		
	var icon_label = $CanvasLayer.find_child("IconItemLabel", true, false) as Label
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
	if NetworkManager.is_connected_to_ws:
		NetworkManager.send_eliminated(NetworkManager.local_player_id)
	
	_show_game_over_banner("💀 REINICIADO PELO RH!\n[ESPAÇO] Modo Espectador | [ESC] Voltar ao Lobby", false)
	_check_match_status()

func _show_game_over_banner(message: String, is_victory: bool) -> void:
	if not is_victory:
		flash_overlay.visible = true
		flash_overlay.color = Color(0.9, 0.1, 0.1, 0.8)
		var tween = create_tween()
		tween.tween_property(flash_overlay, "color:a", 0.0, 0.25)
		await tween.finished
		flash_overlay.visible = false
	else:
		flash_overlay.visible = true
		flash_overlay.color = Color(0.95, 0.85, 0.2, 0.5) # Flash dourado da vitória
		var tween = create_tween()
		tween.tween_property(flash_overlay, "color:a", 0.0, 0.35)
		await tween.finished
		flash_overlay.visible = false
	
	dark_overlay.visible = true
	dark_overlay.color = Color(0, 0, 0, 0)
	var dark_tween = create_tween()
	dark_tween.tween_property(dark_overlay, "color:a", 0.55, 0.4)
	
	marquee_banner.visible = true
	marquee_label.text = message
	marquee_label.modulate = Color(1.0, 0.9, 0.2, 1.0) if is_victory else Color(1.0, 1.0, 1.0, 1.0)
	
	# Só ativa o modo espectador se o jogador local estiver eliminado
	if not (is_instance_valid(local_player) and local_player.post_it_hp > 0):
		_activate_spectator_mode()

func _activate_spectator_mode() -> void:
	if spectator_camera == null:
		spectator_camera = Camera2D.new()
		spectator_camera.name = "SpectatorCamera"
		spectator_camera.limit_left = 0
		spectator_camera.limit_top = 0
		spectator_camera.limit_right = 2560
		spectator_camera.limit_bottom = 1440
		spectator_camera.position_smoothing_enabled = true
		spectator_camera.position_smoothing_speed = 8.0
		add_child(spectator_camera)
		
		if is_instance_valid(local_player):
			spectator_camera.global_position = local_player.global_position
		else:
			spectator_camera.global_position = Vector2(1280, 720)
			
		spectator_camera.make_current()

	for bot in active_bots:
		if is_instance_valid(bot):
			if bot.has_method("reveal_real_skin"):
				bot.reveal_real_skin()
			var b_nick = bot.get_meta("nickname", "Bot_Dev") as String
			_show_floating_nameplate(bot, b_nick)
			
	for p_id in remote_players.keys():
		var remote_inst = remote_players[p_id] as RemotePlayer
		if is_instance_valid(remote_inst):
			remote_inst.reveal_real_skin()
			_show_floating_nameplate(remote_inst, remote_inst.nickname)

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
	_check_match_status()
