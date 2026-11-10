.PHONY: init plan apply inventory ansible bootstrap flux-verify tenant

TF := terraform -chdir=infra/terraform
FLUX_OWNER ?= MartinGalvanCastro
FLUX_REPO ?= martin-ops
KUBECTL := kubectl --kubeconfig kube/kubeconfig

init:
	$(TF) init

plan:
	$(TF) plan

apply:
	$(TF) apply

# Sin HOST usa la IP pública (bootstrap); después: make inventory HOST=martin-ops-k3s (Tailscale)
inventory:
	@ip="$(HOST)"; [ -n "$$ip" ] || ip=$$($(TF) output -raw public_ip 2>/dev/null); \
	[ -n "$$ip" ] || { echo "Sin IP: corre 'make apply' o pasa HOST=..." >&2; exit 1; }; \
	printf '[k3s]\n%s ansible_user=ubuntu\n' "$$ip" > infra/ansible/inventory/hosts.ini; \
	cat infra/ansible/inventory/hosts.ini

# Secrets por entorno, nunca en disco: webhook desde SOPS, auth key de Tailscale desde su archivo 600.
ansible:
	cd infra/ansible && \
	DISCORD_WEBHOOK="$$(sops -d --extract '["stringData"]["webhook-url"]' ../../infrastructure/monitoring/secrets/alertmanager-discord.sops.yaml)" \
	OCI_TENANCY_OCID="$$(terraform -chdir=../terraform output -raw tenancy_ocid)" \
	OCI_COMPARTMENT_OCID="$$(terraform -chdir=../terraform output -raw compartment_ocid)" \
	TAILSCALE_AUTHKEY="$${TAILSCALE_AUTHKEY:-$$(cat ~/.config/martin-ops-tailscale-authkey 2>/dev/null)}" \
	~/.venvs/ops/bin/ansible-playbook playbooks/bootstrap.yml

# Image automation: los repos de apps (tenants) actualizan sus tags con ImagePolicy + ImageUpdateAutomation.
bootstrap: inventory ansible
	$(KUBECTL) create namespace flux-system --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) -n flux-system create secret generic sops-age --from-file=age.agekey=$(HOME)/.config/sops/age/keys.txt --dry-run=client -o yaml | $(KUBECTL) apply -f -
	KUBECONFIG=kube/kubeconfig flux bootstrap github --owner=$(FLUX_OWNER) --repository=$(FLUX_REPO) --path=flux-system --personal=true \
		--components-extra=image-reflector-controller,image-automation-controller

flux-verify:
	$(KUBECTL) get kustomizations -n flux-system
	$(KUBECTL) get helmreleases -A

# Alta de una app de otro repo: make tenant NAME=mi-app REPO=https://github.com/OWNER/mi-app
# Monorepo: un tenant por app, mismo REPO y DIR distinto (DIR=./apps/api/deploy).
DIR ?= ./deploy
tenant:
	@[ -n "$(NAME)" ] && [ -n "$(REPO)" ] || { echo "Uso: make tenant NAME=<app> REPO=<url>" >&2; exit 1; }
	@[ ! -e tenants/$(NAME).yaml ] || { echo "tenants/$(NAME).yaml ya existe" >&2; exit 1; }
	sed -e 's#__NAME__#$(NAME)#g' -e 's#__REPO__#$(REPO)#g' -e 's#__DIR__#$(DIR)#g' docs/tenant-template.yaml > tenants/$(NAME).yaml
	sed -i 's/^resources: \[\]$$/resources:/' tenants/kustomization.yaml
	echo "  - $(NAME).yaml" >> tenants/kustomization.yaml
	kubectl kustomize tenants > /dev/null && echo "OK: revisa tenants/$(NAME).yaml, commit y push"
