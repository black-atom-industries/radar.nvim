# Makefile for radar.nvim

.PHONY: test test-watch test-verbose lint typecheck selene check format install-hooks clean validate help

# Default target
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests (using mini.test)"
	@echo "  test-watch    - Run tests in watch mode (requires entr)"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  check         - Run all linters (lint + typecheck + selene)"
	@echo "  lint          - Check Lua formatting with stylua"
	@echo "  typecheck     - Run type checking (requires lua-language-server)"
	@echo "  selene        - Run selene linter (requires selene)"
	@echo "  format        - Format Lua files with stylua"
	@echo "  install-hooks - Enable pre-commit hooks (git config core.hooksPath .githooks)"
	@echo "  clean         - Clean test artifacts"
	@echo "  validate      - Validate test setup"
	@echo "  help          - Show this help message"

# Run all tests
test:
	@echo "Running radar.nvim tests..."
	nvim --headless -l test/run.lua

# Run tests with verbose output (same as regular for mini.test)
test-verbose:
	@echo "Running tests with verbose output..."
	nvim --headless -l test/run.lua

# Watch for file changes and run tests (requires entr: brew install entr)
test-watch:
	@if command -v entr >/dev/null 2>&1; then \
		echo "Watching for changes... (Press Ctrl+C to stop)"; \
		find lua/ test/ -name "*.lua" | entr -c make test; \
	else \
		echo "Error: 'entr' is not installed."; \
		echo ""; \
		echo "To enable watch mode, install entr:"; \
		echo "  brew install entr        # macOS"; \
		echo "  apt install entr         # Ubuntu/Debian"; \
		echo "  pacman -S entr           # Arch"; \
		echo ""; \
		echo "Alternative: Run tests manually after changes:"; \
		echo "  make test"; \
		exit 1; \
	fi

# Check Lua formatting with stylua (requires stylua: brew install stylua)
lint:
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Checking Lua formatting..."; \
		stylua --check lua/ test/; \
	else \
		echo "Error: 'stylua' is not installed. Install with: brew install stylua"; \
		exit 1; \
	fi

# Type check Lua files (requires lua-language-server)
typecheck:
	@if command -v lua-language-server >/dev/null 2>&1; then \
		echo "Type checking Lua files..."; \
		lua-language-server --check . --checklevel=Warning; \
	else \
		echo "Error: 'lua-language-server' is not installed."; \
		echo ""; \
		echo "To enable type checking, install lua-language-server:"; \
		echo "  brew install lua-language-server  # macOS"; \
		echo "  See: https://luals.github.io/#install"; \
		exit 1; \
	fi

# Lint with selene (requires selene)
selene:
	@if command -v selene >/dev/null 2>&1; then \
		echo "Running selene linter..."; \
		selene --allow-warnings lua/; \
	else \
		echo "Error: 'selene' is not installed."; \
		echo ""; \
		echo "To enable selene linting, install selene:"; \
		echo "  cargo install selene          # Rust/Cargo"; \
		echo "  yay -S selene                 # Arch Linux"; \
		echo "  See: https://github.com/Kampfkarren/selene"; \
		exit 1; \
	fi

# Format Lua files with stylua
format:
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Formatting Lua files..."; \
		stylua lua/ test/; \
	else \
		echo "Error: 'stylua' is not installed. Install with: brew install stylua"; \
		exit 1; \
	fi

# Run all linters (read-only, does not modify files)
check:
	@echo "Running all checks..."
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory typecheck
	@$(MAKE) --no-print-directory selene
	@echo ""
	@echo "✓ All checks passed!"

# Enable pre-commit hooks for collaborators
install-hooks:
	git config core.hooksPath .githooks
	@echo "Hooks installed. Pre-commit checks run on every commit."

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@find test/ -name "*.tmp" -delete 2>/dev/null || true
	@find test/ -name ".DS_Store" -delete 2>/dev/null || true

# Quick test to validate setup
validate:
	@echo "Validating test setup..."
	@if nvim --version >/dev/null 2>&1; then \
		echo "✓ Neovim is available"; \
	else \
		echo "✗ Neovim is not available"; \
		exit 1; \
	fi
	@if [ -f "test/run.lua" ]; then \
		echo "✓ Test configuration exists"; \
	else \
		echo "✗ Test configuration missing"; \
		exit 1; \
	fi
	@echo "Test setup is ready!"
