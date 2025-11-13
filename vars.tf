
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