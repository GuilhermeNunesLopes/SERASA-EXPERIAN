#configurando o terraform e o provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

provider "azurerm" {
  features {}
}

#Criando o grupo de recurso no caso chamaremos de Teste-Serasa

resource "azurerm_resource_group" "teste-serasa" {
  #nomeando o resource group
  name = "SeExperian_GNL"
  #setando a região ao resource group
  location = "westus2"
}

#Criando uma Rede dentro do resource group

resource "azurerm_virtual_network" "teste-serasa" {
  name = "SeExperian_GNL_NET"
  #vinculando a rede ao resource group criado anteriormente
  resource_group_name = azurerm_resource_group.teste-serasa.name
  #vinculando a rede a região de West US 2
  location = azurerm_resource_group.teste-serasa.location
  address_space       = ["10.20.10.0/24"]
}

#Criando o a máquina