extends Control

@onready var nickname_input: LineEdit = $MarginContainer/VBoxContainer/ProfileHBox/NicknameLineEdit
@onready var skin_option: OptionButton = $MarginContainer/VBoxContainer/ProfileHBox/SkinOptionButton
@onready var players_list_label: RichTextLabel = $MarginContainer/VBoxContainer/MainHBox/PlayersVBox/PlayersListLabel

# Controles do Host
@onready var host_panel: VBoxContainer = $MarginContainer/VBoxContainer/MainHBox/HostSettingsVBox
@onready var game_mode_option: OptionButton = $MarginContainer/VBoxContainer/MainHBox/HostSettingsVBox/GameModeOption
@onready var control_mode_option: OptionButton = $MarginContainer/VBoxContainer/MainHBox/HostSettingsVBox/ControlModeOption
@onready var duration_option: OptionButton = $MarginContainer/VBoxContainer/MainHBox/HostSettingsVBox/DurationOption
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton

# Visão do Jogador (Non-Host)
@onready var non_host_info_label: Label = $MarginContainer/VBoxContainer/MainHBox/NonHostInfoLabel
@onready var duos_panel_label: RichTextLabel = $MarginContainer/VBoxContainer/MainHBox/DuosVBox/DuosListLabel

func _ready() -> void:
	_setup_ui_options()
	_connect_signals()
	
	# Fazer Handshake e Conectar à Rede ao entrar no Lobby
	if not NetworkManager.is_connected_to_ws:
		NetworkManager.perform_cold_start_handshake()

func _setup_ui_options() -> void:
	skin_option.clear()
	var skins = GameManager.skins_info.keys()
	for i in range(skins.size()):
		var key = skins[i]
		var info = GameManager.skins_info[key]
		skin_option.add_item(info["icon"] + " " + info["name"], i)
		
	game_mode_option.clear()
	game_mode_option.add_item("🏆 Battle Royale (BR)", 0)
	game_mode_option.add_item("⚔️ Team Deathmatch (TDM)", 1)
	
	control_mode_option.clear()
	control_mode_option.add_item("🕹️ Solo (Movimento + Tiro)", 0)
	control_mode_option.add_item("🤝 Duo (Piloto + Artilheiro)", 1)
	
	duration_option.clear()
	duration_option.add_item("⏱️ 3 Minutos", 0)
	duration_option.add_item("⏱️ 5 Minutos", 1)
	duration_option.add_item("⏱️ 10 Minutos", 2)
	
	var avatar_option = $MarginContainer/VBoxContainer/ProfileHBox.get_node_or_null("AvatarOptionButton") as OptionButton
	if avatar_option:
		avatar_option.clear()
		for i in range(GameManager.avatars_list.size()):
			var _file_name = GameManager.avatars_list[i]
			avatar_option.add_item("👤 Avatar " + str(i + 1), i)
		avatar_option.item_selected.connect(func(idx):
			if idx >= 0 and idx < GameManager.avatars_list.size():
				GameManager.selected_avatar = GameManager.avatars_list[idx]
		)

func _connect_signals() -> void:
	nickname_input.text_changed.connect(_on_profile_changed)
	nickname_input.text_submitted.connect(_on_profile_changed)
	skin_option.item_selected.connect(func(_idx): _on_profile_changed(nickname_input.text))
	
	game_mode_option.item_selected.connect(_on_host_settings_changed)
	control_mode_option.item_selected.connect(_on_host_settings_changed)
	duration_option.item_selected.connect(_on_host_settings_changed)
	
	start_button.pressed.connect(_on_start_pressed)
	
	NetworkManager.room_state_updated.connect(_on_room_state_updated)
	NetworkManager.match_started.connect(_on_match_started)
	NetworkManager.connection_established.connect(_on_connection_established)

func _on_connection_established(p_id: String, is_host: bool) -> void:
	nickname_input.text = "Player_" + p_id
	_on_profile_changed(nickname_input.text)
	host_panel.visible = is_host
	non_host_info_label.visible = not is_host
	start_button.visible = is_host

func _on_profile_changed(_text: String) -> void:
	var nick = nickname_input.text.strip_edges()
	if nick.is_empty():
		nick = "Player_Anon"
	GameManager.player_nickname = nick
	var skins = GameManager.skins_info.keys()
	var selected_skin = skins[skin_option.selected]
	NetworkManager.update_profile(nick, selected_skin)

func _on_host_settings_changed(_idx: int) -> void:
	if not NetworkManager.is_host:
		return
	var g_mode = "BR" if game_mode_option.selected == 0 else "TDM"
	var c_mode = "SOLO" if control_mode_option.selected == 0 else "DUO"
	var dur = 3 if duration_option.selected == 0 else (5 if duration_option.selected == 1 else 10)
	NetworkManager.update_room_settings(g_mode, c_mode, dur)

func _on_room_state_updated(state: Dictionary) -> void:
	var is_host = NetworkManager.is_host
	host_panel.visible = is_host
	non_host_info_label.visible = not is_host
	start_button.visible = is_host
	
	var players = state.get("players", []) as Array
	var g_mode = state.get("gameMode", "BR") as String
	var c_mode = state.get("controlMode", "SOLO") as String
	var dur = state.get("durationMinutes", 5) as int
	var duos = state.get("duos", []) as Array
	
	# Atualizar Lista de Players
	var list_text = "[color=#F1C40F][b]👥 PLAYERS CONECTADOS (" + str(players.size()) + "):[/b][/color]\n\n"
	for p in players:
		var p_dict = p as Dictionary
		var host_tag = " [color=#E74C3C][👑 HOST][/color]" if p_dict.get("isHost", false) else ""
		var skin_key = p_dict.get("skin", "DEV") as String
		var skin_icon = GameManager.skins_info.get(skin_key, {}).get("icon", "💻")
		list_text += skin_icon + " " + p_dict.get("nickname", "") + host_tag + "\n"
		
	players_list_label.text = list_text
	
	# Atualizar Visão Não-Host
	if not is_host:
		non_host_info_label.text = "👑 Configurações do Host:\n• Modo: " + g_mode + "\n• Controle: " + c_mode + "\n• Tempo: " + str(dur) + " min"
		
	# Atualizar Painel de Duplas Pareadas
	var duos_text = "[color=#3498DB][b]🤝 PAREAMENTO DE DUPLAS (" + c_mode + "):[/b][/color]\n\n"
	if c_mode == "SOLO":
		duos_text += "[i]Modo Solo Ativo: Cada participante controla sua própria cadeira.[/i]"
	else:
		for i in range(duos.size()):
			var d = duos[i] as Dictionary
			duos_text += "[b]Dupla " + str(i + 1) + ":[/b] " + d.get("driver", "") + " (Piloto) + " + d.get("gunner", "") + " (Artilheiro)\n"
			
	duos_panel_label.text = duos_text

func _on_start_pressed() -> void:
	_on_profile_changed(nickname_input.text)
	if NetworkManager.is_host:
		NetworkManager.start_match()

func _on_match_started(_data: Dictionary) -> void:
	get_tree().change_scene_to_file(GameManager.get_random_map_scene())
