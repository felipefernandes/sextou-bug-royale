class_name DisketteBomb
extends Area2D

@export var speed: float = 500.0
@export var explosion_radius: float = 120.0
@export var knockback_force: float = 600.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null
var is_exploding: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(1.2).timeout.connect(explode)

func setup(start_pos: Vector2, shoot_dir: Vector2, bomb_shooter: Node2D = null) -> void:
	global_position = start_pos
	direction = shoot_dir.normalized()
	shooter = bomb_shooter
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if not is_exploding:
		position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body == null or body == shooter or (shooter != null and (body == shooter or body.is_ancestor_of(shooter) or shooter.is_ancestor_of(body))) or is_exploding:
		return
	explode()

func explode() -> void:
	if is_exploding:
		return
	is_exploding = true
	
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p != shooter:
			var dist = global_position.distance_to(p.global_position)
			if dist <= explosion_radius:
				if p.has_method("take_damage") and not (shooter is RemotePlayer):
					p.take_damage(1)
				if "velocity" in p:
					var push_dir = (p.global_position - global_position).normalized()
					p.velocity += push_dir * knockback_force
				
	queue_free()
