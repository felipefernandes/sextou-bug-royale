class_name RemotePlayer
extends CharacterBody2D

signal chair_destroyed(chair: RemotePlayer)

@export var player_id: String = ""
@export var nickname: String = "RemoteDev"
@export var skin_key: String = "DEV"

@onready var visual: ColorRect = $ChairVisual
@onready var gun_anchor: Node2D = $GunAnchor
@onready var post_its_container: Node2D = $PostItsContainer
@onready var nameplate_label: Label = $NameplateLabel

var target_position: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0
var target_gun_rotation: float = 0.0
var post_it_hp: int = 3
var is_spectator_visible: bool = false

func _ready() -> void:
	target_position = global_position
	target_rotation = rotation
	_apply_skin_color()
	_setup_nameplate()

func _setup_nameplate() -> void:
	if nameplate_label == null:
		nameplate_label = Label.new()
		nameplate_label.name = "NameplateLabel"
		nameplate_label.position = Vector2(-50, -45)
		nameplate_label.custom_minimum_size = Vector2(100, 20)
		nameplate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameplate_label.modulate = Color(0.95, 0.85, 0.2, 1.0)
		var font_pixel = load("res://assets/fonts/PressStart2P-Regular.ttf") as Font
		if font_pixel:
			nameplate_label.add_theme_font_override("font", font_pixel)
			nameplate_label.add_theme_font_size_override("font_size", 9)
		add_child(nameplate_label)
	nameplate_label.text = nickname

func _apply_skin_color() -> void:
	var skin_info = GameManager.skins_info.get(skin_key, GameManager.skins_info["DEV"])
	if is_spectator_visible:
		visual.color = skin_info["color"]
	else:
		visual.color = Color(0.65, 0.15, 0.85, 1.0)

func update_transform_data(pos: Vector2, rot: float, gun_rot: float) -> void:
	target_position = pos
	target_rotation = rot
	target_gun_rotation = gun_rot

func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(target_position, 15.0 * delta)
	rotation = lerp_angle(rotation, target_rotation, 15.0 * delta)
	if gun_anchor:
		gun_anchor.rotation = lerp_angle(gun_anchor.rotation, target_gun_rotation, 20.0 * delta)

func apply_damage(amount: int) -> void:
	post_it_hp = max(0, post_it_hp - amount)
	_update_post_its()
	if post_it_hp <= 0:
		chair_destroyed.emit(self)
		queue_free()

func _update_post_its() -> void:
	for i in range(1, 4):
		var p_it = post_its_container.get_node_or_null("PostIt" + str(i))
		if p_it:
			p_it.visible = (i <= post_it_hp)

func reveal_real_skin() -> void:
	is_spectator_visible = true
	_apply_skin_color()
