import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LambdaTestComponent } from './components/lambda-test.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, LambdaTestComponent],
  template: `
    <div class="container">
      <h1>IAC Test Application</h1>
      <app-lambda-test></app-lambda-test>
    </div>
  `
})
export class AppComponent {
  title = 'iac-test-frontend';
}