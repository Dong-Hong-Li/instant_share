.PHONY: run build test tidy web web-build

run: web-build
	go run ./cmd/server

build: web-build
	go build -o bin/instant-share-server ./cmd/server

test:
	go test ./...

tidy:
	go mod tidy

web:
	cd web && npm install && npm run dev

web-build:
	./build_web.sh
