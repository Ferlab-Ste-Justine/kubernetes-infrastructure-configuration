locals {
  services_manifest = templatefile(
    "${path.module}/templates/services.yml", 
    {
      services = var.services
      metadata_identifier = var.kubernetes_metadata_identifier
    }
  )
  secrets_manifest = templatefile(
    "${path.module}/templates/secrets.yml", 
    {
      secrets = var.secrets
      metadata_identifier = var.kubernetes_metadata_identifier
    }
  )
}

resource "null_resource" "kubernetes_infra_conf" {
  triggers = {
    kubernetes_installation_id = var.kubernetes_installation_id
    services_manifest         = local.services_manifest
    secrets_manifest           = local.secrets_manifest
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
    content     = local.services_manifest
    destination = "${var.manifests_path}/services.yml"
  }

  provisioner "file" {
    content     = local.secrets_manifest
    destination = "${var.manifests_path}/secrets.yml"
  }

  #Apply the services and secrets on the kubernetes cluster
  provisioner "remote-exec" {
    inline = [
      length(var.services) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply --prune=true --selector=\"${var.kubernetes_metadata_identifier}=infrastructure_services\" -f ${var.manifests_path}/services.yml --namespace=${var.kubernetes_namespace}" : ":",
      length(var.secrets) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply --prune=true --selector=\"${var.kubernetes_metadata_identifier}=infrastructure_secrets\" -f ${var.manifests_path}/secrets.yml --namespace=${var.kubernetes_namespace}" : ":",
      "rm -r ${var.manifests_path}"
    ]
  }
}