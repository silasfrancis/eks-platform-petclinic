ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY discovery-server/pom.xml ./discovery-server/

COPY discovery-server/src ./discovery-server/src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -f discovery-server/pom.xml package -DskipTests

FROM gcr.io/distroless/java17-debian13@sha256:e2844953049b92ed317e208fc50634f46e8fe51a0cef9522863ad18e393ef65a
WORKDIR /app

COPY --from=builder --chown=nonroot:nonroot \
  /app/discovery-server/target/app.jar app.jar

USER nonroot

EXPOSE 8761

ENTRYPOINT ["java", "-jar", "/app/app.jar"]