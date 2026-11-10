FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server .

FROM alpine:3.20

# Imagen para Azure Container Apps (publicada en GHCR) y para docker run local.
# En AWS Lambda la app no usa esta imagen: va como zip con el binario "bootstrap".

RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -D appuser

WORKDIR /app
COPY --from=builder /app/server .

USER appuser
EXPOSE 8080

CMD ["./server"]
