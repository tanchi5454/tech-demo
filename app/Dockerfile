# Building the binary of the App
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky


FROM alpine:3.17.0 as release

WORKDIR /app
COPY --from=build  /go/src/tasky/tasky .
COPY --from=build  /go/src/tasky/assets ./assets

# --- ここから追記 ---
# 課題要件のファイルを追加する
COPY wizexercise.txt .
# --- ここまで追記 ---

EXPOSE 8080
ENTRYPOINT ["/app/tasky"]


