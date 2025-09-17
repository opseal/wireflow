const express = require('express');
const cors = require('cors');
const app = express();
const PORT = 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        message: 'VPN API is running',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/status', (req, res) => {
    res.json({
        wireguard: {
            status: 'running',
            peers: 0,
            transfer_rx: 0,
            transfer_tx: 0
        },
        system: {
            cpu_percent: 25.5,
            memory_percent: 50.0,
            disk_percent: 30.0
        }
    });
});

app.get('/api/clients', (req, res) => {
    res.json([
        {
            id: 1,
            name: 'test-client',
            public_key: 'test-public-key-12345',
            ip_address: '10.0.0.2',
            is_active: true,
            bytes_received: 1024,
            bytes_sent: 2048,
            created_at: new Date().toISOString()
        },
        {
            id: 2,
            name: 'mobile-client',
            public_key: 'test-public-key-67890',
            ip_address: '10.0.0.3',
            is_active: true,
            bytes_received: 5120,
            bytes_sent: 8192,
            created_at: new Date().toISOString()
        }
    ]);
});

app.post('/api/auth/login', (req, res) => {
    const { username, password } = req.body;
    
    if (username === 'admin' && password === 'admin123') {
        res.json({
            access_token: 'test-token-12345',
            user: {
                id: 1,
                username: 'admin',
                email: 'admin@vpn.local',
                is_admin: true
            }
        });
    } else {
        res.status(401).json({
            error: 'Invalid credentials'
        });
    }
});

app.get('/api/servers', (req, res) => {
    res.json([
        {
            id: 1,
            name: 'main-server',
            endpoint: 'vpn.example.com',
            port: 51820,
            public_key: 'server-public-key-12345',
            status: 'running',
            connected_clients: 2
        }
    ]);
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 VPN Test API running on http://localhost:${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`👥 Clients: http://localhost:${PORT}/api/clients`);
    console.log(`🔐 Login: POST http://localhost:${PORT}/api/auth/login`);
});
