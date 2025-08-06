package com.example.iactest.service;

import com.amazonaws.services.lambda.AWSLambda;
import com.amazonaws.services.lambda.model.InvokeRequest;
import com.amazonaws.services.lambda.model.InvokeResult;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LambdaServiceTest {

    @Mock
    private AWSLambda awsLambda;

    @Mock
    private ObjectMapper objectMapper;

    @InjectMocks
    private LambdaService lambdaService;

    private static final String LAMBDA_FUNCTION_NAME = "test-lambda-function";

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(lambdaService, "lambdaFunctionName", LAMBDA_FUNCTION_NAME);
    }

    @Test
    @DisplayName("Test successful Lambda invocation with simple response")
    void invokeLambdaFunction_Success() throws Exception {
        Map<String, Object> lambdaResponse = new HashMap<>();
        lambdaResponse.put("statusCode", 200);
        lambdaResponse.put("message", "Success");
        
        String responseJson = "{\"statusCode\":200,\"message\":\"Success\"}";
        ByteBuffer payloadBuffer = ByteBuffer.wrap(responseJson.getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);
        when(objectMapper.readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(lambdaResponse);

        Map<String, Object> result = lambdaService.invokeLambdaFunction();

        assertNotNull(result);
        assertEquals(200, result.get("statusCode"));
        assertEquals("Success", result.get("message"));
        
        verify(awsLambda).invoke(any(InvokeRequest.class));
    }

    @Test
    @DisplayName("Test successful Lambda invocation with body as string")
    void invokeLambdaFunction_WithBodyAsString() throws Exception {
        Map<String, Object> bodyContent = new HashMap<>();
        bodyContent.put("bucket", "test-bucket");
        bodyContent.put("key", "test-key");
        
        Map<String, Object> lambdaResponse = new HashMap<>();
        lambdaResponse.put("statusCode", 200);
        lambdaResponse.put("body", "{\"bucket\":\"test-bucket\",\"key\":\"test-key\"}");
        
        String responseJson = "{\"statusCode\":200,\"body\":\"{\\\"bucket\\\":\\\"test-bucket\\\",\\\"key\\\":\\\"test-key\\\"}\"}";
        ByteBuffer payloadBuffer = ByteBuffer.wrap(responseJson.getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);
        when(objectMapper.readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(lambdaResponse);
        when(objectMapper.readValue(eq("{\"bucket\":\"test-bucket\",\"key\":\"test-key\"}"), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(bodyContent);

        Map<String, Object> result = lambdaService.invokeLambdaFunction();

        assertNotNull(result);
        assertEquals(200, result.get("statusCode"));
        assertNotNull(result.get("body"));
        assertTrue(result.get("body") instanceof Map);
        
        @SuppressWarnings("unchecked")
        Map<String, Object> body = (Map<String, Object>) result.get("body");
        assertEquals("test-bucket", body.get("bucket"));
        assertEquals("test-key", body.get("key"));
        
        verify(objectMapper, times(2)).readValue(anyString(), any(com.fasterxml.jackson.core.type.TypeReference.class));
    }

    @Test
    @DisplayName("Test Lambda invocation with non-200 status code")
    void invokeLambdaFunction_NonSuccessStatusCode() {
        ByteBuffer payloadBuffer = ByteBuffer.wrap("Error response".getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(500);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);

        RuntimeException exception = assertThrows(RuntimeException.class, 
                () -> lambdaService.invokeLambdaFunction());
        
        assertTrue(exception.getMessage().contains("Lambda function execution failed with status code: 500"));
        verify(awsLambda).invoke(any(InvokeRequest.class));
        verifyNoInteractions(objectMapper);
    }

    @Test
    @DisplayName("Test Lambda invocation with AWS Lambda exception")
    void invokeLambdaFunction_AWSLambdaException() {
        when(awsLambda.invoke(any(InvokeRequest.class)))
                .thenThrow(new RuntimeException("AWS Lambda service error"));

        RuntimeException exception = assertThrows(RuntimeException.class, 
                () -> lambdaService.invokeLambdaFunction());
        
        assertTrue(exception.getMessage().contains("Failed to invoke Lambda function"));
        assertTrue(exception.getMessage().contains("AWS Lambda service error"));
        verify(awsLambda).invoke(any(InvokeRequest.class));
    }

    @Test
    @DisplayName("Test Lambda invocation with JSON parsing exception")
    void invokeLambdaFunction_JsonParsingException() throws Exception {
        String responseJson = "{\"statusCode\":200}";
        ByteBuffer payloadBuffer = ByteBuffer.wrap(responseJson.getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);
        when(objectMapper.readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenThrow(new JsonProcessingException("Invalid JSON") {});

        RuntimeException exception = assertThrows(RuntimeException.class, 
                () -> lambdaService.invokeLambdaFunction());
        
        assertTrue(exception.getMessage().contains("Failed to invoke Lambda function"));
        verify(awsLambda).invoke(any(InvokeRequest.class));
        verify(objectMapper).readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class));
    }

    @Test
    @DisplayName("Test Lambda invocation with body parsing exception")
    void invokeLambdaFunction_BodyParsingException() throws Exception {
        Map<String, Object> lambdaResponse = new HashMap<>();
        lambdaResponse.put("statusCode", 200);
        lambdaResponse.put("body", "invalid-json");
        
        String responseJson = "{\"statusCode\":200,\"body\":\"invalid-json\"}";
        ByteBuffer payloadBuffer = ByteBuffer.wrap(responseJson.getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);
        when(objectMapper.readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(lambdaResponse);
        when(objectMapper.readValue(eq("invalid-json"), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenThrow(new JsonProcessingException("Invalid JSON in body") {});

        RuntimeException exception = assertThrows(RuntimeException.class, 
                () -> lambdaService.invokeLambdaFunction());
        
        assertTrue(exception.getMessage().contains("Failed to invoke Lambda function"));
        verify(awsLambda).invoke(any(InvokeRequest.class));
        verify(objectMapper, times(2)).readValue(anyString(), any(com.fasterxml.jackson.core.type.TypeReference.class));
    }

    @Test
    @DisplayName("Test Lambda invocation with empty response")
    void invokeLambdaFunction_EmptyResponse() throws Exception {
        Map<String, Object> emptyResponse = new HashMap<>();
        
        String responseJson = "{}";
        ByteBuffer payloadBuffer = ByteBuffer.wrap(responseJson.getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);
        when(objectMapper.readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(emptyResponse);

        Map<String, Object> result = lambdaService.invokeLambdaFunction();

        assertNotNull(result);
        assertTrue(result.isEmpty());
        verify(awsLambda).invoke(any(InvokeRequest.class));
    }

    @Test
    @DisplayName("Test Lambda invocation with null payload")
    void invokeLambdaFunction_NullPayload() {
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(null);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);

        RuntimeException exception = assertThrows(RuntimeException.class, 
                () -> lambdaService.invokeLambdaFunction());
        
        assertTrue(exception.getMessage().contains("Failed to invoke Lambda function"));
        verify(awsLambda).invoke(any(InvokeRequest.class));
    }

    @Test
    @DisplayName("Test Lambda invocation with complex nested response")
    void invokeLambdaFunction_ComplexNestedResponse() throws Exception {
        Map<String, Object> nestedBody = new HashMap<>();
        nestedBody.put("data", Map.of("id", "123", "value", 456));
        nestedBody.put("metadata", Map.of("timestamp", "2024-01-01", "region", "us-east-1"));
        
        Map<String, Object> lambdaResponse = new HashMap<>();
        lambdaResponse.put("statusCode", 200);
        lambdaResponse.put("headers", Map.of("Content-Type", "application/json"));
        lambdaResponse.put("body", "{\"data\":{\"id\":\"123\",\"value\":456},\"metadata\":{\"timestamp\":\"2024-01-01\",\"region\":\"us-east-1\"}}");
        
        String responseJson = "{\"statusCode\":200,\"headers\":{\"Content-Type\":\"application/json\"},\"body\":\"{\\\"data\\\":{\\\"id\\\":\\\"123\\\",\\\"value\\\":456},\\\"metadata\\\":{\\\"timestamp\\\":\\\"2024-01-01\\\",\\\"region\\\":\\\"us-east-1\\\"}}\"}";
        ByteBuffer payloadBuffer = ByteBuffer.wrap(responseJson.getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);
        when(objectMapper.readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(lambdaResponse);
        when(objectMapper.readValue(eq("{\"data\":{\"id\":\"123\",\"value\":456},\"metadata\":{\"timestamp\":\"2024-01-01\",\"region\":\"us-east-1\"}}"), 
                any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(nestedBody);

        Map<String, Object> result = lambdaService.invokeLambdaFunction();

        assertNotNull(result);
        assertEquals(200, result.get("statusCode"));
        assertNotNull(result.get("headers"));
        assertNotNull(result.get("body"));
        assertTrue(result.get("body") instanceof Map);
        
        verify(awsLambda).invoke(any(InvokeRequest.class));
        verify(objectMapper, times(2)).readValue(anyString(), any(com.fasterxml.jackson.core.type.TypeReference.class));
    }

    @Test
    @DisplayName("Test Lambda function name configuration")
    void invokeLambdaFunction_VerifyFunctionName() throws Exception {
        String customFunctionName = "custom-lambda-function";
        ReflectionTestUtils.setField(lambdaService, "lambdaFunctionName", customFunctionName);
        
        Map<String, Object> lambdaResponse = new HashMap<>();
        lambdaResponse.put("statusCode", 200);
        
        String responseJson = "{\"statusCode\":200}";
        ByteBuffer payloadBuffer = ByteBuffer.wrap(responseJson.getBytes(StandardCharsets.UTF_8));
        
        InvokeResult invokeResult = new InvokeResult();
        invokeResult.setStatusCode(200);
        invokeResult.setPayload(payloadBuffer);
        
        when(awsLambda.invoke(any(InvokeRequest.class))).thenReturn(invokeResult);
        when(objectMapper.readValue(eq(responseJson), any(com.fasterxml.jackson.core.type.TypeReference.class)))
                .thenReturn(lambdaResponse);

        lambdaService.invokeLambdaFunction();

        verify(awsLambda).invoke(any(InvokeRequest.class));
    }
}