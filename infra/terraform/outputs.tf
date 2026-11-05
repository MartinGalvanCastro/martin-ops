output "public_ip" {
  description = "IP pública de la VM k3s."
  value       = oci_core_instance.k3s.public_ip
}

output "private_ip" {
  description = "IP privada de la VM k3s."
  value       = oci_core_instance.k3s.private_ip
}

output "instance_ocid" {
  value = oci_core_instance.k3s.id
}

output "ssh_user" {
  value = "ubuntu"
}

output "availability_domain" {
  value = oci_core_instance.k3s.availability_domain
}
