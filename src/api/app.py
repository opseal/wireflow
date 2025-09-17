#!/usr/bin/env python3
"""
VPN Management API
A comprehensive API for managing WireGuard VPN connections, users, and monitoring.
"""

import os
import json
import subprocess
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import psutil
import qrcode
from io import BytesIO

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('JWT_SECRET', 'your-secret-key-change-this')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///:memory:')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

# Initialize extensions
db = SQLAlchemy(app)
jwt = JWTManager(app)
CORS(app, origins=['http://localhost:4200', 'http://127.0.0.1:4200'], 
     allow_headers=['Content-Type', 'Authorization'], 
     methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])

# Database Models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class VPNClient(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), unique=True, nullable=False)
    public_key = db.Column(db.String(44), unique=True, nullable=False)
    private_key = db.Column(db.String(44), nullable=False)
    ip_address = db.Column(db.String(15), unique=True, nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_connected = db.Column(db.DateTime)
    bytes_received = db.Column(db.BigInteger, default=0)
    bytes_sent = db.Column(db.BigInteger, default=0)

class VPNServer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), unique=True, nullable=False)
    public_key = db.Column(db.String(44), unique=True, nullable=False)
    private_key = db.Column(db.String(44), nullable=False)
    endpoint = db.Column(db.String(255), nullable=False)
    port = db.Column(db.Integer, default=51820)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# Utility Functions
def get_wireguard_status():
    """Get current WireGuard status and statistics."""
    try:
        # Check if we're on Windows or if WireGuard is not available
        import platform
        if platform.system() == 'Windows':
            # Return mock data for Windows
            return {
                'wg0': {
                    'peers': [
                        {
                            'public_key': 'mOCK_PUBLIC_KEY_FOR_DEFAULT_CLIENT_1234567890123456789012345678901234567890',
                            'endpoint': '192.168.1.100:51820',
                            'allowed_ips': '10.0.0.2/32',
                            'latest_handshake': '1640995200',
                            'transfer_rx': 1024000,
                            'transfer_tx': 512000,
                            'persistent_keepalive': '25'
                        }
                    ]
                }
            }
        
        # Try to run WireGuard command on Unix-like systems
        result = subprocess.run(['wg', 'show', 'all', 'dump'], 
                              capture_output=True, text=True, check=True)
        lines = result.stdout.strip().split('\n')
        
        interfaces = {}
        for line in lines:
            if line:
                parts = line.split('\t')
                if len(parts) >= 5:
                    interface = parts[0]
                    if interface not in interfaces:
                        interfaces[interface] = {'peers': []}
                    
                    if len(parts) >= 8:  # Peer data
                        peer = {
                            'public_key': parts[1],
                            'endpoint': parts[2],
                            'allowed_ips': parts[3],
                            'latest_handshake': parts[4],
                            'transfer_rx': int(parts[5]) if parts[5] else 0,
                            'transfer_tx': int(parts[6]) if parts[6] else 0,
                            'persistent_keepalive': parts[7] if len(parts) > 7 else 0
                        }
                        interfaces[interface]['peers'].append(peer)
        
        return interfaces
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        logger.error(f"Error getting WireGuard status: {e}")
        # Return mock data if WireGuard is not available
        return {
            'wg0': {
                'peers': [
                    {
                        'public_key': 'mOCK_PUBLIC_KEY_FOR_DEFAULT_CLIENT_1234567890123456789012345678901234567890',
                        'endpoint': '192.168.1.100:51820',
                        'allowed_ips': '10.0.0.2/32',
                        'latest_handshake': '1640995200',
                        'transfer_rx': 1024000,
                        'transfer_tx': 512000,
                        'persistent_keepalive': '25'
                    }
                ]
            }
        }

def generate_qr_code(data: str) -> BytesIO:
    """Generate QR code for client configuration."""
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(data)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    img_io = BytesIO()
    img.save(img_io, 'PNG')
    img_io.seek(0)
    return img_io

# API Routes
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })

@app.route('/api/auth/login', methods=['POST'])
def login():
    """User authentication."""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400
    
    user = User.query.filter_by(username=username).first()
    if user and user.check_password(password):
        user.last_login = datetime.utcnow()
        db.session.commit()
        
        access_token = create_access_token(identity=str(user.id))
        return jsonify({
            'access_token': access_token,
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'is_admin': user.is_admin
            }
        })
    
    return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/api/clients', methods=['GET'])
