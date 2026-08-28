class_name ChairPlayer
extends CharacterBody2D

signal chair_destroyed(chair: ChairPlayer)
signal hp_changed(current_hp: int)
signal item_changed(item_name: String)

@export_category("Física da Cadeira")
@export var max_speed: float = 350.0
@export var acceleration: float = 900.0
@export var normal_friction: float = 600.0
@export var drift_friction: float = 120.0
@export var turn_speed: float = 6.0
@export var boost_multiplier: float = 1.6
@export var boost_duration: float = 0.8
@export var boost_cooldown: float = 3.0

@export_category("Combate & Itens")
@export var max_post_its: int = 3
@export var fire_rate: float = 0.25 # segundos entre tiros

# Preloads de Cenas de Armas (Garantidos via var interna para evitar override nulo no Inspetor)
var default_bullet_scene: PackedScene = preload("res://scenes/entities/Bullet.tscn")
var coffee_puddle_scene: PackedScene = preload("res://scenes/entities/CoffeePuddle.tscn")
var elastic_bullet_scene: PackedScene = preload("res://scenes/entities/ElasticBullet.tscn")
var diskette_bomb_scene: PackedScene = preload("res://scenes/entities/DisketteBomb.tscn")

var post_it_hp: int = 3
var is_drifting: bool = false
var is_boosting: bool = false
var boost_timer: float = 0.0
var boost_cooldown_timer: float = 0.0
var fire_cooldown_timer: float = 0.0
var current_heading: Vector2 = Vector2.RIGHT

# Inventário & Habilidades
var equipped_item: String = "NONE"
var elastic_ammo: int = 0
var coffee_ammo: int = 0
var has_ctrl_z_shield: bool = false
var is_invisible_404: bool = false
var pog_boost_timer: float = 0.0
var invulnerable_timer: float = 2.0

@onready var gun_anchor: Node2D = $GunAnchor
@onready var muzzle: Marker2D = $GunAnchor/Muzzle
@onready var post_it_container: Node2D = $PostItsContainer
@onready var chair_sprite: Sprite2D = get_node_or_null("ChairPlayerSprite")
@onready var sprite_anim: AnimationPlayer = get_node_or_null("ChairPlayerSprite/AnimationPlayer")

enum FacingDir { DOWN, UP, SIDE }
var facing_dir: FacingDir = FacingDir.DOWN
var facing_right: bool = false

func _ready() -> void:
	post_it_hp = max_post_its
	_update_post_its_visual()
	invulnerable_timer = 2.0
	_apply_skin_visual()

func _apply_skin_visual() -> void:
	if not is_in_group("bots"):
		var skin_data = GameManager.skins_info.get(GameManager.selected_skin)
		if skin_data and has_node("ChairVisual"):
			$ChairVisual.color = skin_data.color

var net_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if invulnerable_timer > 0:
		invulnerable_timer -= delta
		modulate.a = 0.5 if fmod(invulnerable_timer * 10.0, 2.0) > 1.0 else 1.0
	else:
		modulate.a = 1.0 if not is_invisible_404 else 0.3
		
	_handle_timers(delta)
	_handle_movement(delta)
	_handle_aiming()
	_handle_shooting()
	move_and_slide()
	
	if NetworkManager.is_connected_to_ws and not is_in_group("bots"):
		net_timer += delta
		if net_timer >= 0.05:
			net_timer = 0.0
			NetworkManager.send_transform(global_position, rotation, gun_anchor.rotation)

func _handle_timers(delta: float) -> void:
	if boost_timer > 0:
		boost_timer -= delta
		if boost_timer <= 0:
			is_boosting = false
	
	if boost_cooldown_timer > 0:
		boost_cooldown_timer -= delta
		
	if fire_cooldown_timer > 0:
		fire_cooldown_timer -= delta

	if pog_boost_timer > 0:
		pog_boost_timer -= delta

