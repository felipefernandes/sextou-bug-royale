const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

// Endpoint de Handshake HTTP "Acorda TI" (Cold Start do Render)
app.get('/health', (req, res) => {
    cleanupGhostPlayers();
    res.status(200).json({
        status: 'online',
        message: 'Servidor do TI está acordado e pronto para o deploy!',
        activePlayers: roomState.players.length,
        timestamp: new Date().toISOString()
    });
});

// Endpoint administrativo para resetar ou forçar purga de jogadores fantasmas
app.get('/reset', (req, res) => {
    cleanupGhostPlayers();
    res.status(200).json({
        status: 'reset_ok',
        activePlayers: roomState.players.length,
        roomState
    });
});

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Estado da Sala Global de Partida
let roomState = {
    gameMode: 'BR',          // 'BR' ou 'TDM'
    controlMode: 'SOLO',      // 'SOLO' ou 'DUO'
    durationMinutes: 5,       // Tempo de partida em minutos
    isMatchStarted: false,
    players: [],              // Array de { id, nickname, skin, isHost, role, duoId }
    duos: []                  // Duplas pareadas
};

let nextPlayerId = 1;

function ensureActiveHost() {
    if (roomState.players.length === 0) return;
    const hasHost = roomState.players.some(p => p.isHost);
    if (!hasHost) {
        roomState.players[0].isHost = true;
        console.log(`[WS] 👑 Novo Host eleito automaticamente: ${roomState.players[0].nickname} (${roomState.players[0].id})`);
    }
}

function cleanupGhostPlayers() {
    const activePlayerIds = new Set();
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN && client.playerId) {
            activePlayerIds.add(client.playerId);
        }
    });

    const initialCount = roomState.players.length;
    roomState.players = roomState.players.filter(p => activePlayerIds.has(p.id));

    if (roomState.players.length !== initialCount) {
        console.log(`[WS] Purga de conexões fantasmas: ${initialCount} -> ${roomState.players.length} players ativos.`);
        ensureActiveHost();
        if (roomState.controlMode === 'DUO') updateDuoPairings();
        broadcastRoomState();
    }
}

function broadcastRoomState() {
    const payload = JSON.stringify({
        type: 'room_state',
        data: roomState
    });

    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(payload);
        }
    });
}

function updateDuoPairings() {
    if (roomState.controlMode !== 'DUO') {
        roomState.duos = [];
        roomState.players.forEach(p => { p.role = 'SOLO'; p.duoId = null; });
        return;
    }

    // Pareamento aleatório de duplas
    const shuffled = [...roomState.players].sort(() => 0.5 - Math.random());
    const duos = [];

    for (let i = 0; i < shuffled.length; i += 2) {
        const p1 = shuffled[i];
        const p2 = shuffled[i + 1];

        if (p1 && p2) {
            p1.role = 'DRIVER';
            p1.duoId = `DUO_${i}`;
            p2.role = 'GUNNER';
            p2.duoId = `DUO_${i}`;
            duos.push({
                id: `DUO_${i}`,
                driver: p1.nickname,
                gunner: p2.nickname
            });
        } else if (p1) {
            p1.role = 'DRIVER';
            p1.duoId = `DUO_${i}`;
            duos.push({
                id: `DUO_${i}`,
                driver: p1.nickname,
                gunner: '🤖 BOT COPILOTO'
            });
        }
    }
    roomState.duos = duos;
}

function heartbeat() {
    this.isAlive = true;
}

// Heartbeat ativo a cada 3.5 segundos para expurgar sockets mortos/fantasmas (F5 rápido no browser)
const pingInterval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            console.log(`[WS] 🔌 Socket inativo/zumbi detectado (${ws.playerId}). Encerrando...`);
            return ws.terminate();
        }
        ws.isAlive = false;
        try {
            ws.ping();
        } catch (e) {
            ws.terminate();
        }
    });

    cleanupGhostPlayers();
}, 3500);

wss.on('close', () => {
    clearInterval(pingInterval);
});

wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.on('pong', heartbeat);
    ws.on('error', (err) => {
        console.error(`[WS] Erro no socket (${ws.playerId}):`, err.message);
        ws.terminate();
    });

    // Limpa quaisquer players fantasmas antes de registrar o novo
    cleanupGhostPlayers();

    const playerId = `player_${nextPlayerId++}`;
    const hasActiveHost = roomState.players.some(p => p.isHost);
    const isFirst = !hasActiveHost || roomState.players.length === 0;

    const newPlayer = {
        id: playerId,
        nickname: `Dev_${playerId}`,
        skin: 'DEV',
        isHost: isFirst,
        role: roomState.controlMode === 'DUO' ? 'DRIVER' : 'SOLO',
        duoId: null
    };

    roomState.players.push(newPlayer);
    ws.playerId = playerId;

    if (roomState.controlMode === 'DUO') {
        updateDuoPairings();
    }

    console.log(`[WS] ${newPlayer.nickname} (${playerId}) conectou. Total: ${roomState.players.length} players. Host: ${newPlayer.isHost}`);
    
    // Confirmar conexão com o ID atribuído e status de Host
    ws.send(JSON.stringify({ type: 'connected', playerId: playerId, isHost: newPlayer.isHost }));
    broadcastRoomState();

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'update_profile':
                    const p = roomState.players.find(x => x.id === ws.playerId);
                    if (p) {
                        if (data.nickname) p.nickname = data.nickname;
                        if (data.skin) p.skin = data.skin;
                        if (roomState.controlMode === 'DUO') updateDuoPairings();
                        broadcastRoomState();
                    }
                    break;

                case 'update_room_settings':
                    const sender = roomState.players.find(x => x.id === ws.playerId);
                    if (sender && sender.isHost) {
                        if (data.gameMode) roomState.gameMode = data.gameMode;
                        if (data.controlMode) roomState.controlMode = data.controlMode;
                        if (data.durationMinutes) roomState.durationMinutes = data.durationMinutes;
                        
                        updateDuoPairings();
                        broadcastRoomState();
                    }
                    break;

                case 'return_to_lobby':
                    // Reseta o estado da sala para lobby e re-sincroniza todos os clientes
                    roomState.isMatchStarted = false;
                    const returningPlayer = roomState.players.find(x => x.id === ws.playerId);
                    if (returningPlayer) {
                        if (data.nickname) returningPlayer.nickname = data.nickname;
                        if (data.skin) returningPlayer.skin = data.skin;
                        console.log(`[WS] ${returningPlayer.nickname} retornou ao Lobby.`);
                    }
                    cleanupGhostPlayers();
                    ensureActiveHost();
                    if (roomState.controlMode === 'DUO') updateDuoPairings();
                    broadcastRoomState();
                    break;

                case 'start_match':
                    const hostPlayer = roomState.players.find(x => x.id === ws.playerId);
                    if (hostPlayer && hostPlayer.isHost) {
                        cleanupGhostPlayers();
                        roomState.isMatchStarted = true;
                        const matchPayload = JSON.stringify({ type: 'match_started', data: roomState });
                        wss.clients.forEach(c => {
                            if (c.readyState === WebSocket.OPEN) c.send(matchPayload);
                        });
                    }
                    break;

                case 'player_transform':
                    // Reenviar física de movimento para todos os outros players
                    wss.clients.forEach(c => {
                        if (c !== ws && c.readyState === WebSocket.OPEN) {
                            c.send(JSON.stringify({
                                type: 'player_transform',
                                playerId: ws.playerId,
                                position: data.position,
                                rotation: data.rotation,
                                gunRotation: data.gunRotation
                            }));
                        }
                    });
                    break;

                case 'player_shoot':
                    // Reenviar disparo para a sala
                    wss.clients.forEach(c => {
                        if (c !== ws && c.readyState === WebSocket.OPEN) {
                            c.send(JSON.stringify({
                                type: 'player_shoot',
                                playerId: ws.playerId,
                                position: data.position,
                                direction: data.direction,
                                itemType: data.itemType
                            }));
                        }
                    });
                    break;

                case 'player_hit':
                    // Reenviar evento de dano para sincronizar HP
                    wss.clients.forEach(c => {
                        if (c.readyState === WebSocket.OPEN) {
                            c.send(JSON.stringify({
                                type: 'player_hit',
                                targetId: data.targetId,
                                attackerId: ws.playerId,
                                remainingHp: data.remainingHp
                            }));
                        }
                    });
                    break;

                case 'player_eliminated':
                    // Reenviar eliminação e ativar modo espectador
                    wss.clients.forEach(c => {
                        if (c.readyState === WebSocket.OPEN) {
                            c.send(JSON.stringify({
                                type: 'player_eliminated',
                                playerId: data.playerId || ws.playerId
                            }));
                        }
                    });
                    break;

                case 'box_opened':
                    // Reenviar abertura de caixa de loot
                    wss.clients.forEach(c => {
                        if (c.readyState === WebSocket.OPEN) {
                            c.send(JSON.stringify({
                                type: 'box_opened',
                                boxId: data.boxId,
                                newPosition: data.newPosition,
                                itemType: data.itemType
                            }));
                        }
                    });
                    break;
            }
        } catch (err) {
            console.error('[WS] Erro ao processar mensagem:', err);
        }
    });

    ws.on('close', () => {
        const index = roomState.players.findIndex(x => x.id === ws.playerId);
        if (index !== -1) {
            const removed = roomState.players.splice(index, 1)[0];
            console.log(`[WS] ${removed.nickname} (${removed.id}) desconectou.`);
            
            // Se o Host saiu e ainda há players, passar privilégio de Host para o primeiro da lista
            ensureActiveHost();
            
            if (roomState.controlMode === 'DUO') updateDuoPairings();
            broadcastRoomState();
        }
    });
});

if (require.main === module) {
    server.listen(PORT, () => {
        console.log(`🚀 Servidor Sextou: Bug Royale rodando na porta ${PORT}`);
        console.log(`🔗 Endpoint Handshake: http://localhost:${PORT}/health`);
    });
}

module.exports = { app, server, wss, roomState };
