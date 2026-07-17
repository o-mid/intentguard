FROM golang:1.26-alpine AS build
WORKDIR /src
COPY packages/plan-schema ./packages/plan-schema
COPY services/api ./services/api
WORKDIR /src/services/api
RUN CGO_ENABLED=0 go build -o /out/api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
COPY services/api/migrations /migrations
COPY contracts/deployments /deployments
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/api"]
