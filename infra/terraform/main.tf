locals {
  compartment_ocid = coalesce(var.compartment_ocid, var.tenancy_ocid)
  ssh_public_key   = var.ssh_public_key != "" ? var.ssh_public_key : trimspace(file(pathexpand(var.ssh_public_key_path)))
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_vcn" "main" {
  compartment_id = local.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${var.cluster_name}-vcn"
  dns_label      = replace(var.cluster_name, "-", "")
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.cluster_name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "main" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.cluster_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "main" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.cluster_name}-sl"

  # SSH público solo si admin_cidr != "" (bootstrap, antes de Tailscale). La API k3s nunca es pública:
  # el kubeconfig apunta a la IP de Tailscale.
  dynamic "ingress_security_rules" {
    for_each = var.admin_cidr != "" ? [var.admin_cidr] : []
    content {
      description = "SSH (solo bootstrap)"
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  ingress_security_rules {
    description = "HTTP"
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "HTTPS"
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    description      = "Egress total"
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_subnet" "main" {
  compartment_id             = local.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "${var.cluster_name}-subnet"
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "subnet"
}

resource "oci_core_instance" "k3s" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  compartment_id      = local.compartment_ocid
  display_name        = "${var.cluster_name}-k3s"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    assign_public_ip = true
    hostname_label   = "k3s"
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
  }

  agent_config {
    are_all_plugins_disabled = true
  }

  freeform_tags = {
    project    = var.cluster_name
    managed-by = "terraform"
  }

  lifecycle {
    # La VM tiene el estado de k3s: cualquier plan que la destruya debe fallar.
    # Para borrarla a propósito, quitar esta línea primero.
    prevent_destroy = true
    # Imagen "más nueva" y llaves SSH solo importan al crear; sin esto, una imagen nueva de Ubuntu recrea la VM.
    ignore_changes = [source_details[0].source_id, metadata]
  }
}

data "oci_objectstorage_namespace" "ns" {}

# Buckets de backup (privados). El del tfstate se crea fuera de Terraform: ver README.
resource "oci_objectstorage_bucket" "backup" {
  for_each       = toset(["velero", "restic"])
  compartment_id = local.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.cluster_name}-${each.key}"
  access_type    = "NoPublicAccess"
  freeform_tags  = { project = var.cluster_name, managed-by = "terraform" }
}
