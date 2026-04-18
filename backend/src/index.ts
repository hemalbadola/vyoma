import express from 'express';
import cors from 'cors';
import { GoogleGenerativeAI } from '@google/generative-ai';
import admin from 'firebase-admin';

// Initialize Firebase Admin (uses default credentials locally or via Heroku Env)
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const app = express();
app.use(cors());
app.use(express.json());

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
    const decodedToken = await admin.auth().verifyIdToken(idToken);
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
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: modelName });
    
    const result = await model.generateContent(prompt);
    const text = result.response.text();

    res.json({ text });

  } catch (error) {
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
