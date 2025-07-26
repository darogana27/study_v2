# Terraform Product Generator Makefile

# Default values
name ?= 
region ?= ap-northeast-1

# Directories
TEMPLATE_DIR = ./templates/product-template
PRODUCT_DIR = ./product

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help create-product list-products clean-product

help: ## Show this help message
	@echo "Terraform Product Generator"
	@echo ""
	@echo "Usage:"
	@echo "  make create-product name=<name> [region=<region>]"
	@echo ""
	@echo "Examples:"
	@echo "  make create-product name=my-app"
	@echo "  make create-product name=user-service region=us-east-1"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

create-product: ## Create a new product from template
	@if [ -z "$(name)" ]; then \
		echo "$(RED)Error: name is required$(NC)"; \
		echo "Usage: make create-product name=<name> [region=<region>]"; \
		exit 1; \
	fi
	@if [ -d "$(PRODUCT_DIR)/$(name)" ]; then \
		echo "$(YELLOW)Warning: Product '$(name)' already exists$(NC)"; \
		read -p "Overwrite? (y/N): " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "Operation cancelled"; \
			exit 0; \
		fi; \
		rm -rf "$(PRODUCT_DIR)/$(name)"; \
	fi
	@echo "$(GREEN)Creating product '$(name)' in region '$(region)'...$(NC)"
	@mkdir -p "$(PRODUCT_DIR)/$(name)"
	@cp -r $(TEMPLATE_DIR)/* "$(PRODUCT_DIR)/$(name)/"
	@find "$(PRODUCT_DIR)/$(name)" -type f -exec sed -i 's/{{name}}/$(name)/g' {} \;
	@find "$(PRODUCT_DIR)/$(name)" -type f -exec sed -i 's/{{region}}/$(region)/g' {} \;
	@if [ -f "$(PRODUCT_DIR)/$(name)/terraform.tfvars.template" ]; then \
		mv "$(PRODUCT_DIR)/$(name)/terraform.tfvars.template" "$(PRODUCT_DIR)/$(name)/terraform.tfvars"; \
	fi
	@echo "# Terraform files" > "$(PRODUCT_DIR)/$(name)/.gitignore"
	@echo "*.tfstate" >> "$(PRODUCT_DIR)/$(name)/.gitignore"
	@echo "*.tfstate.*" >> "$(PRODUCT_DIR)/$(name)/.gitignore"
	@echo ".terraform/" >> "$(PRODUCT_DIR)/$(name)/.gitignore"
	@echo ".terraform.lock.hcl" >> "$(PRODUCT_DIR)/$(name)/.gitignore"
	@echo "$(GREEN)✅ Product '$(name)' created successfully!$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. cd $(PRODUCT_DIR)/$(name)"
	@echo "  2. Edit terraform.tfvars to configure your resources"
	@echo "  3. terraform init && terraform plan"

list-products: ## List all existing products
	@echo "$(GREEN)Existing products:$(NC)"
	@if [ -d "$(PRODUCT_DIR)" ]; then \
		ls -1 $(PRODUCT_DIR) 2>/dev/null || echo "No products found"; \
	else \
		echo "No product directory found"; \
	fi

clean-product: ## Remove a product directory
	@if [ -z "$(name)" ]; then \
		echo "$(RED)Error: name is required$(NC)"; \
		echo "Usage: make clean-product name=<name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(PRODUCT_DIR)/$(name)" ]; then \
		echo "$(RED)Error: Product '$(name)' does not exist$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)This will delete the product directory: $(PRODUCT_DIR)/$(name)$(NC)"
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		rm -rf "$(PRODUCT_DIR)/$(name)"; \
		echo "$(GREEN)Product '$(name)' removed$(NC)"; \
	else \
		echo "Operation cancelled"; \
	fi