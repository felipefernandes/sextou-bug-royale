# 🎮 GAME DESIGN DOCUMENT (GDD)

## 📌 1. Visão Geral do Projeto

- **Título do Jogo:** Sextou: Bug Royale
    
- **Gênero:** Party Game / Battle Royale Assimétrico em Duplas / 2D Top Down Combat
    
- **Plataforma Target:** Web Browser (HTML5 / WebGL - leve e acessível)
    
- **Estilo Visual:** 2D Pixel Art
    
- **Câmera:** Top Down
    
- **Tom do Jogo:** Humor nonsense, pastelão corporativo, casual e dinâmico
    

## 📜 2. Lore & Contexto Satírico

> Às 17h59 de uma sexta-feira, alguém enviou um _deploy_ em produção sem realizar nenhum teste. O servidor central emitiu um brilho roxo pixelado: todos os executivos, gerentes e clientes foram abduzidos para a Nuvem, e o próprio código-fonte da empresa ganhou vida.
> 
> O escritório se transformou em um labirinto mutável recheado de glitches e bugs. Para piorar, a realidade se distorceu: **na perspectiva da sua dupla, todos os outros times parecem Monstros de Bug gigantes**.
> 
> Para sobreviver ao inevitável _Reboot do Servidor_, limpar o sistema e finalmente **sair pro Sextou**, vocês precisam subir na sua fiel Cadeira de Escritório e deletar todos os "bugs" do andar!

## 🔁 3. Core Loop (Ciclo Principal da Partida)

1. **Lobby:** Escolha da skin visual da dupla (Dev, QA, Designer, Analista, PM).
    
2. **Spawn:** A dupla aparece em uma posição aleatória no labirinto de escritório.
    
3. **Navegação & Coleta:** Movimentar a cadeira de rodinhas coletando "Caixas de Deploy" (Itens/Armas).
    
4. **Combate Assimétrico:** Pilotar a cadeira enquanto o parceiro atira nos inimigos para remover seus Post-its de vida.
    
5. **Escape da Zona:** Fugir da **Parede de Reboot do Servidor** que fecha o mapa gradualmente.
    
6. **Vitória:** A última dupla viva zera o sistema, vence a rodada e vai pro _Happy Hour / Sextou_!
    

## 🕹️ 4. Controles & A Mecânica da Cadeira de Rodinhas

A jogabilidade é 100% otimizada para o uso do **Mouse** em duplas online:

```
                  ┌────────────────────────┐
                  │        DUPLA           │
                  └──────────┬─────────────┘
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
   PILOTO (Driver)                    ARTILHEIRO (Gunner)
 ───────────────                    ───────────────────
 - Move o Mouse para guiar           - Mira 360° com o Mouse
 - Cadeira segue o cursor           - Clique Esquerdo: Atira
 - Clique Esquerdo: Drift           - Clique Direito: Usa Item
 - Tecla Espaço: Turbo/Boost
```

## 👥 5. Personagens (Skins) & Ilusão de Perspectiva

### Skins Corporativas (Apenas Visual)

- **Dev:** Capuz, fone de ouvido gigante e xícara de café na mão.
    
- **QA:** Capacete de obra e lente de aumento gigantesca.
    
- **Designer:** Boina, tablet de desenho e paletas de cores.
    
- **Analista:** Calculadora no bolso e planilhas flutuando ao redor.
    
- **PM:** Megafone na mão e quadro Kanban flutuante.
    

### O Efeito "Eles são os Bugs!"

- **Visão Local:** A sua dupla enxerga a si mesma como humanos normais.
    
- **Visão dos Inimigos:** Todas as outras duplas são renderizadas na sua tela como **Glitches de Pixel Vermelhos/Roxos**.
    
- **Simetria:** Para os adversários, você é o Bug na tela deles.
    

## ⚔️ 6. Armas, Itens & Sistema de Vida

### Vida (Post-its)

- Cada cadeira começa com **3 Post-its Amarelos** colados nas costas.
    
- Cada acerto pesado recebido remove 1 Post-it. Ao perder todos os 3, a cadeira quebra e a dupla é eliminada.
    

### Armamento das Caixas de Deploy ("Mario Kart Style")

|Tipo|Nome|Efeito|
|---|---|---|
|**Padrão**|**Grampeador Tático**|Disparo simples em linha reta com munição infinita.|
|**Ataque**|**Sniper de Café Quente**|Tiro longo que deixa poça de café fervendo no chão (Dano por segundo).|
|**Ataque**|**Metralhadora de Elásticos**|Alta cadência com disparos que ricocheteiam nas divisórias.|
|**Ataque**|**Wipe de Código (Disquete)**|Lança um disquete que explode em área (AoE) empurrando inimigos.|
|**Defesa**|**CTRL + Z**|Escudo temporário que nega o próximo dano recebido.|
|**Mobilidade**|**Gambiarra (POG)**|Super impulso de velocidade capaz de atravessar ou quebrar divisórias.|
|**Utilitário**|**404 Not Found**|A cadeira fica invisível/fantasma por 3 segundos.|

## 🗺️ 7. Mapa, Eventos & Interface

### Labirinto Procedural

- Gerado aleatoriamente a cada partida contendo Baias de Trabalho, Copas e Salas de Reunião.
    
- **Zone do RH / Reboot:** Uma névoa púrpura de _Reboot do Servidor_ avança das bordas para o centro, reduzindo a área segura.
    

### Eventos Aleatórios (Hazards)

- ☕ **Vazamento de Café:** Corredores do mapa ficam escorregadios, dobrando a velocidade e dificultando curvas.
    
- 💤 **Reunião de Alinhamento:** Mensagem pop-up congela todos os jogadores do servidor por 2 segundos.
