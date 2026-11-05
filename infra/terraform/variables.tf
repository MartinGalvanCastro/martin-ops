variable "tenancy_ocid" {
  type        = string
  description = "OCID del tenancy (raíz)."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment donde crear los recursos. Vacío = compartment raíz del tenancy."
  default     = ""
}

variable "region" {
  type        = string
  description = "Región OCI, ej: eu-madrid-1, us-ashburn-1."
}

variable "ssh_public_key" {
  type        = string
  description = "Contenido de la llave pública SSH para la VM."
  default     = ""
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Ruta a la llave pública SSH (se ignora si ssh_public_key está seteado)."
}

variable "admin_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR autorizado para SSH (22) y API k3s (6443). Restringe a tu IP en producción."
}

variable "ocpus" {
  type        = number
  default     = 2
  description = "OCPUs de la VM A1.Flex (Always Free: hasta 4 OCPU / 24 GB en total)."
}

variable "memory_in_gbs" {
  type        = number
  default     = 12
  description = "RAM GB de la VM (Always Free: hasta 4 OCPU / 24 GB en total)."
}

variable "boot_volume_size_gb" {
  type        = number
  default     = 50
  description = "Tamaño del boot volume en GB (Always Free: hasta 200 GB en total)."
}

variable "cluster_name" {
  type        = string
  default     = "martin-ops"
  description = "Prefijo de nombres de recursos."
}
