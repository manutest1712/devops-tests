provider "azurerm" {
  features {}
  subscription_id = "de282839-e67a-4cbe-a2a6-de7145c67f52"
}

data "azurerm_resource_group" "main" {
  name = "Azuredevops"
}


# App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = var.app_service_plan_name
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name


  # For Linux/web apps set kind = "Linux" and reserved = true
  # We'll create a Windows app (default). To use Linux, uncomment reserved & kind and adjust runtime accordingly.
  # kind     = "Linux"
  # reserved = true
  sku_name = "F1"
  os_type  = "Linux"
  tags     = var.common_tags
}

resource "azurerm_linux_web_app" "main" {
  name                = var.app_name
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.asp.id
  site_config {
    application_stack {
      python_version = "3.12" # or node_version, dotnet_version, etc.
    }
    always_on = false
  }
  tags = var.common_tags
}