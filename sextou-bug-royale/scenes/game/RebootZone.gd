class_name RebootZone
extends Node2D

signal zone_shrank(new_radius: float)

@export var initial_radius: float = 1500.0
@export var min_radius: float = 120.0
@export var shrink_speed: float = 15.0
@export var damage_interval: float = 3.0

var current_radius: float = 1200.0
var damage_timer: float = 0.0

func _ready() -> void:
	current_radius = initial_radius

func _process(delta: float) -> void:
	if current_radius > min_radius:
		current_radius = max(min_radius, current_radius - shrink_speed * delta)
		queue_redraw()
		zone_shrank.emit(current_radius)
		
	damage_timer += delta
	if damage_timer >= damage_interval:
		damage_timer = 0.0
		_check_out_of_zone_players()

func _check_out_of_zone_players() -> void:
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p is ChairPlayer:
			var dist = global_position.distance_to(p.global_position)
			if dist > current_radius:
				p.take_damage(1) # Dano contínuo de Reboot do RH!

func _draw() -> void:
	draw_circle(Vector2.ZERO, current_radius, Color(0.6, 0.1, 0.8, 0.25))
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 64, Color(0.8, 0.2, 1.0, 0.9), 4.0)
