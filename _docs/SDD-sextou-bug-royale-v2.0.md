# 📄 SOFTWARE DESIGN DOCUMENT (SDD) - Version 2.0

**Project Name:** Sextou: Bug Royale  
**Game Engine:** Godot Engine 4 (GDScript, Web export / HTML5)  
**Architecture Style:** Client-Server / WebSocket State Sync  
**Target Hosting:** Vercel (Client Web) + Render (Backend WebSockets)  

---

## 1. Visão Geral da Arquitetura do Sistema

O sistema é construído sobre o **Godot Engine 4** exportado para HTML5/WASM para rodar no navegador WEB. O backend executa em um servidor WebSockets (Node.js ou Godot Headless Server), hospedado no **Render**. O cliente estático é servido pela **Vercel**.

```
┌─────────────────────────────────────────────────────────────┐
│                    VERCEL - CLIENT (Web)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Godot 4 Web (HTML5 / WASM)               │  │
│  │  - Render 2D Top-Down Ortogonal                       │  │
│  │  - Input Handler (Mouse / Teclado)                    │  │
│  │  - Client State Interpolation                         │  │
│  └──────────────────────────┬────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │  Handshake Ping   │ (HTTPS / GET health)
                    ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                   RENDER - BACKEND SERVER                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               WebSocket Room Server                   │  │
│  │  - Sincronização de Posição / Tiros / HP              │  │
│  │  - Lógica do Reboot Zone (Encolhimento)               │  │
│  │  - Gerenciamento de Salas (BR & TDM)                  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Estratégia de Hospedagem & Handshake "Acorda TI" (Cold Start)

### 2.1 Hospedagem
- **Frontend Client (Vercel):** Arquivos estáticos `.html`, `.wasm` e `.pck` gerados pela exportação Web do Godot 4. Alta disponibilidade, sem hibernação.
- **Backend Server (Render):** Servidor WebSockets Node.js/Godot no plano gratuito.

### 2.2 Protocolo de Despertar (Cold Start Handshake)
1. Ao abrir a aplicação web na Vercel, o script da página inicial dispara uma requisição HTTP `GET https://nosso-servidor.onrender.com/health`.
2. A interface do jogo exibe a tela de carregamento temática:
   > ☕ *"Conectando aos servidores da firma... (Acordando o TI)"*
3. O servidor no Render acorda da hibernação (tempo de resposta aproximado: 15-25 segundos).
4. Assim que o HTTP responde `200 OK`, o cliente habilita o WebSocket (`wss://`) e libera o botão **"JOGAR / BUSCAR PARTIDA"**.

---

## 3. Estrutura do Projeto Godot (`/sextou-bug-royale`)

```
sextou-bug-royale/
├── project.godot
├── icon.svg
├── scenes/
│   ├── main_menu/
│   │   ├── MainMenu.tscn
│   │   └── MainMenu.gd
│   ├── game/
│   │   ├── GameScene.tscn
│   │   ├── GameScene.gd
│   │   ├── OfficeMap.tscn
│   │   └── RebootZone.tscn
│   ├── entities/
│   │   ├── ChairPlayer.tscn
│   │   ├── ChairPlayer.gd
│   │   ├── BotPlayer.gd
│   │   ├── Bullet.tscn
│   │   └── DeployBox.tscn
│   └── ui/
│       ├── HUD.tscn
│       └── ColdStartLoader.tscn
├── scripts/
│   ├── autoload/
│   │   ├── GameManager.gd
│   │   └── NetworkManager.gd
│   └── ai/
│       └── BotBrain.gd
└── assets/
    ├── sprites/
    └── audio/
```

---

## 4. Arquitetura das Entidades e Nós no Godot

### 4.1 Cadeira de Rodinhas (`ChairPlayer.tscn` / `CharacterBody2D`)
- **Controlador do Piloto (Driver):** Lê a posição do cursor/WASD e calcula velocidade, aceleração e rotação da cadeira.
- **Controlador do Artilheiro (Gunner):** Gerencia a mira 360° em relação à cadeira e dispara projéteis.
- **Sistema de HP (Post-its):** `post_it_count = 3`. A cada acerto, atualiza a visibilidade dos sprites de Post-it nas costas da cadeira.

### 4.2 Bot Auxiliar / NPC (`BotPlayer.gd` / `BotBrain.gd`)
- Herda as propriedades da cadeira e utiliza `NavigationAgent2D` para desviar de móveis e paredes.
- **Máquina de Estados Finitos (FSM):**
  - `IDLE_PATROL`: Navega aleatoriamente procurando Caixas de Deploy.
  - `ENGAGE_TARGET`: Atira na dupla inimiga mais próxima.
  - `FLEE_ZONE`: Quando o raio da névoa de Reboot do RH encolhe, calcula rota para dentro da zona segura.

---

## 5. Modos de Jogo & Regras de Rede

### 5.1 Battle Royale (BR)
- Sala de 8 a 16 jogadores (4 a 8 duplas).
- Névoa circular que encolhe com o tempo (`RebootZone`).
- Vitória concedida quando resta apenas 1 time ativo.

### 5.2 Team Deathmatch (TDM)
- Duas equipes (Equipe Devs vs Equipe QAs).
- Respawna os jogadores eliminados após 3 segundos nas respectivas bases.
- Partida encerra ao atingir 20 eliminações ou após 5 minutos.
