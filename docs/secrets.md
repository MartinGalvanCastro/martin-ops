# Flujo de secrets (SOPS + age + Flux + ESO)

## Estado

- Claves age: privada en `~/.config/sops/age/keys.txt` (NUNCA al repo), pública en `.sops.yaml`.
- Flux descifra todo `*.sops.yaml` vía `decryption: sops` en `flux-system/infrastructure.yaml`; la llave privada se entrega al cluster como secret `sops-age` en `flux-system` durante el bootstrap (`make bootstrap` lo hace).
- Secrets cifrados en el repo:
  - `infrastructure/cert-manager/secrets/cloudflare-api-token.sops.yaml` (placeholder `REPLACE_ME` → token de Cloudflare para DNS-01)
  - `infrastructure/monitoring/secrets/grafana-admin.sops.yaml` (admin/password reales)
  - `infrastructure/velero/secrets/velero-oci.sops.yaml` (placeholder → credenciales S3 de Oracle Object Storage)

## Editar un secret

```
sops infrastructure/cert-manager/secrets/cloudflare-api-token.sops.yaml
git add ... && git commit
```

Flux lo reconcilia en ≤10 min (o `flux reconcile kustomization infrastructure --with-source`).

## External Secrets Operator

ESO está instalado (`infrastructure/external-secrets/`). Para backends externos (1Password, Vault, etc.) ver ejemplo en `examples/external-secrets.yaml`; ese directorio no lo reconcilia Flux: copiar al componente correspondiente cuando exista el backend.
