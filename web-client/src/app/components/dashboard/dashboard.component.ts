import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';

interface VPNClient {
  id: number;
  name: string;
  ip_address: string;
  is_active: boolean;
  created_at: string;
  last_connected?: string;
  bytes_received: number;
  bytes_sent: number;
}

interface SystemStatus {
  wireguard: any;
  system: {
    cpu_percent: number;
    memory: {
      total: number;
      available: number;
      percent: number;
    };
    disk: {
      total: number;
      free: number;
      percent: number;
    };
  };
  timestamp: string;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="dashboard-container">
      <!-- Header -->
      <header class="dashboard-header">
        <div class="header-content">
          <h1>VPN Management Dashboard</h1>
          <div class="header-actions">
            <span class="user-info">Welcome, {{ currentUser?.username }}</span>
            <button (click)="logout()" class="logout-button">Logout</button>
          </div>
        </div>
      </header>

      <!-- Main Content -->
      <main class="dashboard-main">
        <!-- System Status Cards -->
        <div class="status-cards">
          <div class="status-card">
            <div class="card-icon">🟢</div>
            <div class="card-content">
              <h3>API Status</h3>
              <p [class]="apiOnline ? 'status-online' : 'status-offline'">
                {{ apiOnline ? 'Online' : 'Offline' }}
              </p>
            </div>
          </div>
          
          <div class="status-card">
            <div class="card-icon">👥</div>
            <div class="card-content">
              <h3>Active Clients</h3>
              <p class="status-number">{{ clients.length }}</p>
            </div>
          </div>
          
          <div class="status-card">
            <div class="card-icon">💾</div>
            <div class="card-content">
              <h3>Memory Usage</h3>
              <p class="status-number">{{ systemStatus?.system?.memory?.percent?.toFixed(1) || 'N/A' }}%</p>
            </div>
          </div>
          
          <div class="status-card">
            <div class="card-icon">🖥️</div>
            <div class="card-content">
              <h3>CPU Usage</h3>
              <p class="status-number">{{ systemStatus?.system?.cpu_percent?.toFixed(1) || 'N/A' }}%</p>
            </div>
          </div>
        </div>

        <!-- Actions -->
        <div class="actions-section">
          <button (click)="refreshStatus()" class="action-button primary">
            🔄 Refresh Status
          </button>
          <button (click)="loadClients()" class="action-button secondary">
            📋 Load Clients
          </button>
          <button (click)="showAddClientModal = true" class="action-button success">
            ➕ Add Client
          </button>
        </div>

        <!-- Clients Table -->
        <div class="clients-section">
          <h2>VPN Clients</h2>
          <div *ngIf="clients.length === 0" class="no-clients">
            <p>No clients found. Click "Add Client" to create one.</p>
          </div>
          
          <div *ngIf="clients.length > 0" class="clients-table">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>IP Address</th>
                  <th>Status</th>
                  <th>Data Usage</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr *ngFor="let client of clients">
                  <td>{{ client.name }}</td>
                  <td>{{ client.ip_address }}</td>
                  <td>
                    <span [class]="client.is_active ? 'status-active' : 'status-inactive'">
                      {{ client.is_active ? 'Active' : 'Inactive' }}
                    </span>
                  </td>
                  <td>{{ formatBytes(client.bytes_received + client.bytes_sent) }}</td>
                  <td>{{ formatDate(client.created_at) }}</td>
                  <td>
                    <button (click)="downloadConfig(client)" class="action-btn small">
                      📥 Config
                    </button>
                    <button (click)="showQRCode(client)" class="action-btn small">
                      📱 QR
                    </button>
                    <button (click)="deleteClient(client)" class="action-btn small danger">
                      🗑️ Delete
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- System Status Details -->
        <div class="system-status-section">
          <h2>System Status</h2>
          <div class="status-details">
            <div class="status-item">
              <label>Last Update:</label>
              <span>{{ lastUpdate || 'Never' }}</span>
            </div>
            <div class="status-item">
              <label>WireGuard Interfaces:</label>
              <span>{{ getWireGuardInterfaces() }}</span>
            </div>
            <div class="status-item">
              <label>Disk Usage:</label>
              <span>{{ systemStatus?.system?.disk?.percent?.toFixed(1) || 'N/A' }}%</span>
            </div>
          </div>
        </div>
      </main>