@jwt_required()
def get_clients():
    """Get all VPN clients."""
    clients = VPNClient.query.all()
    return jsonify([{
        'id': client.id,
        'name': client.name,
        'ip_address': client.ip_address,
        'is_active': client.is_active,
        'created_at': client.created_at.isoformat(),
        'last_connected': client.last_connected.isoformat() if client.last_connected else None,
        'bytes_received': client.bytes_received,
        'bytes_sent': client.bytes_sent
    } for client in clients])

@app.route('/api/clients', methods=['POST'])
@jwt_required()
def create_client():
    """Create a new VPN client."""
    data = request.get_json()
    name = data.get('name')
    
    if not name:
        return jsonify({'error': 'Client name required'}), 400
    
    if VPNClient.query.filter_by(name=name).first():
        return jsonify({'error': 'Client name already exists'}), 409
    
    try:
        # Generate client keys
        import platform
        if platform.system() != 'Windows':
            try:
                private_key_result = subprocess.run(['wg', 'genkey'], 
                                                  capture_output=True, text=True, check=True)
                private_key = private_key_result.stdout.strip()
                
                public_key_result = subprocess.run(['wg', 'pubkey'], 
                                                 input=private_key, text=True,
                                                 capture_output=True, check=True)
                public_key = public_key_result.stdout.strip()
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Fallback to mock keys if WireGuard not available
                private_key = f"MOCK_PRIVATE_KEY_FOR_{name.upper().replace('-', '_')}_1234567890123456789012345678901234567890"
                public_key = f"MOCK_PUBLIC_KEY_FOR_{name.upper().replace('-', '_')}_1234567890123456789012345678901234567890"
        else:
            # Use mock keys for Windows
            private_key = f"MOCK_PRIVATE_KEY_FOR_{name.upper().replace('-', '_')}_1234567890123456789012345678901234567890"
            public_key = f"MOCK_PUBLIC_KEY_FOR_{name.upper().replace('-', '_')}_1234567890123456789012345678901234567890"
        
        # Get next available IP
        last_client = VPNClient.query.order_by(VPNClient.id.desc()).first()
        if last_client:
            last_ip = int(last_client.ip_address.split('.')[-1])
            new_ip = f"10.0.0.{last_ip + 1}"
        else:
            new_ip = "10.0.0.2"
        
        # Create client record
        client = VPNClient(
            name=name,
            public_key=public_key,
            private_key=private_key,
            ip_address=new_ip
        )
        
        db.session.add(client)
        db.session.commit()
        
        # Add client to WireGuard configuration
        # This would typically be done by updating the server config
        # and reloading WireGuard
        
        return jsonify({
            'id': client.id,
            'name': client.name,
            'ip_address': client.ip_address,
            'public_key': public_key
        }), 201
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Error generating keys: {e}")
        return jsonify({'error': 'Failed to generate client keys'}), 500

@app.route('/api/clients/<int:client_id>/config', methods=['GET'])
@jwt_required()
def get_client_config(client_id):
    """Get client configuration file."""
    client = VPNClient.query.get_or_404(client_id)
    
    # Get server configuration
    server = VPNServer.query.filter_by(is_active=True).first()
    if not server:
        return jsonify({'error': 'No active server found'}), 404
    
    # Generate client configuration
    config = f"""[Interface]
PrivateKey = {client.private_key}
Address = {client.ip_address}/24
DNS = 8.8.8.8

[Peer]
PublicKey = {server.public_key}
Endpoint = {server.endpoint}:{server.port}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25"""
    
    return jsonify({'config': config})

@app.route('/api/clients/<int:client_id>/qr', methods=['GET'])
@jwt_required()
def get_client_qr(client_id):
    """Get QR code for client configuration."""
    client = VPNClient.query.get_or_404(client_id)
    
    # Get client configuration
    config_response = get_client_config(client_id)
    if config_response[1] != 200:
        return config_response
    
    config = config_response[0].get_json()['config']
    
    # Generate QR code
    qr_io = generate_qr_code(config)
    
    return send_file(qr_io, mimetype='image/png')

