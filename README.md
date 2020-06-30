# About

This terraform module provision kubernetes resources that are highly coupled with the infrastructure and will change as the infrastructure changes.

Currently, this module limits itself to adding endpoints for external services and secrets derived from terraform execution.

In the future, we are very likely to add node labels as well.

# Usage

## Input Variables

- endpoints: Array of external services with each entry having the following format:
  - domain: Name the service will have internally in the kubernetes cluster
  - ip: External ip of the service
  - port: Port the external service can be reached at
- secrets: Array of secrets with each entry taking the following format:
  - name: Name of the secret
    attributes: Map of key-value pairs defining the secret's attributes
- bastion_external_ip: ip the bastion can be sshed from
- bastion_key_pair: Ssh key that can be used to ssh on the bastion
- artifacts_path: Path on the bastion where the **kubectl** binary and **admin.conf** file are located
- manifests_path: Path where the kubernetes manifest files should be uploaded before getting applied. This path will get cleaned up afterwards.
- kubernetes_installation_id: ID uniquely identified the kubernetes installation. Useful to set an ordering dependency and also to retrigger provisioning when the kubernetes installation changes.
- kubernetes_namespace: Namespace the generated resources should be created under. Defaults to 'default'

## Usage Example

Here is an example of how the module might be used:

```
module "kubernetes_installation" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kubernetes-installation.git?ref=feature/output-installation-id"
  master_ips = [for master in module.kubernetes_cluster.masters: master.ip]
  worker_ips = [for worker in module.kubernetes_cluster.workers: worker.ip]
  bastion_external_ip = openstack_networking_floatingip_v2.bastion_floating_ip.address
  load_balancer_external_ip = openstack_networking_floatingip_v2.k8_api_lb_floating_ip.address
  bastion_key_pair = openstack_compute_keypair_v2.bastion_external_keypair
  kubespray_path = "/home/ubuntu/kubespray"
  kubespray_artifacts_path = "/home/ubuntu/kubespray-artifacts"
  cloud_init_sync_path = "/home/ubuntu/cloud-init-sync"
  bastion_dependent_ip = module.bastion.internal_ip
  wait_on_ips = [module.kubernetes_cluster.load_balancer.ip]
}

module "aidbox_postgres" {
  source = "git::https://github.com/Ferlab-Ste-Justine/openstack-postgres-standalone.git"
  namespace = "aidbox"
  image_id = module.ubuntu_bionic_image.id
  flavor_id = module.reference_infra.flavors.micro.id
  keypair_name = openstack_compute_keypair_v2.bastion_internal_keypair.name
  network_name = module.reference_infra.networks.internal.name
  postgres_image = "aidbox/db:11.1.0"
  postgres_user = "myuser"
  postgres_database = "devbox"
}

module "k8_infra_conf" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kubernetes-infrastructure-configuration.git"
  endpoints = [
    {
      domain="aidbox-db"
      ip=module.aidbox_postgres.ip
      port="5432"
    }
  ]
  secrets = [
    {
      name = "aidox-db-credentials"
      attributes = {
        username="myuser"
        password=module.aidbox_postgres.db_password
      }
    }
  ]
  bastion_external_ip = openstack_networking_floatingip_v2.bastion_floating_ip.address
  bastion_key_pair = openstack_compute_keypair_v2.bastion_external_keypair
  artifacts_path = "/home/ubuntu/kubespray-artifacts"
  manifests_path = "/home/ubuntu/infrastructure-manifests"
  kubernetes_installation_id = module.kubernetes_installation.id
}
```