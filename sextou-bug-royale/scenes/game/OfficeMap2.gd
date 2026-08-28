extends Node2D

@onready var game_hud: GameHUD = $GameHUD
@onready var walls_container: Node2D = $Walls

var chair_scene: PackedScene = preload("res://scenes/entities/ChairPlayer.tscn")
var bot_scene: PackedScene = preload("res://scenes/entities/BotPlayer.tscn")
var remote_player_scene: PackedScene = preload("res://scenes/entities/RemotePlayer.tscn")
var default_bullet_scene: PackedScene = preload("res://scenes/entities/Bullet.tscn")

# 8 Pontos de Spawn no Mapa do Data Center / Sala de Servidores (2560x1440)
const SPAWN_CORNERS: Array[Vector2] = [
	Vector2(260, 240),   # 0: Hardware Lab (Noroeste)
	Vector2(2300, 240),  # 1: UPS & Power (Nordeste)
	Vector2(260, 1200),  # 2: Chillers & Refrigeração (Sudoeste)
	Vector2(2300, 1200), # 3: Storage & Cabos (Sudeste)
	Vector2(1280, 200),  # 4: Corredor Norte
	Vector2(1280, 1240), # 5: Corredor Sul
	Vector2(320, 720),   # 6: NOC Control Room (Oeste)
	Vector2(2240, 720)   # 7: Corredor de Racks (Leste)
]

var local_player: ChairPlayer = null
var active_bots: Array[BotPlayer] = []
var remote_players: Dictionary = {} # player_id -> RemotePlayer
var is_game_over: bool = false
var is_player_eliminated: bool = false
var is_spectating_clean: bool = false
var is_returning_to_lobby: bool = false

var match_duration: float = 180.0 # 3 minutos até as 18h
var match_timer: float = 0.0

var spectator_camera: Camera2D = null
var spectator_target_index: int = 0

func _ready() -> void:
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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R and not NetworkManager.is_connected_to_ws:
			get_tree().reload_current_scene()
		elif is_player_eliminated or is_game_over:
			if event.keycode == KEY_SPACE:
				_enter_clean_spectator_mode()
			elif event.keycode == KEY_ESCAPE:
				_return_to_lobby()
			elif event.keycode == KEY_TAB:
				_cycle_spectator_target()

func _enter_clean_spectator_mode() -> void:
	is_spectating_clean = true
	if game_hud:
		game_hud.hide_game_over_banner()
		game_hud.update_info("🎥 MODO ESPECTADOR: [WASD/Setas] Mover | [TAB] Trocar Alvo | [ESC] Lobby")

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
			if game_hud:
				game_hud.update_info("🎥 Focando em: " + str(target_name) + " | [WASD/Setas] Mover | [TAB] Trocar | [ESC] Lobby")

func _start_5s_countdown_to_lobby() -> void:
	if is_returning_to_lobby: return
	is_returning_to_lobby = true
	
	if game_hud:
		for i in range(5, 0, -1):
			game_hud.show_countdown(i)
			await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(5.0).timeout
		
	_return_to_lobby()

func _return_to_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/LobbyScene.tscn")

func _process(delta: float) -> void:
	if not is_returning_to_lobby:
		match_timer += delta
		if game_hud:
			game_hud.update_clock(match_timer, match_duration)
			game_hud.set_radar_targets(local_player if is_instance_valid(local_player) else null, active_bots, remote_players, spectator_camera if is_instance_valid(spectator_camera) else null)
		_update_reboot_zone_status()
		_check_match_status()
		
	if is_instance_valid(spectator_camera) and (is_player_eliminated or is_game_over or is_spectating_clean):
		var cam_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): cam_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): cam_dir.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): cam_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): cam_dir.x += 1.0
		
		if cam_dir != Vector2.ZERO:
			spectator_camera.global_position += cam_dir.normalized() * 750.0 * delta
			spectator_camera.global_position.x = clamp(spectator_camera.global_position.x, 640.0, 1920.0)
			spectator_camera.global_position.y = clamp(spectator_camera.global_position.y, 360.0, 1080.0)

func _update_reboot_zone_status() -> void:
	if is_game_over or is_player_eliminated or game_hud == null: return
	var reboot = get_tree().get_first_node_in_group("reboot_zone") as RebootZone
	if reboot and is_instance_valid(reboot):
		if reboot.cooldown_timer > 0.0:
			var sec_left = int(ceil(reboot.cooldown_timer))
			game_hud.update_info("🛡️ ZONA SEGURA: Reboot do RH inicia em " + str(sec_left) + "s! Colete armas nas caixas!")
		else:
			game_hud.update_info("⚠️ ATENÇÃO: O REBOOT DO RH ESTÁ ENCOLHENDO O ANDAR! FUJA DA NÉVOA!")

func _generate_procedural_partitions() -> void:
	var deploy_boxes = $DeployBoxes.get_children()
	for box in deploy_boxes:
		if box.has_method("relocate_randomly"):
			box.relocate_randomly()

func get_valid_loot_spawn(calling_box: Node2D) -> Vector2:
	var candidate_slots: Array[Vector2] = [
		Vector2(480, 220), Vector2(2060, 240),
		Vector2(480, 720), Vector2(1280, 720),
		Vector2(2060, 720), Vector2(480, 1220),
		Vector2(2060, 1200), Vector2(1280, 200)
	]
	candidate_slots.shuffle()
	
	var other_boxes = $DeployBoxes.get_children()
	for slot in candidate_slots:
		var slot_valid = true
		for box in other_boxes:
			if box != calling_box and is_instance_valid(box) and box.visible:
				if box.global_position.distance_to(slot) < 140.0:
					slot_valid = false
					break
		if slot_valid: return slot
			
	return Vector2(randf_range(300.0, 2200.0), randf_range(200.0, 1150.0))

