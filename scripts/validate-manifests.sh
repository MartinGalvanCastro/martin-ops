#!/bin/sh
# Valida lo que Flux aplicaría: cada Kustomization renderizada contra los schemas de k8s y de las CRDs.
set -eu
CRDS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
# Los Secret SOPS llevan el campo extra "sops": se omiten (Flux los descifra antes de aplicar).
for dir in infrastructure infrastructure/configs apps tenants; do
  echo "== $dir"
  kubectl kustomize "$dir" | kubeconform -strict -summary -skip Secret \
    -schema-location default -schema-location "$CRDS"
done
echo "== flux-system"
kubeconform -strict -summary -schema-location default -schema-location "$CRDS" flux-system/*.yaml
