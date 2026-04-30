# ─────────────────────────────────────────────────────────────
# REGION & RESOURCE GROUP
# ─────────────────────────────────────────────────────────────
variable "location" {
  description = "Azure регион"
  type        = string
  default     = "switzerlandnorth"
}

variable "resource_group_name" {
  description = "Име на ресурсната група"
  type        = string
  default     = "rg-nextcloud"
}

# ─────────────────────────────────────────────────────────────
# VM CONFIGURATION
# ─────────────────────────────────────────────────────────────
variable "vm_name" {
  description = "Име на виртуалната машина"
  type        = string
  default     = "nextcloud"
}

variable "vm_size" {
  description = "Размер на VM (Standard_B1s е най-евтиният)"
  type        = string
  default     = "Standard_B1s"
}

variable "os_disk_size_gb" {
  description = "Размер на OS диска в GB"
  type        = number
  default     = 30
}

# ─────────────────────────────────────────────────────────────
# ADMIN CONFIGURATION
# ─────────────────────────────────────────────────────────────
variable "admin_username" {
  description = "Потребителско име за администриране"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Път до публичния SSH ключ"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_ip" {
  description = "IP адрес, от който е разрешен SSH достъп (за сигурност)"
  type        = string
  default     = "0.0.0.0/0"
  # ВНИМАНИЕ! За production сменете с вашия IP: "123.45.67.89/32"
}

# ─────────────────────────────────────────────────────────────
# AUTOMATION
# ─────────────────────────────────────────────────────────────
variable "shutdown_time" {
  description = "Час за автоматично изключване на VM (24-часов формат)"
  type        = string
  default     = "19:00"
}

# ─────────────────────────────────────────────────────────────
# DATA DISK (опционален - за демо не ви трябва)
# ─────────────────────────────────────────────────────────────
variable "add_data_disk" {
  description = "Добавяне на допълнителен диск за данни"
  type        = bool
  default     = false
}

variable "data_disk_size_gb" {
  description = "Размер на допълнителния диск в GB"
  type        = number
  default     = 100
}

# ─────────────────────────────────────────────────────────────
# TAGS
# ─────────────────────────────────────────────────────────────
variable "tags" {
  description = "Тагове за ресурсите"
  type        = map(string)
  default = {
    Environment  = "demo"
    Application  = "Nextcloud"
    ManagedBy    = "Terraform"
    AutoShutdown = "true"
  }
}