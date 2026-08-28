class_name BotPlayer
extends ChairPlayer

enum BotState {
	PATROL,
	ENGAGE
}

@export var detection_radius: float = 280.0
@export var attack_radius: float = 200.0

var current_state: BotState = BotState.PATROL
var target_enemy: Node2D = null
var patrol_timer: float = 0.0
var patrol_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	add_to_group("bots")
	super._ready()
	# Bots não possuem invulnerabilidade de spawn
	invulnerable_timer = 0.0
	
	# Ajustar atributos do Bot para deixá-lo mais fácil e equilibrado
	max_speed = 180.0 # Mais lento que o jogador (350.0)
	fire_rate = 1.4  # Atira uma vez a cada 1.4 segundos (muito mais cadenciado)
	turn_speed = 3.5
	
	# Visual Glitch/Bug Inimigo ("Eles são os Bugs!")
	var visual = $ChairVisual
	if visual:
		visual.color = Color(0.65, 0.15, 0.85, 1.0) # Glitch Roxo Pixelado

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_scan_for_targets()
	_update_ai_state(delta)
	move_and_slide()

func _scan_for_targets() -> void:
	target_enemy = null
	var min_dist = detection_radius
	
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p == self or not is_instance_valid(p):
			continue
			
		# Se o jogador estiver invisível (404 Not Found), o bot não consegue detectá-lo
		if p is ChairPlayer and p.is_invisible_404:
			continue
			
		var dist = global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			target_enemy = p

func _update_ai_state(delta: float) -> void:
	if target_enemy != null:
		current_state = BotState.ENGAGE
	else:
		current_state = BotState.PATROL

	match current_state:
		BotState.PATROL:
			_do_patrol(delta)
		BotState.ENGAGE:
			_do_engage(delta)

func _do_patrol(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0:
		patrol_timer = randf_range(2.5, 5.0)
		patrol_dir = Vector2.RIGHT.rotated(randf() * TAU)
	
	# Manter o bot rigorosamente dentro das paredes do mapa (2560x1440)
	if global_position.x < 50 or global_position.x > 2510 or global_position.y < 50 or global_position.y > 1390:
		patrol_dir = (Vector2(1280, 720) - global_position).normalized()
		global_position.x = clamp(global_position.x, 50.0, 2510.0)
		global_position.y = clamp(global_position.y, 50.0, 1390.0)
	
	var target_angle = patrol_dir.angle()
	rotation = lerp_angle(rotation, target_angle, turn_speed * delta)
	current_heading = Vector2.RIGHT.rotated(rotation)
	velocity = velocity.move_toward(current_heading * max_speed * 0.5, acceleration * delta)

func _do_engage(delta: float) -> void:
	if target_enemy == null:
		return
		
	var dir_to_target = (target_enemy.global_position - global_position).normalized()
	
	# Mirar suavemente no inimigo
	gun_anchor.rotation = lerp_angle(gun_anchor.rotation, dir_to_target.angle() - rotation, turn_speed * delta)
	
	# Aproximar-se devagar
	var dist = global_position.distance_to(target_enemy.global_position)
	if dist > attack_radius * 0.5:
		var target_angle = dir_to_target.angle()
		rotation = lerp_angle(rotation, target_angle, turn_speed * delta)
		current_heading = Vector2.RIGHT.rotated(rotation)
		velocity = velocity.move_toward(current_heading * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, normal_friction * delta)
		
	# Atirar de forma cadenciada
	if fire_cooldown_timer <= 0:
		shoot()

func reveal_real_skin() -> void:
	# Desativar o disfarce de Bug roxo no modo espectador e mostrar a skin corporativa real
	var visual = $ChairVisual
	if visual:
		visual.color = Color(0.95, 0.5, 0.2, 1.0) # Revela a skin corporativa real do bot

func take_damage(amount: int) -> void:
	# Feedback visual de impacto (Piscar branco/vermelho brilhante ao ser atingido)
	var visual = $ChairVisual
	if visual:
		visual.color = Color(1.0, 1.0, 1.0, 1.0)
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(visual):
				visual.color = Color(0.85, 0.2, 0.2, 1.0)
		)
		
	super.take_damage(amount)
