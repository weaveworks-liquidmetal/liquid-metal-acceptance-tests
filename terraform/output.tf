output "project_name" {
  value = metal_project.liquid_metal_demo.name
}
output "management_cluster_ip" {
  value = metal_device.management_cluster.network.0.address
}
output "host_ips" {
  value = metal_device.host.*.network.0.address
}

output "terraform_state_location" {
  value = <<EOV
${path.cwd}/terraform.tfstate.d/${terraform.workspace}/terraform.tfstate
EOV
}
