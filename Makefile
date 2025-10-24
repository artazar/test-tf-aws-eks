# Makefile for managing Terraform and Terragrunt locally

# Detect OS and architecture
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Set OS and ARCH variables
ifeq ($(UNAME_S),Darwin)
	OS := darwin
endif
ifeq ($(UNAME_S),Linux)
	OS := linux
endif

ifeq ($(UNAME_M),x86_64)
	ARCH := amd64
endif
ifeq ($(UNAME_M),aarch64)
	ARCH := arm64
endif
ifeq ($(UNAME_M),arm64)
	ARCH := arm64
endif

# Tool versions (latest as of October 2025)
TERRAFORM_VERSION := 1.13.4
TERRAGRUNT_VERSION := 0.91.4

# Local installation directory
BIN_DIR := $(CURDIR)/.bin

# Tool paths
TERRAFORM := $(BIN_DIR)/terraform
TERRAGRUNT := $(BIN_DIR)/terragrunt

# Terragrunt configuration
export TG_TF_PATH := $(TERRAFORM)

# Default site (can be overridden)
SITE ?= demo

# Modules to exclude from run-all commands (comma-separated)
EXCLUDE ?= bastion

# Capture positional arguments
SITE_ARG := $(word 2,$(MAKECMDGOALS))
MODULE_ARG := $(word 3,$(MAKECMDGOALS))

# Override SITE and MODULE if positional arguments are provided
ifneq ($(SITE_ARG),)
  SITE := $(SITE_ARG)
endif
ifneq ($(MODULE_ARG),)
  MODULE := $(MODULE_ARG)
endif

# Prevent make from treating positional arguments as targets
ifneq ($(filter init plan apply destroy,$(word 1,$(MAKECMDGOALS))),)
  $(eval $(SITE_ARG):;@:)
  ifneq ($(MODULE_ARG),)
    $(eval $(MODULE_ARG):;@:)
  endif
endif
ifneq ($(filter init-module plan-module apply-module destroy-module,$(word 1,$(MAKECMDGOALS))),)
  $(eval $(SITE_ARG):;@:)
  $(eval $(MODULE_ARG):;@:)
endif

.PHONY: help install clean install-terraform install-terragrunt init plan apply destroy init-module plan-module apply-module destroy-module

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: install-terraform install-terragrunt ## Install all tools locally
	@echo "✓ All tools installed successfully!"
	@echo ""
	@echo "Tool versions:"
	@$(TERRAFORM) version
	@echo ""
	@$(TERRAGRUNT) --version

install-terraform: ## Install Terraform locally
	@echo "Installing Terraform $(TERRAFORM_VERSION)..."
	@mkdir -p $(BIN_DIR)
	@if [ -f $(TERRAFORM) ]; then \
		echo "Terraform already installed at $(TERRAFORM)"; \
	else \
		cd $(BIN_DIR) && \
		curl -sLO https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$(OS)_$(ARCH).zip && \
		unzip -q terraform_$(TERRAFORM_VERSION)_$(OS)_$(ARCH).zip && \
		rm -f terraform_$(TERRAFORM_VERSION)_$(OS)_$(ARCH).zip && \
		echo "✓ Terraform installed successfully"; \
	fi

install-terragrunt: ## Install Terragrunt locally
	@echo "Installing Terragrunt $(TERRAGRUNT_VERSION)..."
	@mkdir -p $(BIN_DIR)
	@if [ -f $(TERRAGRUNT) ]; then \
		echo "Terragrunt already installed at $(TERRAGRUNT)"; \
	else \
		curl -sL https://github.com/gruntwork-io/terragrunt/releases/download/v$(TERRAGRUNT_VERSION)/terragrunt_$(OS)_$(ARCH) -o $(BIN_DIR)/terragrunt && \
		chmod +x $(BIN_DIR)/terragrunt && \
		echo "✓ Terragrunt installed successfully"; \
	fi

clean: ## Remove all locally installed tools
	@echo "Cleaning up local tools..."
	@rm -rf $(BIN_DIR)
	@echo "✓ Cleanup complete"

