class_name CoffeePuddle
extends Area2D

@export var duration: float = 8.0
@export var damage_interval: float = 1.5

var shooter: Node2D = null
var chairs_inside: Array[ChairPlayer] = []
var damage_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	get_tree().create_timer(duration).timeout.connect(queue_free)

func _process(delta: float) -> void:
	if chairs_inside.size() > 0:
		damage_timer += delta
		if damage_timer >= damage_interval:
			damage_timer = 0.0
			for chair in chairs_inside:
				if is_instance_valid(chair) and chair != shooter:
					chair.take_damage(1)

func setup(puddle_shooter: Node2D) -> void:
	shooter = puddle_shooter

func _on_body_entered(body: Node2D) -> void:
	if body is ChairPlayer and body not in chairs_inside:
		chairs_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body in chairs_inside:
		chairs_inside.erase(body)
