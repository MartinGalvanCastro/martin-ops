#!/bin/bash
# Gasto del mes > LIMIT: aviso a Discord y SOFTSTOP de todas las VMs del compartment (incluida esta).
# --check: solo consulta y muestra el gasto (no apaga nada). Auth: instance principal (dynamic group).
set -euo pipefail
set -a; . /etc/cost-guard/env; set +a
export OCI_CLI_AUTH=instance_principal SUPPRESS_LABEL_WARNING=True
OCI=/opt/cost-guard/bin/oci

discord() {
  curl -fsS -m 20 -H 'Content-Type: application/json' \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"content": sys.argv[1]}))' "$1")" "$DISCORD_WEBHOOK" >/dev/null
}
# Un guard que falla en silencio no protege: avisar si algo se rompe.
trap 'discord "⚠️ cost-guard en $(hostname) falló (línea $LINENO). Revisar: journalctl -u cost-guard"' ERR

cost=$($OCI usage-api usage-summary request-summarized-usages --tenant-id "$TENANCY" \
  --time-usage-started "$(date -u +%Y-%m-01T00:00:00Z)" \
  --time-usage-ended "$(date -u -d tomorrow +%Y-%m-%dT00:00:00Z)" \
  --granularity MONTHLY --query-type COST --query 'data.items[]."computed-amount"' --raw-output \
  | python3 -c 'import json,sys; print(round(sum(x or 0 for x in (json.load(sys.stdin) or [])), 4))')
echo "Gasto del mes: $cost (límite $LIMIT)"

[ "${1:-}" = "--check" ] && exit 0
python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)' "$cost" "$LIMIT" || exit 0

discord "🚨 OCI martin-ops: gasto del mes = $cost (límite $LIMIT). Apagando todas las VMs del compartment."
for id in $($OCI compute instance list -c "$COMPARTMENT" --lifecycle-state RUNNING --all \
    --query 'data[].id' --raw-output | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin) or []))'); do
  $OCI compute instance action --instance-id "$id" --action SOFTSTOP >/dev/null
  echo "SOFTSTOP $id"
done
