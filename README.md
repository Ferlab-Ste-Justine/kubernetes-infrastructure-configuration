# About

This terraform module provision kubernetes resources that are highly coupled with the infrastructure and will change as the infrastructure changes.

Currently, this module limits itself to adding endpoints for external services and secrets derived from terraform execution.

In the future, we are very likely to add node labels as well.

# Usage

## Input Variables

- services: Array of external services with each entry having the following format:
  - name: Name the service will have internally in the kubernetes cluster
  - ips: External ips of the service. To circumvent an observed bug in Terraform (on version 0.12.28), this needs to be passed in a single coma-separated string.
  - headless: Whether kubernetes should load-balancer the service behind an intermediate ip (if false) or whether it should just handle dns and return all external ips dns queries on the service name (if true)
  - port: Port the external service can be reached at
- secrets: Array of secrets with each entry taking the following format:
  - name: Name of the secret
  - namespace: Namespace of the secret
  - attributes: Map of key-value pairs defining the secret's attributes
- flux_instances: Array of fluxcd instances with each entry taking the following format:
  - namespace: Namespace of the flux instance. It should be pre-existing and contain a **flux-git-deploy** with an **identity** key containing a valid private ssh key for **user**
  - repository: Repository the flux instance should monitor
  - branch: Branch of the repository the flux instance should monitor
  - path: Directory path the flux instance should monitor
  - user: User the flux instance should access the git repository as
  - email: Email of the user the flux instance should access the git repository as
- bastion_external_ip: ip the bastion can be sshed from
- bastion_port: Port the bastion can be sshed from
- bastion_user: User the bastion should be sshed as
- bastion_key_pair: Ssh key that can be used to ssh on the bastion
- artifacts_path: Path on the bastion where the **kubectl** binary and **admin.conf** file are located
- manifests_path: Path where the kubernetes manifest files should be uploaded before getting applied. This path will get cleaned up afterwards.
- kubernetes_installation_id: ID uniquely identified the kubernetes installation. Useful to set an ordering dependency and also to retrigger provisioning when the kubernetes installation changes.
- kubernetes_namespace: Default namespace the generated resources should be created under if a more specific namespace is not specified. Defaults to 'default'
- kubernetes_metadata_identifier: Metadata label that will be included in generated resources. When the module runs, pre-existing resources with this metadata field that are not present in the resources bring provisioned will be cleaned up. Defaults to **source**.

## Usage Example

Here is an example of how the module might be used:

```
#Install Kubernetes
module "kubernetes_installation" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kubernetes-installation.git"
  master_ips = [for master in module.kubernetes_cluster.masters: master.ip]
  worker_ips = [for worker in module.kubernetes_cluster.workers: worker.ip]
  bastion_external_ip = openstack_networking_floatingip_v2.edge_reverse_proxy_floating_ip.address
  load_balancer_external_ip = openstack_networking_floatingip_v2.edge_reverse_proxy_floating_ip.address
  bastion_key_pair = openstack_compute_keypair_v2.bastion_external_keypair
  bastion_port = 2222
  provisioning_path = "/home/ubuntu/kubespray"
  artifacts_path = "/home/ubuntu/kubespray-artifacts"
  cloud_init_sync_path = "/home/ubuntu/cloud-init-sync"
  bastion_dependent_ip = module.bastion.internal_ip
  wait_on_ips = [module.edge_reverse_proxy.ip]
}

#Keycloak database
module "keycloak_postgres" {
  source = "git::https://github.com/Ferlab-Ste-Justine/openstack-postgres-standalone.git"
  namespace = "keycloak"
  image_id = module.ubuntu_bionic_image.id
  flavor_id = module.reference_infra.flavors.micro.id
  keypair_name = openstack_compute_keypair_v2.bastion_internal_keypair.name
  network_name = module.reference_infra.networks.internal.name
  postgres_image = "postgres:12.3"
  postgres_user = "postgres"
  postgres_database = "keycloak"
}

#Lectern database
module "lectern_db" {
  source = "git::https://github.com/Ferlab-Ste-Justine/openstack-mongodb-replicaset.git"
  namespace = "lectern"
  image_id = module.ubuntu_bionic_image.id
  flavor_id = module.reference_infra.flavors.nano.id
  network_name = module.reference_infra.networks.internal.name
  keypair_name = openstack_compute_keypair_v2.bastion_internal_keypair.name
  replicas_count = 3
  bastion_external_ip = openstack_networking_floatingip_v2.edge_reverse_proxy_floating_ip.address
  bastion_key_pair = openstack_compute_keypair_v2.bastion_external_keypair
  bastion_port = 2222
  setup_path = "/home/ubuntu/lectern-db-setup"
}

#Add kubernetes entities so that pods can talk to external keycloak and lectern databases
module "k8_infra_conf" {
  source = "./kubernetes-infrastructure-configuration" //"git::https://github.com/Ferlab-Ste-Justine/kubernetes-infrastructure-configuration.git?ref=feature/multi-ips-and-headless-services-support"
  services = [
    {
      name = "keycloak-db"
      ips = module.keycloak_postgres.ip
      headless = false
      port = "5432"
    },
    {
      name = "lectern-db"
      ips = join(",", [for replica in module.lectern_db.replicas: replica.ip])
      headless = true
      port = "27017"
    }
  ]
  #Note: A future security improvement here will be to create more limited database-specific users
  secrets = [
    {
      name = "keycloak-db-credentials"
      attributes = {
        username = "postgres"
        password = module.keycloak_postgres.db_password
      }
    },
    {
      name = "lectern-db-credentials"
      attributes = {
        username = "admin"
        password = module.lectern_db.admin_password
      }
    }
  ]
  bastion_external_ip = openstack_networking_floatingip_v2.edge_reverse_proxy_floating_ip.address
  bastion_key_pair = openstack_compute_keypair_v2.bastion_external_keypair
  bastion_port = 2222
  artifacts_path = "/home/ubuntu/kubespray-artifacts"
  manifests_path = "/home/ubuntu/infrastructure-manifests"
  kubernetes_installation_id = module.kubernetes_installation.id
}
```