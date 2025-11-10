.PHONY: help build test clean serve security-check deploy

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the Hugo site
	@echo "Building Hugo site..."
	hugo --gc --minify

build-drafts: ## Build the Hugo site including drafts
	@echo "Building Hugo site with drafts..."
	hugo --buildDrafts --gc --minify

serve: ## Start Hugo development server
	@echo "Starting Hugo development server..."
	hugo server --buildDrafts --bind 0.0.0.0

test: build ## Run HTML tests (links, validation)
	@echo "Running htmltest..."
	htmltest

security-check: ## Run security checks
	@echo "Checking for secrets..."
	@! grep -r "password\|secret\|api.key\|token" --include="*.html" --include="*.md" --include="*.toml" --include="*.js" layouts/ content/ hugo.toml 2>/dev/null || (echo "⚠️  Potential secrets found!" && exit 1)
	@echo "✓ No obvious secrets found"
	@echo ""
	@echo "Checking for insecure HTTP links..."
	@! grep -r "http://" --include="*.html" --include="*.md" layouts/ content/ 2>/dev/null | grep -v "localhost\|127.0.0.1" || (echo "⚠️  Insecure HTTP links found!" && exit 1)
	@echo "✓ No insecure HTTP links found"
	@echo ""
	@echo "Security check passed! ✓"

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	rm -rf public/ resources/ tmp/

deploy: test security-check ## Run tests and deploy (for CI/CD)
	@echo "All checks passed! Ready to deploy."
