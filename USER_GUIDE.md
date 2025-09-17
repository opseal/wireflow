# WireFlow VPN - User Guide

**WireFlow** - Seamless Secure Connections

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Detailed Setup](#detailed-setup)
5. [Using the Web Client](#using-the-web-client)
6. [Managing VPN Clients](#managing-vpn-clients)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

## Overview

WireFlow VPN provides a comprehensive solution for managing WireGuard VPN connections through a modern web interface. It includes:

- **Web Client**: Angular-based frontend for easy VPN management
- **REST API**: Flask-based backend for VPN operations
- **WireGuard Integration**: Full WireGuard VPN server support
- **User Management**: Authentication and authorization
- **Monitoring**: Real-time VPN statistics and system health

## Prerequisites

### System Requirements
- **Operating System**: Windows 10/11, macOS, or Linux
- **Python**: 3.8 or higher
- **Node.js**: 18.0 or higher
- **npm**: 8.0 or higher
- **Git**: For cloning the repository

### Optional (for full VPN functionality)
- **WireGuard**: For actual VPN connections (Linux/macOS)
- **Docker**: For containerized deployment
- **Kubernetes**: For cloud deployment

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/wireflow/vpn.git
cd vpn
```

### 2. Start the API Server
```bash
cd src/api
pip install --user -r requirements.txt
python app.py
```
The API will start on `http://localhost:8080`

### 3. Start the Web Client
```bash
cd web-client
npm install
npm start
```
The web client will start on `http://localhost:4200`

### 4. Access the System
Open your browser and navigate to `http://localhost:4200`

## Detailed Setup

### Backend API Setup

#### Step 1: Install Python Dependencies
```bash
cd src/api
pip install --user -r requirements.txt
```

#### Step 2: Configure Environment Variables (Optional)
Create a `.env` file in the `src/api` directory:
```env
JWT_SECRET=your-secret-key-here
DATABASE_URL=sqlite:///vpn.db
REDIS_URL=redis://localhost:6379
```

#### Step 3: Start the API Server
```bash
python app.py
```

**Default Credentials:**
- Username: `admin`
- Password: `admin123`

### Frontend Web Client Setup

#### Step 1: Install Node.js Dependencies
```bash
cd web-client
npm install
```

#### Step 2: Configure API Endpoint (Optional)
Edit `web-client/src/app/app.component.ts` to change the API base URL:
```typescript
private readonly API_BASE = 'http://localhost:8080';
```

#### Step 3: Start the Development Server
```bash
npm start
```

### Docker Setup (Alternative)

#### Using Docker Compose
```bash
docker-compose up -d vpn-api redis
```

This will start:
- VPN API on port 8080
- Redis cache on port 6379
- All supporting services

## Using the Web Client

### Dashboard Overview

When you first access the web client at `http://localhost:4200`, you'll see:

1. **System Status**: Shows if the API is online
2. **Client Count**: Number of active VPN clients
3. **Health Check**: Real-time system health
4. **Action Buttons**: For refreshing status and managing clients

### Main Features

#### 1. Health Monitoring
- **API Status**: Green ✅ indicates API is responding
- **System Health**: Shows overall system status
- **Last Result**: Displays the latest operation result

#### 2. Client Management
- **View Clients**: See all configured VPN clients
- **Client Details**: IP addresses, connection status, data usage
- **Add Clients**: Create new VPN client configurations
- **Remove Clients**: Delete unused client configurations

#### 3. System Status
- **WireGuard Status**: VPN server statistics
- **System Resources**: CPU, memory, and disk usage
- **Connection Statistics**: Data transfer metrics

### Navigation

The web interface provides intuitive navigation:

- **Refresh Status**: Updates all system information
- **Load Clients**: Fetches current client list
- **System Status**: Shows detailed system metrics

## Managing VPN Clients

### Creating a New Client

1. **Access the API**: Use the `/api/clients` POST endpoint
2. **Provide Client Name**: Choose a unique identifier
3. **Automatic Configuration**: The system generates:
   - Private/Public key pair
   - IP address assignment
   - Client configuration file

### Example API Call
```bash
curl -X POST http://localhost:8080/api/clients \
  -H "Content-Type: application/json" \
  -d '{"name": "my-client"}'
```

### Client Configuration

Each client receives:
- **Private Key**: For client authentication
- **Public Key**: For server verification
- **IP Address**: Assigned from the VPN subnet
- **Configuration File**: Ready-to-use WireGuard config

### Downloading Client Config

Access client configuration via:
```
GET /api/clients/{client_id}/config
```

### QR Code Generation

Get QR code for mobile clients:
```
GET /api/clients/{client_id}/qr
```

## Troubleshooting

### Common Issues

#### 1. API Connection Failed
**Symptoms**: Web client shows "API connection failed"
**Solutions**:
- Verify API server is running on port 8080
- Check firewall settings
- Ensure no other service is using port 8080

#### 2. Authentication Errors
**Symptoms**: 401 Unauthorized responses
**Solutions**:
- Use default credentials: admin/admin123
- Check JWT token expiration
- Verify API secret key configuration

#### 3. WireGuard Commands Not Found
**Symptoms**: 500 errors on status endpoints
**Solutions**:
- Install WireGuard on Linux/macOS
- On Windows, the system uses mock data
- Check WireGuard installation path

#### 4. Database Issues
**Symptoms**: Database connection errors
**Solutions**:
- Check SQLite file permissions
- Verify database URL configuration
- Restart the API server

### Log Analysis

#### API Server Logs
Monitor the console output for:
- Database initialization messages
- Client creation confirmations
- Error details and stack traces

#### Web Client Console
Check browser developer tools for:
- Network request failures
- JavaScript errors
- CORS issues

### Performance Issues

#### High Memory Usage
- Monitor system resources via `/api/status`
- Restart API server if needed
- Check for memory leaks in long-running processes

#### Slow Response Times
- Verify network connectivity
- Check database performance
- Monitor system resource usage

## Advanced Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET` | `your-secret-key-change-this` | Secret key for JWT tokens |
| `DATABASE_URL` | `sqlite:///:memory:` | Database connection string |
| `REDIS_URL` | `redis://localhost:6379` | Redis cache connection |

### Database Configuration

#### SQLite (Default)
```python
DATABASE_URL = 'sqlite:///vpn.db'
```

#### PostgreSQL
```python
DATABASE_URL = 'postgresql://user:password@localhost/vpn_db'
```

#### MySQL
```python
DATABASE_URL = 'mysql://user:password@localhost/vpn_db'
```

### Security Considerations

#### Production Deployment
1. **Change Default Passwords**: Update admin credentials
2. **Use Strong JWT Secret**: Generate a secure random key
3. **Enable HTTPS**: Use SSL certificates
4. **Firewall Configuration**: Restrict access to necessary ports
5. **Regular Updates**: Keep dependencies updated

#### Authentication
- JWT tokens expire after 24 hours
- Implement proper session management
- Consider multi-factor authentication

### Monitoring and Logging

#### System Monitoring
- CPU and memory usage tracking
- Network interface statistics
- Disk space monitoring

#### VPN Monitoring
- Client connection status
- Data transfer metrics
- Connection duration tracking

#### Log Management
- Application logs via Python logging
- Access logs via Flask
- Error tracking and alerting

### Backup and Recovery

#### Database Backup
```bash
# SQLite backup
cp vpn.db vpn_backup_$(date +%Y%m%d).db
```

#### Configuration Backup
```bash
# Backup WireGuard configs
tar -czf wireguard_configs_$(date +%Y%m%d).tar.gz data/wireguard/
```

## API Reference

### Authentication Endpoints
- `POST /api/auth/login` - User login
- `GET /api/auth/logout` - User logout

### Client Management
- `GET /api/clients` - List all clients
- `POST /api/clients` - Create new client
- `GET /api/clients/{id}/config` - Get client config
- `GET /api/clients/{id}/qr` - Get QR code
- `DELETE /api/clients/{id}` - Delete client

### System Information
- `GET /health` - Health check
- `GET /api/status` - System status
- `GET /api/servers` - VPN server info

## Support and Contributing

### Getting Help
- Check the troubleshooting section
- Review API logs for error details
- Consult the project documentation

### Contributing
- Follow the coding standards
- Write comprehensive tests
- Update documentation
- Submit pull requests

### License
This project is licensed under the MIT License. See LICENSE file for details.

---

**Last Updated**: September 2025
**Version**: 0.1
