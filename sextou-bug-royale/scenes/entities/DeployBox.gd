class_name DeployBox
extends Area2D

signal item_collected(item_type: String, recipient: Node2D)

@export var respawn_time: float = 8.0
@export var unlock_duration: float = 0.8

var is_available: bool = true
var unlock_timer: float = 0.0
var active_chair: ChairPlayer = null

var items_dict: Dictionary = {
	"COFFEE_SNIPER": "☕",
	"ELASTIC_GUN": "🟢",
	"DISKETTE_BOMB": "💾",
	"CTRL_Z": "🛡️",
	"POG_BOOST": "🚀",
	"NOT_FOUND_404": "👻"
}

@onready var visual: Node2D = $Visual
@onready var box_base: ColorRect = $Visual/BoxBase
@onready var tape: ColorRect = $Visual/Tape
@onready var box_label: Label = $Visual/Label
@onready var progress_bar: ColorRect = $Visual/ProgressBarBackground/ProgressBarFill
@onready var progress_bg: ColorRect = $Visual/ProgressBarBackground
@onready var emoji_label: Label = $Visual/EmojiLabel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	progress_bg.visible = false
	emoji_label.visible = false

func _process(delta: float) -> void:
	if not is_available or active_chair == null:
		return
		
	unlock_timer += delta
	var progress = min(1.0, unlock_timer / unlock_duration)
	progress_bar.size.x = progress * 24.0
	
	if unlock_timer >= unlock_duration:
		_open_box()

func _on_body_entered(body: Node2D) -> void:
	if not is_available:
		return
	if body is ChairPlayer and active_chair == null:
		active_chair = body
		unlock_timer = 0.0
		progress_bg.visible = true
		progress_bar.size.x = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body == active_chair:
		active_chair = null
		unlock_timer = 0.0
		progress_bg.visible = false

func _open_box() -> void:
	is_available = false
	var recipient = active_chair # Salvar referência do jogador ANTES de desativar monitoring!
	active_chair = null
	monitoring = false
	progress_bg.visible = false
	
	# Esconder a caixa imediatamente após a coleta!
	box_base.visible = false
	tape.visible = false
	box_label.visible = false
	
	var item_keys = items_dict.keys()
	var picked_item = item_keys.pick_random() as String
	var emoji_char = items_dict[picked_item] as String
	
	if recipient and is_instance_valid(recipient) and recipient.has_method("equip_item"):
		recipient.equip_item(picked_item)
		item_collected.emit(picked_item, recipient)
		
	# Efeito Visual do Emoji Flutuando
	_animate_emoji_reveal(emoji_char)
	
	# Responsável por respawnar a caixa em uma nova posição após respawn_time
	get_tree().create_timer(respawn_time).timeout.connect(func():
		if is_instance_valid(self):
			_set_active(true)
	)

func _animate_emoji_reveal(emoji: String) -> void:
	emoji_label.text = emoji
	emoji_label.visible = true
	emoji_label.global_position = global_position + Vector2(-12, -20)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(emoji_label, "global_position:y", emoji_label.global_position.y - 40.0, 1.2)
	tween.tween_property(emoji_label, "modulate:a", 0.0, 1.2).set_delay(0.3)
	
	await tween.finished
	emoji_label.visible = false
	emoji_label.modulate.a = 1.0

func relocate_randomly() -> void:
	var map = get_tree().current_scene
	if map and map.has_method("get_valid_loot_spawn"):
		global_position = map.get_valid_loot_spawn(self)
	else:
		var random_x = randf_range(200.0, 1080.0)
		var random_y = randf_range(160.0, 560.0)
		global_position = Vector2(random_x, random_y)

func _set_active(active: bool) -> void:
	if active:
		relocate_randomly()
		box_base.visible = true
		tape.visible = true
		box_label.visible = true
		
	is_available = active
	visible = active
	monitoring = active
	progress_bg.visible = false
	unlock_timer = 0.0
