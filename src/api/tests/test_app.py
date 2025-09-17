#!/usr/bin/env python3
"""
Test suite for VPN Management API
"""

import pytest
import json
import tempfile
import os
from unittest.mock import patch, MagicMock
from app import app, db, User, VPNClient, VPNServer

@pytest.fixture
def client():
    """Create test client with temporary database."""
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
            yield client

@pytest.fixture
def auth_headers(client):
    """Get authentication headers for test requests."""
    # Create test user
    user = User(username='testuser', email='test@example.com')
    user.set_password('testpass')
    db.session.add(user)
    db.session.commit()
    
    # Login and get token
    response = client.post('/api/auth/login', json={
        'username': 'testuser',
        'password': 'testpass'
    })
    
    token = response.json['access_token']
    return {'Authorization': f'Bearer {token}'}

class TestHealthEndpoint:
    """Test health check endpoint."""
    
    def test_health_check(self, client):
        """Test health check returns 200."""
        response = client.get('/health')
        assert response.status_code == 200
        assert response.json['status'] == 'healthy'

class TestAuthentication:
    """Test authentication endpoints."""
    
    def test_login_success(self, client):
        """Test successful login."""
        # Create test user
        user = User(username='testuser', email='test@example.com')
        user.set_password('testpass')
        db.session.add(user)
        db.session.commit()
        
        response = client.post('/api/auth/login', json={
            'username': 'testuser',
            'password': 'testpass'
        })
        
        assert response.status_code == 200
        assert 'access_token' in response.json
        assert response.json['user']['username'] == 'testuser'
    
    def test_login_invalid_credentials(self, client):
        """Test login with invalid credentials."""
        response = client.post('/api/auth/login', json={
            'username': 'nonexistent',
            'password': 'wrongpass'
        })
        
        assert response.status_code == 401
        assert 'error' in response.json
    
    def test_login_missing_credentials(self, client):
        """Test login with missing credentials."""
        response = client.post('/api/auth/login', json={})
        
        assert response.status_code == 400
        assert 'error' in response.json

class TestVPNClients:
    """Test VPN client management endpoints."""
    
    def test_get_clients_empty(self, client, auth_headers):
        """Test getting clients when none exist."""
        response = client.get('/api/clients', headers=auth_headers)
        
        assert response.status_code == 200
        assert response.json == []
    
    def test_create_client_success(self, client, auth_headers):
        """Test creating a new VPN client."""
        with patch('subprocess.run') as mock_run:
            # Mock key generation
            mock_run.side_effect = [
                MagicMock(stdout='private_key_123\n', returncode=0),
                MagicMock(stdout='public_key_123\n', returncode=0)
            ]
            
            response = client.post('/api/clients', 
                                 json={'name': 'testclient'},
                                 headers=auth_headers)
            
            assert response.status_code == 201
            assert response.json['name'] == 'testclient'
            assert 'public_key' in response.json
    
    def test_create_client_duplicate_name(self, client, auth_headers):
        """Test creating client with duplicate name."""
        # Create first client
        client_obj = VPNClient(
            name='testclient',
            public_key='public_key_123',
            private_key='private_key_123',
            ip_address='10.0.0.2'
        )
        db.session.add(client_obj)
        db.session.commit()
        
        # Try to create duplicate
        response = client.post('/api/clients',
                             json={'name': 'testclient'},
                             headers=auth_headers)
        
        assert response.status_code == 409
        assert 'error' in response.json
    
    def test_create_client_missing_name(self, client, auth_headers):
        """Test creating client without name."""
        response = client.post('/api/clients',
                             json={},
                             headers=auth_headers)
        
        assert response.status_code == 400
        assert 'error' in response.json
    
    def test_get_client_config(self, client, auth_headers):
        """Test getting client configuration."""
        # Create test client
        client_obj = VPNClient(
            name='testclient',
            public_key='client_public_key',
            private_key='client_private_key',
            ip_address='10.0.0.2'
        )
        db.session.add(client_obj)
        
        # Create test server
        server = VPNServer(
            name='testserver',
            public_key='server_public_key',
            private_key='server_private_key',
            endpoint='test.example.com',
            port=51820
        )
        db.session.add(server)
        db.session.commit()
        
        response = client.get('/api/clients/1/config', headers=auth_headers)
        
        assert response.status_code == 200
        assert 'config' in response.json
        assert 'client_private_key' in response.json['config']
        assert 'server_public_key' in response.json['config']
    
    def test_get_client_config_not_found(self, client, auth_headers):
        """Test getting config for non-existent client."""
        response = client.get('/api/clients/999/config', headers=auth_headers)
        
        assert response.status_code == 404
    
    def test_delete_client(self, client, auth_headers):
        """Test deleting a VPN client."""
        # Create test client
        client_obj = VPNClient(
            name='testclient',
            public_key='public_key_123',
            private_key='private_key_123',
            ip_address='10.0.0.2'
        )
        db.session.add(client_obj)
        db.session.commit()
        
        response = client.delete('/api/clients/1', headers=auth_headers)
        
        assert response.status_code == 200
        assert response.json['message'] == 'Client deleted successfully'
        
        # Verify client is deleted
        deleted_client = VPNClient.query.get(1)
        assert deleted_client is None

