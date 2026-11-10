# Flujo de secrets (SOPS + age + Flux)

## Estado

- Claves age: privada en `~/.config/sops/age/keys.txt` (NUNCA al repo), pública en `.sops.yaml`.
- Flux descifra todo `*.sops.yaml` vía `decryption: sops` en `flux-system/infrastructure.yaml`; la llave privada se entrega al cluster como secret `sops-age` en `flux-system` durante el bootstrap (`make bootstrap` lo hace).
- Secrets cifrados en el repo:
  - `infrastructure/cert-manager/secrets/cloudflare-api-token.sops.yaml` (placeholder `REPLACE_ME` → token de Cloudflare para DNS-01)
  - `infrastructure/monitoring/secrets/grafana-admin.sops.yaml` (admin/password reales)
  - `infrastructure/velero/secrets/velero-oci.sops.yaml` (placeholder → credenciales S3 de Oracle Object Storage)
  - `infrastructure/monitoring/secrets/alertmanager-discord.sops.yaml` (placeholder → URL del webhook de Discord)

## Editar un secret

```
sops infrastructure/cert-manager/secrets/cloudflare-api-token.sops.yaml
git add ... && git commit
```

Flux lo reconcilia en ≤10 min (o `flux reconcile kustomization infrastructure --with-source`).

## Por qué no External Secrets Operator

Flux ya descifra SOPS al aplicar; ESO no lee SOPS y solo sirve con un backend externo (Vault, 1Password...). Si algún día hay uno, se instala entonces.
