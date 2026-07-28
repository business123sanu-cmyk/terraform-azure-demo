############################
# Resource Group
############################

resource "azurerm_resource_group" "rg" {
  name     = "terraform-rg"
  location = var.location
}

############################
# Virtual Network
############################

resource "azurerm_virtual_network" "vnet" {
  name                = "terraform-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

############################
# Subnet
############################

resource "azurerm_subnet" "subnet" {
  name                 = "terraform-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

############################
# NSG
############################

resource "azurerm_network_security_group" "nsg" {
  name                = "terraform-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
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

############################
# Public IP
############################

resource "azurerm_public_ip" "pip" {
  count               = 2
  name                = "vm-pip-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

############################
# NIC
############################

resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "vm-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}

############################
# Associate NSG
############################

resource "azurerm_network_interface_security_group_association" "assoc" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

############################
# Linux VM
############################

resource "azurerm_linux_virtual_machine" "vm" {
  count               = 2
  name                = "linux-vm-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2s"

  admin_username = var.admin_username

  disable_password_authentication = false
  admin_password                  = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name = "linuxvm${count.index + 1}"
}

############################
# Data Disk
############################

resource "azurerm_managed_disk" "disk" {
  count               = 2
  name                = "data-disk-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  storage_account_type = "Premium_LRS"

  create_option = "Empty"

  disk_size_gb = 50
}

############################
# Attach Data Disk
############################

resource "azurerm_virtual_machine_data_disk_attachment" "attach" {
  count = 2

  managed_disk_id    = azurerm_managed_disk.disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[count.index].id

  lun     = 0
  caching = "ReadWrite"
}
