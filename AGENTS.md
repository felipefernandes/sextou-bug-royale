# 🤖 AGENTS.MD - GUIA ORIENTADOR PARA AGENTES DE IA

Bem-vindo ao projeto **Sextou: Bug Royale**! Este documento serve como guia mestre agnóstico para qualquer Agente de IA (Gemini, Claude, GPT, etc.) ou desenvolvedor que for atuar no código ou na documentação deste repositório.

---

## 📌 1. Visão Geral & Contexto do Projeto

- **Nome do Jogo:** Sextou: Bug Royale
- **Gênero:** Party Game / Battle Royale assimétrico em duplas / 2D Top-Down Combat
- **Engine Principal:** Godot Engine 4 (GDScript, renderizador `gl_compatibility` para Web)
- **Plataforma Alvo:** Web Browser (Navegador WEB via Vercel)
- **Backend Multiplayer:** Node.js + WebSockets no Render (com Handshake "Acorda TI")
- **Estilo Visual:** 2D Pixel Art Ortogonal (Visão Superior Direta)

---

## 📂 2. Mapeamento do Repositório

```
/sextou-bug-royale (Workspace Root)
├── AGENTS.md                   <-- ESTE DOCUMENTO (Guia do Agente)
├── README.md                   <-- Apresentação do projeto e instruções de execução
├── _docs/
│   ├── GDD-sextou-bug-royale-v2.0.md <-- Game Design Document Oficial (Regras e Lore)
│   ├── SDD-sextou-bug-royale-v2.0.md <-- Software Design Document Oficial (Arquitetura)
│   ├── ROADMAP.md              <-- Planejamento de Implementação por Ondas Funcionais
│   └── archived/               <-- Documentos históricos v1.0 arquivados
├── assets/                     <-- Pacotes de Sprites/Tilesets 2D Top-Down
│   ├── kenney_RPGurbanPack/    <-- Tilesets de escritório, móveis e divisórias
│   └── Tech Dungeon Roguelite - Asset Pack (DEMO)/ <-- Elementos de TI/Bugs
└── sextou-bug-royale/          <-- PASTA DO PROJETO GODOT 4
    ├── project.godot           <-- Arquivo de configuração da Godot Engine
    ├── scenes/                 <-- Cenas do jogo (.tscn)
    └── scripts/                <-- Scripts GDScript (.gd)
```

---

## 👥 3. Protocolo de Personas (Agent Roles)

Ao executar tarefas, assuma as diretrizes das personas conforme a fase:

- **@architect (Arquiteto):** Valida a estrutura de nós no Godot (`CharacterBody2D`, `TileMapLayer`, `NavigationRegion2D`), desacoplamento de scripts e padrão Singleton/Autoload.
- **@developer (Desenvolvedor):** Foco em GDScript limpo, tipado e performático. Prioriza legibilidade e facilidade de manutenção.
- **@tester (QA/Engenheiro de Testes):** Garante a criação de arenas de teste, validação de edge-cases e testes com bots offline (`BotPlayer.gd`).
- **@security (Auditor de Segurança):** Garante que segredos, URLs de produção e chaves de API fiquem em `.env` e impede vazamentos no repositório.
- **@reviewer (Revisor):** Revisa o código antes de finalizar branches, mantendo o padrão de commits e integridade arquitetural.

---

## 📜 4. Padrões de Código GDScript (Godot 4)

1. **Tipagem Estática Obrigatória:**
   Sempre use tipagem estática no GDScript para evitar erros de runtime e otimizar a performance Web:
   ```gdscript
   var speed: float = 250.0
   var post_it_hp: int = 3
   
   func apply_damage(amount: int) -> void:
       post_it_hp -= amount
   ```
2. **Convenção de Nomenclatura:**
   - **Arquivos GDScript e Variáveis:** Use `snake_case` (ex: `chair_player.gd`, `post_it_count`).
   - **Nós e Cenas (`.tscn`):** Use `PascalCase` (ex: `ChairPlayer.tscn`, `RebootZone.tscn`).
   - **Constantes:** Use `UPPER_SNAKE_CASE` (ex: `MAX_POST_ITS = 3`).
3. **Organização das Cenas:**
   - Mantenha a separação entre Lógica (`Scripts`), Visual (`Sprite2D` / `AnimatedSprite2D`), Física (`CollisionShape2D`) e Áudio.

