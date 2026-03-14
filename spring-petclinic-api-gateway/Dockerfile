ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY spring-petclinic-api-gateway/pom.xml ./spring-petclinic-api-gateway/

COPY spring-petclinic-api-gateway/src ./spring-petclinic-api-gateway/src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -f spring-petclinic-api-gateway/pom.xml package -DskipTests

FROM gcr.io/distroless/java17-debian13@sha256:e2844953049b92ed317e208fc50634f46e8fe51a0cef9522863ad18e393ef65a
WORKDIR /app

COPY --from=builder --chown=nonroot:nonroot \
  /app/spring-petclinic-api-gateway/target/app.jar app.jar

USER nonroot

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]