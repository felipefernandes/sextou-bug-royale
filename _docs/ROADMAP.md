# 🗺️ ROADMAP DE IMPLEMENTAÇÃO - SEXTOU: BUG ROYALE

Este documento estabelece o plano de desenvolvimento em **ondas funcionais e incrementais** para o jogo *Sextou: Bug Royale*, construído sobre a **Godot Engine 4** (GDScript) com foco na Web.

---

## 🌊 Onda 1: Protótipo Funcional Local (Singleplayer & Sandbox Offline)
> **Objetivo:** Ter um ciclo básico de física, movimentação, controles de dupla/solo e combate funcional jogável localmente sem dependência de servidores.

- [x] **1.1 Estrutura do Projeto Godot 4:**
  - Organizar pastas (`scenes/`, `scripts/`, `assets/`, `ui/`, `ai/`).
  - Configurar projeto em 2D Top-Down Ortogonal, resolução base e renderizador `gl_compatibility`.
- [x] **1.2 Mecânica da Cadeira de Rodinhas (`ChairPlayer.tscn` / `CharacterBody2D`):**
  - Movimentação física 2D Top-Down: Aceleração, desaceleração, fricção do piso do escritório e efeito de *Drift* (deslizamento).
  - Impulso de *Turbo/Boost*.
- [x] **1.3 Modos de Controle (Lobby / Menu Local):**
  - **Dupla Local:** Piloto (Movimento WASD/Mouse) + Artilheiro (Mira 360° e Tiro).
  - **Bot Copiloto:** Um NPC assume o papel vago (atira automaticamente se o player for Piloto, ou navega se o player for Artilheiro).
  - **Estagiário Solo:** O player solo controla movimento E mira/tiro simultaneamente na mesma cadeira.
- [x] **1.4 Sistema de Vida & Armamento Inicial:**
  - Sistema de 3 Post-its de vida (`post_it_count = 3`).
  - Disparo de projétil básico (Grampeador Tático).
- [x] **1.5 Arena de Teste & Bot Inimigo (`BotPlayer.gd` / `BotBrain.gd`):**
  - Implementar Bot inimigo simples usando `NavigationAgent2D` com FSM (`PATROL`, `ENGAGE_TARGET`).
  - Arena de testes simples para validar acertos de tiro, perda de Post-its e destruição da cadeira.

---

## 🌊 Onda 2: Caixas de Deploy, Armas, Habilidades & Zona de Reboot
> **Objetivo:** Adicionar o ecossistema completo de combate corporativo, itens estilo "Mario Kart" e o encolhimento do mapa.

- [x] **2.1 Labirinto de Escritório & Rotação de Mapas (TileMap 2D Ortogonal):**
  - Construir o mapa base usando os assets de [assets/kenney_RPGurbanPack](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/assets/kenney_RPGurbanPack) e [assets/Tech Dungeon Roguelite - Asset Pack (DEMO)](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/assets/Tech%20Dungeon%20Roguelite%20-%20Asset%20Pack%20(DEMO)).
  - Suporte a múltiplos mapas e rotação no `GameManager`:
    - `OfficeMap1.tscn` (Escritório Central / Baias & Convivência).
    - `OfficeMap2.tscn` (Data Center & Sala de Servidores com Mainframe Core, NOC e Corredores de Racks).
  - Baias de trabalho, corredores, divisórias e áreas de café.
  - `NavigationRegion2D` para pathfinding dos bots.
- [x] **2.2 Caixas de Deploy ("Loot Boxes"):**
  - Spawn aleatório de caixas pelo escritório.
  - Coleta ao passar com a cadeira.
- [x] **2.3 Arsenal Corporativo Completo:**
  - **Sniper de Café Quente:** Tiro de longo alcance que deixa poça de café no chão (dano contínuo).
  - **Metralhadora de Elásticos:** Cadência rápida com ricochete em divisórias.
  - **Wipe de Código (Disquete):** Explosão em área (AoE) com empurrão (knockback).
  - **CTRL + Z:** Escudo temporário.
  - **Gambiarra (POG Boost):** Impulso de alta velocidade que destrói divisórias.
  - **404 Not Found:** Ficar invisível/fantasma por 3 segundos.
- [x] **2.4 Névoa de Reboot do RH (Zone shrinking):**
  - Círculo de névoa púrpura que reduz o raio com o passar do tempo.
  - Dano contínuo em jogadores que ficarem fora da zona segura.

---

## 🌊 Onda 3: UI Satírica, Efeitos Visuais & Ilusão de Perspectiva
> **Objetivo:** Polir a experiência visual, HUD, atmosfera de humor corporativo e a ilusão "Eles são os Bugs!".

- [x] **3.1 Efeito Visual "Eles são os Bugs!":**
  - Shader / filtro de renderização: Na tela do jogador, a sua dupla/cadeira é vista como humana, mas todas as outras duplas inimigas são renderizadas como **Monstros Glitch / Bugs**.
- [x] **3.2 Interface & HUD Satírica (`HUD.tscn`):**
  - Indicador de Post-its colados nas costas da cadeira.
  - Indicador de Arma Atual e Munição.
  - Alertas do RH ("REBOOT DO SERVIDOR EM 10 SEGUNDOS!", "CAFÉ VAZOU NA SALA 2").
  - Minimapa com área segura da Zona de Reboot.
- [x] **3.3 Menu Principal & Seleção de Skins:**
  - Menu principal satírico (`MainMenu.tscn`).
  - Escolha de Skins (Dev, QA, Designer, Analista, PM).
  - Seletor de Modo (Estagiário Solo vs Bot Copiloto vs Sandbox).
- [x] **3.4 Efeitos Sonoros & Partículas:**
  - Sons de grampeador, tiros de elástico, aviso de erro 404, derrapagem de rodinhas e explosões de código.

---

## 🌊 Onda 4: Backend Multiplayer WebSocket & Deploy Web
> **Objetivo:** Conectar o jogo ao servidor multiplayer Node.js no Render e publicar a build Web no Vercel com Handshake "Acorda TI".

- [x] **4.1 Servidor Node.js + WebSockets Leve:**
  - Servidor em Node.js (`server/`) gerenciando salas, sincronização de posições a 20 FPS e eventos de tiro.
  - Endpoint `GET /health` para verificar status da aplicação.
- [x] **4.2 Protocolo Handshake "Acorda TI" (Cold Start) & Lobby Multiplayer:**
  - UI de pré-carregamento no Godot Web enviando ping HTTP para o Render.
  - Feedback visual: *"Conectando aos servidores da firma... (Acordando o TI)"*.
  - Tela de Lobby Multiplayer com identificação do Host (👑), Nicknames, Skins, modos Solo/Duo e pareamento de duplas.
- [x] **4.3 Sincronização Gameplay Online & Cadeiras Remotas:**
  - Envio e recepção de fisíca de cadeiras (`player_transform`), tiros sincronizados, dano em Post-its e entrada no modo espectador em tempo real.
- [x] **4.4 Exportação Web & Deploy:**
  - Configurar exportação Web (HTML5/WASM) no Godot 4.
  - Automação de deploy do client na Vercel e do server no Render.

---

## 🌊 Onda 5: Modo Team Deathmatch (TDM - v2.0)
> **Objetivo:** Adicionar o modo de jogo alternativo em equipe pós-lançamento do Battle Royale.

- [ ] **5.1 Regras de TDM:**
  - Divisão do servidor em 2 grandes equipes (Equipe Devs vs Equipe QAs).
  - Sistema de Respawns programados nas bases.
  - Placar de eliminações por tempo/pontuação.
