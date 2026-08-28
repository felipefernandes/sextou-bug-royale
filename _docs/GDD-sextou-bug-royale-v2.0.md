# 🎮 GAME DESIGN DOCUMENT (GDD) - Version 2.0

## 📌 1. Visão Geral do Projeto

- **Título do Jogo:** Sextou: Bug Royale
- **Gênero:** Party Game / Battle Royale assimétrico em duplas / 2D Top-Down Combat
- **Engine:** Godot Engine 4 (GDScript, HTML5 / WebGL Compatibility)
- **Plataforma Target:** Web Browser (Navegador WEB via Vercel)
- **Estilo Visual:** 2D Pixel Art Ortogonal
- **Câmera:** 2D Top-Down Ortogonal (Visão Superior Direta)
- **Tom do Jogo:** Humor nonsense, pastelão corporativo, casual e dinâmico

---

## 📜 2. Lore & Contexto Satírico

> Às 17h59 de uma sexta-feira, alguém enviou um _deploy_ em produção sem realizar nenhum teste. O relógio de parede do escritório começou a marcar a contagem regressiva para a **Hora do Happy Hour (18:00)**.
> 
> O escritório se transformou em um labirinto mutável recheado de glitches e bugs. Para piorar, a realidade se distorceu: **na perspectiva da sua dupla, todos os outros times parecem Monstros de Bug gigantes disputando a saída do prédio**.
> 
> O tempo está correndo! As cadeiras de escritório duelam e coletam Caixas de Deploy enquanto o **Grande Relógio da Firma** avança em direção às 18:00. Apenas os sobreviventes garantirão a vaga para finalmente **bater o ponto e sair pro Happy Hour**!

---

## 🕹️ 3. Modos de Jogo

### 3.1 Battle Royale - "A Corrida do Happy Hour" (Modo Padrão - v1.0)
- **Objetivo:** Ser a última dupla (ou cadeira) viva no mapa quando o Relógio marcar **18:00 (Happy Hour)**.
- **Mecânica:** O **Relógio Digital do Happy Hour** no HUD avança em tempo real. A névoa roxa de **Fechamento do Ponto / Reboot do RH** encolhe o mapa conforme os minutos passam. Coleta de "Caixas de Deploy" com armas e utilitários temporários.

### 3.2 Team Deathmatch (TDM - v2.0)
- **Objetivo:** Duas equipes de cadeiras disputando limite de eliminações ou maior pontuação por tempo.
- **Mecânica:** Respawns rápidos nas áreas de Spawn de cada equipe. Sem névoa de encolhimento de mapa.

---

## 👥 4. Resolução de Jogadores Ímpares & Sistema de NPCs (Bots)

### 4.1 Modos de Controle da Sala: Solo & Duo
No Lobby da partida, o **Host (👑)** define o modo de controle para todos os participantes:

- **Modo Solo:** Cada jogador controla a sua própria cadeira (movimentação + tiro simultâneos).
- **Modo Duo:** As cadeiras são operadas por **duplas de jogadores pareados aleatoriamente** pelo Lobby (1 Piloto responsável pela movimentação + 1 Artilheiro responsável pela mira e tiro).

### 4.2 Tela de Lobby Multiplayer & Privilégios do Host
- **Identificação dos Players:** Cada jogador digita seu **Nickname** e escolhe sua **Skin/Classe Corporativa** (Dev 💻, QA 🦺, Designer 🎨, Analista 📊, PM 📢).
- **Privilégios do Host (👑):**
  - **Modo de Jogo:** Escolha entre `Battle Royale (BR)` e `Team Deathmatch (TDM)`.
  - **Modo de Controle:** Escolha entre `"Solo"` e `"Duo"`.
  - **Duração da Partida:** Definição do tempo limite (3min, 5min, 10min).
  - **Início da Partida:** Botão de Deploy exclusivo para o Host.
- **Pareamento de Duplas:** No Modo `"Duo"`, o Lobby exibe visualmente as duplas montadas. Se houver número ímpar de jogadores, a vaga remanescente da dupla é preenchida por um Bot Copiloto.

### 4.4 NPCs de Teste / Sandbox Offline
- Para testes de desenvolvimento e gameplay sem conexões ativas, o jogo permite criar partidas 100% locais contra Bots dotados de Máquina de Estados Finitos (FSM):
  - **Estados:** `LOOTING` (busca armas), `ENGAGE_TARGET` (ataca alvos próximos), `RETREATING` (foge da Zona do RH), `PATROL`.

---

## 🕹️ 5. Controles & A Mecânica da Cadeira de Rodinhas

A jogabilidade é otimizada para Teclado + Mouse em duplas:

```
                  ┌────────────────────────┐
                  │        DUPLA           │
                  └──────────┬─────────────┘
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
   PILOTO (Driver)                    ARTILHEIRO (Gunner)
 ───────────────                    ───────────────────
 - Direciona a cadeira (Mouse/WASD) - Mira 360° com o Mouse
 - Clique Esquerdo: Drift           - Clique Esquerdo: Atira
 - Tecla Espaço: Turbo/Boost        - Clique Direito: Usa Item
```

---

## 👥 6. Personagens (Skins) & Ilusão de Perspectiva

### Skins Corporativas (Visual)
- **Dev:** Capuz, fone de ouvido gigante e xícara de café.
- **QA:** Capacete de obra e lente de aumento.
- **Designer:** Boina, tablet de desenho e paleta de cores.
- **Analista:** Calculadora no bolso e planilhas flutuando.
- **PM:** Megafone e quadro Kanban.

### O Efeito "Eles são os Bugs!"
- **Teammate / Visão Local:** Você e sua dupla enxergam seus avatares humanos corporativos.
- **Adversários:** Renderizados como **Monstros Glitch Pixelados (Bugs)**.

---

## ⚔️ 7. Armas, Itens & Sistema de Vida

### Vida (Post-its)
- Cada cadeira possui **3 Post-its Amarelos**. Cada impacto pesado remove 1 Post-it. Ao zerar, a cadeira quebra.

### Armamento ("Mario Kart Style")
|Tipo|Nome|Efeito|
|---|---|---|
|**Padrão**|**Grampeador Tático**|Tiro direto simples com munição infinita.|
|**Ataque**|**Sniper de Café Quente**|Tiro longo que deixa poça de café fervendo.|
|**Ataque**|**Metralhadora de Elásticos**|Tiro rápido que ricocheteia em paredes.|
|**Ataque**|**Wipe de Código (Disquete)**|Explosão em área (AoE) com knockback.|
|**Defesa**|**CTRL + Z**|Escudo que anula 1 acerto.|
|**Mobilidade**|**Gambiarra (POG)**|Super impulso que quebra divisórias.|
|**Utilitário**|**404 Not Found**|Fica invisível/fantasma por 3s.|

---

## 🎨 8. Direção de Arte & Assets
- Utilização dos tilesets e sprites 2D Top-Down presentes na pasta `assets/`:
  - `kenney_RPGurbanPack`: Paredes de escritório, móveis, pisos e divisórias.
  - `Tech Dungeon Roguelite`: Elementos de TI, servidores, glitches e luzes cyberpunk.