func _handle_movement(delta: float) -> void:
	var move_input := Vector2.ZERO
	var mode = GameManager.current_control_mode
	
	if mode == GameManager.ControlMode.SOLO_INTERN or mode == GameManager.ControlMode.DUO_LOCAL:
		move_input.x = Input.get_action_strength("right") - Input.get_action_strength("left")
		move_input.y = Input.get_action_strength("down") - Input.get_action_strength("up")

		# Movimento estilo Pacman: só um eixo por vez, sem diagonal
		if move_input.x != 0.0 and move_input.y != 0.0:
			if absf(move_input.x) >= absf(move_input.y):
				move_input.y = 0.0
			else:
				move_input.x = 0.0

		is_drifting = Input.is_key_pressed(KEY_SHIFT)
		
		if Input.is_key_pressed(KEY_SPACE) and boost_cooldown_timer <= 0:
			trigger_boost()

		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_E):
			use_equipped_item()

	_update_animation(move_input)

	if move_input != Vector2.ZERO:
		current_heading = move_input

		var active_speed = max_speed * (boost_multiplier if is_boosting else 1.0)
		if pog_boost_timer > 0:
			active_speed *= 1.8 # Super velocidade POG
			
		var target_velocity = current_heading * active_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		var current_friction = drift_friction if is_drifting else normal_friction
		velocity = velocity.move_toward(Vector2.ZERO, current_friction * delta)

func _update_animation(move_input: Vector2) -> void:
	# Eixo dominante decide a direção; parado, mantém a última direção (idle)
	if move_input.y < 0.0:
		facing_dir = FacingDir.UP
	elif move_input.y > 0.0:
		facing_dir = FacingDir.DOWN
	elif move_input.x != 0.0:
		facing_dir = FacingDir.SIDE
		facing_right = move_input.x > 0.0

	if chair_sprite != null:
		chair_sprite.flip_h = facing_dir == FacingDir.SIDE and not facing_right

	if sprite_anim == null:
		return

	var suffix := "down_front"
	match facing_dir:
		FacingDir.UP:
			suffix = "up_back"
		FacingDir.SIDE:
			suffix = "left"

	var prefix := "move_" if move_input != Vector2.ZERO else "idle_"
	var anim_name := prefix + suffix
	if sprite_anim.has_animation(anim_name) and sprite_anim.current_animation != anim_name:
		sprite_anim.play(anim_name)

func _handle_aiming() -> void:
	var mode = GameManager.current_control_mode
	if mode == GameManager.ControlMode.SOLO_INTERN or mode == GameManager.ControlMode.DUO_LOCAL:
		var mouse_pos = get_global_mouse_position()
		gun_anchor.look_at(mouse_pos)

func _handle_shooting() -> void:
	var mode = GameManager.current_control_mode
	if mode == GameManager.ControlMode.SOLO_INTERN:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown_timer <= 0:
			shoot()

func shoot() -> void:
	if fire_cooldown_timer > 0:
		return
		
	fire_cooldown_timer = fire_rate
	var shoot_dir = Vector2.RIGHT.rotated(gun_anchor.global_rotation)
	
	GameManager.play_sfx("res://assets/sfx/Sound FX Starter Pack Vol. 1/Retro/Attack.wav", -12.0)
	
	if NetworkManager.is_connected_to_ws and not is_in_group("bots"):
		NetworkManager.send_shoot(muzzle.global_position, shoot_dir, equipped_item)
	
	if equipped_item == "ELASTIC_GUN" and elastic_bullet_scene != null:
		var bullet_inst = elastic_bullet_scene.instantiate()
		bullet_inst.setup(muzzle.global_position, shoot_dir, self)
		get_parent().add_child(bullet_inst)
		
		elastic_ammo -= 1
		if elastic_ammo <= 0:
			equipped_item = "NONE"
			item_changed.emit("NENHUM")
		else:
			item_changed.emit("🟢 Elásticos (" + str(elastic_ammo) + ")")
	elif equipped_item == "DISKETTE_BOMB" and diskette_bomb_scene != null:
		var bomb_inst = diskette_bomb_scene.instantiate()
		bomb_inst.setup(muzzle.global_position, shoot_dir, self)
		get_parent().add_child(bomb_inst)
		equipped_item = "NONE"
		item_changed.emit("NENHUM")
	elif equipped_item == "COFFEE_SNIPER" and coffee_puddle_scene != null:
		var bullet_inst = default_bullet_scene.instantiate() as Bullet
		bullet_inst.setup(muzzle.global_position, shoot_dir, self)
		get_parent().add_child(bullet_inst)
		
		var puddle = coffee_puddle_scene.instantiate()
		puddle.setup(self)
		puddle.global_position = muzzle.global_position + shoot_dir * 250.0
		get_parent().add_child(puddle)
		
		coffee_ammo -= 1
		if coffee_ammo <= 0:
			equipped_item = "NONE"
			item_changed.emit("NENHUM")
		else:
			item_changed.emit("☕ Sniper de Café (" + str(coffee_ammo) + ")")
	else:
		var bullet_inst = default_bullet_scene.instantiate() as Bullet
		bullet_inst.setup(muzzle.global_position, shoot_dir, self)
		get_parent().add_child(bullet_inst)

