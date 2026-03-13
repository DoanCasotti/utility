# ==============================================================================
# Variables - Configuração do Projeto
# ==============================================================================

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "DataApp"
}

variable "environment" {
  description = "Ambiente (Prod, Dev, HML)"
  type        = string
  default     = "Prod"
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS Profile"
  type        = string
  default     = "default"
}

variable "db_username" {
  description = "Usuário do banco RDS"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "Senha do banco RDS"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "bastion_instance_type" {
  description = "Tipo da instância Bastion"
  type        = string
  default     = "t3.nano"
}

variable "rds_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "Storage alocado para RDS (GB)"
  type        = number
  default     = 20
}
