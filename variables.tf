variable "endpoints" {
  description = "Array of endpoints abstracting external resources from the cluster, each entry defined by the following keys: domain, ip, port"
  type = list(any)
  default = []
}

variable "secrets" {
  description = "Array of secrets defined as the following structure: [{name=... , attributes={...}}, ...]"
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
  description = "Namespace where resources are created"
  type = string
  default = "default"
}