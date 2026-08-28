const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;
const EXPORT_DIR = path.join(__dirname, '..', 'export');

// Headers de Cross-Origin Isolation para Godot 4 Web (WASM + Threads / SharedArrayBuffer)
app.use((req, res, next) => {
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    res.setHeader('Access-Control-Allow-Origin', '*');
    next();
});

// Servir arquivos estáticos do jogo compilado com headers garantidos
app.use(express.static(EXPORT_DIR, {
    setHeaders: (res, filePath) => {
        res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
        res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
        res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
        res.setHeader('Access-Control-Allow-Origin', '*');
    }
}));

app.listen(PORT, () => {
    console.log(`🎮 Servidor Web do Sextou: Bug Royale rodando em: http://localhost:${PORT}`);
    console.log(`📂 Servindo arquivos de: ${EXPORT_DIR}`);
});
