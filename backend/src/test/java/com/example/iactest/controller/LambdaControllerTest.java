package com.example.iactest.controller;

import com.example.iactest.service.LambdaService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LambdaControllerTest {

    @Mock
    private LambdaService lambdaService;

    @InjectMocks
    private LambdaController lambdaController;

    private Map<String, Object> mockLambdaResponse;

    @BeforeEach
    void setUp() {
        mockLambdaResponse = new HashMap<>();
        mockLambdaResponse.put("statusCode", 200);
        mockLambdaResponse.put("body", Map.of(
                "message", "Lambda executed successfully",
                "timestamp", "2024-01-01T00:00:00Z",
                "bucket", "test-bucket"
        ));
    }

    @Test
    @DisplayName("Test successful Lambda invocation")
    void testLambda_Success() {
        when(lambdaService.invokeLambdaFunction()).thenReturn(mockLambdaResponse);

        ResponseEntity<Map<String, Object>> response = lambdaController.testLambda();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(200, response.getBody().get("statusCode"));
        
        verify(lambdaService, times(1)).invokeLambdaFunction();
    }

    @Test
    @DisplayName("Test Lambda invocation with exception")
    void testLambda_Exception() {
        String errorMessage = "Lambda invocation failed";
        when(lambdaService.invokeLambdaFunction()).thenThrow(new RuntimeException(errorMessage));

        ResponseEntity<Map<String, Object>> response = lambdaController.testLambda();

        assertNotNull(response);
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("Failed to invoke Lambda function", response.getBody().get("error"));
        assertEquals(errorMessage, response.getBody().get("message"));
        
        verify(lambdaService, times(1)).invokeLambdaFunction();
    }

    @Test
    @DisplayName("Test Lambda invocation with null response")
    void testLambda_NullResponse() {
        when(lambdaService.invokeLambdaFunction()).thenReturn(null);

        ResponseEntity<Map<String, Object>> response = lambdaController.testLambda();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNull(response.getBody());
        
        verify(lambdaService, times(1)).invokeLambdaFunction();
    }

    @Test
    @DisplayName("Test Lambda invocation with empty response")
    void testLambda_EmptyResponse() {
        Map<String, Object> emptyResponse = new HashMap<>();
        when(lambdaService.invokeLambdaFunction()).thenReturn(emptyResponse);

        ResponseEntity<Map<String, Object>> response = lambdaController.testLambda();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertTrue(response.getBody().isEmpty());
        
        verify(lambdaService, times(1)).invokeLambdaFunction();
    }

    @Test
    @DisplayName("Test Lambda invocation with complex response")
    void testLambda_ComplexResponse() {
        Map<String, Object> complexResponse = new HashMap<>();
        complexResponse.put("statusCode", 200);
        complexResponse.put("headers", Map.of("Content-Type", "application/json"));
        
        Map<String, Object> body = new HashMap<>();
        body.put("files", new String[]{"file1.txt", "file2.txt"});
        body.put("metadata", Map.of("region", "us-east-1", "env", "test"));
        complexResponse.put("body", body);
        
        when(lambdaService.invokeLambdaFunction()).thenReturn(complexResponse);

        ResponseEntity<Map<String, Object>> response = lambdaController.testLambda();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(200, response.getBody().get("statusCode"));
        assertNotNull(response.getBody().get("headers"));
        assertNotNull(response.getBody().get("body"));
        
        verify(lambdaService, times(1)).invokeLambdaFunction();
    }

    @Test
    @DisplayName("Test health endpoint")
    void health() {
        ResponseEntity<Map<String, String>> response = lambdaController.health();

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("healthy", response.getBody().get("status"));
        
        verifyNoInteractions(lambdaService);
    }

    @Test
    @DisplayName("Test Lambda invocation with specific exception types")
    void testLambda_SpecificExceptions() {
        when(lambdaService.invokeLambdaFunction()).thenThrow(new IllegalArgumentException("Invalid argument"));

        ResponseEntity<Map<String, Object>> response = lambdaController.testLambda();

        assertNotNull(response);
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("Failed to invoke Lambda function", response.getBody().get("error"));
        assertEquals("Invalid argument", response.getBody().get("message"));
        
        verify(lambdaService, times(1)).invokeLambdaFunction();
    }

    @Test
    @DisplayName("Test Lambda invocation method is called once per request")
    void testLambda_MethodCallCount() {
        when(lambdaService.invokeLambdaFunction()).thenReturn(mockLambdaResponse);

        lambdaController.testLambda();
        lambdaController.testLambda();
        lambdaController.testLambda();

        verify(lambdaService, times(3)).invokeLambdaFunction();
    }
}