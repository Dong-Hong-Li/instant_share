.PHONY: run build test tidy

run:
	go run ./cmd/server

build:
	go build -o bin/instant-share-server ./cmd/server

test:
	go test ./...

tidy:
	go mod tidy
