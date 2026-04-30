terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.66.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }

  # Опционален backend - ако искате да съхранявате state в Azure
  #backend "azurerm" {
  #  resource_group_name  = "StorageRG"
  #  storage_account_name = "hmstorage2026"
  #  container_name       = "homiescontainer"
  #  key                  = "terraform.tfstate"
  #  use_azuread_auth     = true
  #}
}

provider "azurerm" {
  features {}
  subscription_id = "45ab7c0b-0483-4cfa-b5bb-498a103b8661"
}

# ─────────────────────────────────────────────────────────────
# RANDOM SUFFIX ЗА УНИКАЛНИ ИМЕНА
# ─────────────────────────────────────────────────────────────
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# ─────────────────────────────────────────────────────────────
# SSH КЛЮЧ (ГЕНЕРИРАН ОТ TERRAFORM)
# ─────────────────────────────────────────────────────────────
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ─────────────────────────────────────────────────────────────
# RESOURCE GROUP
# ─────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-nextcloud-demo-${random_string.suffix.result}"
  location = var.location
}

# ─────────────────────────────────────────────────────────────
# VIRTUAL NETWORK
# ─────────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-nextcloud-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

# ─────────────────────────────────────────────────────────────
# SUBNET
# ─────────────────────────────────────────────────────────────
resource "azurerm_subnet" "main" {
  name                 = "subnet-main"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ─────────────────────────────────────────────────────────────
# PUBLIC IP
# ─────────────────────────────────────────────────────────────
resource "azurerm_public_ip" "main" {
  name                = "pip-nextcloud-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "nextcloud-${random_string.suffix.result}"
}

# ─────────────────────────────────────────────────────────────
# HTTP DATA SOURCE ЗА ВАШИЯ IP
# ─────────────────────────────────────────────────────────────
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# ─────────────────────────────────────────────────────────────
# NETWORK SECURITY GROUP
# ─────────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "main" {
  name                = "nsg-nextcloud-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${chomp(data.http.my_ip.response_body)}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ─────────────────────────────────────────────────────────────
# NSG TO SUBNET
# ─────────────────────────────────────────────────────────────
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ─────────────────────────────────────────────────────────────
# NETWORK INTERFACE
# ─────────────────────────────────────────────────────────────
resource "azurerm_network_interface" "main" {
  name                = "nic-nextcloud-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# ─────────────────────────────────────────────────────────────
# LINUX VIRTUAL MACHINE
# ─────────────────────────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-nextcloud-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }
  
  network_interface_ids = [
    azurerm_network_interface.main.id
  ]
  
  os_disk {
    name                 = "osdisk-nextcloud-${random_string.suffix.result}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22_04-lts"
    version   = "latest"
  }
  
  tags = {
    Environment = "demo"
    Application = "Nextcloud"
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────
# AUTOMATIC SHUTDOWN
# ─────────────────────────────────────────────────────────────
resource "azurerm_dev_test_global_vm_shutdown_schedule" "auto_shutdown" {
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  location           = azurerm_resource_group.main.location
  enabled            = true
  
  daily_recurrence_time = "1900"
  timezone              = "Central European Standard Time"
  
  notification_settings {
    enabled         = false
    time_in_minutes = 30
  }
}

# ─────────────────────────────────────────────────────────────
# INSTALL DOCKER & NEXTCLOUD
# ─────────────────────────────────────────────────────────────
resource "azurerm_virtual_machine_extension" "docker_nextcloud" {
  name                 = "install-docker-nextcloud"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  
  settings = <<SETTINGS
    {
      "commandToExecute": "bash -c 'apt-get update && apt-get install -y docker.io docker-compose && usermod -aG docker azureuser && mkdir -p /opt/nextcloud && cd /opt/nextcloud && cat > docker-compose.yml << \"EOF\"\nservices:\n  db:\n    image: mariadb:10.6\n    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW\n    restart: always\n    volumes:\n      - db_data:/var/lib/mysql\n    environment:\n      - MYSQL_ROOT_PASSWORD=NextcloudRootP@ss123\n      - MYSQL_PASSWORD=NextcloudP@ss123\n      - MYSQL_DATABASE=nextcloud\n      - MYSQL_USER=nextcloud\n  redis:\n    image: redis:alpine\n    restart: always\n  nextcloud:\n    image: nextcloud:stable-apache\n    restart: always\n    ports:\n      - \"80:80\"\n    volumes:\n      - nextcloud_data:/var/www/html/data\n    environment:\n      - MYSQL_HOST=db\n      - MYSQL_PASSWORD=NextcloudP@ss123\n      - MYSQL_DATABASE=nextcloud\n      - MYSQL_USER=nextcloud\n      - REDIS_HOST=redis\n    depends_on:\n      - db\n      - redis\nvolumes:\n  db_data:\n  nextcloud_data:\nEOF\ndocker compose up -d'"
    }
  SETTINGS
  
  depends_on = [azurerm_linux_virtual_machine.main]
}

# ─────────────────────────────────────────────────────────────
# ЗАПАЗВАНЕ НА PRIVATE SSH КЛЮЧА КАТО OUTPUT
# ─────────────────────────────────────────────────────────────
resource "local_file" "private_key" {
  content  = tls_private_key.ssh.private_key_pem
  filename = "${path.module}/nextcloud-ssh-key.pem"
  file_permission = "0600"
}