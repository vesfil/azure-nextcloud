output "nextcloud_url" {
  description = "URL за достъп до Nextcloud"
  value       = "http://${azurerm_public_ip.main.domain_name_label}.${var.location}.cloudapp.azure.com"
}

output "ssh_command" {
  description = "SSH команда за свързване"
  value       = "ssh -i nextcloud-ssh-key.pem azureuser@${azurerm_public_ip.main.domain_name_label}.${var.location}.cloudapp.azure.com"
}

output "resource_group_name" {
  description = "Име на ресурсната група"
  value       = azurerm_resource_group.main.name
}

output "private_key" {
  description = "Приватният SSH ключ (запазете го сигурно!)"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}