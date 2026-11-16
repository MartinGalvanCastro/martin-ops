# Guardrails de costo. Todo esto es gratis: budgets, alertas y quotas no se cobran.

# Quotas: en la tenancy solo se pueden crear las formas Always Free. Lo que cobra no se puede ni crear.
# Orden importa: dentro de una misma policy, el "set" posterior le gana al "zero" anterior.
resource "oci_limits_quota" "always_free_only" {
  compartment_id = var.tenancy_ocid
  name           = "${var.cluster_name}-always-free-only"
  description    = "Solo recursos Always Free: A1 4 OCPU / 24 GB y 200 GB de block storage."
  statements = [
    "zero compute-core quota /*/ in tenancy",
    "set compute-core quota standard-a1-core-count to 4 in tenancy",
    "set compute-core quota standard-a1-core-regional-count to 4 in tenancy",
    "zero compute-memory quota /*/ in tenancy",
    "set compute-memory quota standard-a1-memory-count to 24 in tenancy",
    "set compute-memory quota standard-a1-memory-regional-count to 24 in tenancy",
    "set block-storage quota total-storage-gb to 200 in tenancy",
  ]
}

# Budget sobre toda la tenancy (no solo martin-ops): cualquier gasto cuenta.
resource "oci_budget_budget" "monthly" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.cluster_name}-monthly"
  description    = "Tope mensual: lo esperado es $0 (Always Free)."
  amount         = var.budget_amount
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.tenancy_ocid]
}

resource "oci_budget_alert_rule" "actual" {
  budget_id      = oci_budget_budget.monthly.id
  display_name   = "gasto-real"
  type           = "ACTUAL"
  threshold_type = "PERCENTAGE"
  threshold      = 1 # 1% del budget: cualquier cargo real
  recipients     = var.alert_email
  message        = "OCI martin-ops: hay gasto real este mes. Revisar Cost Analysis."
}

resource "oci_budget_alert_rule" "forecast" {
  budget_id      = oci_budget_budget.monthly.id
  display_name   = "pronostico"
  type           = "FORECAST"
  threshold_type = "PERCENTAGE"
  threshold      = 100
  recipients     = var.alert_email
  message        = "OCI martin-ops: el pronóstico del mes supera el budget."
}
