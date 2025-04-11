terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

data "azurerm_shared_image" "devbox-image" {
  name                = var.imagename 
  gallery_name        = var.galleryname  
  resource_group_name = var.imageresgrp  
}
# 1. Resource Group (reuse if already exists)
resource "azurerm_resource_group" "devbox-rg" {
  name     = var.resourcegroup
  location = var.location
}
resource "azurerm_virtual_network" "devbox-vnet" {
  name                = var.vnetname
  depends_on          = [ azurerm_network_security_group.devbox-nsg ]
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resourcegroup
}

resource "azurerm_subnet" "devbox-subnet" {
  name                 = var.subnetname
  depends_on = [ azurerm_virtual_network.devbox-vnet ]
  resource_group_name  = var.resourcegroup
  virtual_network_name = var.vnetname
  address_prefixes     = ["10.0.2.0/24"]
 # service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]
}

resource "azurerm_public_ip" "devbox-pip" {
  name                = var.publicipname
  depends_on = [ azurerm_subnet.devbox-subnet ]
  location            = var.location
  resource_group_name = var.resourcegroup
  allocation_method   = "Dynamic"
  domain_name_label   = "examplelabel121"
}

resource "azurerm_network_security_group" "devbox-nsg" {
  name                = var.nsgname
  depends_on = [ azurerm_virtual_network.devbox-vnet ]
  location            = var.location
  resource_group_name = var.resourcegroup

  security_rule {
    name                       = "allow-ssh"
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
    name                       = "allow-rdp"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "devbox-nic" {
  name                = var.nicname
  depends_on          = [ azurerm_public_ip.devbox-pip, azurerm_subnet.devbox-subnet ]
  location            = var.location
  resource_group_name = var.resourcegroup

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.devbox-subnet.id
    private_ip_address_allocation = "Dynamic"
       public_ip_address_id         = azurerm_public_ip.devbox-pip.id
  }
}

# 3. Deploy the VM
resource "azurerm_windows_virtual_machine" "devbox-vm" {
  name                = var.vmname
  depends_on          = [ azurerm_network_interface.devbox-nic ]
  resource_group_name = var.resourcegroup
  location            = var.location
  size                = "Standard_D2s_v4"
  admin_username      = var.adminusername
  admin_password      = var.adminpassword
  network_interface_ids = [
    azurerm_network_interface.devbox-nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = data.azurerm_shared_image.devbox-image.id
}
# 4. Optional: Run script after provisioning
resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = var.customscriptname
  virtual_machine_id   = azurerm_windows_virtual_machine.devbox-vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    fileUris = ["https://raw.githubusercontent.com/narinani225/temp/main/CombinedScript.ps1"]
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -File CombinedScript.ps1"
  })

  depends_on = [azurerm_windows_virtual_machine.devbox-vm]
}
