# martin-ops — k3s en Oracle Cloud (Always Free), GitOps con FluxCD

Stack: Terraform → Oracle VM A1.Flex (Ubuntu 24.04) → Ansible (Tailscale + k3s sin traefik) → FluxCD (componentes + apps + tenants) → SOPS+age (secrets) → kube-prometheus-stack/Loki/Tempo/Alloy (observabilidad, alertas a Discord) → Velero+restic (backup).

## Requisitos (una vez)

- OCI: usuario `terraform` en el grupo `terraform-admins`, API key en `~/.oci/config`. Policies en el compartment raíz:
  - `Allow group terraform-admins to manage instance-family in compartment martin-ops`
  - `Allow group terraform-admins to manage virtual-network-family in compartment martin-ops`
  - `Allow group terraform-admins to manage volume-family in compartment martin-ops`
  - `Allow group terraform-admins to manage object-family in compartment martin-ops` (state y buckets de backup)
  - `Allow group terraform-admins to inspect compartments in tenancy`
- Bucket del state (fuera de Terraform, versionado):
  `oci os bucket create --name martin-ops-tfstate --compartment-id <martin-ops OCID> --versioning Enabled`
- Llave SSH dedicada: `ssh-keygen -t ed25519 -f ~/.ssh/martin-ops`.
- Tailscale instalado y logueado en tu máquina (`kubectl` y SSH van por el tailnet).
- `~/.config/sops/age/keys.txt` (llave age del repo).

## Flujo completo

1. `infra/terraform/terraform.tfvars` con `tenancy_ocid`, `compartment_ocid`, `region` y `admin_cidr = "TU.IP/32"` (abre SSH solo para el bootstrap).
2. `make init` → `make apply`: VM, red, security list (80/443 públicos; 22 solo `admin_cidr`) y buckets `martin-ops-velero` / `martin-ops-restic`.
3. Auth key en https://login.tailscale.com/admin/settings/keys (no reusable, no ephemeral), sin dejarla en el historial: `read -s TAILSCALE_AUTHKEY && export TAILSCALE_AUTHKEY`.
4. `make bootstrap`: Tailscale + k3s vía Ansible, secret `sops-age` y `flux bootstrap` (necesita `GITHUB_TOKEN`, ej. `export GITHUB_TOKEN=$(gh auth token)`).
5. Admin de Tailscale: **Disable key expiry** en `martin-ops-k3s` (si no, el nodo sale del tailnet a los 180 días).
6. Cerrar SSH público: `admin_cidr = ""` → `make apply` (solo cambia la security list) → `make inventory HOST=martin-ops-k3s`.
7. ~10 min: Flux reconcilia `infrastructure` → `infrastructure-configs` → `apps` y `tenants` (`make flux-verify`).

## Uso diario

- Deploy = push a `main` (Flux reconcilia en ≤10 min). Los PR pasan `validate.yml`: `terraform fmt/validate`, kustomize + kubeconform, `ansible-lint`.
- Apps de este repo: `apps/<nombre>/`. Si tiene `Dockerfile`, `build-push.yml` publica `ghcr.io/<owner>/<nombre>:main-<sha7>-<epoch>` (ARM64).
- Apps de otros repos: `make tenant NAME=<app> REPO=<url>`, ver `docs/tenants.md`.
- Secrets: `docs/secrets.md`.
- Actualizar k3s: subir `k3s_version` en `infra/ansible/roles/k3s/defaults/main.yml` y `make ansible`.
- Versiones (charts, actions, k3s, Terraform): Renovate abre PRs (`renovate.json`).
- Kubeconfig local: `kube/kubeconfig` (generado por Ansible, modo 600; no se commitea).

## Pendientes

- Pasar la cuenta OCI a **Pay As You Go** (Billing → Upgrade): en Free Tier, Oracle reclama instancias Always Free con poco uso de CPU. Sigue sin costo dentro de los límites gratuitos.
- Instalar la app de Renovate en el repo: https://github.com/apps/renovate.
- Reemplazar `REPLACE_ME` (`sops <archivo>`):
  - `infrastructure/monitoring/secrets/alertmanager-discord.sops.yaml`: URL del webhook de Discord (canal → Integraciones → Webhooks).
  - `infrastructure/cert-manager/secrets/cloudflare-api-token.sops.yaml`: token Cloudflare (Zone.DNS edit).
  - `infrastructure/velero/secrets/velero-oci.sops.yaml`: Customer Secret Key de OCI (S3) de un usuario con acceso solo a los buckets de backup.
- Velero: para respaldar volúmenes de un pod, anotación `backup.velero.io/backup-volumes=<volumen>`.
- restic (backup de k3s: SQLite + TLS + token): `restic_repo`, `restic_password` y `restic_env` en Ansible.
- DNS en Cloudflare: registro A `podinfo.realeflow.cloud` (o `*.realeflow.cloud`) → IP pública de la VM (`terraform output public_ip`).
- Runners self-hosted (ARC) para los otros repos.
- Object Storage Always Free: 20 GB en total entre los buckets.