      <!-- Add Client Modal -->
      <div *ngIf="showAddClientModal" class="modal-overlay" (click)="closeModal()">
        <div class="modal-content" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <h3>Add New VPN Client</h3>
            <button (click)="closeModal()" class="close-button">×</button>
          </div>
          <div class="modal-body">
            <form (ngSubmit)="addClient()">
              <div class="form-group">
                <label for="clientName">Client Name</label>
                <input 
                  type="text" 
                  id="clientName" 
                  [(ngModel)]="newClient.name" 
                  name="clientName"
                  required
                  placeholder="Enter client name"
                >
              </div>
              <div class="modal-actions">
                <button type="button" (click)="closeModal()" class="btn secondary">
                  Cancel
                </button>
                <button type="submit" [disabled]="isAddingClient" class="btn primary">
                  {{ isAddingClient ? 'Adding...' : 'Add Client' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <!-- QR Code Modal -->
      <div *ngIf="showQRModal" class="modal-overlay" (click)="closeQRModal()">
        <div class="modal-content" (click)="$event.stopPropagation()">
          <div class="modal-header">
            <h3>QR Code for {{ selectedClient?.name }}</h3>
            <button (click)="closeQRModal()" class="close-button">×</button>
          </div>
          <div class="modal-body">
            <div class="qr-container">
              <img [src]="qrCodeUrl" alt="QR Code" *ngIf="qrCodeUrl">
              <p>Scan this QR code with your mobile WireGuard app</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .dashboard-container {
      min-height: 100vh;
      background: #f5f7fa;
    }
    
    .dashboard-header {
      background: white;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
      padding: 1rem 0;
    }
    
    .header-content {
      max-width: 1200px;
      margin: 0 auto;
      padding: 0 2rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .header-content h1 {
      margin: 0;
      color: #333;
      font-size: 24px;
    }
    
    .header-actions {
      display: flex;
      align-items: center;
      gap: 1rem;
    }
    
    .user-info {
      color: #666;
      font-size: 14px;
    }
    
    .logout-button {
      background: #dc3545;
      color: white;
      border: none;
      padding: 8px 16px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 14px;
    }
    
    .dashboard-main {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
    }
    
    .status-cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 1.5rem;
      margin-bottom: 2rem;
    }
    
    .status-card {
      background: white;
      border-radius: 12px;
      padding: 1.5rem;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
      display: flex;
      align-items: center;
      gap: 1rem;
    }
    
    .card-icon {
      font-size: 2rem;
    }
    
    .card-content h3 {
      margin: 0 0 0.5rem 0;
      color: #333;
      font-size: 16px;
    }
    
    .card-content p {
      margin: 0;
      font-size: 24px;
      font-weight: 600;
    }
    
    .status-online { color: #28a745; }
    .status-offline { color: #dc3545; }
    .status-number { color: #007bff; }
    
    .actions-section {
      display: flex;
      gap: 1rem;
      margin-bottom: 2rem;
      flex-wrap: wrap;
    }
    
    .action-button {
      padding: 12px 24px;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      font-size: 14px;
      font-weight: 500;
      transition: transform 0.2s ease;
    }
    
    .action-button:hover {
      transform: translateY(-2px);
    }
    
    .action-button.primary { background: #007bff; color: white; }
    .action-button.secondary { background: #6c757d; color: white; }
    .action-button.success { background: #28a745; color: white; }
    
    .clients-section, .system-status-section {
      background: white;
      border-radius: 12px;
      padding: 1.5rem;
      margin-bottom: 2rem;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }
    
    .clients-section h2, .system-status-section h2 {
      margin: 0 0 1rem 0;
      color: #333;
    }
    
    .no-clients {
      text-align: center;
      padding: 2rem;
      color: #666;
    }
    
    .clients-table {
      overflow-x: auto;
    }
    
    .clients-table table {
      width: 100%;
      border-collapse: collapse;
    }
    
    .clients-table th,
    .clients-table td {
      padding: 12px;
      text-align: left;
      border-bottom: 1px solid #eee;
    }
    
    .clients-table th {
      background: #f8f9fa;
      font-weight: 600;
      color: #333;
    }
    
    .status-active { color: #28a745; font-weight: 500; }
    .status-inactive { color: #dc3545; font-weight: 500; }
    
    .action-btn {
      padding: 6px 12px;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 12px;
      margin-right: 4px;
    }
    
    .action-btn.small { background: #e9ecef; color: #333; }
    .action-btn.danger { background: #f8d7da; color: #721c24; }
    
    .status-details {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 1rem;
    }
    
    .status-item {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      border-bottom: 1px solid #eee;
    }
    
    .status-item label {
      font-weight: 500;
      color: #333;
    }
    
    .modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.5);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
    }
    
    .modal-content {
      background: white;
      border-radius: 12px;
      max-width: 500px;
      width: 90%;
      max-height: 90vh;
      overflow-y: auto;
    }
    
    .modal-header {
      padding: 1.5rem;
      border-bottom: 1px solid #eee;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .modal-header h3 {
      margin: 0;
      color: #333;
    }
    
    .close-button {
      background: none;
      border: none;
      font-size: 24px;
      cursor: pointer;
      color: #666;
    }
    
    .modal-body {
      padding: 1.5rem;
    }
    
    .form-group {
      margin-bottom: 1rem;
    }
    
    .form-group label {
      display: block;
      margin-bottom: 0.5rem;
      font-weight: 500;
      color: #333;
    }
    
    .form-group input {
      width: 100%;
      padding: 12px;
      border: 2px solid #e1e5e9;
      border-radius: 8px;
      font-size: 16px;
    }
    
    .modal-actions {
      display: flex;
      gap: 1rem;
      justify-content: flex-end;
      margin-top: 1.5rem;
    }
    
    .btn {
      padding: 10px 20px;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      font-size: 14px;
    }
    
    .btn.primary { background: #007bff; color: white; }
    .btn.secondary { background: #6c757d; color: white; }
    
    .qr-container {
      text-align: center;
    }
    
    .qr-container img {
      max-width: 200px;
      margin-bottom: 1rem;
    }
  `]
})
export class DashboardComponent implements OnInit {
  clients: VPNClient[] = [];
  systemStatus: SystemStatus | null = null;
  apiOnline = false;
  currentUser: any = null;
  lastUpdate = '';
  
  // Modal states
  showAddClientModal = false;
  showQRModal = false;
  selectedClient: VPNClient | null = null;
  qrCodeUrl = '';
  
  // New client form
  newClient = { name: '' };
  isAddingClient = false;
  
  private readonly API_BASE = 'http://localhost:8080';
  
  constructor(private http: HttpClient, private router: Router) {}
  
  ngOnInit(): void {
    this.checkAuth();
    this.loadInitialData();
  }
  
  private checkAuth(): void {
    const token = localStorage.getItem('access_token');
    if (!token) {
      this.router.navigate(['/login']);
      return;
    }
    
    const user = localStorage.getItem('user');
    if (user) {
      this.currentUser = JSON.parse(user);
    }
  }
  
  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token');
    return new HttpHeaders({
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    });
  }
  
  private loadInitialData(): void {
    this.testAPI();
    this.loadClients();
    this.refreshStatus();
  }
  
  testAPI(): void {
    this.http.get(`${this.API_BASE}/health`).subscribe({
      next: () => {
        this.apiOnline = true;
      },
      error: () => {
        this.apiOnline = false;
      }
    });
  }
  
  refreshStatus(): void {
    this.http.get<SystemStatus>(`${this.API_BASE}/api/status`, { headers: this.getHeaders() })
      .subscribe({
        next: (status) => {
          this.systemStatus = status;
          this.lastUpdate = new Date().toLocaleString();
        },
        error: (error) => {
          console.error('Failed to get system status:', error);
        }
      });
  }
  
  loadClients(): void {
    this.http.get<VPNClient[]>(`${this.API_BASE}/api/clients`, { headers: this.getHeaders() })
      .subscribe({
        next: (clients) => {
          this.clients = clients;
        },
        error: (error) => {
          console.error('Failed to load clients:', error);
        }
      });
  }
  
  addClient(): void {
    if (!this.newClient.name.trim()) return;
    
    this.isAddingClient = true;
    this.http.post<any>(`${this.API_BASE}/api/clients`, this.newClient, { headers: this.getHeaders() })
      .subscribe({
        next: (response) => {
          this.isAddingClient = false;
          this.showAddClientModal = false;
          this.newClient.name = '';
          this.loadClients();
        },
        error: (error) => {
          this.isAddingClient = false;
          console.error('Failed to add client:', error);
        }
      });
  }
  
  deleteClient(client: VPNClient): void {
    if (confirm(`Are you sure you want to delete client "${client.name}"?`)) {
      this.http.delete(`${this.API_BASE}/api/clients/${client.id}`, { headers: this.getHeaders() })
        .subscribe({
          next: () => {
            this.loadClients();
          },
          error: (error) => {
            console.error('Failed to delete client:', error);
          }
        });
    }
  }
  
  downloadConfig(client: VPNClient): void {
    this.http.get(`${this.API_BASE}/api/clients/${client.id}/config`, { 
      headers: this.getHeaders(),
      responseType: 'text'
    }).subscribe({
      next: (config) => {
        const blob = new Blob([config], { type: 'text/plain' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${client.name}.conf`;
        a.click();
        window.URL.revokeObjectURL(url);
      },
      error: (error) => {
        console.error('Failed to download config:', error);
      }
    });
  }
  
  showQRCode(client: VPNClient): void {
    this.selectedClient = client;
    this.qrCodeUrl = `${this.API_BASE}/api/clients/${client.id}/qr`;
    this.showQRModal = true;
  }
  
  closeModal(): void {
    this.showAddClientModal = false;
    this.newClient.name = '';
  }
  
  closeQRModal(): void {
    this.showQRModal = false;
    this.selectedClient = null;
    this.qrCodeUrl = '';
  }
  
  logout(): void {
    localStorage.removeItem('access_token');
    localStorage.removeItem('user');
    this.router.navigate(['/login']);
  }
  
  formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
  
  formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }
  
  getWireGuardInterfaces(): string {
    if (!this.systemStatus?.wireguard) return 'None';
    return Object.keys(this.systemStatus.wireguard).join(', ');
  }
}
