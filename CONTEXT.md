# CONTEXT.md — Estado del Harness OmO + Infra Target

**Última actualización:** 2026-11-03  
**Sesión actual:** Harness limpio + definición de infra target

---

## ✅ Estado actual (limpio y funcional)

### Harness OmO/Senpi — LIMPIO
- **Motor**: OmO = Senpi empaquetado (`@code-yeongyu/omo-senpi`)
- **Configuración**: `~/.omo/omo.jsonc` + `~/.omo/agent/settings.json`
- **Modelo por defecto**: `opencode-go/glm-5.2` (Go Plus, barato/rápido)
- **Proveedores reales** (3):
  - `anthropic-subscription` → Claude Max (opus-5.5, sonnet-5.5, haiku-5.5)
  - `chatgpt-subscription` → Codex Plus (gpt-6.1-sol, gpt-5.6-sol, etc.)
  - `opencode-go` → Go Plus (glm-5.2, kimi-k2.7-code, qwen3.7-plus, minimax-m3, glm-4.7-flash)
- **Categorías** (`omo.jsonc`): quick, deep-low, deep-high, visual-engineering, artistry, unspecified-low, unspecified-high, writing
- **Fallback chains** (`settings.json`): coherentes con los 3 proveedores
- **Modelo default**: `opencode-go/glm-5.2` (Go Plus, barato/rápido)
- **Fallback chains** en `settings.json` alineados con 3 proveedores
- **tuiMode**: `fullscreen` (persistente en settings.json)
- **Ponytail**: instalado como paquete global (filosofía minimalista)
- **Skills**: 85 en `~/.agents/skills/`
- **MCP servers**: 4 (anthropic-subscription, chatgpt-subscription, ast-grep, context7, grep_app)
- **Ponytail**: paquete global instalado

### Extensiones HUD — ELIMINADAS
- `hud.js`, `agents.js`, `worktrees.js` → **borradas** (aparecían arriba del input, no en panel derecho)
- Respaldo en `~/Repos/harness-backup` (commit `0d4c6e5`)

### OpenRouter
- **NO configurado**, **no necesario**. OmO/Senpi tiene enrutador propio.
- Solo se añadiría si se necesita modelo exclusivo de OpenRouter.

---

## 🎯 Infra Target — Arquitectura Definida

