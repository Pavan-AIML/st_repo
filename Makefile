SUBSCRIPTION_ID := 3e4b93a6-966a-4d17-af62-540ffd96a13c
REGION         := germanywestcentral

.PHONY: bootstrap up down plan apply destroy help

help:
	@echo "make bootstrap  - create Terraform remote state backend (run once)"
	@echo "make up         - provision all infrastructure + deploy apps"
	@echo "make down       - destroy all infrastructure"
	@echo "make plan       - terraform plan (no changes)"

bootstrap:
	@bash scripts/bootstrap-tfstate.sh $(SUBSCRIPTION_ID) $(REGION)

up:
	@echo "TODO: terraform init + apply staging, then prod"

down:
	@echo "TODO: terraform destroy staging + prod"

plan:
	@echo "TODO: terraform plan staging + prod"
