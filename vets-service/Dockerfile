ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY vets-service/pom.xml ./vets-service/

COPY vets-service/src ./vets-service/src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -f vets-service/pom.xml package -DskipTests

FROM gcr.io/distroless/java17-debian13@sha256:29c93433e7b5fb06e8e23962dd635a6656670081b91a34dfba5f6d864f9cbfa0
WORKDIR /app

ENV SPRING_PROFILES_ACTIVE=docker,mysql

COPY --from=builder --chown=nonroot:nonroot \
  /app/vets-service/target/app.jar app.jar

USER nonroot

EXPOSE 8083

ENTRYPOINT ["java", "-jar", "/app/app.jar"]