# Terragrunt commands
init: ## Run terragrunt init (usage: make init [demo] [vpc] [ARGS="-upgrade"] [EXCLUDE="bastion"])
	@if [ -n "$(MODULE)" ]; then \
		echo "Running terragrunt init for module $(MODULE) in site: $(SITE)..."; \
		cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) init $(ARGS); \
	else \
		echo "Running terragrunt init --all for site: $(SITE) ..."; \
		cd sites/$(SITE) && $(TERRAGRUNT) run --all --queue-exclude-dir "*/{$(EXCLUDE)}" -- init $(ARGS); \
	fi

plan: ## Run terragrunt plan (usage: make plan [demo] [vpc] [ARGS="-out=plan.tfplan"] [EXCLUDE="bastion"])
	@if [ -n "$(MODULE)" ]; then \
		echo "Running terragrunt plan for module $(MODULE) in site: $(SITE)..."; \
		cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) plan $(ARGS); \
	else \
		echo "Running terragrunt plan --all for site: $(SITE) ..."; \
		cd sites/$(SITE) && $(TERRAGRUNT) run --all --queue-exclude-dir "*/{$(EXCLUDE)}" -- plan $(ARGS); \
	fi

apply: ## Run terragrunt apply (usage: make apply [demo] [vpc] [ARGS="additional-args"] [EXCLUDE="bastion"])
	@if [ -n "$(MODULE)" ]; then \
		echo "Running terragrunt apply for module $(MODULE) in site: $(SITE)..."; \
		cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) apply -auto-approve $(ARGS); \
	else \
		echo "Running terragrunt apply --all for site: $(SITE) ..."; \
		cd sites/$(SITE) && $(TERRAGRUNT) run --all --queue-exclude-dir "*/{$(EXCLUDE)}" -- apply -auto-approve $(ARGS); \
	fi

destroy: ## Run terragrunt destroy (usage: make destroy [demo] [vpc] [ARGS="additional-args"] [EXCLUDE="bastion"])
	@if [ -n "$(MODULE)" ]; then \
		echo "Running terragrunt destroy for module $(MODULE) in site: $(SITE)..."; \
		cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) destroy -auto-approve $(ARGS); \
	else \
		echo "Running terragrunt destroy --all for site: $(SITE) ..."; \
		cd sites/$(SITE) && $(TERRAGRUNT) run --all --queue-exclude-dir "*/{$(EXCLUDE)}" -- destroy -auto-approve $(ARGS); \
	fi

# Per-module commands
init-module: ## Run terragrunt init for a specific module (usage: make init-module demo vpc [ARGS="-upgrade"])
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: MODULE is required. Usage: make init-module <site> <module>"; \
		exit 1; \
	fi
	@echo "Running terragrunt init for module $(MODULE) in site: $(SITE)..."
	@cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) init $(ARGS)

plan-module: ## Run terragrunt plan for a specific module (usage: make plan-module demo vpc [ARGS="-out=plan.tfplan"])
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: MODULE is required. Usage: make plan-module <site> <module>"; \
		exit 1; \
	fi
	@echo "Running terragrunt plan for module $(MODULE) in site: $(SITE)..."
	@cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) plan $(ARGS)

apply-module: ## Run terragrunt apply for a specific module (usage: make apply-module demo vpc [ARGS="additional-args"])
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: MODULE is required. Usage: make apply-module <site> <module>"; \
		exit 1; \
	fi
	@echo "Running terragrunt apply for module $(MODULE) in site: $(SITE)..."
	@cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) apply -auto-approve $(ARGS)

destroy-module: ## Run terragrunt destroy for a specific module (usage: make destroy-module demo vpc [ARGS="additional-args"])
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: MODULE is required. Usage: make destroy-module <site> <module>"; \
		exit 1; \
	fi
	@echo "Running terragrunt destroy for module $(MODULE) in site: $(SITE)..."
	@cd sites/$(SITE)/$(MODULE) && $(TERRAGRUNT) destroy -auto-approve $(ARGS)
