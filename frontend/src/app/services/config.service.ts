import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';

export interface AppConfig {
  apiUrl: string;
}

@Injectable({
  providedIn: 'root'
})
export class ConfigService {
  private config: AppConfig | null = null;

  constructor(private http: HttpClient) {}

  loadConfig(): Observable<AppConfig> {
    if (this.config) {
      return of(this.config);
    }

    return this.http.get<AppConfig>('/assets/config.json').pipe(
      map(config => {
        this.config = config;
        return config;
      }),
      catchError(error => {
        console.error('Failed to load config, using fallback:', error);
        // Fallback configuration
        this.config = {
          apiUrl: 'https://api.example.com/prod'
        };
        return of(this.config);
      })
    );
  }

  getConfig(): AppConfig | null {
    return this.config;
  }

  getApiUrl(): string {
    return this.config?.apiUrl || 'https://api.example.com/prod';
  }
}