### Stack
| Capa | Decisión |
|------|----------|
| **Provisioning** | Terraform → Oracle Cloud VM (Always Free) + VCN + Security Lists |
| **Bootstrap** | Ansible → k3s + KEDA + Traefik + cert-manager + monitoring stack |
| **Orquestador** | **k3s** (ligero, k8s nativo) + **KEDA** (escalado event-driven) |
| **Ingress** | **Traefik** + cert-manager (Let's Encrypt + Cloudflare DNS) |
| **CI** | GitHub Actions (ya existente) |
| **CD** | **FluxCD** (GitOps nativo, ligero, CRDs nativos) — *pendiente decidir vs GitHub Actions deploy* |
| **Secrets** | **SOPS + age** (repo público, gratis, git-native) + **External Secrets Operator** para sincronizar a K8s |
| **Ingress** | Traefik + cert-manager (Let's Encrypt + Cloudflare DNS) |
| **Observabilidad cluster** | **Prometheus + Grafana + Loki + Tempo + Alertmanager** (kube-prometheus-stack) — centralizado |
| **Apps observabilidad** | Cada app su propia (Grafana Cloud, Datadog, etc.) |
| **Escalado** | **KEDA** (event-driven) |
| **Backup/DR** | Velero (K8s) + restic (archivos) + Oracle snapshots |
| **Secrets** | **SOPS + age** (repo público, gratis, git-native) + **External Secrets Operator** para sincronizar a K8s secrets |

### Stack k3s — componentes adicionales (declarativos, YAML)
| Componente | Por qué |
|---|---|
| **KEDA** | Escalado event-driven |
| **cert-manager** | TLS automático Let's Encrypt + Cloudflare DNS |
| **Traefik** (nuestro) | Ingress + middleware + TLS terminación |
| **cert-manager** | Certificados TLS automáticos |
| **External Secrets Operator** | Sincroniza secrets de SOPS/1Password/Vault a K8s secrets |
| **kube-prometheus-stack** | Prometheus + Grafana + Alertmanager + Loki + Tempo (observabilidad cluster) |
| **KEDA** | Escalado event-driven |

> Todo declarativo (YAML/Helm/HelmFile/Flux). **Sin comandos imperativos** salvo patches puntuales.

### Secrets — Repo público → SOPS + age
- Cifra secrets en git, se descifran en deploy (Flux/ArgoCD/External Secrets)
- Gratis, seguro, nativo git, funciona con repo público
- Flujo: `sops -e secrets.yaml > secrets.enc.yaml` → commit → Flux/ArgoCD descifra al aplicar

### CD — Pendiente decisión
| Opción | Pros | Contras |
|---|---|---|
| **FluxCD** | GitOps nativo, ligero, CRDs nativos, funciona bien con k3s | Un componente más |
| **GitHub Actions + kubectl** | Cero componentes extra, ya tienes GH Actions | Menos GitOps puro, más imperativo |
| **ArgoCD** | UI rica, multi-cluster, RBAC | Más pesado, CRDs propios |
| **Woodpecker CI** | Ligero, self-hosted | Menos adopción |

> Recomendación: **FluxCD** (GitOps nativo) o **GitHub Actions + kubectl** si quieres cero componentes extra.

---

## 📦 Stack k3s — Componentes Adicionales (Declarativos)

Todos se instalan via Helm/HelmFile/Flux — **todo declarativo (YAML)**.

| Componente | Chart/Repo | Namespace | Notas |
|---|---|---|---|
| **k3s** | — | — | `--disable=traefik` (usamos nuestro Traefik) |
| **KEDA** | `kedacore/keda` | `keda` | Escalado event-driven |
| **cert-manager** | `jetstack/cert-manager` | `cert-manager` | TLS automático Let's Encrypt + Cloudflare DNS |
| **Traefik** | `traefik/traefik` | `traefik` | Ingress + middleware + TLS terminación |
| **cert-manager** | `jetstack/cert-manager` | `cert-manager` | Certificados TLS automáticos |
| **External Secrets Operator** | `external-secrets/external-secrets` | `external-secrets` | Sincroniza secrets de SOPS/1Password/Vault a K8s secrets |
| **kube-prometheus-stack** | `prometheus-community/kube-prometheus-stack` | `monitoring` | Prometheus + Grafana + Alertmanager + Loki + Tempo |
| **KEDA** | `kedacore/keda` | `keda` | Escalado event-driven |
| **External Secrets Operator** | `external-secrets/external-secrets` | `external-secrets` | Sincroniza secrets de SOPS/1Password/Vault a K8s secrets |
| **Velero** | `vmware-tanzu/velero` | `velero` | Backup/DR K8s |
| **restic** | — | — | Backup/DR archivos |

> Todo instalado via **Helm/HelmFile/Flux** — **todo declarativo (YAML)**. Sin comandos imperativos salvo patches puntuales.

---

## 🎯 Próximos Pasos (Flow Propuesto)

### Fase 1: Terraform → Oracle Cloud
```hcl
# infra/terraform/
# - main.tf, variables.tf, outputs.tf
# - Oracle VM (Always Free), VCN, Security Lists, LB opcional
# Outputs → IPs, IPs públicas, SSH keys → input para Ansible
```

### Fase 2: Ansible → Bootstrap VM
```yaml
# infra/ansible/
# - playbooks/bootstrap.yml
# - roles/k3s, roles/traefik, roles/monitoring, roles/keda, roles/cert-manager
# - Instala k3s + componentes declarativos via Helm/HelmFile
```

### Fase 3: CD Pipeline
```yaml
# Opción A: FluxCD (GitOps nativo)
# infra/flux/
# - flux-system/ (bootstrap)
# - apps/ (kustomize/helm)

# Opción B: GitHub Actions + kubectl
# .github/workflows/deploy.yml
# - build → push image → kubectl apply/helm upgrade
```

### Fase 4: Secrets
```bash
# SOPS + age
sops -e secrets.yaml > secrets.enc.yaml
# External Secrets Operator lee secrets.enc.yaml y crea K8s Secrets
```

### Fase 5: Observabilidad Cluster
- **Prometheus** → métricas
- **Grafana** → dashboards
- **Alertmanager** → alertas (dedup, grouping, silencing, routing)
- **Loki** → logs
- **Tempo** → traces
- **Grafana** → visualización única

> **Grafana Alerting** es para casos simples. **Alertmanager** sigue siendo el estándar para producción (dedup, grouping, silencing, routing, HA nativo).

---

## 📋 Checklist de Próximos Pasos

- [ ] **Terraform** → Oracle VM + VCN + Security Lists + outputs
- [ ] **Ansible** → bootstrap k3s + componentes (KEDA, Traefik, cert-manager, monitoring)
- [ ] **CD Pipeline** → decidir FluxCD vs GitHub Actions deploy
- [ ] **Secrets** → SOPS + age + External Secrets Operator
- [ ] **Observabilidad** → kube-prometheus-stack + Alertmanager (no Grafana Alerting)
- [ ] **Backup/DR** → Velero + restic + Oracle snapshots
- [ ] **Primer flow real** → desplegar primera app end-to-end

---

## 📌 Notas Importantes

- **OpenRouter**: NO necesario. OmO/Senpi tiene routing propio.
- **Widgets HUD**: Eliminados (aparecían arriba del input, no en panel derecho).
- **Side panel**: En fullscreen (`tuiMode: fullscreen` en settings.json) → panel nativo OmO a la derecha.
- **Barra de estado**: Abajo del input (modelo | ctx | caché | gasto $) — sin cajas arriba.
- **Comandos clave**: `/model`, `/cost` (desactivado), `/agents`, `/worktrees`, `/mode`, `/thinking`, `Ctrl+P`.

---

## 📌 Próximo Paso Inmediato

¿Por cuál empezamos?

1. **Terraform** → Oracle VM + VCN
2. **Pipeline CD** → FluxCD vs GitHub Actions deploy
3. **Secrets** → SOPS + age + External Secrets Operator
4. **Flow completo** → Terraform → Ansible → CD → Secrets → Observabilidad → Primer deploy real

**Tú decides. Yo ejecuto.**