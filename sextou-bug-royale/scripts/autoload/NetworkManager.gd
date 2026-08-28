extends Node

signal connection_established(player_id: String, is_host: bool)
signal room_state_updated(state_data: Dictionary)
signal match_started(state_data: Dictionary)
signal remote_player_transformed(player_id: String, pos: Vector2, rot: float, gun_rot: float)
signal remote_player_shot(player_id: String, pos: Vector2, dir: Vector2, item_type: String)
signal remote_player_hit(target_id: String, attacker_id: String, remaining_hp: int)
signal remote_player_eliminated(player_id: String)
signal box_opened_synced(box_id: String, new_pos: Vector2, item_type: String)
signal cold_start_progress(message: String)

const PROD_HTTP_URL: String = "https://sextou-bug-royale.onrender.com/health"
const PROD_WS_URL: String = "wss://sextou-bug-royale.onrender.com"

const LOCAL_HTTP_URL: String = "http://localhost:3000/health"
const LOCAL_WS_URL: String = "ws://localhost:3000"

var server_http_url: String = PROD_HTTP_URL
var server_ws_url: String = PROD_WS_URL

var ws_peer: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_ws: bool = false
var local_player_id: String = ""
var is_host: bool = false
var last_room_state: Dictionary = {}

func _ready() -> void:
	set_process(false)
	_configure_environment_urls()

func _configure_environment_urls() -> void:
	if OS.has_feature("editor"):
		server_http_url = LOCAL_HTTP_URL
		server_ws_url = LOCAL_WS_URL
	elif OS.has_feature("web"):
		var hostname: String = ""
		if ClassDB.class_exists("JavaScriptBridge"):
			var js_host = JavaScriptBridge.eval("window.location.hostname", true)
			if js_host != null:
				hostname = str(js_host)
		
		if hostname == "localhost" or hostname == "127.0.0.1":
			server_http_url = LOCAL_HTTP_URL
			server_ws_url = LOCAL_WS_URL
		else:
			server_http_url = PROD_HTTP_URL
			server_ws_url = PROD_WS_URL
	else:
		server_http_url = PROD_HTTP_URL
		server_ws_url = PROD_WS_URL
	
	print("[NetworkManager] Conexão configurada: HTTP=", server_http_url, " | WS=", server_ws_url)

func perform_cold_start_handshake() -> void:
	cold_start_progress.emit("Conectando aos servidores da firma... (Acordando o TI)")
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_handshake_completed.bind(http_request))
	
	var err = http_request.request(server_http_url)
	if err != OK:
		cold_start_progress.emit("Erro de conexão local. Tentando conectar diretamente ao servidor...")
		connect_to_websocket()

func _on_handshake_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, http_req: HTTPRequest) -> void:
	http_req.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		cold_start_progress.emit("Servidor do TI Ativo! Abrindo conexão de rede...")
		connect_to_websocket()
	else:
		cold_start_progress.emit("Servidor do TI acordando (Render Cold Start)... Tentando em 3s...")
		get_tree().create_timer(3.0).timeout.connect(perform_cold_start_handshake)

func connect_to_websocket() -> void:
	ws_peer = WebSocketPeer.new()
	var err = ws_peer.connect_to_url(server_ws_url)
	if err == OK:
		set_process(true)
	else:
		print("[NetworkManager] Erro ao conectar ao WebSocket: ", err)

func _process(_delta: float) -> void:
	ws_peer.poll()
	var state = ws_peer.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_ws:
			is_connected_to_ws = true
			print("[NetworkManager] Conexão WebSocket Aberta com Sucesso!")
			
		while ws_peer.get_available_packet_count() > 0:
			var packet = ws_peer.get_packet()
			var text = packet.get_string_from_utf8()
			_parse_network_message(text)
			
	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected_to_ws:
			is_connected_to_ws = false
			print("[NetworkManager] Conexão WebSocket Encerrada.")
			set_process(false)

