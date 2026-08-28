class_name ElasticBullet
extends CharacterBody2D

@export var speed: float = 750.0
@export var damage: int = 1
@export var max_bounces: int = 2

var bounces_left: int = 2
var shooter: Node2D = null

func _ready() -> void:
	bounces_left = max_bounces
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func setup(start_pos: Vector2, shoot_direction: Vector2, bullet_shooter: Node2D = null) -> void:
	global_position = start_pos
	velocity = shoot_direction.normalized() * speed
	shooter = bullet_shooter
	rotation = velocity.angle()
	if shooter != null and shooter is CollisionObject2D:
		add_collision_exception_with(shooter)

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider == null or collider == shooter or (shooter != null and (collider == shooter or collider.is_ancestor_of(shooter) or shooter.is_ancestor_of(collider))):
			return
			
		if collider.has_method("take_damage"):
			collider.take_damage(damage)
			queue_free()
		elif bounces_left > 0:
			bounces_left -= 1
			velocity = velocity.bounce(collision.get_normal())
			rotation = velocity.angle()
		else:
			queue_free()
