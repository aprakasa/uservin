# Makefile for uservin
# Ubuntu Server Initialization Tool

.PHONY: all build clean test lint help

# Default target
all: build

# Build the bundled single-file script
build:
	@echo "Building uservin.sh..."
	@bash build.sh

# Clean generated files
clean:
	@echo "Removing generated uservin.sh..."
	@rm -f uservin.sh
	@echo "Done. Run 'make build' to regenerate."

# Run all tests
test:
	@echo "Running tests..."
	@bash tests/runner.sh

# Run linting (if shellcheck is available)
lint:
	@echo "Running shellcheck..."
	@which shellcheck >/dev/null 2>&1 && shellcheck uservin.sh lib/*.sh || echo "shellcheck not installed, skipping"

# Show help
help:
	@echo "uservin build system"
	@echo ""
	@echo "Targets:"
	@echo "  make build    - Bundle into single uservin.sh file"
	@echo "  make clean    - Restore uservin.sh to original state"
	@echo "  make test     - Run test suite"
	@echo "  make lint     - Run shellcheck (if available)"
	@echo "  make help     - Show this help"
	@echo ""
	@echo "Development workflow:"
	@echo "  1. Edit files in lib/ directory"
	@echo "  2. Run 'make build' to create bundled uservin.sh"
	@echo "  3. Run 'make test' to verify"
	@echo "  4. Commit both lib/ and uservin.sh changes"
