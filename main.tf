
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.13.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "a9ab978b-a5d4-42b1-a453-fe2690ceb40f"
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


# Get your Packer Image (same as LB config)
data "azurerm_image" "packer_image" {
  name                = "CDTestPackerImage"
  resource_group_name = data.azurerm_resource_group.main.name
}

# Public IP
resource "azurerm_public_ip" "vm_ip" {
  name                = "singlevm-public-ip"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NSG
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "singlevm-nsg"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network
resource "azurerm_virtual_network" "vnet" {
  name                = "singlevm-vnet"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = ["10.90.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "singlevm-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.90.1.0/24"]
}

# NIC
resource "azurerm_network_interface" "nic" {
  name                = "singlevm-nic"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# ✅ VM Using Packer Image
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "self-host-agent"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = "Standard_B2s"

  admin_username                  = var.admin_username
  admin_password                  = "Staple17121980@"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  # ✅ Use your packer image
  source_image_id = data.azurerm_image.packer_image.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  custom_data = base64encode(templatefile("${path.module}/agent_install.sh", {
    ADO_URL     = var.azdo_url
    PAT_TOKEN   = var.azdo_pat
    POOL_NAME   = var.azdo_pool
    ADMIN_USER  = var.admin_username
    AGENT_FILE  = "vsts-agent-linux-x64-4.264.2.tar.gz"
    AGENT_URL   = "https://download.agent.dev.azure.com/agent/4.264.2/vsts-agent-linux-x64-4.264.2.tar.gz"
    VM_NAME = "self-host-agent"
  }))
}

output "public_ip" {
  value = azurerm_public_ip.vm_ip.ip_address
}


# New VM for selenium test
#############################################
# Public IP for Selenium VM
#############################################
resource "azurerm_public_ip" "selenium_ip" {
  name                = "seleniumvm-public-ip"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

#############################################
# NSG for Selenium VM
#############################################
resource "azurerm_network_security_group" "selenium_nsg" {
  name                = "seleniumvm-nsg"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#############################################
# NIC for Selenium VM
#############################################
resource "azurerm_network_interface" "selenium_nic" {
  name                = "seleniumvm-nic"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.selenium_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "selenium_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.selenium_nic.id
  network_security_group_id = azurerm_network_security_group.selenium_nsg.id
}

#############################################
# Selenium Linux VM
#############################################
resource "azurerm_linux_virtual_machine" "selenium_vm" {
  name                = "selenium-test-vm"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = "Standard_B1s"

  admin_username                  = "ManuMP"
  admin_password                  = "Staple17121980@"   # Change this
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.selenium_nic.id
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Simple cloud-init; replace with Selenium install script later
  custom_data = base64encode(
    file("${path.module}/dependency_install.sh")
  )
  
  # Add tags here
  tags = {
    selenium = "true"
  }
}

output "selenium_vm_public_ip" {
  value = azurerm_public_ip.selenium_ip.ip_address
}



#############################################
# Log analytics for selinium logs
#############################################

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-selenium-udacity-x"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_data_collection_endpoint" "selenium_dce" {
  name                = "selenium-dce-udacity-x"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
}


resource "azapi_resource" "data_collection_logs_table" {
  name      = "SeleniumLogs_CL"
  parent_id = azurerm_log_analytics_workspace.law.id
  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"

  body = jsonencode({
    properties = {
      schema = {
        name = "SeleniumLogs_CL"
        columns = [
          {
            name        = "TimeGenerated"
            type        = "datetime"
            description = "Log timestamp"
          },
          {
            name        = "RawData"
            type        = "string"
            description = "Entire raw log line"
          }
        ]
      }
      retentionInDays      = 30
      totalRetentionInDays = 30
    }
  })
}


resource "azurerm_monitor_data_collection_rule" "selenium_dcr" {

  name                = "selenium-custom-log-dcr"
  location            = var.resource_location
  resource_group_name = data.azurerm_resource_group.main.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.selenium_dce.id

	# Explicit dependency
	
  depends_on = [
    azurerm_monitor_data_collection_endpoint.selenium_dce,
	azapi_resource.data_collection_logs_table
  ]
  
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
      name                  = "law-destination"
    }
  }

  data_sources {
    log_file {
      name = "selenium-file-source"

      file_patterns = [
        "/var/log/selenium/*.log"
      ]

      format = "text"  # can be json, text, csv
	  
	  streams = [
		"Custom-SeleniumLogs_CL"
      ]

      settings {
        text {
          record_start_timestamp_format = "ISO 8601"
        }
      }
    }
  }

  data_flow {
    streams      = ["Custom-SeleniumLogs_CL"]
    destinations = ["law-destination"]
  }
}


resource "azurerm_virtual_machine_extension" "ama" {
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.selenium_vm.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = true
  
  depends_on = [
    azurerm_monitor_data_collection_rule.selenium_dcr,
	azurerm_linux_virtual_machine.selenium_vm
  ]
}



resource "azurerm_monitor_data_collection_rule_association" "dcr_vm" {
  name                    = "selenium-dcr-association"
  target_resource_id      = azurerm_linux_virtual_machine.selenium_vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.selenium_dcr.id
  
  depends_on = [
    azurerm_virtual_machine_extension.ama
  ]
}

resource "azurerm_monitor_data_collection_rule_association" "dce_vm" {
  name                         = "configurationAccessEndpoint"
  target_resource_id           = azurerm_linux_virtual_machine.selenium_vm.id
  data_collection_endpoint_id  = azurerm_monitor_data_collection_endpoint.selenium_dce.id
  
    depends_on = [
    azurerm_virtual_machine_extension.ama
  ]
}