func _parse_network_message(json_text: String) -> void:
	var json = JSON.new()
	var err = json.parse(json_text)
	if err != OK:
		return
		
	var data = json.get_data() as Dictionary
	var type = data.get("type", "") as String
	
	match type:
		"connected":
			local_player_id = data.get("playerId", "")
			is_host = data.get("isHost", false)
			connection_established.emit(local_player_id, is_host)
		"room_state":
			last_room_state = data.get("data", {})
			var players_list = last_room_state.get("players", []) as Array
			for p in players_list:
				if p is Dictionary and p.get("id", "") == local_player_id:
					var new_host_status = p.get("isHost", false)
					if is_host != new_host_status:
						is_host = new_host_status
						print("[NetworkManager] 👑 Status de Host sincronizado para: ", is_host)
					break
			room_state_updated.emit(last_room_state)
		"match_started":
			match_started.emit(data.get("data", {}))
		"player_transform":
			var p_id = data.get("playerId", "")
			var pos_dict = data.get("position", {})
			var pos = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
			var rot = float(data.get("rotation", 0.0))
			var gun_rot = float(data.get("gunRotation", 0.0))
			remote_player_transformed.emit(p_id, pos, rot, gun_rot)
		"player_shoot":
			var p_id = data.get("playerId", "")
			var pos_dict = data.get("position", {})
			var dir_dict = data.get("direction", {})
			var pos = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
			var dir = Vector2(dir_dict.get("x", 0), dir_dict.get("y", 0))
			var item_type = data.get("itemType", "STAPLE")
			remote_player_shot.emit(p_id, pos, dir, item_type)
		"player_hit":
			var target_id = data.get("targetId", "")
			var attacker_id = data.get("attackerId", "")
			var rem_hp = int(data.get("remainingHp", 3))
			remote_player_hit.emit(target_id, attacker_id, rem_hp)
		"player_eliminated":
			var p_id = data.get("playerId", "")
			remote_player_eliminated.emit(p_id)
		"box_opened":
			var b_id = data.get("boxId", "")
			var pos_dict = data.get("newPosition", {})
			var new_pos = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
			var item_type = data.get("itemType", "")
			box_opened_synced.emit(b_id, new_pos, item_type)

func update_profile(nickname: String, skin: String) -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({"type": "update_profile", "nickname": nickname, "skin": skin})
	ws_peer.send_text(msg)

func update_room_settings(game_mode: String, control_mode: String, duration: int) -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({
		"type": "update_room_settings",
		"gameMode": game_mode,
		"controlMode": control_mode,
		"durationMinutes": duration
	})
	ws_peer.send_text(msg)

func notify_return_to_lobby(nickname: String, skin: String) -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({
		"type": "return_to_lobby",
		"nickname": nickname,
		"skin": skin
	})
	ws_peer.send_text(msg)

func start_match() -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({"type": "start_match"})
	ws_peer.send_text(msg)

func send_transform(pos: Vector2, rot: float, gun_rot: float) -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({
		"type": "player_transform",
		"position": {"x": pos.x, "y": pos.y},
		"rotation": rot,
		"gunRotation": gun_rot
	})
	ws_peer.send_text(msg)

func send_shoot(pos: Vector2, dir: Vector2, item_type: String) -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({
		"type": "player_shoot",
		"position": {"x": pos.x, "y": pos.y},
		"direction": {"x": dir.x, "y": dir.y},
		"itemType": item_type
	})
	ws_peer.send_text(msg)

func send_hit(target_id: String, remaining_hp: int) -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({
		"type": "player_hit",
		"targetId": target_id,
		"remainingHp": remaining_hp
	})
	ws_peer.send_text(msg)

func send_eliminated(player_id: String) -> void:
	if not is_connected_to_ws: return
	var msg = JSON.stringify({
		"type": "player_eliminated",
		"playerId": player_id
	})
	ws_peer.send_text(msg)
