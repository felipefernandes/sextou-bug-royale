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
var patrol_dir: Vector2 = Vector2.DOWN

@onready var bot_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var bot_anim: AnimationPlayer = get_node_or_null("Sprite2D/AnimationPlayer")

func _ready() -> void:
	add_to_group("bots")
	super._ready()
	# Bots não possuem invulnerabilidade de spawn
	invulnerable_timer = 0.0
	
	# Ajustar atributos do Bot para deixá-lo equilibrado
	max_speed = 180.0 # Mais lento que o jogador (350.0)
	fire_rate = 1.4  # Atira uma vez a cada 1.4 segundos
	turn_speed = 4.0

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_scan_for_targets()
	_update_ai_state(delta)
	_update_bot_animation()
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
	
	# Mirar a arma na direção de patrulha
	gun_anchor.rotation = lerp_angle(gun_anchor.rotation, patrol_dir.angle(), turn_speed * delta)
	velocity = velocity.move_toward(patrol_dir.normalized() * (max_speed * 0.5), acceleration * delta)

func _do_engage(delta: float) -> void:
	if target_enemy == null:
		return
		
	var dir_to_target = (target_enemy.global_position - global_position).normalized()
	
	# Mirar suavemente no inimigo
	gun_anchor.rotation = lerp_angle(gun_anchor.rotation, dir_to_target.angle(), turn_speed * delta)
	
	# Aproximar-se devagar
	var dist = global_position.distance_to(target_enemy.global_position)
	if dist > attack_radius * 0.5:
		velocity = velocity.move_toward(dir_to_target * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, normal_friction * delta)
		
	# Atirar de forma cadenciada
	if fire_cooldown_timer <= 0:
		shoot()

func _update_bot_animation() -> void:
	if bot_sprite == null:
		return
		
	var speed = velocity.length()
	
	if speed > 10.0:
		if bot_anim != null and bot_anim.has_animation("moving") and bot_anim.current_animation != "moving":
			bot_anim.play("moving")
			
		# Controle de orientação por Flip (sem girar a raiz do nó para não ficar de cabeça para baixo)
		if absf(velocity.y) >= absf(velocity.x):
			# Movimentação vertical dominante
			bot_sprite.flip_h = false
			if velocity.y < -10.0:
				bot_sprite.flip_v = true  # Indo para CIMA (inverte o sprite base que aponta para baixo)
			elif velocity.y > 10.0:
				bot_sprite.flip_v = false # Indo para BAIXO (orientação padrão)
		else:
			# Movimentação horizontal dominante
			bot_sprite.flip_v = false
			if velocity.x < -10.0:
				bot_sprite.flip_h = true  # Indo para a ESQUERDA
			elif velocity.x > 10.0:
				bot_sprite.flip_h = false # Indo para a DIREITA
	else:
		if bot_anim != null and bot_anim.has_animation("idle") and bot_anim.current_animation != "idle":
			bot_anim.play("idle")

func reveal_real_skin() -> void:
	# Compatibilidade com modo espectador
	pass

func take_damage(amount: int) -> void:
	if bot_sprite:
		var orig_mod = bot_sprite.modulate
		bot_sprite.modulate = Color(2.0, 0.4, 0.4, 1.0)
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(self) and is_instance_valid(bot_sprite):
				bot_sprite.modulate = orig_mod
		)
	super.take_damage(amount)
