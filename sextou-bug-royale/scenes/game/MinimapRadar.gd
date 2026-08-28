class_name MinimapRadar
extends Control

var map_size: Vector2 = Vector2(2560.0, 1440.0)
var local_player: Node2D = null
var active_bots: Array = []
var remote_players: Dictionary = {}
var spectator_camera: Camera2D = null

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w_size = size
	if w_size.x <= 10.0 or w_size.y <= 10.0:
		w_size = Vector2(220, 140)

	# 1. Moldura e Fundo do Minimapa
	draw_rect(Rect2(Vector2.ZERO, w_size), Color(0.06, 0.08, 0.12, 0.85), true)
	draw_rect(Rect2(Vector2.ZERO, w_size), Color(0.25, 0.7, 0.9, 0.8), false, 2.0)
	
	# 2. Linhas de grade dividindo os setores do escritório
	var sector_x = w_size.x * 0.5
	var sector_y = w_size.y * 0.5
	draw_line(Vector2(sector_x, 0), Vector2(sector_x, w_size.y), Color(1, 1, 1, 0.12), 1.0)
	draw_line(Vector2(0, sector_y), Vector2(w_size.x, sector_y), Color(1, 1, 1, 0.12), 1.0)
	
	var scale_x = w_size.x / map_size.x
	var scale_y = w_size.y / map_size.y
	
	# 3. Névoa de Reboot do RH (Círculo Púrpura)
	var reboot = get_tree().get_first_node_in_group("reboot_zone") as RebootZone
	if reboot and is_instance_valid(reboot):
		var r_center = reboot.global_position
		var r_radius = reboot.current_radius
		var mini_c = Vector2(r_center.x * scale_x, r_center.y * scale_y)
		var mini_r = r_radius * scale_x
		draw_arc(mini_c, mini_r, 0, TAU, 32, Color(0.7, 0.2, 0.9, 0.9), 2.0)
		draw_circle(mini_c, max(1.0, mini_r), Color(0.7, 0.2, 0.9, 0.12))
		
	# 4. Caixas de Deploy (Loot Boxes)
	var boxes = get_tree().get_nodes_in_group("deploy_boxes")
	for box in boxes:
		if is_instance_valid(box) and box.visible:
			var b_pos = Vector2(box.global_position.x * scale_x, box.global_position.y * scale_y)
			draw_rect(Rect2(b_pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.95, 0.85, 0.2, 0.9), true)

	# 5. Bots Inimigos (Pontos Vermelhos)
	for bot in active_bots:
		if is_instance_valid(bot):
			var b_pos = Vector2(bot.global_position.x * scale_x, bot.global_position.y * scale_y)
			draw_circle(b_pos, 3.0, Color(0.9, 0.2, 0.2, 0.9))

	# 6. Jogadores Remotos (Pontos Laranjas)
	for r_p in remote_players.values():
		if is_instance_valid(r_p):
			var r_pos = Vector2(r_p.global_position.x * scale_x, r_p.global_position.y * scale_y)
			draw_circle(r_pos, 3.0, Color(0.95, 0.6, 0.1, 0.9))

	# 7. Jogador Local / Espectador (Ponto Verde Brilhante)
	var target_node: Node2D = null
	if is_instance_valid(local_player):
		target_node = local_player
	elif is_instance_valid(spectator_camera):
		target_node = spectator_camera

	if is_instance_valid(target_node):
		var p_pos = Vector2(target_node.global_position.x * scale_x, target_node.global_position.y * scale_y)
		draw_circle(p_pos, 4.0, Color(0.2, 0.9, 0.3, 1.0))
		draw_circle(p_pos, 1.5, Color(1.0, 1.0, 1.0, 1.0))
