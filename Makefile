# Xcode Project Makefile
# Example of building Xcode projects with proper settings and clean output

.DEFAULT_GOAL := help

# Configuration
PROJECT_PATH = DynamicalSystems/DynamicalSystems.xcodeproj
SCHEME = gamer
CONFIG = Debug
DERIVED_DATA = build
DESTINATION = 'platform:macOS,arch:arm64'

# ANSI color codes for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo "Xcode Project Commands:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the project
	@echo "$(YELLOW)Building Xcode project...$(NC)"
	@echo "$(YELLOW)Resolving package dependencies...$(NC)"
	@xcodebuild -resolvePackageDependencies \
		-project $(PROJECT_PATH) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) >/dev/null 2>&1 || true
	@xcodebuild build \
		-project $(PROJECT_PATH) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination $(DESTINATION) \
		-skipMacroValidation \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO 2>&1 | ./bin/xcodebuild-filter --errors-only
	@echo "$(GREEN)✓ Build complete$(NC)"

.PHONY: test
test: ## Run tests
	@echo "$(YELLOW)Running tests...$(NC)"
	@xcodebuild test \
		-project $(PROJECT_PATH) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-skipMacroValidation \
		-destination $(DESTINATION) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO 2>&1 | ./bin/xcodebuild-filter --errors-only
	@echo "$(GREEN)✓ Tests complete$(NC)"

.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(DERIVED_DATA)
	@echo "$(GREEN)✓ Clean complete$(NC)"

# Key build flags explained:
# -skipMacroValidation: Avoids macro approval prompts during CI/automation
# CODE_SIGN_IDENTITY="": Disables code signing for local builds
# CODE_SIGNING_REQUIRED=NO: Allows building without certificates
# CODE_SIGNING_ALLOWED=NO: Completely disables signing (for testing)
# -derivedDataPath: Uses local directory instead of system DerivedData
# xcodebuild-filter: Filters verbose xcodebuild output to show only errors
