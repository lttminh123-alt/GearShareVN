// api/index.js
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mongoose from 'mongoose';

// Load environment variables
dotenv.config();

const app = express();

// CORS Configuration cho Flutter
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
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin']
};

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ==================== ROUTES ====================

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: '🚀 GearShare Vietnam API',
    status: 'running',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    deployed_on: 'Vercel',
    timestamp: new Date().toISOString(),
    endpoints: {
      root: '/',
      health: '/health',
      test: '/api/test',
      auth: '/api/auth/*',
      users: '/api/users/*'
    }
  });
});

// Health check (cho monitoring)
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    memory: process.memoryUsage()
  });
});

// Test endpoint
app.get('/api/test', (req, res) => {
  res.json({ 
    success: true,
    message: 'API is working perfectly on Vercel! 🎉',
    data: {
      server: 'Vercel Serverless',
      region: process.env.VERCEL_REGION || 'unknown',
      time: new Date().toLocaleString('vi-VN')
    }
  });
});

// Authentication routes
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    
    // TODO: Add your registration logic here
    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: {
        id: 'temp_id',
        email,
        name
      }
    });
  } catch (error) {
    res.status(400).json({
      success: false,
      message: error.message
    });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // TODO: Add your login logic here
    res.json({
      success: true,
      message: 'Login successful',
      token: 'jwt_token_here',
      user: {
        id: 'user_id',
        email,
        name: 'User Name'
      }
    });
  } catch (error) {
    res.status(401).json({
      success: false,
      message: 'Invalid credentials'
    });
  }
});

// Products routes (example)
app.get('/api/products', (req, res) => {
  res.json({
    success: true,
    data: [
      { id: 1, name: 'Product 1', price: 100 },
      { id: 2, name: 'Product 2', price: 200 }
    ]
  });
});

// Users routes
app.get('/api/users/profile', (req, res) => {
  // TODO: Add authentication middleware
  res.json({
    success: true,
    data: {
      id: 'user_id',
      name: 'John Doe',
      email: 'john@example.com',
      joined: '2024-01-01'
    }
  });
});

// ==================== DATABASE ====================

// MongoDB Connection (optional)
if (process.env.MONGODB_URI) {
  mongoose.connect(process.env.MONGODB_URI)
    .then(() => console.log('✅ Connected to MongoDB on Vercel'))
    .catch(err => console.error('❌ MongoDB error:', err));
}

// ==================== ERROR HANDLING ====================

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found',
    path: req.originalUrl,
    method: req.method
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('❌ Server Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// ==================== EXPORT FOR VERCEL ====================
// Đây là phần QUAN TRỌNG cho Vercel Serverless

// Export app as serverless function
export default app;

// Hoặc export handler cho Vercel
export const config = {
  api: {
    bodyParser: false, // Disable body parsing để handle file uploads
  },
};