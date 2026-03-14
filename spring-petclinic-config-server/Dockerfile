ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /app

COPY pom.xml .

COPY spring-petclinic-config-server/pom.xml ./spring-petclinic-config-server/

COPY spring-petclinic-config-server/microservices-config ./spring-petclinic-config-server/config

COPY spring-petclinic-config-server/src ./spring-petclinic-config-server/src

RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q -f spring-petclinic-config-server/pom.xml package -DskipTests

FROM gcr.io/distroless/java17-debian13@sha256:e2844953049b92ed317e208fc50634f46e8fe51a0cef9522863ad18e393ef65a
WORKDIR /app

ENV SPRING_PROFILES_ACTIVE=native
ENV CONFIG_DIR=/config

COPY --from=builder --chown=nonroot:nonroot \
  /app/spring-petclinic-config-server/target/spring-petclinic-config-server-[0-9]*.jar app.jar

COPY --from=builder --chown=nonroot:nonroot \
/app/spring-petclinic-config-server/config /config

USER nonroot

EXPOSE 8888

ENTRYPOINT ["java", "-jar", "/app/app.jar"]