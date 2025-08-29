FROM golang:1.25-alpine AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -a -o player-monitor .

FROM alpine:3.18
RUN apk add --no-cache ca-certificates
COPY --from=builder /build/player-monitor /player-monitor
ENTRYPOINT ["/player-monitor"]
