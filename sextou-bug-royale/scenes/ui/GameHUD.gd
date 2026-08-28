class_name GameHUD
extends CanvasLayer

@onready var hud_root: Control = $HUD
@onready var player_avatar: Sprite2D = $HUD/PlayerAvatar
@onready var player_nick_label: Label = $HUD/PlayerNickLabel
@onready var hp_label: Label = $HUD/HpLabel
@onready var item_label: Label = $HUD/ItemLabel
@onready var icon_item_label: Label = $HUD/IconItemLabel
@onready var clock_label: Label = $HUD/ClockLabel
@onready var info_label: Label = $HUD/InfoLabel
@onready var dark_overlay: ColorRect = $HUD/DarkOverlay
@onready var flash_overlay: ColorRect = $HUD/FlashOverlay
@onready var marquee_banner: Panel = $HUD/MarqueeBanner
@onready var marquee_label: Label = $HUD/MarqueeBanner/MarqueeLabel
@onready var marquee_banner_countdown: Panel = $HUD/MarqueeBannerCountdown
@onready var countdown_label: Label = $HUD/MarqueeBannerCountdown/CountDownLabel
@onready var minimap: Control = $HUD/Minimap

var radar: MinimapRadar = null

func _ready() -> void:
	if minimap:
		radar = minimap as MinimapRadar
		if radar == null:
			radar = MinimapRadar.new()
			radar.name = "MinimapRadar"
			radar.size = minimap.size
			minimap.add_child(radar)

func setup_profile(nickname: String, avatar_file: String) -> void:
	if player_nick_label:
		player_nick_label.text = nickname
		
	if player_avatar and not avatar_file.is_empty():
		var tex_path = "res://assets/tilemaps/Characters/" + avatar_file
		if ResourceLoader.exists(tex_path):
			player_avatar.texture = load(tex_path)

func update_hp(current_hp: int, max_hp: int = 3) -> void:
	if hp_label:
		hp_label.text = "Post-its de Vida: " + str(current_hp) + " / " + str(max_hp)

func update_item(item_name: String) -> void:
	if item_label:
		item_label.text = item_name
	if icon_item_label:
		if "Elásticos" in item_name or "ELASTIC" in item_name:
			icon_item_label.text = "🟢"
		elif "Sniper" in item_name or "COFFEE" in item_name:
			icon_item_label.text = "☕"
		elif "Disquete" in item_name or "DISKETTE" in item_name:
			icon_item_label.text = "💾"
		elif "ESCUDO" in item_name or "CTRL_Z" in item_name:
			icon_item_label.text = "🛡️"
		elif "GAMBIARRA" in item_name or "POG" in item_name:
			icon_item_label.text = "🚀"
		elif "404" in item_name or "NOT_FOUND" in item_name:
			icon_item_label.text = "👻"
		else:
			icon_item_label.text = "✨"

func update_clock(elapsed_seconds: float, duration_seconds: float) -> void:
	if clock_label == null:
		return
	var remaining = max(0.0, duration_seconds - elapsed_seconds)
	var mins = int(remaining / 60.0)
	var secs = int(remaining) % 60
	clock_label.text = "🕒 17:%02d:%02d (HAPPY HOUR ÀS 18:00)" % [mins, secs]

func update_info(text: String) -> void:
	if info_label:
		info_label.text = text

func show_game_over_banner(message: String, is_victory: bool) -> void:
	if dark_overlay:
		dark_overlay.visible = true
		dark_overlay.color = Color(0.05, 0.25, 0.1, 0.4) if is_victory else Color(0.1, 0.05, 0.05, 0.6)
		
	if marquee_banner and marquee_label:
		marquee_banner.visible = true
		marquee_label.text = message
		if is_victory:
			marquee_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.3, 1.0))
		else:
			marquee_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2, 1.0))

func hide_game_over_banner() -> void:
	if marquee_banner:
		marquee_banner.visible = false
	if dark_overlay:
		dark_overlay.visible = false

func show_countdown(seconds: int) -> void:
	if marquee_banner_countdown and countdown_label:
		marquee_banner_countdown.visible = true
		countdown_label.text = "VOLTANDO PARA O LOBBY EM... %d" % seconds

func hide_countdown() -> void:
	if marquee_banner_countdown:
		marquee_banner_countdown.visible = false

func flash_screen(color: Color = Color.WHITE, duration: float = 0.35) -> void:
	if flash_overlay == null:
		return
	flash_overlay.visible = true
	flash_overlay.color = color
	var tween = create_tween()
	tween.tween_property(flash_overlay, "color:a", 0.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(flash_overlay):
			flash_overlay.visible = false
	)

func set_radar_targets(player: Node2D, bots: Array, remote_players_dict: Dictionary, camera: Camera2D) -> void:
	if radar and is_instance_valid(radar):
		radar.local_player = player
		radar.active_bots = bots
		radar.remote_players = remote_players_dict
		radar.spectator_camera = camera
