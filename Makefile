.PHONY: inventory apply bootstrap ansible k3s flux-verify

TF := terraform -chdir=infra/terraform
ANSIBLE := ~/.venvs/ops/bin/ansible-playbook -i infra/ansible/inventory/hosts.ini
FLUX_OWNER ?= MartinGalvanCastro
FLUX_REPO ?= martin-ops

inventory:
	@ip=$$($(TF) output -raw public_ip 2>/dev/null || echo "APLICA_TERRAFORM_PRIMERO"); \
	printf '[k3s]\n%s ansible_user=ubuntu\n' "$$ip" > infra/ansible/inventory/hosts.ini; \
	cat infra/ansible/inventory/hosts.ini

apply:
	$(TF) apply

ansible:
	cd infra/ansible && ~/.venvs/ops/bin/ansible-playbook playbooks/bootstrap.yml

bootstrap: inventory ansible
	kubectl --kubeconfig kube/kubeconfig create namespace flux-system --dry-run=client -o yaml | kubectl --kubeconfig kube/kubeconfig apply -f -
	kubectl --kubeconfig kube/kubeconfig -n flux-system create secret generic sops-age --from-file=age.agekey=~/.config/sops/age/keys.txt --dry-run=client -o yaml | kubectl --kubeconfig kube/kubeconfig apply -f -
	export KUBECONFIG=kube/kubeconfig && flux bootstrap github --owner=$(FLUX_OWNER) --repository=$(FLUX_REPO) --path=flux-system --personal=true

flux-verify:
	kubectl --kubeconfig kube/kubeconfig get kustomizations -n flux-system
	kubectl --kubeconfig kube/kubeconfig get helmreleases -A
