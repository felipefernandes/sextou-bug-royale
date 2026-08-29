const request = require('supertest');
const { app, server, wss } = require('../index');

describe('API Endpoints', () => {
    afterAll((done) => {
        // Fechar o servidor WebSocket
        wss.close(() => {
            done();
        });
    });

    it('GET /health deve retornar status online e o número de players', async () => {
        const response = await request(app).get('/health');
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('status', 'online');
        expect(response.body).toHaveProperty('activePlayers');
        expect(response.body).toHaveProperty('timestamp');
    });

    it('GET /reset deve limpar o estado da sala', async () => {
        const response = await request(app).get('/reset');
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('status', 'reset_ok');
        expect(response.body.roomState.players.length).toBe(0);
    });
});
