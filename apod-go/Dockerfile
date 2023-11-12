FROM golang:1.21-alpine as build

ENV CGO_ENABLED 0
ENV GOOS linux
ENV GOARCH amd64

WORKDIR /build

COPY . .

RUN go build -mod=readonly -o /app

FROM scratch as prod

COPY --from=build /app /app

CMD [ "/app" ]
