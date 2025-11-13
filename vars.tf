
variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "testsss"
}

variable "app_name" {
  description = "Name of the Web App (must be globally unique for some SKUs)"
  type        = string
  default     = "myappdemoservic123"
}

variable "app_service_sku" {
  description = "SKU for the App Service Plan (tier/size)"
  type        = string
  default     = "B1" # Free tier for demo. Use S1/P1V2 for production
}

variable "worker_count" {
  description = "Number of workers (for scale-out). Only applies to certain SKUs"
  type        = number
  default     = 1
}

variable "common_tags" {
  type = map(string)
  default = {
    environment = "dev"
    owner       = "terraform"
  }
}

variable "resource_location" {
  description = "Location of the resources"
  type        = string
  default     = "eastus"
}

# Optional if you want to pass Azure DevOps config via environment
variable "azdo_url" {
  type    = string
  default = "https://dev.azure.com/odluser289853"
}
variable "azdo_pat" {
  type    = string
  default = "93uxqIfCeo7AJAsKzB2fCPATNeaMinqKZIrcoKJs79K0sBsGSksUJQQJ99BKACAAAAAPDBwgAAASAZDO4dKJ"
}
variable "azdo_pool" {
  type    = string
  default = "myAgentPool"
}

variable "admin_username" {
  type    = string
  default = "ManuMP"
}
