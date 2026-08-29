extends GutTest

func test_game_manager_starts_with_default_control_mode():
    assert_not_null(GameManager, "O GameManager Autoload deve existir")
    assert_eq(GameManager.current_control_mode, GameManager.ControlMode.SOLO_INTERN, "O modo padrão deve ser SOLO_INTERN")

func test_get_skin_icon_returns_texture():
    var icon = GameManager.get_skin_icon("DEV")
    assert_not_null(icon, "Deve retornar uma textura válida para a skin DEV")
    
    var fallback_icon = GameManager.get_skin_icon("NON_EXISTENT_SKIN")
    assert_not_null(fallback_icon, "Deve retornar a textura fallback (DEV) para skins inexistentes")

