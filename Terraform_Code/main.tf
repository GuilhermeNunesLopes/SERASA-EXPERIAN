#configurando o terraform e o provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}
#Utilizando a Feature do Azure Resource Manager para provisionar a infra
provider "azurerm" {
  features {}
}

#Criando o grupo de recurso que caso chamaremos de Teste-Serasa

resource "azurerm_resource_group" "teste-serasa" {
  #nomeando o resource group
  name = "SeExperian_GNL"
  #setando a região ao resource group Oeste 2 dos Estados Unidos
  location = "westus2"
}

#Criando uma Rede dentro do resource group

resource "azurerm_virtual_network" "VNET-teste-serasa" {
  name = "SeExperian_GNL_NET"
  #vinculando a rede ao resource group criado anteriormente
  resource_group_name = azurerm_resource_group.teste-serasa.name
  #vinculando a rede a região de West US 2
  location = azurerm_resource_group.teste-serasa.location
  #Determinando a rede da VNET
  address_space       = ["10.20.0.0/16"]
}

#Criando subnet interna

resource "azurerm_subnet" "interno" {
  name                 = "interno-serasa"
  #Vinculando a subrede ao grupo de recursos
  resource_group_name  = azurerm_resource_group.teste-serasa.name
  #Vinculando a subrede a VNET principal
  virtual_network_name = azurerm_virtual_network.VNET-teste-serasa.name
  address_prefixes     = ["10.20.1.0/24"]
}
#Criando um ip publico
resource "azurerm_public_ip" "public-ip-serasa-teste" {
  name                = "Ip_Publico_SeExperian"
   #Vinculando a subrede ao grupo de recursos
  resource_group_name = azurerm_resource_group.teste-serasa.name
   #Determinando que o public IP será setado na região que o Resource group foi criado no caso OESTE 2 US
  location            = azurerm_resource_group.teste-serasa.location
  #Determinando que o tipo de alocação será Estático, ou seja, não irá mudar uma vez provisionado.
  allocation_method   = "Static"
  #Setando o ip como IPV4
  ip_version = "IPv4"
   #Colocando uma TAG ao ip plublico
  tags = {
    environment = "IP da Aplicação Go"
  }
}

#criando uma interface de rede e vinculando a subnet
resource "azurerm_network_interface" "interface-serasa-teste" {
  #Dando um nome a interface de rede
  name                = "interface-appgo"
  #solicitando a criação na mesma região que o resource group
  location            = azurerm_resource_group.teste-serasa.location
  #vinculando a interface ao resource group
  resource_group_name = azurerm_resource_group.teste-serasa.name

#Determinando as configurações de ips
  ip_configuration {
    #O nome da interface
    name                          = "internal"
    #vinculando a interface a subnet criada anteriormente
    subnet_id                     = azurerm_subnet.interno.id
    #determinando que o ip privado que a interface ganhará será dinamico, ou seja, será distribuido via DHCP
    private_ip_address_allocation = "Dynamic"
    #vinculando o ip publico a interface de rede
    public_ip_address_id = azurerm_public_ip.public-ip-serasa-teste.id
  }
}

#criando um security group - firewall a nivel de vm
resource "azurerm_network_security_group" "NSG" {
  name                = "Protege_Teste"
  location            = azurerm_resource_group.teste-serasa.location
  resource_group_name = azurerm_resource_group.teste-serasa.name
#Neste ponto setei uma regra ALL para todas as portas TCPs de prioridade 100 ou seja a primeira prioridade onde ela libera a entrada apartir de qualquer destino em qualquer porta para facilitar os testes.
  security_rule {
    name                       = "Libera"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Aplicação Go"
  }
}

#Vinculando um security group a interface de rede.
resource "azurerm_network_interface_security_group_association" "SG_A" {
  network_interface_id      = azurerm_network_interface.interface-serasa-teste.id
  network_security_group_id = azurerm_network_security_group.NSG.id
}


#criando instância
resource "azurerm_linux_virtual_machine" "instance-go" {
  #Nomeando a instância
  name                = "App"
  #vinculando um resource group e uma região a VM 
  resource_group_name = azurerm_resource_group.teste-serasa.name
  location            = azurerm_resource_group.teste-serasa.location
  #Determinando o tier/tipo da instância e tamanho da instancia
  size                = "Standard_F2" 
  #Determinando que no momento da criação será criado o user adminuser
  admin_username      = "adminuser"
 /*Por padrão quando setamos o atributo admin_username temos que setar uma public key, 
  *como no caso para facilitar eu não queria criar uma chave, setei o parametro de desabilitar senha como falso, logo
  * preciso setar uma senha que tenha de [6-60] caracter com letras e números
  */
    disable_password_authentication = false
  #setei a senha que eu queria ao user adminuser
  admin_password = "@SeExperien2021rtgh"
  #utilizei o atributo network interface para vincular a interface criada acima que ja esta com o ip publico setado
    network_interface_ids = [
    azurerm_network_interface.interface-serasa-teste.id
      ]
#setei um disco padrão na azure
  os_disk {
    caching              = "ReadWrite"
#do modelo uso geral com redundancia local
    storage_account_type = "Standard_LRS"
  }

#Criei uma image baseada em CentOS 7.5 - https://docs.microsoft.com/pt-br/azure/virtual-machines/linux/cli-ps-findimage
  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5"
    version   = "latest"
  }

}

