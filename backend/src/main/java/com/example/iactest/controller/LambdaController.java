package com.example.iactest.controller;

import com.example.iactest.service.LambdaService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/lambda")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
@Slf4j
public class LambdaController {

    private final LambdaService lambdaService;

    @PostMapping("/test")
    public ResponseEntity<Map<String, Object>> testLambda() {
        log.info("Received request to test Lambda function");
        
        try {
            Map<String, Object> result = lambdaService.invokeLambdaFunction();
            log.info("Lambda function invoked successfully");
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("Error invoking Lambda function", e);
            return ResponseEntity.internalServerError()
                    .body(Map.of(
                            "error", "Failed to invoke Lambda function",
                            "message", e.getMessage()
                    ));
        }
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "healthy"));
    }
}