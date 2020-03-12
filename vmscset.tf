# Deploy a VM scale set on Azure with a load balancer

provider "azurerm" {
version = "1.44.0"
}

resource "azurerm_resource_group" "gft-demo-ss" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"
  tags     = "${var.tags}"
}

resource "random_string" "gft-dn" {
  length  = 6
  special = false
  upper   = false
  number  = false
}

resource "azurerm_virtual_network" "gft-demo-ss" {
  name                = "gft-demo-ss-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.gft-demo-ss.name}"
  tags                = "${var.tags}"
}

resource "azurerm_subnet" "gft-demo-ss" {
  name                 = "gft-demo-ss-subnet"
  resource_group_name  = "${azurerm_resource_group.gft-demo-ss.name}"
  virtual_network_name = "${azurerm_virtual_network.gft-demo-ss.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "gft-demo-ss" {
  name                         = "gft-demo-ss-public-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.gft-demo-ss.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${random_string.gft-dn.result}"
  tags                         = "${var.tags}"
}

resource "azurerm_lb" "gft-demo-ss" {
  name                = "gft-demo-ss-lb"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.gft-demo-ss.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.gft-demo-ss.id}"
  }

  tags = "${var.tags}"
}

resource "azurerm_lb_backend_address_pool" "bkndpool" {
  resource_group_name = "${azurerm_resource_group.gft-demo-ss.name}"
  loadbalancer_id     = "${azurerm_lb.gft-demo-ss.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "gft-demo-ss" {
  resource_group_name = "${azurerm_resource_group.gft-demo-ss.name}"
  loadbalancer_id     = "${azurerm_lb.gft-demo-ss.id}"
  name                = "ssh-running-probe"
  port                = "${var.application_port}"
}

resource "azurerm_lb_rule" "lbrule" {
  resource_group_name            = "${azurerm_resource_group.gft-demo-ss.name}"
  loadbalancer_id                = "${azurerm_lb.gft-demo-ss.id}"
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = "${var.application_port}"
  backend_port                   = "${var.application_port}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bkndpool.id}"
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = "${azurerm_lb_probe.gft-demo-ss.id}"
}

resource "azurerm_virtual_machine_scale_set" "gft-demo-ss" {
  name                = "vmscaleset"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.gft-demo-ss.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_B1ms"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "gft-demo-ss-web"
    admin_username       = "${var.admin_user}"
    admin_password       = "${var.admin_password}"
    custom_data          = "${file("web.conf")}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = "${azurerm_subnet.gft-demo-ss.id}"
	  primary  								 = true
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bkndpool.id}"]
    }
  }

  tags = "${var.tags}"
}

resource "azurerm_public_ip" "gft-demo-jb" {
  name                         = "gft-demo-jb-public-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.gft-demo-ss.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${random_string.gft-dn.result}-ssh"
  tags                         = "${var.tags}"
}

resource "azurerm_network_interface" "gft-demo-jb" {
  name                = "gft-demo-jb-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.gft-demo-ss.name}"

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = "${azurerm_subnet.gft-demo-ss.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.gft-demo-jb.id}"
  }

  tags = "${var.tags}"
}

resource "azurerm_virtual_machine" "gft-demo-jb" {
  name                  = "gft-demo-jb"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.gft-demo-ss.name}"
  network_interface_ids = ["${azurerm_network_interface.gft-demo-jb.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "gft-demo-jb-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "gft-demo-jb"
    admin_username = "${var.admin_user}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = "${var.tags}"
}