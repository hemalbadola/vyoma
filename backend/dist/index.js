"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const generative_ai_1 = require("@google/generative-ai");
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
        // 3. Extract request body
        const { prompt, modelName = 'gemini-2.5-flash' } = req.body;
        if (!prompt) {
            return res.status(400).json({ error: 'Bad Request: prompt is required' });
        }
        // 4. Read secret keys from ENV (Not bundled in frontend)
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) {
            console.error('Server configuration error: GEMINI_API_KEY not found');
            return res.status(500).json({ error: 'Server configuration error' });
        }
        // 5. Call Gemini
        const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: modelName });
        const result = await model.generateContent(prompt);
        const text = result.response.text();
        res.json({ text });
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
