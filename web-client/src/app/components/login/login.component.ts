import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="login-container">
      <div class="login-card">
        <div class="login-header">
          <h1>VPN Management System</h1>
          <p>Sign in to manage your VPN clients</p>
        </div>
        
        <form (ngSubmit)="onLogin()" class="login-form">
          <div class="form-group">
            <label for="username">Username</label>
            <input 
              type="text" 
              id="username" 
              [(ngModel)]="credentials.username" 
              name="username"
              required
              placeholder="Enter your username"
            >
          </div>
          
          <div class="form-group">
            <label for="password">Password</label>
            <input 
              type="password" 
              id="password" 
              [(ngModel)]="credentials.password" 
              name="password"
              required
              placeholder="Enter your password"
            >
          </div>
          
          <button type="submit" [disabled]="isLoading" class="login-button">
            <span *ngIf="!isLoading">Sign In</span>
            <span *ngIf="isLoading">Signing In...</span>
          </button>
          
          <div *ngIf="errorMessage" class="error-message">
            {{ errorMessage }}
          </div>
        </form>
        
        <div class="login-footer">
          <p>Default credentials: admin / admin123</p>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .login-container {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 20px;
    }
    
    .login-card {
      background: white;
      border-radius: 12px;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
      padding: 40px;
      width: 100%;
      max-width: 400px;
    }
    
    .login-header {
      text-align: center;
      margin-bottom: 30px;
    }
    
    .login-header h1 {
      color: #333;
      margin: 0 0 10px 0;
      font-size: 28px;
      font-weight: 600;
    }
    
    .login-header p {
      color: #666;
      margin: 0;
      font-size: 14px;
    }
    
    .login-form {
      display: flex;
      flex-direction: column;
      gap: 20px;
    }
    
    .form-group {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    
    .form-group label {
      font-weight: 500;
      color: #333;
      font-size: 14px;
    }
    
    .form-group input {
      padding: 12px 16px;
      border: 2px solid #e1e5e9;
      border-radius: 8px;
      font-size: 16px;
      transition: border-color 0.3s ease;
    }
    
    .form-group input:focus {
      outline: none;
      border-color: #667eea;
    }
    
    .login-button {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      padding: 14px 20px;
      border-radius: 8px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: transform 0.2s ease;
    }
    
    .login-button:hover:not(:disabled) {
      transform: translateY(-2px);
    }
    
    .login-button:disabled {
      opacity: 0.7;
      cursor: not-allowed;
    }
    
    .error-message {
      background: #fee;
      color: #c33;
      padding: 12px;
      border-radius: 8px;
      font-size: 14px;
      text-align: center;
    }
    
    .login-footer {
      margin-top: 20px;
      text-align: center;
    }
    
    .login-footer p {
      color: #666;
      font-size: 12px;
      margin: 0;
    }
  `]
})
export class LoginComponent implements OnInit {
  credentials = {
    username: '',
    password: ''
  };
  
  isLoading = false;
  errorMessage = '';
  
  private readonly API_BASE = 'http://localhost:8080';
  
  constructor(private http: HttpClient, private router: Router) {}
  
  ngOnInit(): void {
    // Check if already logged in
    const token = localStorage.getItem('access_token');
    if (token) {
      this.router.navigate(['/dashboard']);
    }
  }
  
  onLogin(): void {
    this.isLoading = true;
    this.errorMessage = '';
    
    this.http.post<any>(`${this.API_BASE}/api/auth/login`, this.credentials)
      .subscribe({
        next: (response) => {
          localStorage.setItem('access_token', response.access_token);
          localStorage.setItem('user', JSON.stringify(response.user));
          this.router.navigate(['/dashboard']);
        },
        error: (error) => {
          this.isLoading = false;
          this.errorMessage = error.error?.error || 'Login failed. Please try again.';
        }
      });
  }
}
