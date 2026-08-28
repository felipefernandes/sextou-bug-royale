extends Node

# Modos de Controle para o Jogador Solo / Dupla
enum ControlMode {
	DUO_LOCAL,    # Piloto (WASD) + Artilheiro (Mouse)
	BOT_PARTNER,  # Player é Piloto ou Gunner; Bot assume a vaga restante
	SOLO_INTERN   # Estagiário Solo: Player controla Movimento + Tiro simultaneamente
}

enum PartnerRole {
	PLAYER_IS_DRIVER,
	PLAYER_IS_GUNNER
}

var current_control_mode: ControlMode = ControlMode.SOLO_INTERN
var partner_role: PartnerRole = PartnerRole.PLAYER_IS_DRIVER
var selected_skin: String = "DEV"
var player_nickname: String = "Estagiário"
var selected_avatar: String = "player_char_001.png"

var maps_list: Array[String] = [
	"res://scenes/game/OfficeMap1.tscn"
]

func get_random_map_scene() -> String:
	return maps_list.pick_random()

var avatars_list: Array[String] = [
	"player_char_001.png",
	"player_char_002.png",
	"player_char_003.png",
	"player_char_004.png",
	"player_char_005.png"
]

var skins_info: Dictionary = {
	"DEV": {"name": "DEV (Desenvolvedor)", "color": Color(0.2, 0.5, 0.9, 1.0), "icon": "💻"},
	"QA": {"name": "QA (Engenheiro de Testes)", "color": Color(0.9, 0.6, 0.1, 1.0), "icon": "🦺"},
	"DESIGNER": {"name": "DESIGNER (UI/UX)", "color": Color(0.8, 0.2, 0.7, 1.0), "icon": "🎨"},
	"ANALISTA": {"name": "ANALISTA DE DADOS", "color": Color(0.1, 0.7, 0.6, 1.0), "icon": "📊"},
	"PM": {"name": "PM (PRODUCT MANAGER)", "color": Color(0.9, 0.2, 0.3, 1.0), "icon": "📢"}
}

func _ready() -> void:
	print("[GameManager] Inicializado. Modo Atual: ", ControlMode.keys()[current_control_mode])
	_setup_emoji_font_fallback()

func _setup_emoji_font_fallback() -> void:
	var emoji_font: FontFile = load("res://assets/fonts/NotoEmoji-Regular.ttf")
	if emoji_font and ThemeDB.fallback_font:
		if not emoji_font in ThemeDB.fallback_font.fallbacks:
			ThemeDB.fallback_font.fallbacks.append(emoji_font)

func set_control_mode(mode: ControlMode, role: PartnerRole = PartnerRole.PLAYER_IS_DRIVER) -> void:
	current_control_mode = mode
	partner_role = role
	print("[GameManager] Modo alterado para: ", ControlMode.keys()[current_control_mode])
