provider "azurerm" {
  features {}
  subscription_id = "99c360d5-5a1d-45b7-93ae-80a16feaccb7"
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
  size                = "Standard_B1s"

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