func _setup_match() -> void:
	is_game_over = false
	is_player_eliminated = false
	is_spectating_clean = false
	is_returning_to_lobby = false
	active_bots.clear()
	remote_players.clear()
	
	for p in get_tree().get_nodes_in_group("players"):
		p.queue_free()
		
	if game_hud:
		game_hud.setup_profile(GameManager.player_nickname, GameManager.selected_avatar)
		
	# 1. Determinar o índice de Spawn do Jogador Local
	var local_spawn_pos = SPAWN_CORNERS[0]
	var net_players = NetworkManager.last_room_state.get("players", []) as Array
	
	if NetworkManager.is_connected_to_ws and net_players.size() > 0:
		var local_idx = 0
		for i in range(net_players.size()):
			if net_players[i] is Dictionary and net_players[i].get("id", "") == NetworkManager.local_player_id:
				local_idx = i
				break
		var loop_count = local_idx / SPAWN_CORNERS.size()
		var offset = Vector2(loop_count * 60, loop_count * 60)
		local_spawn_pos = SPAWN_CORNERS[local_idx % SPAWN_CORNERS.size()] + offset
	
	local_player = chair_scene.instantiate() as ChairPlayer
	local_player.global_position = local_spawn_pos
	local_player.add_to_group("players")
	add_child(local_player)
	
	local_player.hp_changed.connect(_on_player_hp_changed)
	local_player.item_changed.connect(_on_player_item_changed)
	local_player.chair_destroyed.connect(_on_player_destroyed)
	_on_player_hp_changed(local_player.post_it_hp)
	_on_player_item_changed("NENHUM")
	
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
				
				var loop_count = i / SPAWN_CORNERS.size()
				var offset = Vector2(loop_count * 60, loop_count * 60)
				var remote_spawn_pos = SPAWN_CORNERS[i % SPAWN_CORNERS.size()] + offset
				remote_inst.global_position = remote_spawn_pos
					
				remote_inst.add_to_group("players")
				add_child(remote_inst)
				remote_players[p_id] = remote_inst
				remote_inst.chair_destroyed.connect(_on_remote_chair_destroyed.bind(p_id))
				
	# 3. Se estiver jogando sozinho, spawnar bots de treino nas outras pontas!
	if remote_players.is_empty():
		var bot_names = ["SysAdmin_Bot", "NOC_Operator", "Infra_Glitch"]
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
		var shooter_node = remote_players.get(p_id, null)
		var bullet_inst = default_bullet_scene.instantiate() as Bullet
		bullet_inst.setup(pos, dir, shooter_node)
		add_child(bullet_inst)
		GameManager.play_sfx("res://assets/sfx/Sound FX Starter Pack Vol. 1/Retro/Attack.wav", -12.0)

func _on_remote_player_hit(target_id: String, _attacker_id: String, remaining_hp: int) -> void:
	if target_id == NetworkManager.local_player_id and is_instance_valid(local_player):
		if local_player.has_method("sync_hp"):
			local_player.sync_hp(remaining_hp)
	elif remote_players.has(target_id):
		var remote_inst = remote_players[target_id] as RemotePlayer
		if is_instance_valid(remote_inst):
			remote_inst.post_it_hp = remaining_hp
			remote_inst._update_post_its()
			remote_inst._update_nameplate_text()
			remote_inst._play_hit_feedback()
			remote_inst._spawn_damage_indicator()
			if remote_inst.post_it_hp <= 0:
				remote_players.erase(target_id)
				_check_match_status()

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
			if game_hud:
				game_hud.show_game_over_banner("🏆 SEXTOU! VITÓRIA ROYALE!\nVOCÊ SOBREVIVEU AO DEPLOY NO DATA CENTER!", true)
				game_hud.flash_screen(Color(0.95, 0.85, 0.2, 0.5), 0.5)
		else:
			if remote_players.size() > 0:
				var first_remote = remote_players.values()[0] as RemotePlayer
				if is_instance_valid(first_remote):
					winner_name = first_remote.nickname
			elif active_bots.size() > 0 and is_instance_valid(active_bots[0]):
				winner_name = active_bots[0].get_meta("nickname", "SysAdmin_Bot") as String
			else:
				winner_name = "O RH (Reboot Geral)"
				
			if game_hud:
				game_hud.show_game_over_banner("🏆 FIM DA PARTIDA!\n👑 VENCEDOR DO DEPLOY: " + winner_name, false)
				game_hud.flash_screen(Color(0.9, 0.1, 0.1, 0.5), 0.4)
			
		_start_5s_countdown_to_lobby()

func _on_player_hp_changed(hp: int) -> void:
	if game_hud and not is_game_over:
		game_hud.update_hp(hp)

func _on_player_item_changed(item_name: String) -> void:
	if game_hud:
		game_hud.update_item(item_name)

func _on_player_destroyed(_chair: ChairPlayer) -> void:
	if NetworkManager.is_connected_to_ws:
		NetworkManager.send_eliminated(NetworkManager.local_player_id)
	
	is_player_eliminated = true
	_activate_spectator_mode()
	if game_hud:
		game_hud.show_game_over_banner("💀 REINICIADO PELO RH!\n[ESPAÇO] Modo Espectador | [TAB] Trocar Alvo | [ESC] Voltar ao Lobby", false)
		game_hud.flash_screen(Color(0.9, 0.1, 0.1, 0.8), 0.3)
	_check_match_status()

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
			var b_nick = bot.get_meta("nickname", "SysAdmin_Bot") as String
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
