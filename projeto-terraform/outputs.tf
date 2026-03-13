# ==============================================================================
# Outputs
# ==============================================================================

output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "bastion_instance_id" {
  description = "ID da instância Bastion"
  value       = aws_instance.bastion.id
}

output "bastion_instance_state" {
  description = "Estado da instância Bastion"
  value       = aws_instance.bastion.instance_state
}

output "rds_endpoint" {
  description = "Endpoint do RDS"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "Endereço do RDS"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "rds_port" {
  description = "Porta do RDS"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.main.db_name
}

output "connection_command" {
  description = "Comando para conectar ao banco"
  value       = "psql -h localhost -p 5433 -U ${var.db_username} -d postgres"
  sensitive   = true
}
