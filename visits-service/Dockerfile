ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY visits-service/pom.xml ./visits-service/

COPY visits-service/src ./visits-service/src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -f visits-service/pom.xml package -DskipTests

FROM gcr.io/distroless/java17-debian13@sha256:e2844953049b92ed317e208fc50634f46e8fe51a0cef9522863ad18e393ef65a
WORKDIR /app

ENV SPRING_PROFILES_ACTIVE=docker,mysql

COPY --from=builder --chown=nonroot:nonroot \
  /app/visits-service/target/app.jar app.jar

USER nonroot

EXPOSE 8082

ENTRYPOINT ["java", "-jar", "/app/app.jar"]