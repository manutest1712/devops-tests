output "resource_group_name" {
  description = "The name of the Resource Group where resources are deployed"
  value       = data.azurerm_resource_group.main.name
}
