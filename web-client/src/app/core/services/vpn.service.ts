import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable, BehaviorSubject } from 'rxjs';
import { map, tap } from 'rxjs/operators';

import { environment } from '../../../environments/environment';
import { AuthService } from './auth.service';
import { 
  VPNClient, 
  VPNServer, 
  VPNStatus, 
  CreateClientRequest, 
  UpdateClientRequest,
  ClientConfig,
  QRCodeData
} from '../models/vpn.model';

@Injectable({
  providedIn: 'root'
})
export class VpnService {
  private readonly API_URL = environment.apiUrl;
  private clientsSubject = new BehaviorSubject<VPNClient[]>([]);
  public clients$ = this.clientsSubject.asObservable();

  private statusSubject = new BehaviorSubject<VPNStatus | null>(null);
  public status$ = this.statusSubject.asObservable();

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {}

  // VPN Clients Management
  getClients(): Observable<VPNClient[]> {
    return this.http.get<VPNClient[]>(`${this.API_URL}/api/clients`, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(clients => this.clientsSubject.next(clients))
    );
  }

  getClient(id: number): Observable<VPNClient> {
    return this.http.get<VPNClient>(`${this.API_URL}/api/clients/${id}`, {
      headers: this.authService.getAuthHeaders()
    });
  }

  createClient(clientData: CreateClientRequest): Observable<VPNClient> {
    return this.http.post<VPNClient>(`${this.API_URL}/api/clients`, clientData, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(client => {
        const currentClients = this.clientsSubject.value;
        this.clientsSubject.next([...currentClients, client]);
      })
    );
  }

  updateClient(id: number, clientData: UpdateClientRequest): Observable<VPNClient> {
    return this.http.put<VPNClient>(`${this.API_URL}/api/clients/${id}`, clientData, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(updatedClient => {
        const currentClients = this.clientsSubject.value;
        const index = currentClients.findIndex(c => c.id === id);
        if (index !== -1) {
          currentClients[index] = updatedClient;
          this.clientsSubject.next([...currentClients]);
        }
      })
    );
  }

  deleteClient(id: number): Observable<void> {
    return this.http.delete<void>(`${this.API_URL}/api/clients/${id}`, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(() => {
        const currentClients = this.clientsSubject.value;
        this.clientsSubject.next(currentClients.filter(c => c.id !== id));
      })
    );
  }

  // Client Configuration
  getClientConfig(id: number): Observable<ClientConfig> {
    return this.http.get<ClientConfig>(`${this.API_URL}/api/clients/${id}/config`, {
      headers: this.authService.getAuthHeaders()
    });
  }

  downloadClientConfig(id: number): Observable<Blob> {
    return this.http.get(`${this.API_URL}/api/clients/${id}/config/download`, {
      headers: this.authService.getAuthHeaders(),
      responseType: 'blob'
    });
  }

  getClientQRCode(id: number): Observable<Blob> {
    return this.http.get(`${this.API_URL}/api/clients/${id}/qr`, {
      headers: this.authService.getAuthHeaders(),
      responseType: 'blob'
    });
  }

  // VPN Servers Management
  getServers(): Observable<VPNServer[]> {
    return this.http.get<VPNServer[]>(`${this.API_URL}/api/servers`, {
      headers: this.authService.getAuthHeaders()
    });
  }

  getServer(id: number): Observable<VPNServer> {
    return this.http.get<VPNServer>(`${this.API_URL}/api/servers/${id}`, {
      headers: this.authService.getAuthHeaders()
    });
  }

  // VPN Status and Monitoring
  getStatus(): Observable<VPNStatus> {
    return this.http.get<VPNStatus>(`${this.API_URL}/api/status`, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(status => this.statusSubject.next(status))
    );
  }

  getMetrics(timeRange: string = '1h'): Observable<any> {
    const params = new HttpParams().set('range', timeRange);
    return this.http.get(`${this.API_URL}/api/metrics`, {
      headers: this.authService.getAuthHeaders(),
      params
    });
  }

  getLogs(level?: string, limit: number = 100): Observable<any[]> {
    let params = new HttpParams().set('limit', limit.toString());
    if (level) {
      params = params.set('level', level);
    }
    
    return this.http.get<any[]>(`${this.API_URL}/api/logs`, {
      headers: this.authService.getAuthHeaders(),
      params
    });
  }

  // Real-time Updates
  startStatusPolling(interval: number = 5000): void {
    setInterval(() => {
      this.getStatus().subscribe();
    }, interval);
  }

  stopStatusPolling(): void {
    // Implementation for stopping polling
  }

  // Bulk Operations
  bulkDeleteClients(ids: number[]): Observable<void> {
    return this.http.post<void>(`${this.API_URL}/api/clients/bulk-delete`, { ids }, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(() => {
        const currentClients = this.clientsSubject.value;
        this.clientsSubject.next(currentClients.filter(c => !ids.includes(c.id)));
      })
    );
  }

  bulkCreateClients(clients: CreateClientRequest[]): Observable<VPNClient[]> {
    return this.http.post<VPNClient[]>(`${this.API_URL}/api/clients/bulk-create`, { clients }, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(newClients => {
        const currentClients = this.clientsSubject.value;
        this.clientsSubject.next([...currentClients, ...newClients]);
      })
    );
  }

  // Export/Import
  exportClients(): Observable<Blob> {
    return this.http.get(`${this.API_URL}/api/clients/export`, {
      headers: this.authService.getAuthHeaders(),
      responseType: 'blob'
    });
  }

  importClients(file: File): Observable<VPNClient[]> {
    const formData = new FormData();
    formData.append('file', file);

    return this.http.post<VPNClient[]>(`${this.API_URL}/api/clients/import`, formData, {
      headers: this.authService.getAuthHeaders()
    }).pipe(
      tap(importedClients => {
        const currentClients = this.clientsSubject.value;
        this.clientsSubject.next([...currentClients, ...importedClients]);
      })
    );
  }
}






