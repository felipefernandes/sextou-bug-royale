class_name Bullet
extends Area2D

@export var speed: float = 800.0
@export var damage: int = 1
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func setup(start_pos: Vector2, shoot_direction: Vector2, bullet_shooter: Node2D = null) -> void:
	global_position = start_pos
	direction = shoot_direction.normalized()
	rotation = direction.angle()
	shooter = bullet_shooter
	if shooter != null and shooter is CollisionObject2D:
		add_collision_exception_with(shooter)

func _on_body_entered(body: Node2D) -> void:
	if body == null or body == shooter or (shooter != null and (body == shooter or body.is_ancestor_of(shooter) or shooter.is_ancestor_of(body))):
		return # Não causa dano ao próprio atirador
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body is TileMapLayer or body is StaticBody2D:
		queue_free()
