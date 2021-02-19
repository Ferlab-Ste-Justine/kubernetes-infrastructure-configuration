locals {
  namespaces_manifest = templatefile(
    "${path.module}/templates/namespaces.yml", 
    {
      namespaces = var.namespaces
      metadata_identifier = var.kubernetes_metadata_identifier
    }
  )
  services_manifest = templatefile(
    "${path.module}/templates/services.yml", 
    {
      services = var.services
      default_namespace = var.kubernetes_namespace
      metadata_identifier = var.kubernetes_metadata_identifier
    }
  )
  secrets_manifest = templatefile(
    "${path.module}/templates/secrets.yml", 
    {
      secrets = var.secrets
      default_namespace = var.kubernetes_namespace
      metadata_identifier = var.kubernetes_metadata_identifier
    }
  )
  flux_manifest = templatefile(
    "${path.module}/templates/flux.yml", 
    {
      flux_instances = var.flux_instances
      metadata_identifier = var.kubernetes_metadata_identifier
    }
  )
}

resource "null_resource" "kubernetes_infra_conf" {
  triggers = {
    kubernetes_installation_id = var.kubernetes_installation_id
    namespaces_manifest        = local.namespaces_manifest
    services_manifest          = local.services_manifest
    secrets_manifest           = local.secrets_manifest
    flux_manifest              = local.flux_manifest
  }

  connection {
    host        = var.bastion_external_ip
    type        = "ssh"
    user        = var.bastion_user
    port        = var.bastion_port
    private_key = var.bastion_key_pair.private_key
  }

  provisioner "remote-exec" {
    inline = [
        "mkdir -p ${var.manifests_path}"
    ]
  }

  provisioner "file" {
    content     = local.namespaces_manifest
    destination = "${var.manifests_path}/namespaces.yml"
  }

  provisioner "file" {
    content     = local.services_manifest
    destination = "${var.manifests_path}/services.yml"
  }

  provisioner "file" {
    content     = local.secrets_manifest
    destination = "${var.manifests_path}/secrets.yml"
  }

  provisioner "file" {
    content     = local.flux_manifest
    destination = "${var.manifests_path}/flux.yml"
  }

  #Apply the services and secrets on the kubernetes cluster
  provisioner "remote-exec" {
    inline = [
      length(var.secrets) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply --prune=true --selector=\"${var.kubernetes_metadata_identifier}=infrastructure_namespaces\" -f ${var.manifests_path}/namespaces.yml" : ":",
      length(var.services) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply --prune=true --selector=\"${var.kubernetes_metadata_identifier}=infrastructure_services\" -f ${var.manifests_path}/services.yml" : ":",
      length(var.secrets) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply --prune=true --selector=\"${var.kubernetes_metadata_identifier}=infrastructure_secrets\" -f ${var.manifests_path}/secrets.yml" : ":",
      length(var.flux_instances) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply --prune=true --selector=\"${var.kubernetes_metadata_identifier}=infrastructure_flux_instances\" -f ${var.manifests_path}/flux.yml" : ":"
    ]
  }
}