import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LambdaService } from '../services/lambda.service';

@Component({
  selector: 'app-lambda-test',
  standalone: true,
  imports: [CommonModule],
  template: `
    <button 
      class="test-button" 
      (click)="testLambda()" 
      [disabled]="isLoading">
      <span *ngIf="isLoading" class="loading"></span>
      {{ isLoading ? 'Testing...' : 'Test Lambda' }}
    </button>

    <div *ngIf="result" class="result" [ngClass]="result.success ? 'success' : 'error'">
      <h3>{{ result.success ? 'Success!' : 'Error' }}</h3>
      <p>{{ result.message }}</p>
      
      <div *ngIf="result.details" class="result-details">
        <strong>Details:</strong>
        <pre>{{ result.details | json }}</pre>
      </div>
    </div>
  `
})
export class LambdaTestComponent {
  isLoading = false;
  result: { success: boolean; message: string; details?: any } | null = null;

  constructor(private lambdaService: LambdaService) {}

  testLambda() {
    this.isLoading = true;
    this.result = null;

    this.lambdaService.testLambda().subscribe({
      next: (response) => {
        this.isLoading = false;
        this.result = {
          success: true,
          message: 'Lambda function executed successfully!',
          details: response
        };
      },
      error: (error) => {
        this.isLoading = false;
        this.result = {
          success: false,
          message: error.error?.message || 'Failed to execute Lambda function',
          details: error.error
        };
      }
    });
  }
}