# About

This terraform module provision kubernetes resources that are highly coupled with the infrastructure and will change as the infrastructure changes.

Supports the creation of the following kubernetes resources:
- namespaces
- services and endpoints derived from external services
- secrets derived from terraform execution
- fluxcd (version 1) instances

# Usage

## Input Variables
- namespaces: Array of namespaces to create
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
  - git_poll_interval: Interval at which the git repository should be polled for new commits. Defaults to '5m'.
  - garbage_collection: Determine if flux will garbage collect resources it created that are no longer present in the git reference repo. Defaults to 'true'.
  - image_pull_secret: Optional name of secret containing credentials to pull images from registries
  - image_pull_filename: File name of the configuration file containing the credentials to pull images
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
module "k8_v1_19_3_alpha_infra_conf" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kubernetes-infrastructure-configuration.git"
  namespaces = [
    "flux-clin-qa",
    "flux-cqdg-qa"
  ]
  services = [
    {
      name = "keycloak-db"
      namespace = "default"
      ips = module.keycloak_postgres.ip
      headless = false
      port = "5432"
    },
    {
      name = "elasticsearch-workers"
      namespace = "default"
      ips = join(",", [for worker in module.elasticsearch_cluster.workers: worker.ip])
      headless = false
      port = "9200"
    },
    {
      name = "mongodb-replicaset-lectern-${var.namespace}-1"
      namespace = "default"
      ips = module.lectern_db.replicas.0.ip
      headless = true
      port = "27017"
    },
    {
      name = "mongodb-replicaset-lectern-${var.namespace}-2"
      namespace = "default"
      ips = module.lectern_db.replicas.1.ip
      headless = true
      port = "27017"
    },
    {
      name = "mongodb-replicaset-lectern-${var.namespace}-3"
      namespace = "default"
      ips = module.lectern_db.replicas.2.ip
      headless = true
      port = "27017"
    }
  ]
  secrets = [
    {
      name = "keycloak-db-credentials"
      namespace = "default"
      attributes = {
        username = "mydbadmin"
        password = module.keycloak_postgres.db_password
      }
    },
    {
      name = "lectern-db-credentials"
      namespace = "default"
      attributes = {
        username = "mydbadmin"
        password = module.lectern_db.admin_password
      }
    },
    {
      name = "flux-git-deploy"
      namespace = "flux-clin-qa"
      attributes = {
        identity = var.flux_private_key
      }
    },
    {
      name = "flux-git-deploy"
      namespace = "flux-cqdg-qa"
      attributes = {
        identity = var.flux_private_key
      }
    }
  ]
  flux_instances = [
    {
      namespace = "flux-clin-qa"
      repository = "git@github.com:Ferlab-Ste-Justine/clin-environments.git"
      branch = "master"
      path = "qa"
    },
    {
      namespace = "flux-cqdg-qa"
      repository = "git@github.com:Ferlab-Ste-Justine/cqdg-environments.git"
      branch = "master"
      path = "qa"
    }
  ]
  bastion_external_ip = var.bastion_external_ip
  bastion_key_pair = var.bastion_external_keypair
  artifacts_path = "/home/ubuntu/${var.namespace}/k8-v1.19.3-alpha/kubespray-artifacts"
  manifests_path = "/home/ubuntu/${var.namespace}/k8-v1.19.3-alpha/infrastructure-manifests"
  kubernetes_installation_id = module.kubernetes_v1_19_3_alpha_installation.id
}
```