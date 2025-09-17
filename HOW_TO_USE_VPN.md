# How to Use WireFlow VPN

## 🚀 Quick Start Guide

**WireFlow** - Seamless Secure Connections

### **Current Status**
- ✅ Web Client: `http://localhost:4200`
- ✅ API Server: `http://localhost:8080`
- ✅ Default client created automatically

## 📱 **Step-by-Step Usage**

### **1. Access the Web Interface**
```
Open: http://localhost:4200
```
You'll see the WireFlow VPN Management Dashboard with:
- System status indicators
- Client count
- Action buttons

### **2. View Your VPN Clients**
1. Click **"Load Clients"** button
2. You'll see: `default-client` (IP: 10.0.0.2)

### **3. Get Client Configuration**

#### **Method A: Using Web Interface**
1. Click **"Refresh Status"** to see system info
2. The web client will show client details

#### **Method B: Using API Directly**
```bash
# Get client configuration
curl http://localhost:8080/api/clients/1/config
```

This returns a WireGuard config file like:
```
[Interface]
PrivateKey = [YOUR_PRIVATE_KEY]
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = [SERVER_PUBLIC_KEY]
Endpoint = localhost:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### **4. Install WireGuard Client**

#### **Windows**
1. Download: https://www.wireguard.com/install/
2. Install WireGuard application
3. Import the configuration file

#### **macOS**
```bash
brew install wireguard-tools
```

#### **Linux**
```bash
sudo apt install wireguard  # Ubuntu/Debian
sudo yum install wireguard   # CentOS/RHEL
```

### **5. Connect to VPN**
1. Save the config as `vpn-client.conf`
2. Import into WireGuard client
3. Click **"Connect"**

## 🔧 **Creating New Clients**

### **Via Web Interface**
The web client provides buttons to:
- Load existing clients
- Refresh system status
- View client details

### **Via API**
```bash
# Create a new client
curl -X POST http://localhost:8080/api/clients \
  -H "Content-Type: application/json" \
  -d '{"name": "my-laptop"}'
```

### **Via Web Client (Future Enhancement)**
The web interface will be enhanced to include:
- Add client button
- Delete client button
- Client configuration download

## 📊 **Monitoring Your VPN**

### **System Status**
- **API Health**: Shows if backend is running
- **Client Count**: Number of active clients
- **System Resources**: CPU, memory, disk usage

### **VPN Statistics**
- **Connection Status**: Active/inactive clients
- **Data Transfer**: Bytes sent/received
- **Connection Duration**: How long clients are connected

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **1. Can't Connect to VPN**
- **Check**: WireGuard is installed
- **Check**: Configuration file is correct
- **Check**: Server is running on port 51820

#### **2. Web Client Shows Errors**
- **Check**: API server is running on port 8080
- **Check**: Browser console for JavaScript errors
- **Check**: Network connectivity

#### **3. Mock Keys Warning**
- **Windows**: Uses mock keys (development only)
- **Linux/macOS**: Generates real keys if WireGuard installed
- **Solution**: Install WireGuard for real VPN functionality

## 🔐 **Security Notes**

### **Development vs Production**
- **Current Setup**: Development with mock keys
- **Production**: Requires real WireGuard installation
- **Security**: Change default passwords in production

### **Default Credentials**
- **Username**: `admin`
- **Password**: `admin123`
- **⚠️ Change these in production!**

## 📱 **Mobile Usage**

### **QR Code Generation**
```bash
# Get QR code for mobile clients
curl http://localhost:8080/api/clients/1/qr
```

### **Mobile WireGuard Apps**
- **iOS**: WireGuard app from App Store
- **Android**: WireGuard app from Google Play
- **Import**: Use QR code or configuration file

## 🚀 **Next Steps**

### **For Real VPN Usage**
1. **Install WireGuard** on your server
2. **Configure Firewall** to allow port 51820
3. **Set up Real Server** with public IP
4. **Generate Real Keys** (automatic if WireGuard installed)

### **For Development**
1. **Test Web Interface** functionality
2. **Create Multiple Clients** via API
3. **Monitor System Status** via dashboard
4. **Test Client Management** features

## 📞 **Getting Help**

### **Check Logs**
- **API Server**: Console output shows detailed logs
- **Web Client**: Browser developer tools
- **WireGuard**: System logs for connection issues

### **Common Commands**
```bash
# Check if API is running
curl http://localhost:8080/health

# List all clients
curl http://localhost:8080/api/clients

# Get system status
curl http://localhost:8080/api/status
```

---

**Remember**: This is a development setup. For production WireFlow VPN usage, you'll need a real server with WireGuard installed and proper network configuration!