---

## 🔄 5. Fluxo de Trabalho e GitFlow

1. **Consulte Sempre o ROADMAP:**
   Antes de iniciar qualquer código, consulte [_docs/ROADMAP.md](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/_docs/ROADMAP.md) para identificar qual **Onda Funcional** e tarefa está sendo trabalhada.
2. **Não faça commits diretos na branch `main`:**
   Crie branches temáticas como `feat/chair-movement`, `fix/bot-pathfinding` ou `refactor/hud-ui`.
3. **Padrão de Commit (Conventional Commits):**
   - `feat(scope): ...` para novas funcionalidades.
   - `fix(scope): ...` para correções de bugs.
   - `docs(scope): ...` para alterações em documentação.

---

## 🎯 6. Regra de Ouro para o Agente IA

> **"Nunca assuma caminhos ou esquemas sem consultar a fonte autoritativa."**  
> Verifique sempre os arquivos de especificações [_docs/GDD-sextou-bug-royale-v2.0.md](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/_docs/GDD-sextou-bug-royale-v2.0.md), [_docs/SDD-sextou-bug-royale-v2.0.md](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/_docs/SDD-sextou-bug-royale-v2.0.md) e o projeto Godot em [sextou-bug-royale/project.godot](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/sextou-bug-royale/project.godot).

---

## ⚠️ 7. Armadilhas de GDScript & Godot 4 a Evitar

1. **Evitar `@export` para Cenas de Preload Interno:**
   - Nunca use `@export var scene = preload(...)` para projéteis e efeitos visuais internos. Use `var scene = preload(...)` para impedir que o Inspetor do Godot sobrescreva a variável com `null` na cena `.tscn`.
2. **Ordem de Execução com `Area2D.monitoring = false`:**
   - Desativar o `monitoring` dispara `body_exited` instantaneamente no Godot. Salve referências locais de corpos sobrepostos (`var recipient = active_body`) ANTES de alterar `monitoring` para `false`.
3. **Spawns Procedurais de Objetos:**
   - Valide sempre distâncias mínimas contra paredes e outros objetos (`distance_to < min_dist`) antes de atribuir a propriedade `global_position`.
4. **Fontes de UI do Inspetor vs `add_theme_font_override`:**
   - Nunca use `add_theme_font_override` no GDScript em nós destinados à estilização visual no Inspetor do Godot, para não sobrescrever as escolhas do desenvolvedor.
5. **Loop `_process` em Modo Espectador:**
   - Não trave a execução de `_process()` com `if not is_game_over` quando o jogador morre. Mantenha o loop rodando a checagem de fim de partida (`_check_match_status()`) para processar eliminações entre bots e acionar a contagem do lobby.
6. **Clamping Rígido de Limites de Patrulha dos Bots:**
   - Em arenas expandidas, aplique `clamp()` nas coordenadas e rebata o vetor de patrulha (`patrol_dir`) para o centro do mapa ao detectar aproximação das paredes externas.
7. **Proteção de Lambdas Assíncronas (`create_timer`):**
   - Sempre valide `if is_instance_valid(self):` dentro de lambdas anônimas em timers para evitar o erro de runtime `Lambda capture at index 0 was freed`.
8. **Campos de Texto LineEdit:**
   - Conecte `text_changed` além de `text_submitted` para salvar edições no modelo instantaneamente sem depender da tecla Enter.
9. **Evitar Warning de Divisão Inteira (`INTEGER_DIVISION`):**
   - Use `int(float(a) / float(b))` para divisões inteiras warning-free em GDScript 4.
10. **Câmera de Espectador Livre:**
   - Instancie uma `Camera2D` independente ao entrar no modo espectador para liberar a navegação livre pelo mapa e alternância de alvos sobreviventes via `TAB`.
11. **Ícones de UI e Emojis em Builds Web (Wasm):**
   - Nunca dependa de caracteres de emojis do sistema operacional para ícones de interface. No WebAssembly, a engine não tem acesso às fontes do SO hospedeiro, causando renderização monocromática ou ausência de glifos. Use sempre spritesheets de ícones recortados como `AtlasTexture` (.tres) integrados via `OptionButton.add_icon_item()`, `TextureRect` ou BBCode `[img]` em `RichTextLabel`.