func equip_item(item_type: String) -> void:
	equipped_item = item_type
	
	if equipped_item == "ELASTIC_GUN":
		elastic_ammo = 12
		item_changed.emit("🟢 Elásticos (" + str(elastic_ammo) + ")")
	elif equipped_item == "COFFEE_SNIPER":
		coffee_ammo = 5
		item_changed.emit("☕ Sniper de Café (" + str(coffee_ammo) + ")")
	elif equipped_item == "DISKETTE_BOMB":
		item_changed.emit("💾 Disquete Explosivo (1)")
	elif equipped_item == "CTRL_Z":
		has_ctrl_z_shield = true
		equipped_item = "NONE"
		item_changed.emit("🛡️ ESCUDO CTRL+Z ATIVADO!")
	elif equipped_item == "POG_BOOST":
		pog_boost_timer = 2.5
		equipped_item = "NONE"
		item_changed.emit("🚀 GAMBIARRA POG ATIVADA!")
	elif equipped_item == "NOT_FOUND_404":
		_activate_404_invisibility()
		equipped_item = "NONE"
		item_changed.emit("👻 404 NOT FOUND ATIVADO!")

func use_equipped_item() -> void:
	if equipped_item == "NONE":
		return
	shoot()

func _activate_404_invisibility() -> void:
	is_invisible_404 = true
	modulate.a = 0.3
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(self):
			is_invisible_404 = false
			modulate.a = 1.0
	)

func trigger_boost() -> void:
	is_boosting = true
	boost_timer = boost_duration
	boost_cooldown_timer = boost_cooldown

func take_damage(amount: int) -> void:
	if invulnerable_timer > 0:
		return
		
	if has_ctrl_z_shield:
		has_ctrl_z_shield = false
		item_changed.emit("NENHUM (ESCUDO UTILIZADO)")
		return

	post_it_hp = max(0, post_it_hp - amount)
	hp_changed.emit(post_it_hp)
	_update_post_its_visual()
	_play_hit_feedback()
	_spawn_damage_indicator()
	GameManager.play_sfx("res://assets/sfx/Sound FX Starter Pack Vol. 1/Retro/Damage.wav")
	
	if NetworkManager.is_connected_to_ws and not NetworkManager.local_player_id.is_empty():
		# Evitar que BotPlayers disparem hit para o NetworkManager do jogador local
		if not is_in_group("bots"):
			NetworkManager.send_hit(NetworkManager.local_player_id, post_it_hp)
	
	if post_it_hp <= 0:
		die()

func _play_hit_feedback() -> void:
	var flash_target = chair_sprite if chair_sprite else self
	var orig_mod = flash_target.modulate
	flash_target.modulate = Color(1.8, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(flash_target, "modulate", orig_mod, 0.2)

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

func die() -> void:
	chair_destroyed.emit(self)
	queue_free()

func _update_post_its_visual() -> void:
	if post_it_container == null:
		return
	var count = post_it_container.get_child_count()
	for i in range(count):
		var child = post_it_container.get_child(i)
		child.visible = i < post_it_hp