class TestStatusEndpoint:
    """Test status and monitoring endpoints."""
    
    @patch('app.get_wireguard_status')
    @patch('psutil.cpu_percent')
    @patch('psutil.virtual_memory')
    @patch('psutil.disk_usage')
    def test_get_status(self, mock_disk, mock_memory, mock_cpu, mock_wg, client, auth_headers):
        """Test getting system and VPN status."""
        # Mock system stats
        mock_cpu.return_value = 25.5
        mock_memory.return_value = MagicMock(total=8589934592, available=4294967296, percent=50.0)
        mock_disk.return_value = MagicMock(total=107374182400, free=53687091200, used=53687091200)
        
        # Mock WireGuard status
        mock_wg.return_value = {
            'wg0': {
                'peers': [
                    {
                        'public_key': 'test_key',
                        'transfer_rx': 1024,
                        'transfer_tx': 2048
                    }
                ]
            }
        }
        
        response = client.get('/api/status', headers=auth_headers)
        
        assert response.status_code == 200
        assert 'wireguard' in response.json
        assert 'system' in response.json
        assert response.json['system']['cpu_percent'] == 25.5

class TestErrorHandling:
    """Test error handling and edge cases."""
    
    def test_unauthorized_access(self, client):
        """Test accessing protected endpoints without authentication."""
        response = client.get('/api/clients')
        assert response.status_code == 401
    
    def test_invalid_json(self, client, auth_headers):
        """Test sending invalid JSON."""
        response = client.post('/api/clients',
                             data='invalid json',
                             headers=auth_headers,
                             content_type='application/json')
        assert response.status_code == 400
    
    def test_missing_content_type(self, client, auth_headers):
        """Test missing content type header."""
        response = client.post('/api/clients',
                             data='{"name": "test"}',
                             headers=auth_headers)
        assert response.status_code == 400

class TestDatabaseModels:
    """Test database models."""
    
    def test_user_password_hashing(self):
        """Test user password hashing."""
        user = User(username='test', email='test@example.com')
        user.set_password('testpass')
        
        assert user.check_password('testpass')
        assert not user.check_password('wrongpass')
        assert user.password_hash != 'testpass'
    
    def test_vpn_client_creation(self):
        """Test VPN client model creation."""
        client = VPNClient(
            name='testclient',
            public_key='public_key',
            private_key='private_key',
            ip_address='10.0.0.2'
        )
        
        assert client.name == 'testclient'
        assert client.is_active == True
        assert client.bytes_received == 0
        assert client.bytes_sent == 0

class TestIntegration:
    """Integration tests."""
    
    def test_full_client_lifecycle(self, client, auth_headers):
        """Test complete client lifecycle."""
        with patch('subprocess.run') as mock_run:
            # Mock key generation
            mock_run.side_effect = [
                MagicMock(stdout='private_key_123\n', returncode=0),
                MagicMock(stdout='public_key_123\n', returncode=0)
            ]
            
            # Create client
            response = client.post('/api/clients',
                                 json={'name': 'lifecycle_test'},
                                 headers=auth_headers)
            assert response.status_code == 201
            client_id = response.json['id']
            
            # Get client list
            response = client.get('/api/clients', headers=auth_headers)
            assert response.status_code == 200
            assert len(response.json) == 1
            assert response.json[0]['name'] == 'lifecycle_test'
            
            # Get client config
            response = client.get(f'/api/clients/{client_id}/config', headers=auth_headers)
            assert response.status_code == 200
            assert 'config' in response.json
            
            # Delete client
            response = client.delete(f'/api/clients/{client_id}', headers=auth_headers)
            assert response.status_code == 200
            
            # Verify deletion
            response = client.get('/api/clients', headers=auth_headers)
            assert response.status_code == 200
            assert len(response.json) == 0

if __name__ == '__main__':
    pytest.main([__file__, '-v'])






