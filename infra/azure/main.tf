resource "random_string" "random_prefix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
  numeric = false
}

resource "azurerm_resource_group" "tsb_single_vm" {
  name     = "${var.resource_group_name}}-${random_string.random_prefix.result}"
  location = var.region
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_group_name}-vnet"
  resource_group_name = azurerm_resource_group.tsb_single_vm.name
  location            = azurerm_resource_group.tsb_single_vm.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.resource_group_name}-subnet"
  resource_group_name  = azurerm_resource_group.tsb_single_vm.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "${var.vm_name}-public-ip"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  tags                = var.tags
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.tsb_single_vm.location
  resource_group_name = azurerm_resource_group.tsb_single_vm.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "single_vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.tsb_single_vm.name
  location            = azurerm_resource_group.tsb_single_vm.location
  size                = var.vm_machine_type
  admin_username      = var.ssh.user
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  custom_data = base64encode(templatefile("${path.module}/templates/docker-cloud-init.tpl", {
    hostname    = var.vm_name
    docker_port = var.docker_port
    ssh_user    = var.ssh.user
  }))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.ssh.user
    public_key = file(var.ssh.key)
  }



  tags = var.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.resource_group_name}-nsg"
  location            = azurerm_resource_group.tsb_single_vm.location
  resource_group_name = azurerm_resource_group.tsb_single_vm.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DOCKER_DAEMON"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2376"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "KUBERNETES_API"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "null_resource" "wait_for_docker_ready" {
  triggers = {
    instance_id = azurerm_linux_virtual_machine.single_vm.id
    always_run  = timestamp()
  }
  provisioner "local-exec" {
    command     = <<EOT
      count=0
      max_count=30
      until echo > /dev/tcp/${azurerm_public_ip.vm_public_ip.ip_address}/${var.docker_port} || [ $count -eq $max_count ]; do
        echo "Waiting for port ${var.docker_port}... (count: $count)"
        sleep 10
        count=$((count+1))
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [azurerm_linux_virtual_machine.single_vm]
}
