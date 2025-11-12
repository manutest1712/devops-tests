provider "azurerm" {
  features {}
  subscription_id = "51003162-956a-4e6f-877b-3d0d913c7ca1"
}

data "azurerm_resource_group" "main" {
  name = "Azuredevops"
}

# App Service Plan
resource "azurerm_app_service_plan" "asp" {
  name                = var.app_service_plan_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
 
  # For Linux/web apps set kind = "Linux" and reserved = true
  # We'll create a Windows app (default). To use Linux, uncomment reserved & kind and adjust runtime accordingly.
  # kind     = "Linux"
  # reserved = true

  kind = "Linux"
  reserved = true

  sku {
    tier = "PremiumV3"
    size = "P1v3"
  }

  # number of workers for scale-out if supported by SKU
  maximum_elastic_worker_count = null
  tags = var.common_tags
}

# App Service (Web App)
resource "azurerm_app_service" "web" {
  name                = var.app_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.asp.id

  site_config {
    # Example: when deploying a Linux container, this is where you'd set linux_fx_version
    # Example for Python on Linux (if using Linux reserved):
    # linux_fx_version = "PYTHON|3.9"

    # Example app settings
    always_on = false
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "0"  # change if using zip deployment from storage
    "ENV"                      = "dev"
  }

  tags = var.common_tags
}