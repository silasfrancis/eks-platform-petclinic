ARG BUILDPLATFORM=linux/amd64
ARG TARGETPLATFORM

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY discovery-server/pom.xml ./discovery-server/

COPY discovery-server/src ./discovery-server/src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -f discovery-server/pom.xml package -DskipTests

FROM --platform=$TARGETPLATFORM gcr.io/distroless/java17-debian13@sha256:29c93433e7b5fb06e8e23962dd635a6656670081b91a34dfba5f6d864f9cbfa0
WORKDIR /app

COPY --from=builder --chown=nonroot:nonroot \
  /app/discovery-server/target/app.jar app.jar

USER nonroot

EXPOSE 8761

ENTRYPOINT ["java", "-jar", "/app/app.jar"]