.DEFAULT_GOAL:=help

OCI_REGISTRY := projects.registry.vmware.com/tce

help: ## display help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


push-extensions: ## build and push extension templates
	imgpkg push --image $(OCI_REGISTRY)/velero-extension-templates -f extensions/gatekeeper/config/


redeploy-gatekeeper: ## delete and redeploy the velero extension
	kubectl -n tanzu-extensions delete app gatekeeper
	kubectl apply -f extensions/velero/extension.yaml
