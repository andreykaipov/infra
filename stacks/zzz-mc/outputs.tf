output "minecraft_java_fqdn" {
  description = "The FQDN of the Minecraft Java server"
  value       = module.minecraft_java.fqdn
}

output "player_monitor_fqdn" {
  description = "The FQDN of the player monitor service"
  value       = module.player_monitor.fqdn
}

output "backup_manager_fqdn" {
  description = "The FQDN of the backup manager service"
  value       = module.backup_manager.fqdn
}
