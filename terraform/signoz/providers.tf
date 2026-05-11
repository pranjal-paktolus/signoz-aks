terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateaksgitops"
    container_name       = "tfstate"
    key                  = "signoz.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}
