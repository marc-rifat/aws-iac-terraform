FROM openjdk:17-jdk-slim

WORKDIR /app

# Accept JAR file path as build argument with fallback for both Maven and Gradle
ARG JAR_FILE=target/*.jar

# Copy the built JAR file - support both Maven (target/) and Gradle (build/libs/) locations
COPY ${JAR_FILE} app.jar

# Expose the port the app runs on
EXPOSE 8080

# Set JVM options for container environment
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]