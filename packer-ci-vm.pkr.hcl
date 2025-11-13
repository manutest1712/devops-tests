packer {
  required_plugins {
    azure = {
      version = ">= 1.7.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "client_id" {
    type    = string
    default = "312d979d-dcd8-481e-8cac-2df7056c7146"
}
variable "client_secret" {
    type    = string
    default = "9GZ8Q~HyZ5xIKmaGNJuJ4UNKAP.Zy4l0Ps4UBaB-"
}
variable "tenant_id" {
    type    = string
    default = "f958e84a-92b8-439f-a62d-4f45996b6d07"
}
variable "subscription_id" {
    type    = string
    default = "99c360d5-5a1d-45b7-93ae-80a16feaccb7"
}

# Optional if you want to pass Azure DevOps config via environment
variable "azdo_url" {
  type    = string
  default = "https://dev.azure.com/YOUR_ORG"
}
variable "azdo_pat" {
  type    = string
  default = "YOUR_PERSONAL_ACCESS_TOKEN"
}
variable "azdo_pool" {
  type    = string
  default = "default"
}

source "azure-arm" "ubuntu" {
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  tenant_id                         = var.tenant_id
  subscription_id                   = var.subscription_id

  managed_image_resource_group_name = "Azuredevops"
  managed_image_name                = "CDTestPackerImage"
  location                          = "eastus"
  vm_size                           = "Standard_B2s"

  os_type        = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "latest"

  ssh_username = "azureuser"
}

build {
  name    = "ubuntu-docker-agent"
  sources = ["source.azure-arm.ubuntu"]

  # Step 1: Install Docker and reboot for group changes
  provisioner "shell" {
    inline = [
      "sudo snap install docker",
      "python3 --version",
      "sudo apt update -y",
      "sudo groupadd docker || true",
      "sudo usermod -aG docker $USER",
      "echo '*** Rebooting VM to apply Docker group changes ***'",
      "sudo reboot"
    ]
    expect_disconnect = true
  }

  provisioner "shell" {
    pause_before = "45s"
    inline = [
      "echo '*** VM reboot complete ***'"
    ]
  }

  # Step 2: Install Azure DevOps agent and Python dependencies
  provisioner "shell" {
    inline = [
      "set -e",
      "sudo mkdir -p /opt/azure-agent",
      "cd /opt/azure-agent",
      "sudo curl -L -o vsts-agent-linux-x64-4.264.2.tar.gz https://download.agent.dev.azure.com/agent/4.264.2/vsts-agent-linux-x64-4.264.2.tar.gz",
      "sudo tar zxvf vsts-agent-linux-x64-4.264.2.tar.gz",
      "",
      "echo 'Agent extracted'",
      "sudo apt-get update -y",
      "sudo apt install -y software-properties-common",
      "sudo add-apt-repository -y ppa:deadsnakes/ppa",
      "sudo apt install -y python3-pip python3-venv python3.7-distutils zip",
      "echo 'Installation over. Now the VM can be created'"
    ]
  }

  # Optional cleanup to reduce image size
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "echo '*** Image cleanup done ***'"
    ]
  }
}
