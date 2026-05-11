# syntax=docker/dockerfile:1
# Build stage - Maven DHI for building Pet Clinic


# All these steps are from the official Hardened Docker Image usage page
FROM dhi.io/maven:3-jdk25-debian13-dev AS build
    #dhi.io/maven:3-jdk17-debian13-dev

WORKDIR /app

# Copy Maven files for dependency caching
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# Download dependencies (cached layer)
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the Pet Clinic application
RUN mvn clean package -DskipTests -B

# Runtime stage - JRE for running Pet Clinic
FROM eclipse-temurin:17-jre-alpine-3.23 AS runtime

# Create non-root user for security
RUN addgroup -g 1001 petclinic && \
    adduser -u 1001 -G petclinic -s /bin/sh -D petclinic

WORKDIR /app

COPY --from=build /app/target/spring-petclinic-*.jar app.jar
RUN chown petclinic:petclinic app.jar
USER petclinic

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
