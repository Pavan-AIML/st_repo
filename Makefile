SUBSCRIPTION_ID := 3e4b93a6-966a-4d17-af62-540ffd96a13c
REGION          := germanywestcentral

SHARED_DIR  := infra/envs/shared
STAGING_DIR := infra/envs/staging
PROD_DIR    := infra/envs/prod

.PHONY: help bootstrap init init-shared init-staging init-prod \
        plan plan-shared plan-staging plan-prod \
        apply-shared apply-staging apply-prod up \
        down down-shared down-staging down-prod \
        kubeconfig bootstrap-gitops

help:
	@echo ""
	@echo "ShopLite platform — one-command targets"
	@echo ""
	@echo "  bootstrap          Create tfstate storage account (run once per subscription)"
	@echo ""
	@echo "  init               terraform init in all three envs (shared, staging, prod)"
	@echo "  plan               terraform plan in all three envs"
	@echo ""
	@echo "  apply-shared       Apply shared cluster + Argo CD"
	@echo "  apply-staging      Apply staging env (DB + identity)"
	@echo "  apply-prod         Apply prod env (DB + identity)"
	@echo "  up                 Apply shared, then staging, then prod"
	@echo ""
	@echo "  down               Destroy all three (prod → staging → shared)"
	@echo ""
	@echo "  kubeconfig         Merge shared AKS creds into ~/.kube/config"
	@echo "  bootstrap-gitops   kubectl apply the three Argo CD root apps"
	@echo ""

# ---------------------------------------------------------------------------
# Bootstrap — once per subscription.
# ---------------------------------------------------------------------------
bootstrap:
	@bash scripts/bootstrap-tfstate.sh $(SUBSCRIPTION_ID) $(REGION)

# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------
init: init-shared init-staging init-prod

init-shared:
	cd $(SHARED_DIR) && terraform init

init-staging:
	cd $(STAGING_DIR) && terraform init

init-prod:
	cd $(PROD_DIR) && terraform init

# ---------------------------------------------------------------------------
# plan — read-only
# ---------------------------------------------------------------------------
plan: plan-shared plan-staging plan-prod

plan-shared:
	cd $(SHARED_DIR) && terraform plan

plan-staging:
	cd $(STAGING_DIR) && terraform plan

plan-prod:
	cd $(PROD_DIR) && terraform plan

# ---------------------------------------------------------------------------
# apply — writes to Azure. Order matters: shared → staging → prod.
# ---------------------------------------------------------------------------
apply-shared:
	cd $(SHARED_DIR) && terraform apply

apply-staging:
	cd $(STAGING_DIR) && terraform apply

apply-prod:
	cd $(PROD_DIR) && terraform apply

up: apply-shared apply-staging apply-prod

# ---------------------------------------------------------------------------
# destroy — reverse order. Prod first so dependent namespaces are gone.
# ---------------------------------------------------------------------------
down: down-prod down-staging down-shared

down-shared:
	cd $(SHARED_DIR) && terraform destroy

down-staging:
	cd $(STAGING_DIR) && terraform destroy

down-prod:
	cd $(PROD_DIR) && terraform destroy

# ---------------------------------------------------------------------------
# kubeconfig — pull creds for the shared AKS cluster.
# ---------------------------------------------------------------------------
kubeconfig:
	az aks get-credentials \
		--resource-group rg-shoplite-shared \
		--name aks-shoplite \
		--only-show-errors

# ---------------------------------------------------------------------------
# bootstrap-gitops — one-time apply of the three Argo CD root apps.
# Run after `make apply-shared` and `make kubeconfig`.
# ---------------------------------------------------------------------------
bootstrap-gitops:
	kubectl apply -f gitops/apps/root-platform.yaml
	kubectl apply -f gitops/apps/root-staging.yaml
	kubectl apply -f gitops/apps/root-prod.yaml
