# Builds the demo-data seeder. data.json is embedded into the binary at build
# time; the user keys and CA cert are mounted at run time (see docker-compose).
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /seed .

FROM alpine:3.20
COPY --from=build /seed /usr/local/bin/seed
ENTRYPOINT ["/usr/local/bin/seed"]
