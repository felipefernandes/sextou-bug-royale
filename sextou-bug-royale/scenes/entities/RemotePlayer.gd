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
	_update_post_its()

func _setup_nameplate() -> void:
	if nameplate_label == null:
		nameplate_label = Label.new()
		nameplate_label.name = "NameplateLabel"
		nameplate_label.position = Vector2(-70, -48)
		nameplate_label.custom_minimum_size = Vector2(140, 24)
		nameplate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameplate_label.modulate = Color(0.95, 0.85, 0.2, 1.0)
		var font_pixel = load("res://assets/fonts/PressStart2P-Regular.ttf") as Font
		if font_pixel:
			nameplate_label.add_theme_font_override("font", font_pixel)
			nameplate_label.add_theme_font_size_override("font_size", 9)
		add_child(nameplate_label)
	_update_nameplate_text()

func _update_nameplate_text() -> void:
	if nameplate_label == null: return
	var hp_icons = ""
	for i in range(1, 4):
		hp_icons += "🟨" if i <= post_it_hp else "⬛"
	nameplate_label.text = nickname + "\n" + hp_icons

func _apply_skin_color() -> void:
	if visual == null: return
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
	global_position = global_position.lerp(target_position, 18.0 * delta)
	rotation = lerp_angle(rotation, target_rotation, 18.0 * delta)
	if gun_anchor:
		gun_anchor.rotation = lerp_angle(gun_anchor.rotation, target_gun_rotation, 20.0 * delta)

func take_damage(amount: int) -> void:
	apply_damage(amount)
	# Notificar a rede imediatamente sobre o acerto no oponente
	if NetworkManager.is_connected_to_ws and not player_id.is_empty():
		NetworkManager.send_hit(player_id, post_it_hp)

func apply_damage(amount: int) -> void:
	post_it_hp = max(0, post_it_hp - amount)
	_update_post_its()
	_update_nameplate_text()
	_play_hit_feedback()
	_spawn_damage_indicator()
	GameManager.play_sfx("res://assets/sfx/Sound FX Starter Pack Vol. 1/Retro/Damage.wav")
	
	if post_it_hp <= 0:
		chair_destroyed.emit(self)
		if NetworkManager.is_connected_to_ws and not player_id.is_empty():
			NetworkManager.send_eliminated(player_id)
		queue_free()

func _update_post_its() -> void:
	if post_its_container == null: return
	for i in range(1, 4):
		var p_it = post_its_container.get_node_or_null("PostIt" + str(i))
		if p_it:
			p_it.visible = (i <= post_it_hp)

func _play_hit_feedback() -> void:
	if visual == null: return
	var orig_color = visual.color
	visual.color = Color(1.0, 0.2, 0.2, 1.0) # Flash vermelho vibrante de dano
	
	var tween = create_tween()
	tween.tween_property(visual, "color", orig_color, 0.2)

func _spawn_damage_indicator() -> void:
	var dmg_label = Label.new()
	dmg_label.text = "-1 📄"
	dmg_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	dmg_label.position = Vector2(-20, -55)
	var font_pixel = load("res://assets/fonts/PressStart2P-Regular.ttf") as Font
	if font_pixel:
		dmg_label.add_theme_font_override("font", font_pixel)
		dmg_label.add_theme_font_size_override("font_size", 10)
	add_child(dmg_label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dmg_label, "position:y", dmg_label.position.y - 30.0, 0.5)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(dmg_label.queue_free)

func reveal_real_skin() -> void:
	is_spectator_visible = true
	_apply_skin_color()
