# Apps de otros repos (tenants)

Cada app vive en su propio repo y se registra aquí con un archivo. Flux la despliega en su namespace con permisos solo dentro de él.

## Alta

1. En el repo de la app: carpeta `deploy/` con un `kustomization.yaml` y sus manifests (Deployment, Service, Ingress...). Sin `namespace:`: Flux pone el del tenant.
2. Aquí: `make tenant NAME=mi-app REPO=https://github.com/OWNER/mi-app` → revisar `tenants/mi-app.yaml` → commit + push.
3. Flux crea el namespace `mi-app`, su quota y aplica `deploy/` cada 10 min (`flux get kustomizations -n mi-app`).

### Monorepo (varias apps en un repo)

Un tenant por app, mismo `REPO`, distinto `DIR`. Cada app queda en su namespace con su quota:

```
make tenant NAME=api REPO=https://github.com/OWNER/mono DIR=./apps/api/deploy
make tenant NAME=web REPO=https://github.com/OWNER/mono DIR=./apps/web/deploy
```

Cada tenant clona el repo por separado (barato). Un push que solo toca `apps/web/` no cambia nada en `api`: Flux aplica lo mismo y no hay diff.
Si usan image automation, cada `ImageUpdateAutomation` con su `update.path` (`./apps/api/deploy`).

Baja: borrar `tenants/mi-app.yaml` y su línea en `tenants/kustomization.yaml`. `prune` borra todo lo del namespace.

## Qué puede hacer un tenant

- Todo dentro de su namespace (ClusterRole `admin`), nada fuera: ni CRDs, ni otros namespaces, ni cambiar su quota.
- Quota por defecto: 1 CPU / 2 GiB de requests, 4 GiB de limits. Ajustar en `tenants/<app>.yaml`.
- Ingress: `ingressClassName: traefik` y `cert-manager.io/cluster-issuer: letsencrypt` (o `letsencrypt-staging` para probar).

## Repo privado

Deploy key de solo lectura (o de escritura si usa image automation):

```
flux create secret git mi-app-git --namespace=mi-app --url=ssh://git@github.com/OWNER/mi-app --export > tenants/mi-app-git.sops.yaml
sops -e -i tenants/mi-app-git.sops.yaml
```

Copiar la llave pública que imprime a GitHub → repo → Settings → Deploy keys. En `tenants/mi-app.yaml`: URL `ssh://git@github.com/OWNER/mi-app`, descomentar `secretRef` y agregar `mi-app-git.sops.yaml` a `tenants/kustomization.yaml`.

Imágenes privadas en GHCR: `imagePullSecrets` con un token `read:packages`, también como Secret SOPS.

## Actualizar imágenes sin tocar manifests

El CI de la app publica tags ordenables: `main-<sha7>-<epoch>` (ver `.github/workflows/build-push.yml`). En `deploy/` de la app:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: mi-app
spec:
  image: ghcr.io/owner/mi-app
  interval: 5m
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: mi-app
spec:
  imageRepositoryRef:
    name: mi-app
  filterTags:
    pattern: '^main-[a-f0-9]+-(?P<ts>[0-9]+)$'
    extract: '$ts'
  policy:
    numerical:
      order: asc
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageUpdateAutomation
metadata:
  name: mi-app
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: mi-app
  git:
    commit:
      author:
        name: fluxcdbot
        email: fluxcdbot@users.noreply.github.com
    push:
      branch: main
  update:
    path: ./deploy
    strategy: Setters
```

Y en el Deployment: `image: ghcr.io/owner/mi-app:main-abc1234-1700000000 # {"$imagepolicy": "mi-app:mi-app"}`.

Flux hace commit del tag nuevo en el repo de la app, así que la deploy key necesita escritura.

## CI de las apps

Por ahora en runners de GitHub (`ubuntu-24.04-arm` para que la imagen sea ARM64 como la VM). Runners self-hosted en este clúster (ARC): pendiente.
