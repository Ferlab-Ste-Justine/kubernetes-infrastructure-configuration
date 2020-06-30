locals {
  endpoints_manifest = templatefile(
    "${path.module}/templates/endpoints.yml", 
    {
      endpoints = var.endpoints
    }
  )
  secrets_manifest = templatefile(
    "${path.module}/templates/secrets.yml", 
    {
      secrets = var.secrets
    }
  )
}

resource "null_resource" "kubernetes_infra_conf" {
  triggers = {
    kubernetes_installation_id = var.kubernetes_installation_id
    endpoints_manifest         = local.endpoints_manifest
    secrets_manifest           = local.secrets_manifest
  }

  connection {
    host        = var.bastion_external_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.bastion_key_pair.private_key
  }

  provisioner "remote-exec" {
    inline = [
        "mkdir -p ${var.manifests_path}"
    ]
  }

  provisioner "file" {
    content     = local.endpoints_manifest
    destination = "${var.manifests_path}/endpoints.yml"
  }

  provisioner "file" {
    content     = local.secrets_manifest
    destination = "${var.manifests_path}/secrets.yml"
  }

  #Apply the endpoints and secrets on the kubernetes cluster
  provisioner "remote-exec" {
    inline = [
      length(var.endpoints) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply -f ${var.manifests_path}/endpoints.yml --namespace=${var.kubernetes_namespace}" : ":",
      length(var.secrets) > 0 ? "${var.artifacts_path}/kubectl --kubeconfig=${var.artifacts_path}/admin.conf apply -f ${var.manifests_path}/secrets.yml --namespace=${var.kubernetes_namespace}" : ":",
      "rm -r ${var.manifests_path}"
    ]
  }
}