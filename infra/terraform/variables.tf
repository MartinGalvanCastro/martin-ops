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
  default     = "~/.ssh/martin-ops.pub"
  description = "Ruta a la llave pública SSH (se ignora si ssh_public_key está seteado)."
}

variable "admin_cidr" {
  type        = string
  default     = ""
  description = "CIDR con SSH (22) público, ej. TU.IP/32, solo para el bootstrap. Vacío = cerrado (acceso por Tailscale)."

  validation {
    condition     = var.admin_cidr == "" || can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr debe ser \"\" o un CIDR, ej. 1.2.3.4/32."
  }
}

variable "ocpus" {
  type        = number
  default     = 4
  description = "OCPUs de la VM A1.Flex (Always Free: hasta 4 OCPU / 24 GB en total)."
}

variable "memory_in_gbs" {
  type        = number
  default     = 24
  description = "RAM GB de la VM (Always Free: hasta 4 OCPU / 24 GB en total)."
}

variable "boot_volume_size_gb" {
  type        = number
  default     = 200
  description = "Tamaño del boot volume en GB (Always Free: hasta 200 GB en total)."
}

variable "cluster_name" {
  type        = string
  default     = "martin-ops"
  description = "Prefijo de nombres de recursos."
}
