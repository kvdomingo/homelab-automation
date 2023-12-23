FROM golang:1.21-alpine

ENV CGO_ENABLED 0
ENV GOOS linux
ENV GOARCH amd64

RUN go install github.com/cosmtrek/air@latest

WORKDIR /app

CMD [ "air", "-c", ".air.toml" ]
