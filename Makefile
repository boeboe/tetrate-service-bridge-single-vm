.PHONY: init plan deploy destroy clean reset validate update

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

# Variables
# TF_CMD  := terraform -chdir=infra/gcp
# TF_CMD  := terraform -chdir=infra/azure
TF_CMD  := terraform -chdir=infra/aws
TF_PLAN := plan.tfout

# Default target
all: init plan apply

init: ## Initialize Terraform
	@$(TF_CMD) init

fmt: ## Format Terraform code
	@$(TF_CMD) fmt

validate: ## Validate Terraform code
	@$(TF_CMD) validate

plan: fmt validate ## Generate and show an execution plan
	@$(TF_CMD) plan -out=$(TF_PLAN)

apply: ## Build or change infrastructure
	@$(TF_CMD) apply $(TF_PLAN)

destroy: ## Destroy Terraform-managed infrastructure
	@$(TF_CMD) destroy

show: ## Show current state or a resource
	@$(TF_CMD) show

clean: ## Clean up files
	@rm -f $(TF_PLAN)

.PHONY: all init fmt validate plan apply destroy show clean
