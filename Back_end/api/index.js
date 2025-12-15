// api/index.js
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import serverless from 'serverless-http';

dotenv.config();

const app = express();

// ==================== MIDDLEWARE ====================

// Use Express built-in JSON parser (replaces body-parser)
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// CORS Configuration for Flutter/Web
const corsOptions = {
  origin: [
    'http://localhost:3000',
    'http://localhost:5555',
    'http://10.0.2.2:3000',
    'http://10.0.2.2',
    'http://localhost',
    'https://gearshare-vn.vercel.app',
    'https://*.vercel.app',
    'https://your-flutter-app.web.app',
    'exp://*'
  ],
  credentials: true,
};
app.use(cors(corsOptions));

// ==================== DATABASE ====================

let conn = null;

async function connectDB() {
  if (conn) return conn;

  if (!process.env.MONGODB_URI) {
    console.warn('⚠️ MONGODB_URI is not defined');
    return null;
  }

  conn = await mongoose.connect(process.env.MONGODB_URI);
  console.log('✅ Connected to MongoDB');
  return conn;
}

// ==================== ROUTES ====================

app.get('/', (req, res) => {
  res.json({
    message: '🚀 GearShare Vietnam API',
    status: 'running',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    deployed_on: 'Vercel',
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    memory: process.memoryUsage(),
  });
});

app.get('/api/test', (req, res) => {
  res.json({
    success: true,
    message: 'API is working perfectly on Vercel! 🎉',
    data: {
      server: 'Vercel Serverless',
      region: process.env.VERCEL_REGION || 'unknown',
      time: new Date().toLocaleString('vi-VN'),
    },
  });
});

app.post('/api/auth/register', async (req, res) => {
  try {
    await connectDB();
    const { email, password, name } = req.body;
    // TODO: Implement actual user creation logic
    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: { id: 'temp_id', email, name },
    });
  } catch (err) {
    console.error(err);
    res.status(400).json({ success: false, message: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    await connectDB();
    const { email, password } = req.body;
    // TODO: Implement actual login logic
    res.json({
      success: true,
      message: 'Login successful',
      token: 'jwt_token_here',
      user: { id: 'user_id', email, name: 'User Name' },
    });
  } catch (err) {
    console.error(err);
    res.status(401).json({ success: false, message: 'Invalid credentials' });
  }
});

app.get('/api/products', async (req, res) => {
  await connectDB();
  res.json({
    success: true,
    data: [
      { id: 1, name: 'Product 1', price: 100 },
      { id: 2, name: 'Product 2', price: 200 },
    ],
  });
});

app.get('/api/users/profile', async (req, res) => {
  await connectDB();
  res.json({
    success: true,
    data: { id: 'user_id', name: 'John Doe', email: 'john@example.com', joined: '2024-01-01' },
  });
});

// ==================== ERROR HANDLING ====================

app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Route not found', path: req.originalUrl });
});

app.use((err, req, res, next) => {
  console.error('❌ Server Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// ==================== EXPORT FOR VERCEL ====================

export default app;

// For local testing only
export const handler = serverless(app);
