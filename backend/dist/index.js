"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
// Initialize Firebase Admin (uses default credentials locally or via Heroku Env)
firebase_admin_1.default.initializeApp({
    credential: firebase_admin_1.default.credential.applicationDefault()
});
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
app.use(express_1.default.json());
const port = process.env.PORT || 3000;
// Example API endpoint for Gemini
app.post('/api/gemini/generate', async (req, res) => {
    try {
        // 1. Require Authentication Header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Unauthorized: Missing or invalid token' });
        }
        // 2. Verify Firebase Token
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await firebase_admin_1.default.auth().verifyIdToken(idToken);
        const userId = decodedToken.uid;
        if (!userId) {
            return res.status(401).json({ error: 'Unauthorized: Invalid token user' });
        }
        // 3. Forward request directly to Gemini API
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) {
            console.error('Server configuration error: GEMINI_API_KEY not found');
            return res.status(500).json({ error: 'Server configuration error' });
        }
        const { modelName = 'gemini-2.5-flash' } = req.body;
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;
        const geminiRes = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(req.body.payload || req.body),
        });
        const data = await geminiRes.json();
        res.status(geminiRes.status).json(data);
    }
    catch (error) {
        console.error('API Error:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});
app.get('/health', (req, res) => {
    res.json({ status: 'ok', version: '1.0.0' });
});
app.listen(port, () => {
    console.log(`Vyoma Backend running on port ${port}`);
});
