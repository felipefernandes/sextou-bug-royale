# 🎮 Sextou: Bug Royale

> Party Game / Battle Royale assimétrico 2D Top-Down em duplas ambientado no caos corporativo de uma sexta-feira às 17h59!

---

## 📌 Visão Geral do Jogo

**Sextou: Bug Royale** é um jogo multiplayer 2D Top-Down desenvolvido em **Godot Engine 4 (GDScript)** otimizado para rodar diretamente no navegador Web.

Nas sextas-feiras no final do expediente, um deploy em produção deu errado e o código-fonte da empresa ganhou vida. Suba em uma **Cadeira de Escritório de Rodinhas** com sua dupla para deletar todos os "bugs" do andar antes que o **Reboot do Servidor (RH)** limpe tudo!

---

## 🚀 Funcionalidades Principais

- **Jogabilidade em Duplas (Piloto & Artilheiro):** Um jogador guia a velocidade e drift da cadeira enquanto o outro faz mira 360° e atira nos inimigos.
- **Tratativa para Jogadores Ímpares:**
  - **Bot Copiloto:** Um NPC assume automaticamente a função restante da dupla (atira ou navega).
  - **Estagiário Solo:** O jogador solo assume tanto a pilotagem quanto o tiro na mesma cadeira.
- **Ilusão de Perspectiva ("Eles são os Bugs!"):** Sua dupla se enxerga como humanos normais, mas todas as outras duplas adversárias são renderizadas como monstros glitch/bugs na sua tela.
- **Modos de Jogo:**
  - **Battle Royale (BR - v1.0):** Sobrevivência com névoa roxa de encolhimento do mapa.
  - **Team Deathmatch (TDM - v2.0):** Combate rápido entre equipes com respawn.
- **Armas Corporativas & Caixas de Deploy:** Grampeador Tático, Sniper de Café Quente, Metralhadora de Elásticos, Disquete AoE, CTRL+Z e Gambiarra POG.

---

## 🛠️ Stack Tecnológica & Arquitetura

- **Game Engine:** Godot Engine 4 (GDScript, HTML5/WebGL compatibility mode).
- **Client Web Hosting:** Vercel (Hospedagem estática de arquivos `.html`, `.wasm`, `.pck`).
- **Multiplayer Backend:** Node.js + WebSockets no Render (com Handshake HTTP *"Acorda TI"* para cold start).
- **Assets Visuais:** Tilesets 2D Top-Down (`kenney_RPGurbanPack` e `Tech Dungeon Roguelite`).

---

## 📂 Documentação & Links Relevantes

- 🤖 [Guia para Agentes de IA (AGENTS.md)](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/AGENTS.md)
- 🗺️ [Roadmap de Implementação (_docs/ROADMAP.md)](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/_docs/ROADMAP.md)
- 📜 [Game Design Document - GDD v2.0 (_docs/GDD-sextou-bug-royale-v2.0.md)](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/_docs/GDD-sextou-bug-royale-v2.0.md)
- 📄 [Software Design Document - SDD v2.0 (_docs/SDD-sextou-bug-royale-v2.0.md)](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/_docs/SDD-sextou-bug-royale-v2.0.md)

---

## 🎮 Como Executar Localmente (Godot 4)

1. Baixe e instale o [Godot Engine 4](https://godotengine.org/).
2. Abra o Godot e escolha **Importar Project**.
3. Selecione o arquivo `project.godot` localizado dentro da pasta [sextou-bug-royale/project.godot](file:///c:/Users/felip/OneDrive/Documents/Projects/sextou-bug-royale/sextou-bug-royale/project.godot).
4. Pressione `F5` no Godot para rodar o projeto localmente!
