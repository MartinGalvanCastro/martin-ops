# martin-ops — k3s en Oracle Cloud (Always Free), GitOps con FluxCD

Stack: Terraform → Oracle VM A1.Flex (Ubuntu 24.04) → Ansible (k3s sin traefik) → FluxCD (componentes + apps) → SOPS+age (secrets) → kube-prometheus-stack/Loki/Tempo (observabilidad) → Velero+restic (backup).

## Flujo completo (una vez)

1. Credenciales OCI en `~/.oci/config` (ApiKey).
2. `make apply` — VM + VCN + security list (ports 22/80/443/6443).
3. `make bootstrap` — genera inventory, instala k3s vía Ansible, crea secret `sops-age` y `flux bootstrap` del repo.
4. Esperar ~10 min a que Flux reconcile `infrastructure` y `apps`.

## Uso diario

- Deploy = push al repo (Flux reconcilia en ≤10 min).
- Apps: manifest en `apps/<nombre>/` + kustomization; si tiene `Dockerfile`, GitHub Actions (`build-push.yml`) publica en `ghcr.io`.
- Secrets: ver `docs/secrets.md`.
- Kubeconfig local: `kube/kubeconfig` (generado por Ansible; no se commitea).

## Pendientes tras el bootstrap

- Reemplazar `REPLACE_ME` en `cloudflare-api-token` y `velero-oci` (`sops <archivo>`).
- Host del ingress de podinfo (`apps/podinfo/ingress.yaml`) al tener dominio.
- `restic_repo`/`restic_password` en Ansible para el backup de archivos del nodo.
