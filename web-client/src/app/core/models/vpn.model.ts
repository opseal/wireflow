export interface VPNClient {
  id: number;
  name: string;
  description?: string;
  publicKey: string;
  privateKey?: string;
  ipAddress: string;
  isActive: boolean;
  isConnected: boolean;
  lastConnected?: Date;
  bytesReceived: number;
  bytesSent: number;
  createdAt: Date;
  updatedAt: Date;
  createdBy: number;
  tags?: string[];
  metadata?: Record<string, any>;
}

export interface VPNServer {
  id: number;
  name: string;
  description?: string;
  publicKey: string;
  privateKey?: string;
  endpoint: string;
  port: number;
  isActive: boolean;
  isHealthy: boolean;
  region: string;
  provider: string;
  createdAt: Date;
  updatedAt: Date;
  stats?: ServerStats;
}

export interface ServerStats {
  connectedClients: number;
  totalClients: number;
  bytesReceived: number;
  bytesSent: number;
  uptime: number;
  lastHandshake?: Date;
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
}

export interface VPNStatus {
  servers: VPNServer[];
  totalClients: number;
  connectedClients: number;
  totalTraffic: TrafficStats;
  systemHealth: SystemHealth;
  lastUpdated: Date;
}

export interface TrafficStats {
  bytesReceived: number;
  bytesSent: number;
  packetsReceived: number;
  packetsSent: number;
  rateReceived: number; // bytes per second
  rateSent: number; // bytes per second
}

export interface SystemHealth {
  status: 'healthy' | 'warning' | 'critical';
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
  networkLatency: number;
  uptime: number;
  alerts: SystemAlert[];
}

export interface SystemAlert {
  id: string;
  type: 'info' | 'warning' | 'error' | 'critical';
  title: string;
  message: string;
  timestamp: Date;
  resolved: boolean;
  resolvedAt?: Date;
}

export interface CreateClientRequest {
  name: string;
  description?: string;
  ipAddress?: string;
  tags?: string[];
  metadata?: Record<string, any>;
}

export interface UpdateClientRequest {
  name?: string;
  description?: string;
  isActive?: boolean;
  tags?: string[];
  metadata?: Record<string, any>;
}

export interface ClientConfig {
  id: number;
  name: string;
  config: string;
  qrCode?: string;
  downloadUrl: string;
  expiresAt?: Date;
}

export interface QRCodeData {
  id: number;
  name: string;
  qrCode: string;
  config: string;
}

export interface VPNMetrics {
  timestamp: Date;
  clients: ClientMetrics[];
  servers: ServerMetrics[];
  system: SystemMetrics;
}

export interface ClientMetrics {
  clientId: number;
  name: string;
  isConnected: boolean;
  bytesReceived: number;
  bytesSent: number;
  lastHandshake?: Date;
  latency?: number;
}

export interface ServerMetrics {
  serverId: number;
  name: string;
  connectedClients: number;
  bytesReceived: number;
  bytesSent: number;
  cpuUsage: number;
  memoryUsage: number;
  uptime: number;
}

export interface SystemMetrics {
  totalClients: number;
  connectedClients: number;
  totalTraffic: TrafficStats;
  systemResources: SystemResources;
}

export interface SystemResources {
  cpuUsage: number;
  memoryUsage: number;
  diskUsage: number;
  networkLatency: number;
  uptime: number;
}

export interface VPNLog {
  id: string;
  timestamp: Date;
  level: 'debug' | 'info' | 'warn' | 'error';
  component: string;
  message: string;
  details?: Record<string, any>;
  clientId?: number;
  serverId?: number;
}

export interface VPNEvent {
  id: string;
  type: 'client_connected' | 'client_disconnected' | 'client_created' | 'client_deleted' | 
        'server_started' | 'server_stopped' | 'system_alert' | 'security_event';
  timestamp: Date;
  clientId?: number;
  serverId?: number;
  userId?: number;
  details: Record<string, any>;
}

export interface DashboardWidget {
  id: string;
  type: 'chart' | 'metric' | 'table' | 'status' | 'map';
  title: string;
  position: { x: number; y: number; w: number; h: number };
  config: Record<string, any>;
  data?: any;
}

export interface DashboardConfig {
  id: string;
  name: string;
  widgets: DashboardWidget[];
  isDefault: boolean;
  createdAt: Date;
  updatedAt: Date;
}






