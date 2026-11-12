FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o server .

FROM alpine:3.20

# Imagen para Azure Container Apps (la publica pipelines/build.yml en GHCR) y para docker run local.
# En AWS Lambda no se usa: el pipeline compila el binario "bootstrap" y lo sube en un zip.

RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -D appuser

WORKDIR /app
COPY --from=builder /app/server .

USER appuser
EXPOSE 8080

CMD ["./server"]
