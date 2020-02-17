GO=GOOS=linux GOARCH=amd64 GO111MODULE=on go
BINARY=bin/estore-infra
MAIN_GO=cmd/main.go

mod-init:
	@echo "==> Mod Init..."
	${GO} mod init

all: clean deps fmt check test

clean:
	@echo "==> Cleaning..."
	rm -f report.json coverage.out

deps:
	@echo "==> Getting Dependencies..."
	${GO} mod tidy
	${GO} mod download

fmt:
	@echo "==> Code Formatting..."
	${GO} fmt ./...

check: fmt
	@echo "==> Code Check..."
	golangci-lint run --fast --tests

test: clean
	@echo "==> Testing..."
	CGO_ENABLED=0 ${GO} test -v -covermode=atomic -count=1 ./... -coverprofile coverage.out
	CGO_ENABLED=1 ${GO} test -race -covermode=atomic -count=1 ./... -json > report.json
	${GO} tool cover -func=coverage.out

build: test
	@echo "==> Building..."
	CGO_ENABLED=0 ${GO} build -o ${BINARY} ${MAIN_GO}
