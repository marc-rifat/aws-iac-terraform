package com.example.iactest.service;

import com.amazonaws.services.lambda.AWSLambda;
import com.amazonaws.services.lambda.model.InvokeRequest;
import com.amazonaws.services.lambda.model.InvokeResult;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class LambdaService {

    private final AWSLambda awsLambda;
    private final ObjectMapper objectMapper;

    @Value("${aws.lambda.function-name:iac-test-lambda}")
    private String lambdaFunctionName;

    public Map<String, Object> invokeLambdaFunction() {
        try {
            log.info("Invoking Lambda function: {}", lambdaFunctionName);

            InvokeRequest invokeRequest = new InvokeRequest()
                    .withFunctionName(lambdaFunctionName)
                    .withPayload("{}");

            InvokeResult invokeResult = awsLambda.invoke(invokeRequest);

            if (invokeResult.getStatusCode() == 200) {
                String payload = new String(invokeResult.getPayload().array(), StandardCharsets.UTF_8);
                log.info("Lambda function executed successfully. Response: {}", payload);

                Map<String, Object> response = objectMapper.readValue(payload, new TypeReference<Map<String, Object>>() {});
                
                if (response.containsKey("body")) {
                    String bodyString = (String) response.get("body");
                    Map<String, Object> body = objectMapper.readValue(bodyString, new TypeReference<Map<String, Object>>() {});
                    response.put("body", body);
                }
                
                return response;
            } else {
                log.error("Lambda function execution failed with status code: {}", invokeResult.getStatusCode());
                throw new RuntimeException("Lambda function execution failed with status code: " + invokeResult.getStatusCode());
            }

        } catch (Exception e) {
            log.error("Error invoking Lambda function", e);
            throw new RuntimeException("Failed to invoke Lambda function: " + e.getMessage(), e);
        }
    }
}