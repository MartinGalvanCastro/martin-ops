output "public_ip" {
  description = "IP pública de la VM k3s."
  value       = oci_core_instance.k3s.public_ip
}

output "private_ip" {
  description = "IP privada de la VM k3s."
  value       = oci_core_instance.k3s.private_ip
}

output "instance_ocid" {
  description = "OCID de la VM k3s."
  value       = oci_core_instance.k3s.id
}

output "ssh_user" {
  description = "Usuario SSH de la imagen Ubuntu."
  value       = "ubuntu"
}

output "availability_domain" {
  description = "AD donde quedó la VM."
  value       = oci_core_instance.k3s.availability_domain
}

output "objectstorage_namespace" {
  description = "Namespace de Object Storage (va en el s3Url de Velero y en restic_repo)."
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "s3_endpoint" {
  description = "Endpoint S3-compatible de OCI para Velero y restic."
  value       = "https://${data.oci_objectstorage_namespace.ns.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

output "tenancy_ocid" {
  description = "OCID de la tenancy (lo usa el cost guard)."
  value       = var.tenancy_ocid
}

output "compartment_ocid" {
  description = "Compartment de martin-ops (el cost guard apaga sus VMs)."
  value       = local.compartment_ocid
}
