ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY config-server/pom.xml ./config-server/

COPY config-server/microservices-config ./config-server/config

COPY config-server/src ./config-server/src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -f config-server/pom.xml package -DskipTests

FROM gcr.io/distroless/java17-debian13@sha256:29c93433e7b5fb06e8e23962dd635a6656670081b91a34dfba5f6d864f9cbfa0
WORKDIR /app

ENV SPRING_PROFILES_ACTIVE=native
ENV CONFIG_DIR=/config

COPY --from=builder --chown=nonroot:nonroot \
  /app/config-server/target/app.jar app.jar

COPY --from=builder --chown=nonroot:nonroot \
/app/config-server/config /config

USER nonroot

EXPOSE 8888

ENTRYPOINT ["java", "-jar", "/app/app.jar"]