@app.route('/api/status', methods=['GET'])
@jwt_required()
def get_status():
    """Get VPN server status and statistics."""
    wg_status = get_wireguard_status()
    
    # Get system stats
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    return jsonify({
        'wireguard': wg_status,
        'system': {
            'cpu_percent': cpu_percent,
            'memory': {
                'total': memory.total,
                'available': memory.available,
                'percent': memory.percent
            },
            'disk': {
                'total': disk.total,
                'free': disk.free,
                'percent': (disk.used / disk.total) * 100
            }
        },
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/clients/<int:client_id>', methods=['DELETE'])
@jwt_required()
def delete_client(client_id):
    """Delete a VPN client."""
    client = VPNClient.query.get_or_404(client_id)
    
    # Remove from WireGuard configuration
    # This would typically involve updating the server config
    # and reloading WireGuard
    
    db.session.delete(client)
    db.session.commit()
    
    return jsonify({'message': 'Client deleted successfully'})

# Initialize database
def create_tables():
    with app.app_context():
        db.create_all()
        
        # Create default admin user if none exists
        if not User.query.filter_by(username='admin').first():
            admin = User(
                username='admin',
                email='admin@vpn.local',
                is_admin=True
            )
            admin.set_password('admin123')  # Change this in production!
            db.session.add(admin)
            db.session.commit()
            logger.info("Created default admin user: admin/admin123")
        
        # Create default VPN client if none exists
        if not VPNClient.query.first():
            try:
                # Generate real client keys if WireGuard is available
                import platform
                if platform.system() != 'Windows':
                    try:
                        private_key_result = subprocess.run(['wg', 'genkey'], 
                                                          capture_output=True, text=True, check=True)
                        private_key = private_key_result.stdout.strip()
                        
                        public_key_result = subprocess.run(['wg', 'pubkey'], 
                                                         input=private_key, text=True,
                                                         capture_output=True, check=True)
                        public_key = public_key_result.stdout.strip()
                    except (subprocess.CalledProcessError, FileNotFoundError):
                        # Fallback to mock keys if WireGuard not available
                        private_key = "mOCK_PRIVATE_KEY_FOR_DEFAULT_CLIENT_1234567890123456789012345678901234567890"
                        public_key = "mOCK_PUBLIC_KEY_FOR_DEFAULT_CLIENT_1234567890123456789012345678901234567890"
                else:
                    # Use mock keys for Windows
                    private_key = "mOCK_PRIVATE_KEY_FOR_DEFAULT_CLIENT_1234567890123456789012345678901234567890"
                    public_key = "mOCK_PUBLIC_KEY_FOR_DEFAULT_CLIENT_1234567890123456789012345678901234567890"
                
                # Create default client
                default_client = VPNClient(
                    name='default-client',
                    public_key=public_key,
                    private_key=private_key,
                    ip_address='10.0.0.2',
                    is_active=True
                )
                
                db.session.add(default_client)
                db.session.commit()
                logger.info("Created default VPN client: default-client")
                
            except Exception as e:
                logger.error(f"Error creating default client: {e}")
        
        # Create default VPN server if none exists
        if not VPNServer.query.first():
            try:
                # Generate real server keys if WireGuard is available
                import platform
                if platform.system() != 'Windows':
                    try:
                        server_private_key_result = subprocess.run(['wg', 'genkey'], 
                                                                  capture_output=True, text=True, check=True)
                        server_private_key = server_private_key_result.stdout.strip()
                        
                        server_public_key_result = subprocess.run(['wg', 'pubkey'], 
                                                                 input=server_private_key, text=True,
                                                                 capture_output=True, check=True)
                        server_public_key = server_public_key_result.stdout.strip()
                    except (subprocess.CalledProcessError, FileNotFoundError):
                        # Fallback to mock keys if WireGuard not available
                        server_private_key = "mOCK_SERVER_PRIVATE_KEY_1234567890123456789012345678901234567890"
                        server_public_key = "mOCK_SERVER_PUBLIC_KEY_1234567890123456789012345678901234567890"
                else:
                    # Use mock keys for Windows
                    server_private_key = "mOCK_SERVER_PRIVATE_KEY_1234567890123456789012345678901234567890"
                    server_public_key = "mOCK_SERVER_PUBLIC_KEY_1234567890123456789012345678901234567890"
                
                # Create default server
                default_server = VPNServer(
                    name='default-server',
                    public_key=server_public_key,
                    private_key=server_private_key,
                    endpoint='localhost',
                    port=51820,
                    is_active=True
                )
                
                db.session.add(default_server)
                db.session.commit()
                logger.info("Created default VPN server: default-server")
                
            except Exception as e:
                logger.error(f"Error creating default server: {e}")

# Initialize database on startup
create_tables()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)

