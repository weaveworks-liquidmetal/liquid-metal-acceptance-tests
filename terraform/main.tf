module "create_devices" {
  source  = "weaveworks-liquidmetal/liquidmetal/equinix"
  version = "0.0.2"

  project_name = var.project_name
  public_key = var.public_key
  org_id = var.org_id
  metal_auth_token = var.metal_auth_token
  microvm_host_device_count = var.microvm_host_device_count
  metro = var.metro
  server_type = var.server_type
  operating_system = var.operating_system
}

module "provision_hosts" {
  source  = "weaveworks-liquidmetal/liquidmetal/equinix//modules/provision-lmats"
  version = "0.0.2"

  private_key_path = var.private_key_path
  microvm_host_device_count = var.microvm_host_device_count
  flintlock_version = var.flintlock_version
  firecracker_version = var.firecracker_version

  vlan_id = module.create_devices.vlan_id
  network_hub_address = module.create_devices.network_hub_ip
  microvm_host_addresses = module.create_devices.microvm_host_ips
}

# required variables pulled from terraform.tfvars.json
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "org_id" {
  description = "Org id"
  type        = string
}

variable "metal_auth_token" {
  description = "Auth token"
  type        = string
  sensitive   = true
}

variable "public_key" {
  description = "public key to add to hosts"
  type        = string
}

variable "private_key_path" {
  description = "the path to the private key to use for SSH"
  type        = string
  sensitive   = true
}

# optional variables with defaults
variable "flintlock_version" {
  description = "flintlock version"
  type        = string
  default = "latest"
}

variable "firecracker_version" {
  description = "firecracker version"
  type        = string
  default = "latest"
}

variable "microvm_host_device_count" {
  description = "The number of devices to provision as flintlock hosts."
  type        = number
  default     = 2
}

variable "metro" {
  description = "The metro to create devices in"
  type        = string
  default     = "fr"
}

variable "server_type" {
  description = "The type of device to create"
  type        = string
  default     = "c3.small.x86"
}

variable "operating_system" {
  description = "The OS to install on the devices"
  type        = string
  default     = "ubuntu_20_04"
}

# outputs used by tests do not rename
# i mean it claudia just don't do it
output "management_ip" {
  value = module.create_devices.network_hub_ip
  description = "The address of the device created to act as a networking and management hub"
}

output "microvm_host_ips" {
  value = module.create_devices.microvm_host_ips
  description = "The addresses of the devices provisioned as flintlock microvm hosts"
}
