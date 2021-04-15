variable "services" {
  description = "Array of services abstracting external resources from the cluster, each entry defined by the following keys: name, ips, headless, port"
  type = list(any)
  default = []
}

variable "secrets" {
  description = "Array of secrets defined as the following structure: [{name=... , namespace=..., attributes={...}}, ...]"
  type = list(any)
  default = []
}

variable "configmaps" {
  description = "Array of configmaps defined as the following structure: [{name=... , namespace=..., attributes={...}}, ...]"
  type = list(any)
  default = []
}

variable "namespaces" {
  description = "Array of namespaces"
  type = list(string)
  default = []
}

variable "flux_instances" {
  description = "Instances of fluxcd that will be running on the kubernetes cluster"
  type = list(any)
  default = []
}

variable "bastion_external_ip" {
  description = "External ip of the bastion"
  type = string
}

variable "bastion_port" {
  description = "Ssh port the bastion uses"
  type = number
  default = 22
}

variable "bastion_user" {
  description = "User to ssh on the bastion as"
  type = string
  default = "ubuntu"
}

variable "bastion_key_pair" {
  description = "SSh key pair"
  type = any
}

variable "artifacts_path" {
  description = "Directory where kubernetes management artifacts (admin.conf file and kubectl binary) can be found on the bastion"
  type = string
}

variable "manifests_path" {
  description = "Directory to store the manifests in"
  type = string
}

variable "kubernetes_installation_id" {
  description = "ID of the kubernetes installation task. Used to trigger reprovisioning and establish dependency"
  type = string
}

variable "kubernetes_namespace" {
  description = "Default namespace where resources are created"
  type = string
  default = "default"
}

variable "kubernetes_metadata_identifier" {
  description = "Metadata property that is used to identify and cleanup dangling kubernetes resources generated by previous invocations of the module"
  type = string
  default = "source"
}