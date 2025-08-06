import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, switchMap } from 'rxjs';
import { ConfigService } from './config.service';

@Injectable({
  providedIn: 'root'
})
export class LambdaService {
  constructor(
    private http: HttpClient,
    private configService: ConfigService
  ) {}

  testLambda(): Observable<any> {
    return this.configService.loadConfig().pipe(
      switchMap(config => {
        return this.http.post(`${config.apiUrl}/test-lambda`, {});
      })
    );
  }
}