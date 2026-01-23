.PHONY: help validate validate-yaml validate-kustomize validate-schemas security-scan build-all clean

KUBERNETES_VERSION ?= 1.29.0
ENVS := dev staging prod
COMPONENTS := operator instance

# Use kustomize if available, fallback to oc kustomize
KUSTOMIZE := $(shell which kustomize 2>/dev/null || echo "oc kustomize")

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

validate: validate-yaml validate-kustomize validate-schemas ## Run all validations

validate-yaml: ## Validate YAML syntax
	@echo "==> Validating YAML syntax..."
	@yamllint -c .yamllint . || true
	@echo "==> YAML validation complete"

validate-kustomize: ## Validate all Kustomize builds
	@echo "==> Validating Kustomize builds (using $(KUSTOMIZE))..."
	@for env in $(ENVS); do \
		for component in $(COMPONENTS); do \
			echo "Building overlays/$$env/$$component"; \
			$(KUSTOMIZE) overlays/$$env/$$component > /dev/null || exit 1; \
		done; \
	done
	@echo "Building argocd/"
	@$(KUSTOMIZE) argocd/ > /dev/null || exit 1
	@echo "Building namespaces/"
	@$(KUSTOMIZE) namespaces/ > /dev/null || exit 1
	@echo "==> All Kustomize builds successful"

validate-schemas: ## Validate against Kubernetes schemas
	@echo "==> Validating Kubernetes schemas..."
	@for env in $(ENVS); do \
		for component in $(COMPONENTS); do \
			echo "Validating overlays/$$env/$$component"; \
			$(KUSTOMIZE) overlays/$$env/$$component | kubeconform -strict -ignore-missing-schemas -kubernetes-version $(KUBERNETES_VERSION) -summary || exit 1; \
		done; \
	done
	@echo "==> Schema validation complete"

security-scan: ## Run Trivy security scan on production manifests
	@echo "==> Running security scan on production manifests..."
	@$(KUSTOMIZE) overlays/prod/operator | trivy config - --severity HIGH,CRITICAL
	@$(KUSTOMIZE) overlays/prod/instance | trivy config - --severity HIGH,CRITICAL
	@echo "==> Security scan complete"

build-all: ## Build and output all manifests to build/ directory
	@mkdir -p build
	@for env in $(ENVS); do \
		for component in $(COMPONENTS); do \
			echo "Building overlays/$$env/$$component -> build/$$env-$$component.yaml"; \
			$(KUSTOMIZE) overlays/$$env/$$component > build/$$env-$$component.yaml; \
		done; \
	done
	@echo "Building argocd/ -> build/argocd.yaml"
	@$(KUSTOMIZE) argocd/ > build/argocd.yaml
	@echo "Building namespaces/ -> build/namespaces.yaml"
	@$(KUSTOMIZE) namespaces/ > build/namespaces.yaml
	@echo "==> All manifests built in build/"

build-env: ## Build specific environment (usage: make build-env ENV=prod)
ifndef ENV
	$(error ENV is not set. Usage: make build-env ENV=dev|staging|prod)
endif
	@mkdir -p build
	@echo "Building overlays/$(ENV)/operator -> build/$(ENV)-operator.yaml"
	@$(KUSTOMIZE) overlays/$(ENV)/operator > build/$(ENV)-operator.yaml
	@echo "Building overlays/$(ENV)/instance -> build/$(ENV)-instance.yaml"
	@$(KUSTOMIZE) overlays/$(ENV)/instance > build/$(ENV)-instance.yaml
	@echo "==> $(ENV) manifests built"

diff-prod: ## Show diff between current and deployed production
	@echo "==> Comparing local prod manifests with cluster..."
	@echo "Operator diff:"
	@$(KUSTOMIZE) overlays/prod/operator | kubectl diff -f - || true
	@echo ""
	@echo "Instance diff:"
	@$(KUSTOMIZE) overlays/prod/instance | kubectl diff -f - || true

clean: ## Clean build artifacts
	@rm -rf build/
	@echo "==> Cleaned build directory"

install-tools: ## Install required tools (macOS/Linux)
	@echo "==> Installing validation tools..."
	@which kustomize > /dev/null || (echo "Installing kustomize..." && curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && sudo mv kustomize /usr/local/bin/)
	@which kubeconform > /dev/null || (echo "Installing kubeconform..." && go install github.com/yannh/kubeconform/cmd/kubeconform@latest)
	@which yamllint > /dev/null || (echo "Installing yamllint..." && pip install yamllint)
	@which trivy > /dev/null || (echo "Installing trivy..." && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin)
	@echo "==> Tools installed"
