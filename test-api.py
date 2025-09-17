#!/usr/bin/env python3
"""
Simple test API for VPN system
"""

from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'message': 'VPN API is running'})

@app.route('/api/status')
def status():
    return jsonify({
        'wireguard': {
            'status': 'running',
            'peers': 0,
            'transfer_rx': 0,
            'transfer_tx': 0
        },
        'system': {
            'cpu_percent': 25.5,
            'memory_percent': 50.0,
            'disk_percent': 30.0
        }
    })

@app.route('/api/clients')
def clients():
    return jsonify([
        {
            'id': 1,
            'name': 'test-client',
            'public_key': 'test-public-key',
            'ip_address': '10.0.0.2',
            'is_active': True,
            'bytes_received': 1024,
            'bytes_sent': 2048,
            'created_at': '2024-01-01T00:00:00Z'
        }
    ])

@app.route('/api/auth/login', methods=['POST'])
def login():
    return jsonify({
        'access_token': 'test-token-123',
        'user': {
            'id': 1,
            'username': 'admin',
            'email': 'admin@vpn.local',
            'is_admin': True
        }
    })

if __name__ == '__main__':
    print("Starting test API on http://localhost:8080")
    app.run(host='0.0.0.0', port=8080, debug=True)
