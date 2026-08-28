class_name RebootZone
extends Node2D

signal zone_shrank(new_radius: float)
signal zone_started()

@export var initial_radius: float = 1600.0
@export var min_radius: float = 140.0
@export var shrink_speed: float = 16.0
@export var damage_interval: float = 2.5
@export var safe_cooldown_seconds: float = 20.0 # 20 segundos de preparação inicial

var current_radius: float = 1600.0
var damage_timer: float = 0.0
var cooldown_timer: float = 20.0
var has_started_shrinking: bool = false

func _ready() -> void:
	current_radius = initial_radius
	cooldown_timer = safe_cooldown_seconds

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			has_started_shrinking = true
			zone_started.emit()
		queue_redraw()
		return
		
	# Inicia o encolhimento após o cooldown
	if current_radius > min_radius:
		current_radius = max(min_radius, current_radius - shrink_speed * delta)
		queue_redraw()
		zone_shrank.emit(current_radius)
		
	damage_timer += delta
	if damage_timer >= damage_interval:
		damage_timer = 0.0
		_check_out_of_zone_players()

func _check_out_of_zone_players() -> void:
	if cooldown_timer > 0.0:
		return
		
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p is ChairPlayer:
			var dist = global_position.distance_to(p.global_position)
			if dist > current_radius:
				p.take_damage(1) # Dano contínuo da névoa de Reboot do RH

func _draw() -> void:
	if cooldown_timer > 0.0:
		# Visual sutil/amigável durante a fase de preparação
		var pulse = 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.005)
		draw_circle(Vector2.ZERO, current_radius, Color(0.2, 0.6, 0.9, 0.08 * pulse))
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 64, Color(0.3, 0.7, 1.0, 0.6 * pulse), 3.0)
	else:
		# Névoa roxa ativa de Reboot do RH
		draw_circle(Vector2.ZERO, current_radius, Color(0.6, 0.1, 0.8, 0.22))
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 64, Color(0.85, 0.2, 1.0, 0.95), 4.0)
