ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY spring-petclinic-genai-service/pom.xml ./spring-petclinic-genai-service/

RUN mvn -B -q dependency:go-offline

COPY spring-petclinic-genai-service/src ./spring-petclinic-genai-service/src

RUN mvn -B -q -f spring-petclinic-genai-service/pom.xml package -DskipTests

FROM gcr.io/distroless/java17-debian13@sha256:e2844953049b92ed317e208fc50634f46e8fe51a0cef9522863ad18e393ef65a
WORKDIR /app

COPY --from=builder --chown=nonroot:nonroot \
  /app/spring-petclinic-genai-service/target/spring-petclinic-genai-service-[0-9]*.jar app.jar

USER nonroot

EXPOSE 8084

ENTRYPOINT ["java", "-jar", "/app/app.jar"]